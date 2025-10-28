//#define ENABLE_QREGS

// Only save registers in IRQ wrapper that are to be saved by the caller in
// the RISC-V ABI, with the excepetion of the stack pointer. The IRQ handler
// will save the rest if necessary. I.e. skip x3, x4, x8, x9, and x18-x27.

//#undef ENABLE_FASTIRQ

// Includes
#include "custom_ops.S"
#include "periph.S"

// Defines
.equ DELAY, 1500
.equ CS_FLASH_MASK_INV, ~CS_FLASH_MASK
.equ BOOT_MASK_INV, ~BOOT_MASK

// Globals
.global main

// Main code
.section .text

#ifdef BOOTLOADER_USES_SPI_FLASH_COMMANDS
SpiBoot:
	// Loads the program stored on the SPI flash into RAM, then executes it
	// This is what is executed first when the system is reset
	
	// Disable all interrupts and set them to high priority
	li a0, SYSTEM_BASE
	sw zero, IRQEN_OFFSET(a0)
	sw zero, IRQPRI_OFFSET(a0)

	// Initialize the stack pointer
	li sp, StackPointerInit	// This is the stack pointer, x2

	// Turn on all memory by setting MEMPWRCR to zero
	sw zero, MEMPWRCR_OFFSET(a0)	// (a0 = SYSTEM_BASE) Clear MEMPWRCR
	
	// Set a0 to contain the SPI0 base address
	li a0, SPI0_BASE
	
	// Set a1 to contain the Port 1 base address
	li a1, GPIO1_BASE
	
	// Set pin BOOT on GPIO1 to input mode and CS_FLASH to output mode
	li a2, CS_FLASH_MASK	// CS_FLASH bit is '1', BOOT bit is '0'
	sb a2, PxDIR_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a2 to P1DIR

	// Set P1SEL so that all the Port 1 pins are configured properly in GPIO mode or peripheral mode
	li a2, P1SEL_BOOT_VAL
	sb a2, PxSEL_OFFSET(a1)
	
	// Set a2 to contain the current RAM address, beginning with the RAM start address
	li a2, RamStartAddress
	
	// Set a3 to contain the end RAM address
	li a3, RamStartAddress + RamSize
	
	// Port 1 OR bit mask for CS. Set a4 as all '0's, except the CS bit is a '1'
	li a4, CS_FLASH_MASK	// Update this with a '1' for CS
	
	// Port 1 AND bit mask for CS. Set a5 as all '1's, except the CS bit is a '0'
	//li a5, CS_FLASH_MASK_INV	// Update this with a '0' for CS, and the rest are '1's

checkBootPin:
	// Check if the BOOT pin is set to forth interpreter mode or SPI flash mode. The BOOT pin must reset to GPIO input mode
	// If BOOT = '0': Launch the forth interpreter from ROM
	// If BOOT = '1': Launch the program stored in the SPI flash memory
	lw a5, PxIN_OFFSET(a1)	// Load P1IN into a5
	andi a5, a5, BOOT_MASK	// a5 &= BOOT_MASK, so only the BOOT_BIT can be a '1'
	beqz a5, main	// If BOOT = '0', launch the forth interpreter from ROM, otherwise continue and load the program in the SPI flash
	
	// Clear SPI0SR status register
setupSPI_1:
	not a6, zero
	sw a6, SPIxSR_OFFSET(a0)	// (a0 = SPI_BASE) Clear SPI0SR
	
	// Set up SPI0 with SPIMODE3 (CPHA = 1, CPOL = 1), DL = 8 bits (SPIDL = "00"), MSB first, enabled, fast baud
	//li a6, 0x00C3	// The SPI0CR register value
	li a6, (SPICPOL | SPICPHA | SPIDL_8 | SPIMSB | SPIEN)
	sw a6, SPIxCR_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0CR
	
	// Assert CS (set CS low)
assertCS_1:
	sw a4, PxOUTC_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTC, clearing the CS_FLASH bit
	
	// Send command over SPI to wake the SPI flash from deep power down mode
sendWakeup:
	li a6, 0xAB	// The SPI flash command to wake from deep power down mode
	sw a6, SPIxTX_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0TXBUF
	
	// Wait for the command to finish sending
	jal ra, spi0_wait_for_current_transmission_to_finish
	
	// Deassert CS (set CS high)
deassertCS_1:
	sw a4, PxOUTS_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTS, setting the CS_FLASH bit
	
	// Delay for at least 30 us to allow the SPI flash to wake up
	li a6, DELAY	//	The number of delay cycles to perform
delay1:
	addi a6, a6, -1	// Subtract 1 from a6 every delay cycle (is this sign extended???)
	bnez a6, delay1	// Go back to delay1 if the delay counter in a6 has not reached zero yet
	
	// Assert CS (set CS low)
assertCS_2:
	sw a4, PxOUTC_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTC, clearing the CS_FLASH bit
	
	// Send command over SPI to set to read mode
sendReadCmd:
	li a6, 0x0B	// The SPI flash command for read mode (high frequency)
	sw a6, SPIxTX_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0TXBUF
	
	// Wait for the command to finish sending
	jal ra, spi0_wait_for_current_transmission_to_finish
	
	// Set up SPI0 with SPIMODE3 (CPHA = 1, CPOL = 1), DL = 32 bits (SPIDL = "10"), MSB first, swap bytes, enabled, fast baud
setupSPI_2:
	//li a6, 0x100CB	// The SPI0CR register value
	li a6, (SPICPOL | SPICPHA | SPIDL_32 | SPIMSB | SPIEN | SPIRXSB)
	sw a6, SPIxCR_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0CR
	
	// Send the 24-bit start address with a dummy byte on the end
sendAddress:
	// Start reading the SPI Flash memory at its address 0x00000000
	sw zero, SPIxTX_OFFSET(a0)	// (a0 = SPI0_BASE) Store 0x00000000 to SPI0TXBUF
	
	// Wait for the command to finish sending
	jal ra, spi0_wait_for_current_transmission_to_finish
	
	// Clear SPI0SR
clearSR_1:
	not a6, zero
	sw a6, SPIxSR_OFFSET(a0)




// Send a 0x00000000 to the SPI flash, during which time the SPI flash will respond with the command word
sw zero, SPIxTX_OFFSET(a0)	// Store 0 to SPI0TXBUF

getCommand:
	// Get the command from the SPI flash
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the command word in register t0
	li a7, 0x831D2F7C	// Store the "dump segment" command in a7
	beq t0, a7, dumpSegmentToRam	// If this is the "dump segment" command, jump to that function
	li a7, 0xDBE556E8	// Store the "erase segment" command in a7
	beq t0, a7, eraseSegment	// If this is the "erase segment" command, jump to that function
	li a7, 0x44573DB0	// Store the "write word" command in a7
	beq t0, a7, writeWord
	li a7, 0x1EC021EE	// Store the "write masked word" command in a7
	beq t0, a7, writeMaskedWord
	li a7, 0xAE3BF97C	// Store the "execute program" command in a7
	beq t0, a7, finishBootloadingProcess	// If this is the "execute program" command, jump to the function that finishes the bootloading process
	j force_trap	// If execution gets to this point, force a trap condition



	
dumpSegmentToRam:
	// FORMAT:
	//	word[0]: dump segment command 0x831D2F7C
	//	word[1]: start address of RAM segment to dump to
	//	word[2]: end address of RAM segment to dump to (not inclusive)
	//	word[3, ..., 3 + (end address - start address) / 4]: The words to dump to the RAM segment. Must be exactly (end address - start address) / 4 words long.
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the start address of the RAM segment to load in register t0
	addi a2, t0, 0	// Copy t0 (which contains the start address) to a2 (which will contain the current RAM destination address)
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the stop address of the RAM segment to load in register t0
	addi a3, t0, 0	// Copy t0 (which contains the start address) to a3 (which will contain the stop RAM destination address)

	// Error checking
	bgeu a2, a3, force_trap	// If start address >= stop address, make a trap condition
	li a6, RamStartAddress
	bltu a2, a6, force_trap	// If start address < peripheral memory start address, make a trap condition
	li a6, RamStartAddress + RamSize
	bltu a6, a3, force_trap	// If RAM end address < end address, make a trap condition
	
	// Read the SPI RX buffer and store it in the next RAM location
readNextProgramWord:
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the next RAM value in register t0
	// This is assuming that for every four bytes stored in the SPI flash, byte0 and byte3 are swapped, and byte1 and byte2 are swapped.
	sw t0, 0(a2)				// Store the data to RAM at the next RAM location
	addi a2, a2, 4				// Add 4 (32 bits, 4 bytes) to the next RAM location
	
	// If the next RAM address < stop address, loop back to read the next word
	bltu a2, a3, readNextProgramWord

	// Loop back to getCommand to see if there is another command
	j getCommand





eraseSegment:
	// FORMAT:
	//	word[0]: erase segment command 0xDBE556E8
	//	word[1]: start address of RAM segment to erase
	//	word[2]: end address of RAM segment to erase (not inclusive)
	//	word[3]: The value to write each word in the erase segment of the RAM as.
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the start address of the RAM segment in register t0
	addi a2, t0, 0	// Copy t0 (which contains the start address) to a2 (which will contain the current RAM destination address)
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the stop address of the RAM segment in register t0
	addi a3, t0, 0	// Copy t0 (which contains the start address) to a3 (which will contain the stop RAM destination address)
	
	// Error checking
	bgeu a2, a3, force_trap	// If start address >= stop address, make a trap condition
	li a6, RamStartAddress
	bltu a2, a6, force_trap	// If start address < peripheral memory start address, make a trap condition
	li a6, RamStartAddress + RamSize
	bltu a6, a3, force_trap	// If RAM end address < end address, make a trap condition

	// Get the "erase" word, which is what each word to be erased will be written as
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the "erase" word in register t0 (if this is was the last word, then this function will actually read the next command from the SPI flash)

eraseNextWord:
	sw t0, 0(a2)	// Store the "erase" word (contained in t0) to the next RAM location
	addi a2, a2, 4	// Add 4 (32 bits, 4 bytes) to the next RAM location

	// If the next RAM address < stop address, loop back to erase the next word
	bltu a2, a3, eraseNextWord

	// Loop back to getCommand to see if there is another command
	j getCommand





writeWord:
	// FORMAT:
	//	word[0]: write word command 0x44573DB0
	//	word[1]: address of on-chip memory to write to
	//	word[2]: the value of to write to the on-chip memory
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the address memory location to write to
	addi a2, t0, 0	// Copy t0 (which contains the start address) to a2 (which will contain the address)
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the value to write
	addi a3, t0, 0	// Copy t0 (which contains the start address) to a3 (which will contain the stop RAM destination address)
	
	// Error checking
	li a6, PeripheralMemoryStartAddress
	bltu a2, a6, force_trap	// If address < peripheral memory start address, make a trap condition
	li a6, RamStartAddress + RamSize
	bltu a6, a2, force_trap	// If RAM end address < address, make a trap condition

	// Write to the memory location
	sw a3, 0(a2)	// Stores the value of a3 (the memory value) to the address in a2 (the memory address)

	// Loop back to getCommand to see if there is another command
	j getCommand





writeMaskedWord:
	// FORMAT:
	//	word[0]: write masked word command 0x1EC021EE
	//	word[1]: address of on-chip memory to write to
	//	word[2]: the value of to write to the on-chip memory
	//	word[3]: the mask. The value of the on-chip memory word will end up being newValue = (currentValue & ~mask) | (writeValue & mask)
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the address memory location to write to
	addi a2, t0, 0	// Copy t0 (which contains the start address) to a2 (which will contain the address)
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the value to write
	addi a3, t0, 0	// Copy t0 (which contains the start address) to a3 (which will contain the stop RAM destination address)
	
	// Error checking
	li a6, PeripheralMemoryStartAddress
	bltu a2, a6, force_trap	// If address < peripheral memory start address, make a trap condition
	li a6, RamStartAddress + RamSize
	bltu a6, a2, force_trap	// If RAM end address < address, make a trap condition

	// Get the mask
	jal ra, spi0_finish_current_read_then_start_next_read	// returns the mask
	addi a6, t0, 0	// Copy t0 (which contains the start address) to a6 (which will contain the mask)

	// Mask the data to write
	and a3, a3, a6	// a3 (masked word to write) = a3 (not-yet-masked word to write) & a6 (mask)

	// Read the memory location
	lw t0, 0(a2)	// Read the data at location a2 (the memory address) and store it in t0

	// Inverse mask the memory location
	not a6, a6	// Invert the mask
	and t0, t0, a6	// t0 (inverse masked current memory value) = t0 (current memory value) & a6 (~mask)

	// OR the maked word to write with the inverse masked current memory value
	or a3, a3, t0	// a3 (value to write) = a3 (masked word to write) | t0 (inverse masked current memory value)

	// Write to the memory location
	sw a3, 0(a2)	// Stores the value of a3 (the memory value) to the address in a2 (the memory address)

	// Loop back to getCommand to see if there is another command
	j getCommand






finishBootloadingProcess:
	// Wait for the transfer to complete
	jal ra, spi0_wait_for_current_transmission_to_finish
	
	// Deassert CS (set CS high)
deassertCS_2:
	sw a4, PxOUTS_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTS, setting the CS_FLASH bit
	
	// Set up SPI0 with SPIMODE3 (CPHA = 1, CPOL = 1), DL = 8 bits (SPIDL = "00"), MSB first, enabled, fast baud
setupSPI_3:
	//li a6, 0x00C3	// The SPI0CR register value
	li a6, (SPICPOL | SPICPHA | SPIDL_8 | SPIMSB | SPIEN)
	sw a6, SPIxCR_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0CR
	
	// Assert CS (set CS low)
assertCS_3:
	sw a4, PxOUTC_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTC, clearing the CS_FLASH bit
	
	// Send command to SPI flash to put it in deep power down mode
sendSleepCmd:
	li a6, 0xB9	// The SPI flash command for deep power down mode
	sw a6, SPIxTX_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0TXBUF

	// Wait for the command to finish sending
	jal ra, spi0_wait_for_current_transmission_to_finish
	
	// Deassert CS (set CS high)
deassertCS_3:
	sw a4, PxOUTS_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTS, setting the CS_FLASH bit
	
	// Initialize all registers
initRegs:
	li x1, 0
	li sp, StackPointerInit	// This is the stack pointer, x2
	li x3, 0
	li x4, 0
	li x5, 0
	li x6, 0
	li x7, 0
	li x8, 0
	li x9, 0
	li x10, 0
	li x11, 0
	li x12, 0
	li x13, 0
	li x14, 0
	li x15, 0
	li x16, 0
	li x17, 0
	li x18, 0
	li x19, 0
	li x20, 0
	li x21, 0
	li x22, 0
	li x23, 0
	li x24, 0
	li x25, 0
	li x26, 0
	li x27, 0
	li x28, 0
	li x29, 0
	li x30, 0
	li x31, 0
	
	// Jump to the beginning of the RAM
jumpToMain:
	j RamProgramStartAddress



/** Functions **/
spi0_finish_current_read_then_start_next_read:
	// First, waits for the SPI0TX buffer to be empty. Then, transmits a 0 to SPI0TX to queue that bit for the next transmission. Then, waits for the current SPI0 transfer to be complete. Then, loads SPI0RX into register t0.
	// Arguments: none
	// Returns:
	//	register t0: the byte received (swapped to be in the correct order
	// Depends on the following registers:
	//	a0: contains SPI0_BASE
	// Modifies the following registers:
	//	a7, t0

	// Wait for the SPI0TX register to be empty
	lw a7, SPIxSR_OFFSET(a0)	// (a0 = SPI_BASE) Read SPI0SR and store in a7
	andi a7, a7, SPITEIF	// Zero everything except SPITEIF
	beqz a7, spi0_finish_current_read_then_start_next_read	// Loop back again to read SPI0SR if SPITEIF is a 0 (aka wait until SPITEIF == 1, meaning the TX buffer is empty)
	sw a7, SPIxSR_OFFSET(a0)	// (a0 = SPI_BASE) Clear SPITEIF by setting it to 1

	// Queue the next word for transmission (a zero)
	sw zero, SPIxTX_OFFSET(a0)	// Write 0x00000000 to SPI0TX, queueing 0x00000000 for the next transmission. Writing to SPI0TX also clears SPITEIF

	// Wait for the current transmission to finish
spi0_wait_for_current_transmission_to_finish:
	lw a7, SPIxSR_OFFSET(a0);	// (a0 = SPI_BASE) Read SPI0SR and store in a7
	andi a7, a7, SPITCIF	// Zero everything except SPITCIF
	beqz a7, spi0_wait_for_current_transmission_to_finish	// Loop back again to read SPI0SR if SPITCIF is a 0 (aka wait until SPITCIF == 1, meaning the SPI transfer is complete)

	// Load the received word to register t0
	lw t0, SPIxRX_OFFSET(a0)	// (a0 = SPI_BASE) Read SPI0RX and store in t0. Reading SPI0RX also clears SPITCIF
	ret

force_trap:
	.word 0xFFFFFFFF







#else	// #ifdef BOOTLOADER_USES_SPI_FLASH_COMMANDS

SpiBoot:
	// Loads the program stored on the SPI flash into RAM, then executes it
	// This is what is executed first when the system is reset
	
	// Disable all interrupts and set them to high priority
	li a0, SYSTEM_BASE
	sw zero, IRQEN_OFFSET(a0)
	sw zero, IRQPRI_OFFSET(a0)

	// Initialize the stack pointer
	li sp, StackPointerInit	// This is the stack pointer, x2

	// Turn on all memory by setting MEMPWRCR to zero
	sw zero, MEMPWRCR_OFFSET(a0)	// (a0 = SYSTEM_BASE) Clear MEMPWRCR
	
	// Set a0 to contain the SPI0 base address
	li a0, SPI0_BASE
	
	// Set a1 to contain the Port 1 base address
	li a1, GPIO1_BASE
	
	// Set pin BOOT on GPIO1 to input mode and CS_FLASH to output mode
	li a2, CS_FLASH_MASK	// CS_FLASH bit is '1', BOOT bit is '0'
	sb a2, PxDIR_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a2 to P1DIR

	// Set P1SEL so that all the Port 1 pins are configured properly in GPIO mode or peripheral mode
	li a2, P1SEL_BOOT_VAL
	sb a2, PxSEL_OFFSET(a1)
	
	// Set a2 to contain the current RAM address, beginning with the RAM start address
	li a2, RamStartAddress
	
	// Set a3 to contain the end RAM address
	li a3, RamStartAddress + RamSize
	
	// Port 1 OR bit mask for CS. Set a4 as all '0's, except the CS bit is a '1'
	li a4, CS_FLASH_MASK	// Update this with a '1' for CS
	
	// Port 1 AND bit mask for CS. Set a5 as all '1's, except the CS bit is a '0'
	//li a5, CS_FLASH_MASK_INV	// Update this with a '0' for CS, and the rest are '1's

checkBootPin:
	// Check if the BOOT pin is set to forth interpreter mode or SPI flash mode. The BOOT pin must reset to GPIO input mode
	// If BOOT = '0': Launch the forth interpreter from ROM
	// If BOOT = '1': Launch the program stored in the SPI flash memory
	lw a5, PxIN_OFFSET(a1)	// Load P1IN into a5
	andi a5, a5, BOOT_MASK	// a5 &= BOOT_MASK, so only the BOOT_BIT can be a '1'
	beqz a5, main	// If BOOT = '0', launch the forth interpreter from ROM, otherwise continue and load the program in the SPI flash
	
	// Clear SPI0SR status register
setupSPI_1:
	not a6, zero
	sw a6, SPIxSR_OFFSET(a0)	// (a0 = SPI_BASE) Clear SPI0SR
	
	// Set up SPI0 with SPIMODE3 (CPHA = 1, CPOL = 1), DL = 8 bits (SPIDL = "00"), MSB first, enabled, fast baud
	//li a6, 0x00C3	// The SPI0CR register value
	li a6, (SPICPOL | SPICPHA | SPIDL_8 | SPIMSB | SPIEN)
	sw a6, SPIxCR_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0CR
	
	// Assert CS (set CS low)
assertCS_1:
	sw a4, PxOUTC_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTC, clearing the CS_FLASH bit
	
	// Send command over SPI to wake the SPI flash from deep power down mode
sendWakeup:
	li a6, 0xAB	// The SPI flash command to wake from deep power down mode
	sw a6, SPIxTX_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0TXBUF
	
	// Wait for the command to finish sending
.align 2
wait1:
	lw a7, SPIxSR_OFFSET(a0)	// (a0 = SPI_BASE) Read SPI0SR and store in a7
	andi a7, a7, SPIBUSY	// Is SPIBUSY still active?
	bnez a7, wait1	//	Go back to wait1 if SPIBUSY = 1 (transfer not yet complete)
	
	// Deassert CS (set CS high)
deassertCS_1:
	sw a4, PxOUTS_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTS, setting the CS_FLASH bit
	
	// Delay for at least 30 us to allow the SPI flash to wake up
	li a6, DELAY	//	The number of delay cycles to perform
.align 2
delay1:
	addi a6, a6, -1	// Subtract 1 from a6 every delay cycle (is this sign extended???)
	bnez a6, delay1	// Go back to delay1 if the delay counter in a6 has not reached zero yet
	
	// Assert CS (set CS low)
assertCS_2:
	sw a4, PxOUTC_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTC, clearing the CS_FLASH bit
	
	// Send command over SPI to set to read mode
sendReadCmd:
	li a6, 0x0B	// The SPI flash command for read mode (high frequency)
	sw a6, SPIxTX_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0TXBUF
	
	// Wait for the command to finish sending
.align 2
wait2:
	lw a7, SPIxSR_OFFSET(a0)	// (a0 = SPI_BASE) Read SPI0SR and store in a7
	andi a7, a7, SPIBUSY	// Is SPIBUSY still active?
	bnez a7, wait2	//	Go back to wait2 if SPIBUSY = 2 (transfer not yet complete)
	
	// Set up SPI0 with SPIMODE3 (CPHA = 1, CPOL = 1), DL = 32 bits (SPIDL = "10"), MSB first, swap bytes, enabled, fast baud
setupSPI_2:
	//li a6, 0x100CB	// The SPI0CR register value
	li a6, (SPICPOL | SPICPHA | SPIDL_32 | SPIMSB | SPIEN | SPIRXSB)
	sw a6, SPIxCR_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0CR
	
	// Send the 24-bit start address with a dummy byte on the end
sendAddress:
	//slli a6, a2, 8	// Shift a2 (RamStartAddress) left by 8 and store in a6 (to shift up the 24-bit address and add a dummy byte)
	//sw a6, SPIxTX_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0TXBUF
	// This was modified so that the program begins at address 0x000000 of the SPI Flash
	sw zero, SPIxTX_OFFSET(a0)	// (a0 = SPI0_BASE) Store 0x00000000 to SPI0TXBUF
	
	// Wait for the command to finish sending
.align 2
wait3:
	lw a7, SPIxSR_OFFSET(a0)	// (a0 = SPI_BASE) Read SPI0SR and store in a7
	andi a7, a7, SPIBUSY	// Is SPIBUSY still active?
	bnez a7, wait3	//	Go back to wait3 if SPIBUSY = 2 (transfer not yet complete)
	
	// Clear SPI0SR
clearSR_1:
	not a6, zero
	sw a6, SPIxSR_OFFSET(a0)
	
	// Send a 0x00000000 out over SPI, during which time the SPI flash will respond with the first word
sendZero_1:
	sw zero, SPIxTX_OFFSET(a0)	// Store 0 to SPI0TXBUF
	
.align 2
loadloop:
	// Wait for the transfer to complete with SPITXCIFG (BIT1)
	lw a7, SPIxSR_OFFSET(a0)	// (a0 = SPI_BASE) Read SPI0SR and store in a7
	andi a7, a7, SPITCIF	// Wait until SPITCIF is set
	beqz a7, loadloop	//	Go back to loadloop if SPITXCIFG = 0 (not ready for new byte)
	
	// Clear SPI0SR
clearSR_2:
	not a6, zero
	sw a6, SPIxSR_OFFSET(a0)
	
	// Read the SPI RX buffer and store it in the next RAM location
readRXandStoreAndIncrement:
	// This is assuming that for every four bytes stored in the SPI flash, byte0 and byte3 are swapped, and byte1 and byte2 are swapped. (if commented out, see the previous non-commented code)
	lw a7, SPIxRX_OFFSET(a0)	// a7 now contains the memory to be stored in the next RAM location
	sw a7, SPIxTX_OFFSET(a0)	// Send back what was just received (for debugging)
	sw a7, 0(a2)				// Store the data to RAM at the next RAM location
	addi a2, a2, 4				// Add 4 (32 bits, 4 bytes) to the next RAM location
	
	// If the next RAM location is < the RAM END, loop back
loopback:
	bltu a2, a3, loadloop

wait4:
	// Wait for the transfer to complete with SPITXCIFG (BIT1)
	lw a7, SPIxSR_OFFSET(a0)	// (a0 = SPI_BASE) Read SPI0SR and store in a7
	andi a7, a7, SPITCIF	// Wait until SPITCIF is set
	beqz a7, wait4	//	Go back to wait4 if SPITXCIFG = 0 (not ready for new byte)
	
	// Deassert CS (set CS high)
deassertCS_2:
	sw a4, PxOUTS_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTS, setting the CS_FLASH bit
	
	// Set up SPI0 with SPIMODE3 (CPHA = 1, CPOL = 1), DL = 8 bits (SPIDL = "00"), MSB first, enabled, fast baud
setupSPI_3:
	//li a6, 0x00C3	// The SPI0CR register value
	li a6, (SPICPOL | SPICPHA | SPIDL_8 | SPIMSB | SPIEN)
	sw a6, SPIxCR_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0CR
	
	// Assert CS (set CS low)
assertCS_3:
	sw a4, PxOUTC_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTC, clearing the CS_FLASH bit
	
	// Send command to SPI flash to put it in deep power down mode
sendSleepCmd:
	li a6, 0xB9	// The SPI flash command for deep power down mode
	sw a6, SPIxTX_OFFSET(a0)	// (a0 = SPI0_BASE) Store a6 to SPI0TXBUF

	// Wait for the command to finish sending
.align 2
wait5:
	lw a7, SPIxSR_OFFSET(a0)	// (a0 = SPI_BASE) Read SPI0SR and store in a7
	andi a7, a7, SPIBUSY	// Is SPIBUSY still active?
	bnez a7, wait5	//	Go back to wait5 if SPIBUSY = 1 (transfer not yet complete)
	
	// Deassert CS (set CS high)
deassertCS_3:
	sw a4, PxOUTS_OFFSET(a1)	// (a1 = GPIO1_BASE) Store a4 (CS_FLASH_MASK) to P1OUTS, setting the CS_FLASH bit
	
	// Initialize all registers
initRegs:
	li x1, 0
	li sp, StackPointerInit	// This is the stack pointer, x2
	li x3, 0
	li x4, 0
	li x5, 0
	li x6, 0
	li x7, 0
	li x8, 0
	li x9, 0
	li x10, 0
	li x11, 0
	li x12, 0
	li x13, 0
	li x14, 0
	li x15, 0
	li x16, 0
	li x17, 0
	li x18, 0
	li x19, 0
	li x20, 0
	li x21, 0
	li x22, 0
	li x23, 0
	li x24, 0
	li x25, 0
	li x26, 0
	li x27, 0
	li x28, 0
	li x29, 0
	li x30, 0
	li x31, 0
	
	// Jump to the beginning of the RAM
jumpToMain:
	j RamProgramStartAddress

#endif	// #ifdef BOOTLOADER_USES_SPI_FLASH_COMMANDS