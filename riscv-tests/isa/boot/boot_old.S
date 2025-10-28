#include "riscv_test.h"
#include "test_macros.h"

#define GPIO_BASE           0x4000 // Base address for GPIO registers
#define GPIO_INPUT_REG      0x00  // RegSlotPxIN  
#define GPIO_OUT_REG        0x04  // RegSlotPxOUT
#define GPIO_OUT_SET_REG    0x08  // RegSlotPxOUTS
#define GPIO_OUT_CLR_REG    0x0C  // RegSlotPxOUTC
#define GPIO_OUT_TOG_REG    0x10  // RegSlotPxOUTT
#define GPIO_DIR_REG        0x14  // RegSlotPxDIR
#define GPIO_IFG_REG        0x18  // RegSlotPxIFG x
#define GPIO_IES_REG        0x1C  // RegSlotPxIES x
#define GPIO_IE_REG         0x20  // RegSlotPxIE x
#define GPIO_SEL_REG        0x24  // RegSlotPxSEL
#define GPIO_REN_REG        0x28  // RegSlotPxREN
#define GPIO_JUNK_REG       0x2C  // Junk Reg for Testing

.equ RAM_BASE,            0x8000
.equ SPI_FLASH_BASE,      0x4200
.equ FLASH_ADDR_OFFSET,   0x0000
.equ SPI_FLASH_RX,          0x0C
.equ SPI_FLASH_TX,          0x08
.equ SPI_FLASH_FOS,         0x10
.equ SPI_FLASH_SR,          0x04
.equ SPI_FLASH_CR,          0x00
.equ SPI_FLASH_CR_VALUE,    0x000004C0 # SPI Flash Control Register value:
.equ FLASH_SLAVE_PU, 0xAB
.equ FLASH_SLAVE_SRREAD, 0xD7
.equ SPI_FLASH_SR_VAL, 0x01 # SPI Flash Status Register value for busy check


# Documentation:
# NUM_WORDS is defined as 2048, representing the total number of 32-bit words in an 8KB memory region.
# This is calculated by dividing the total size (8KB) by the size of each word (4 bytes).
# SPI_Flash Control Register (CR) bit definitions:
# - Bit 18: spi_flash_en   -- SPI Flash enable
#       Enable Extended Flash Memory. '0' = disabled, '1' = enabled
# - Bit 17: spi_tx_sb     -- SPI transmit swap bytes
#       Transmit swap bytes. '0' = no byte swap; '1' = bytes swapped
# - Bit 16: spi_rx_sb     -- SPI receive swap bytes
#       Receive swap bytes. '0' = no byte swap; '1' = bytes swapped
# - Bits 15:8: spi_br     -- SPI baud rate (clock divider)
#       Baud Rate. Baud rate = SMCLK / (2 * (1 + SCBR))
# - Bit 7: spi_en         -- SPI peripheral enable
#       Enable SPI. '0' = disabled, '1' = enabled
# - Bit 6: spi_msb        -- SPI MSB first select
#       MSB first. '0' = LSB first, '1' = MSB first
# - Bit 5: spi_tcie       -- SPI transmit complete interrupt enable
#       Transmit Complete Interrupt Enable. '1' = disabled, '0' = enabled
# - Bit 4: spi_teie       -- SPI transmit buffer empty interrupt enable
#       Transmit Buffer Empty Interrupt Enable. '1' = disabled, '0' = enabled
# - Bits 3:2: spi_dl      -- SPI data length
#       Data length. "00" = 8-bit transfers; "01" = 16-bit transfers; "10" = 32-bit transfers; "11" = reserved
# - Bit 1: spi_cpol       -- SPI clock polarity
#       Clock polarity. '0' = low when idle, '1' = high when idle
# - Bit 0: spi_cpha       -- SPI clock phase
#       Clock phase. '0' = data sampled on first edge, '1' = data sampled on second edge
# 0 0 0 (0000)(0100) (1 1 0 0) (00 0 0) 
# x 000004C0 8 bit commands to slave

.equ NUM_WORDS, 2048    # 8KB / 4 bytes per word = 2048 words

#define BOOT_COPY(labelprefix)                             \
    li t0, RAM_BASE                /* RAM base address (destination pointer) */ ; \
    li t1, SPI_FLASH_BASE          /* SPI flash base address (peripheral base) */ ; \
    li t2, NUM_WORDS               /* Number of words to copy (loop counter) */ ; \
    li t3, FLASH_ADDR_OFFSET       /* Flash offset (source pointer) */ ; \
    li t4, SPI_FLASH_CR_VALUE      /* Control register value */ ; \
    li s1, FLASH_SLAVE_PU          /* Flash Slave Power Up value */ ; \
    li s2, FLASH_SLAVE_SRREAD      /* Flash Slave Status Register Read value */ ; \
    sw t3, SPI_FLASH_FOS(t1)       /* Write initial flash offset */ ; \
    sw t4, SPI_FLASH_CR(t1)        /* Set SPI control register */ ; \
    sw s1, SPI_FLASH_TX(t1)        /* Write Flash Slave Power Up command */ ; \
labelprefix##_wait_tx_empty:       /* Wait for SPIxTX buffer to be empty */ ; \
labelprefix##_wait_ready:       /* Wait for SPIxTX buffer to be empty */ ; \
    lw s3, SPI_FLASH_SR(t1)        /* Load SPIxSR into s3 */ ; \
    andi t6, s3, 1                 /* Check LSB */ ; \
    beqz t6, labelprefix##_wait_tx_empty /* If not empty, keep waiting */ ; \
    sw s2, SPI_FLASH_TX(t1)        /* Send Status Register Read command (D7) */ ; \
    li s4, SPI_FLASH_SR_VAL        /* Store SPIxSR value to memory */ ; \
    sw s4, SPI_FLASH_SR(t1)         /* Write status register value */ ; \
    lw t5, SPI_FLASH_RX(t1)        /* Read RX value into t5 */ ; \
    andi t6, t5, 0x80              /* Mask bit 7 (0x80) */ ; \
    beqz t6, labelprefix##_wait_ready /* If bit 7 not set, repeat (send D7 again) */ ; \
labelprefix##_copy_loop:           /* Start of copy loop (unique label prefix) */ ; \
    sw t3, SPI_FLASH_FOS(t1)       /* Write current flash offset to Flash Offset Select register */ ; \
labelprefix##_wait_busy:           /* Busy-wait loop label (unique label prefix) */ ; \
    lw t5, SPI_FLASH_SR(t1)        /* Read SPI flash status register into t5 */ ; \
    andi t5, t5, 1                 /* Mask all but the least significant bit (busy flag) in t5 */ ; \
    bnez t5, labelprefix##_wait_busy /* If busy flag is set, repeat wait loop */ ; \
    lw t6, SPI_FLASH_RX(t1)        /* Load received word from SPI flash RX register into t6 */ ; \
    sw t6, 0(t0)                   /* Store received word from t6 into RAM at t0 */ ; \
    addi t0, t0, 4                 /* Increment RAM pointer to next word */ ; \
    addi t3, t3, 4                 /* Increment flash offset to next word */ ; \
    addi t2, t2, -1                /* Decrement loop counter */ ; \
    bnez t2, labelprefix##_copy_loop /* If words remain, repeat copy loop */ ;
    
    .section .text
    .globl _start
_start:
    # Set the SPI control register
    li t1, SPI_FLASH_BASE
    li t2, SPI_FLASH_CR_VALUE
    sw t2, SPI_FLASH_CR(t1)

    # Copy 1024 words from flash to RAM
    BOOT_COPY(bootmain)

    # Jump to RAM base
    li ra, RAM_BASE
    jr ra