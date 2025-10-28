# See LICENSE for license details.

#*****************************************************************************
# gpio.S
#-----------------------------------------------------------------------------
#
# Test GPIO peripheral(s) instruction.
#

#include "riscv_test.h"
#include "test_macros.h"

#define GPIO_BASE_ADDR 0x4000



RVTEST_RV64U
RVTEST_CODE_BEGIN

  #-------------------------------------------------------------
  # Basic GPIO Output Functionality
  #-------------------------------------------------------------

  # Run GPIO tests
  TEST_GPIO_OUTPUT(1, GPIO_BASE_ADDR, 0x01, 1)      # Test pin 0 output high
  TEST_GPIO_OUTPUT(2, GPIO_BASE_ADDR, 0x01, 0)      # Test pin 0 output low


  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

tdat:
tdat1:  .byte 0xff
tdat2:  .byte 0x00
tdat3:  .byte 0xf0
tdat4:  .byte 0x0f

RVTEST_DATA_END
