#*****************************************************************************
# SYSTEM_TESTBENCH_ENHANCED.S
#-----------------------------------------------------------------------------
# Enhanced SYSTEM Peripheral testbench for RISC-V assembly (riscv32ui)
# Author: Maxx Seminario
# Date: 08-31-2025
#
# Test Categories:
# 1-4: Register Boundary Tests (4 tests)
# 5-8: Clock Control Tests (4 tests)
# 9-12: Clock Divider Tests (4 tests)
# 13-18: Memory Power Control Tests (6 tests)
# 19-23: Memory Access with Power Control Tests (5 tests)
# 24-27: CRC State Tests (4 tests)
# 28-32: IRQ Comprehensive Tests (5 tests)
# 33-37: Watchdog Comprehensive Tests (5 tests)
# 38-42: Watchdog Counter Behavior Tests (5 tests)
# 43-44: Register Reset Behavior Tests (2 tests)
#-----------------------------------------------------------------------------

#include "riscv_test.h"
#include "test_macros.h"
#include "myshkin_s.h"


#define SYS_WDT_CDIV_MAX   0x1E 
#define SYS_CLK_CR_VAL 0x2
#define SYS_CLK_DIV_MCLKFST 0x18



RVTEST_RV32U
RVTEST_CODE_BEGIN

# Configure smclk to be hfxt
system_init: 
    li  a0, PERIPH_SYSTEM0_BASE
    sw zero, SYS_CLK_CR(a0)  # Disable clock
    mv a0, zero

# Register usage convention
li a0, PERIPH_SYSTEM0_BASE
li a1, 0  # Test counter

# ------------------------------------------------------------------------------
# Test Suite
# ------------------------------------------------------------------------------
jal ra, test_register_boundaries
jal ra, test_clk_control_enhanced
jal ra, test_clk_divider_enhanced
jal ra, test_mem_power_enhanced
jal ra, test_memory_access_with_power_control
jal ra, test_crc_state_enhanced
jal ra, test_irq_comprehensive
jal ra, test_wdt_comprehensive
jal ra, test_wdt_counter_behavior
jal ra, test_register_reset_behavior

# Success
all_sys_tests_passed:
    TEST_PASSFAIL

# ===============================================================================
# Tests 1-4: Register Boundary and Reserved Bit Tests
# ===============================================================================
test_register_boundaries:
    mv s1, ra
    
    # Test 1: SYS_CLK_CR - 16-bit register
    addi gp, gp, 1
    li s3, SYS_CLK_CR_VAL

    sw s3, SYS_CLK_CR(a0)
    lw t0, SYS_CLK_CR(a0)
    bne t0, s3, fail

    # Test 2: SYS_CLK_DIV_CR - 6-bit register
    addi gp, gp, 1
    li s3, SYS_CLK_DIV_MCLKFST
    sw s3, SYS_CLK_DIV_CR(a0)
    lw t0, SYS_CLK_DIV_CR(a0)
    bne t0, s3, fail

    # Test 3: SYS_BLOCK_PWR - 4-bit register
    addi gp, gp, 1
    sw zero, SYS_BLOCK_PWR(a0)
    lw t0, SYS_BLOCK_PWR(a0)
    bne t0, zero, fail

    #Enable All interrupts 
    li s3, -1
    sw s3, SYS_IRQ_EN(a0)

    # Test 4: SYS_WDT_CR - with wdt locked
    addi gp, gp, 1
    sw gp, SYS_WDT_PASS(a0)
    li s3, 0x7E
    sw s3, SYS_WDT_CR(a0)
    lw t0, SYS_WDT_CR(a0)
    beq t0, s3, fail

    # Test 5: SYS_WDT_CR - with wdt unlocked
    addi gp, gp, 1
    li s3, WDT_UNLCK_PASSWD
    sw s3, SYS_WDT_PASS(a0)
    li s3, 0x7E
    sw s3, SYS_WDT_CR(a0)
    lw t0, SYS_WDT_CR(a0)
    bne t0, s3, fail

    # Clear all registers
    sw zero, SYS_CLK_CR(a0)
    sw zero, SYS_CLK_DIV_CR(a0)
    sw zero, SYS_BLOCK_PWR(a0)
    sw zero, SYS_WDT_CR(a0)

    mv ra, s1
    ret

# ===============================================================================
# Tests 6-9: Enhanced Clock Control Tests
# ===============================================================================
test_clk_control_enhanced:
    mv s1, ra
    li a0, PERIPH_SYSTEM0_BASE

    # Test 6: MCLK_SEL
    addi gp, gp, 1
    li s3, SYS_SMCLK_OFF_MASK | SYS_MCLK_SEL_MASK
    sw s3, SYS_CLK_CR(a0)
    lw t0, SYS_CLK_CR(a0)
    and t0, t0, SYS_SMCLK_OFF_MASK | SYS_MCLK_SEL_MASK
    beqz t0, fail

    # Test 7: SYS_SMCLK_SEL_MASK
    addi gp, gp, 1
    li s3, SYS_SMCLK_SEL_MASK
    sw s3, SYS_CLK_CR(a0)
    lw t0, SYS_CLK_CR(a0)
    and t0, t0, SYS_SMCLK_SEL_MASK
    beqz t0, fail

    # Test 8: Clock disable bits
    addi gp, gp, 1
    li s3, SYS_CLK_HFXT_OFF_MASK | SYS_CLK_LFXT_OFF_MASK | SYS_SMCLK_OFF_MASK
    sw s3, SYS_CLK_CR(a0)
    lw t0, SYS_CLK_CR(a0)
    and t0, t0, s3
    bne t0, s3, fail

    # Test 9: Clock output selection
    addi gp, gp, 1
    # li s3, 0x2000  # CLK_OSEL = 001
    # sw s3, SYS_CLK_CR(a0)
    # lw t0, SYS_CLK_CR(a0)
    # li t1, CLK_OSEL_MASK
    # and t0, t0, t1
    # bne t0, s3, fail

    sw zero, SYS_CLK_CR(a0)
    mv ra, s1
    ret

# ===============================================================================
# Tests 10-13: Enhanced Clock Divider Tests
# ===============================================================================
test_clk_divider_enhanced:
    mv s1, ra
    li a0, PERIPH_SYSTEM0_BASE

    # Test 9: No division
    addi gp, gp, 1
    li s3, 0x00
    sw s3, SYS_CLK_DIV_CR(a0)
    lw t0, SYS_CLK_DIV_CR(a0)
    bne t0, s3, fail

    # Test 10: MCLK /2, SMCLK /2
    addi gp, gp, 1
    li s3, 0x09
    sw s3, SYS_CLK_DIV_CR(a0)
    lw t0, SYS_CLK_DIV_CR(a0)
    bne t0, s3, fail

    # Test 11: MCLK /4, SMCLK /4
    addi gp, gp, 1
    li s3, 0x12
    sw s3, SYS_CLK_DIV_CR(a0)
    lw t0, SYS_CLK_DIV_CR(a0)
    bne t0, s3, fail

    # Test 12: Maximum division
    addi gp, gp, 1
    li s3, 0x3F
    sw s3, SYS_CLK_DIV_CR(a0)
    lw t0, SYS_CLK_DIV_CR(a0)
    bne t0, s3, fail

    sw zero, SYS_CLK_DIV_CR(a0)
    mv ra, s1
    ret

# ===============================================================================
# Tests 14-19: Enhanced Memory Power Control
# ===============================================================================
test_mem_power_enhanced:
    mv s1, ra
    li a0, PERIPH_SYSTEM0_BASE

    # Setup CR
    li s3, SYS_CLK_CR_VAL
    sw s3, SYS_CLK_CR(a0)

    # Test 13: SYS_ROM_OFF_MASK
    addi gp, gp, 1
    # li s3, SYS_ROM_OFF_MASK
    # sw s3, SYS_BLOCK_PWR(a0)
    # lw t0, SYS_BLOCK_PWR(a0)
    # and t0, t0, SYS_ROM_OFF_MASK
    # beqz t0, fail

    # Test 14: SYS_RAM0_OFF_MASK
    addi gp, gp, 1
    # li s3, SYS_RAM0_OFF_MASK
    # sw s3, SYS_BLOCK_PWR(a0)
    # lw t0, SYS_BLOCK_PWR(a0)
    # and t0, t0, SYS_RAM0_OFF_MASK
    # beqz t0, fail

    # Test 15: SYS_RAM1_OFF_MASK
    addi gp, gp, 1
    # li s3, SYS_RAM1_OFF_MASK
    # sw s3, SYS_BLOCK_PWR(a0)
    # lw t0, SYS_BLOCK_PWR(a0)
    # and t0, t0, SYS_RAM1_OFF_MASK
    # beqz t0, fail

    # Test 16: SYS_RAM2_OFF_MASK
    addi gp, gp, 1
    li s3, SYS_RAM2_OFF_MASK
    # sw s3, SYS_BLOCK_PWR(a0)
    # lw t0, SYS_BLOCK_PWR(a0)
    # and t0, t0, SYS_RAM2_OFF_MASK
    # beqz t0, fail

    # Test 17: Combination SYS_RAM0_OFF_MASK | SYS_RAM1_OFF_MASK
    addi gp, gp, 1
    # li s3, SYS_RAM0_OFF_MASK | SYS_RAM1_OFF_MASK
    # sw s3, SYS_BLOCK_PWR(a0)
    # lw t0, SYS_BLOCK_PWR(a0)
    # bne t0, s3, fail

    # Test 18: Combination SYS_ROM_OFF_MASK | SYS_RAM2_OFF_MASK
    addi gp, gp, 1
    # li s3, SYS_ROM_OFF_MASK | SYS_RAM2_OFF_MASK
    # sw s3, SYS_BLOCK_PWR(a0)
    # lw t0, SYS_BLOCK_PWR(a0)
    # bne t0, s3, fail

    sw zero, SYS_BLOCK_PWR(a0)
    mv ra, s1
    ret

# ===============================================================================
# Tests 20-24: Memory Access with Power Control
# ===============================================================================
test_memory_access_with_power_control:
    mv s1, ra
    li a0, PERIPH_SYSTEM0_BASE
    li a1, RAM0_BASE_ADDR
    li a2, RAM1_BASE_ADDR
    li a3, RAM2_BASE_ADDR

    # Test 19: Write to RAM0 when enabled
    addi gp, gp, 1
    sw zero, SYS_BLOCK_PWR(a0)  # All memory enabled
    li s3, 0xDEADBEEF
    sw s3, 0(a1)
    lw t0, 0(a1)
    bne t0, s3, fail

    # Test 20: Write to RAM1
    addi gp, gp, 1
    li s3, 0x12345678
    sw s3, 0(a2)
    lw t0, 0(a2)
    bne t0, s3, fail

    # Test 21: Write to RAM2
    addi gp, gp, 1
    li s3, 0xABCDEF00
    sw s3, 0(a3)
    lw t0, 0(a3)
    bne t0, s3, fail

    # Test 22: Different addresses in same block
    addi gp, gp, 1
    li s3, 0x55555555
    sw s3, 4(a1)
    lw t0, 4(a1)
    bne t0, s3, fail

    # Test 23: Another address in same block
    addi gp, gp, 1
    li s3, 0xAAAAAAAA
    sw s3, 8(a1)
    lw t0, 8(a1)
    bne t0, s3, fail

    sw zero, SYS_BLOCK_PWR(a0)  # Restore all memory enabled
    mv ra, s1
    ret

# ===============================================================================
# Tests 25-28: Enhanced CRC Tests
# ===============================================================================
test_crc_state_enhanced:
    mv s1, ra
    li a0, PERIPH_SYSTEM0_BASE

    # Test 25: CRC initialization
    addi gp, gp, 1
    li s3, 0x0000
    sw s3, SYS_CRC_STATE(a0)
    # lw t0, SYS_CRC_STATE(a0)
    # beqz t0, fail  # Should not be zero after write

    # Test 26: CRC with different data patterns
    addi gp, gp, 1
    li s3, 0x00
    sw s3, SYS_CRC_DATA(a0)
    lw s4, SYS_CRC_STATE(a0)  # Store first result
    li s3, 0xFF
    sw s3, SYS_CRC_DATA(a0)
    lw t0, SYS_CRC_STATE(a0)
    beq t0, s4, fail  # Should be different

    # Test 27: CRC with repeated data
    addi gp, gp, 1
    li s3, 0x55
    sw s3, SYS_CRC_DATA(a0)
    lw s4, SYS_CRC_STATE(a0)
    sw s3, SYS_CRC_DATA(a0)  # Same data again
    lw t0, SYS_CRC_STATE(a0)
    beq t0, s4, fail  # Should be different

    # Test 28: CRC state preservation
    addi gp, gp, 1
    li s3, 0x1234
    sw s3, SYS_CRC_STATE(a0)
    li s3, 0xAA
    sw s3, SYS_CRC_DATA(a0)
    lw t0, SYS_CRC_STATE(a0)
    beqz t0, fail

    mv ra, s1
    ret

# ===============================================================================
# Tests 29-33: Comprehensive IRQ Tests
# ===============================================================================
test_irq_comprehensive:
    mv s1, ra
    li a0, PERIPH_SYSTEM0_BASE

    # Test 28-30: All 16 IRQ enables individually (condensed for brevity)
    addi gp, gp, 1
    li s8, 0  # Counter
irq_enable_loop:
    li s3, 1
    sll s3, s3, s8  # Create bit mask
    sw s3, SYS_IRQ_EN(a0)
    lw t0, SYS_IRQ_EN(a0)
    bne t0, s3, fail
    addi s8, s8, 1
    li t1, 16
    blt s8, t1, irq_enable_loop

    # TODO: Add these tests pack in, for now, irq_pri is optimized away by genus as now irq present in hdl
    # # Test 31: IRQ priorities pattern 1
    addi gp, gp, 1
    # li s3, 0x5555
    # sw s3, SYS_IRQ_PRI(a0)
    # lw t0, SYS_IRQ_PRI(a0)
    # bne t0, s3, fail

    # # Test 32: IRQ priorities pattern 2
    addi gp, gp, 1
    # li s3, 0xAAAA
    # sw s3, SYS_IRQ_PRI(a0)
    # lw t0, SYS_IRQ_PRI(a0)
    # bne t0, s3, fail

    # Clear registers
    sw zero, SYS_IRQ_EN(a0)
    sw zero, SYS_IRQ_PRI(a0)
    mv ra, s1
    ret

# ===============================================================================
# Tests 33-37: Comprehensive Watchdog Tests
# ===============================================================================
test_wdt_comprehensive:
    mv s1, ra
    li a0, PERIPH_SYSTEM0_BASE

    # Ensure System will not reset during WDT tests (Enable IRQ_EN and WDT_IE)
    li s3, IRQB_SYSTEM 
    sw s3, SYS_IRQ_EN(a0)

    # Test 33: Wrong password unlock attempt
    addi gp, gp, 1
    li s3, 0x12345678  # Wrong password
    sw s3, SYS_WDT_PASS(a0)
    li s3, SYS_WDT_EN_MASK | SYS_WDT_IE_MASK
    sw s3, SYS_WDT_CR(a0)
    lw t0, SYS_WDT_CR(a0)
    bnez t0, fail  # Should not be writable with wrong password


    # Test 34: Correct unlock
    addi gp, gp, 1
    li s3, WDT_UNLCK_PASSWD
    sw s3, SYS_WDT_PASS(a0)
    li s3, SYS_WDT_EN_MASK | SYS_WDT_IE_MASK
    sw s3, SYS_WDT_CR(a0)
    lw t0, SYS_WDT_CR(a0)
    and t0, t0, SYS_WDT_EN_MASK
    beqz t0, fail

    # Test 35: Clear password functionality
    addi gp, gp, 1
    li s3, WDT_CLR_PASSWD
    sw s3, SYS_WDT_PASS(a0)
    jal ra, wait_short
    lw t0, SYS_WDT_VAL(a0)
    li t1, 1000
    bgt t0, t1, fail

    # Test 36: Clock divider setting
    addi gp, gp, 1
    li s3, WDT_UNLCK_PASSWD
    sw s3, SYS_WDT_PASS(a0)
    li s3, SYS_WDT_EN_MASK | (1 << 2) | SYS_WDT_IE_MASK # cdiv = 1
    sw s3, SYS_WDT_CR(a0)
    lw t0, SYS_WDT_CR(a0)
    and t0, t0, SYS_WDT_CDIV_MASK
    li t1, (1 << 2)
    bne t0, t1, fail

    # Test 37: WDT disable
    addi gp, gp, 1
    sw zero, SYS_WDT_CR(a0)
    lw t0, SYS_WDT_CR(a0)
    bnez t0, fail

    mv ra, s1
    ret

# ===============================================================================
# Tests 38-42: Watchdog Counter Behavior
# ===============================================================================
test_wdt_counter_behavior:
    mv s1, ra
    li a0, PERIPH_SYSTEM0_BASE

    # Test 37: Enable WDT and IRQ
    addi gp, gp, 1
    li s3, IRQB_SYSTEM
    sw s3, SYS_IRQ_EN(a0)
    li s3, WDT_UNLCK_PASSWD
    sw s3, SYS_WDT_PASS(a0)
    li s3, SYS_WDT_EN_MASK | SYS_WDT_IE_MASK  # cdiv = 0 (fastest)
    sw s3, SYS_WDT_CR(a0)
    lw s4, SYS_WDT_VAL(a0)  # Read initial counter value

    # Test 38: Counter increment
    addi gp, gp, 1
    jal ra, wait_short
    lw t0, SYS_WDT_VAL(a0)
    ble t0, s4, fail  # Counter should have increased

    # Test 39: Counter clear
    addi gp, gp, 1
    li s3, WDT_CLR_PASSWD
    sw s3, SYS_WDT_PASS(a0)
    lw t0, SYS_WDT_VAL(a0)
    bgt t0, s4, fail  # Should be smaller than before clear

    # Test 40: Interrupt generation
    addi gp, gp, 1
    li s3, WDT_UNLCK_PASSWD
    sw s3, SYS_WDT_PASS(a0)
    li s3, 0x18 # Set cdiv = 6 for slower interrupt
    ori s3, s3, SYS_WDT_EN_MASK | SYS_WDT_IE_MASK | SYS_WDT_CDIV_MAX
    sw s3, SYS_WDT_CR(a0)
    li s3, WDT_CLR_PASSWD
    sw s3, SYS_WDT_PASS(a0)
    jal ra, wait_short
    lw t0, SYS_WDT_SR(a0)
    andi t0, t0, SYS_WDT_IF_MASK  # Check interrupt flag
    beqz t0, fail

    # Test 41: Clear interrupt flag
    addi gp, gp, 1
    li s3, 0x2
    sw s3, SYS_WDT_SR(a0)
    lw t0, SYS_WDT_SR(a0)
    andi t0, t0, 0x2
    bnez t0, fail

    li s3, WDT_UNLCK_PASSWD
    sw s3, SYS_WDT_PASS(a0)
    sw zero, SYS_WDT_CR(a0)
    sw zero, SYS_IRQ_EN(a0)
    mv ra, s1
    ret

# ===============================================================================
# Tests 42-43: Register Reset Behavior
# ===============================================================================
test_register_reset_behavior:
    mv s1, ra
    li a0, PERIPH_SYSTEM0_BASE

    # Test 42: Set registers to known values
    addi gp, gp, 1
    li s3, SYS_CLK_CR_VAL
    sw s3, SYS_CLK_CR(a0)
    li s3, 0x02
    sw s3, SYS_CLK_DIV_CR(a0)
    # li s3, 0x0F
    # sw s3, SYS_BLOCK_PWR(a0)
    # li s3, 0xFF
    # sw s3, SYS_CRC_DATA(a0)
    # li s3, 0xFFFF
    # sw s3, SYS_IRQ_EN(a0)
    # li s3, 0xFFFF
    # sw s3, SYS_IRQ_PRI(a0)

    # Test 43: Verify values are set
    addi gp, gp, 1
    lw t0, SYS_CLK_CR(a0)
    li t1, SYS_CLK_CR_VAL
    bne t0, t1, fail
    lw t0, SYS_CLK_DIV_CR(a0)
    li t1, 0x02
    bne t0, t1, fail

    mv ra, s1
    ret

# ===============================================================================
# Utility Functions
# ===============================================================================
wait_short:
    li t0, 300
1:  addi t0, t0, -1
    bnez t0, 1b
    ret

wait_medium:
    li t0, 100000
1:  addi t0, t0, -1
    bnez t0, 1b
    ret

wait_long:
    li t0, 1000000
1:  addi t0, t0, -1
    bnez t0, 1b
    ret

RVTEST_CODE_END