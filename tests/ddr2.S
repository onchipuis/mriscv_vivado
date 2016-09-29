# See LICENSE for license details.

#*****************************************************************************
# ddr2.S
#-----------------------------------------------------------------------------
#
# Test ddr2 basic save-load
#

#include "riscv_test.h"
#include "test_macros.h"

#define TEST_DDR2_OP( testnum, load_inst, store_inst, result, offset, base ) \
TEST_CASE( testnum, x3, result, \
  lui	a0,DIR_PRINT>>12;	\
  ori a0,a0,%lo(DIR_PRINT);		\
  mv		a5,zero;		\
  addi	a5,t3,48;	\
  sw	a5,0(a0);		\
  li  x1, base; \
  li  x2, result; \
  store_inst x2, offset(x1); \
  load_inst x3, offset(x1); \
)

RVTEST_RV32U
RVTEST_CODE_BEGIN

  #-------------------------------------------------------------
  # Basic tests
  #-------------------------------------------------------------

  TEST_DDR2_OP( 2, lw, sw, 0x00aa00aa, 0,  0x81000000 );
  TEST_DDR2_OP( 3, lw, sw, 0xaa00aa00, 4,  0x81000000 );
  TEST_DDR2_OP( 4, lw, sw, 0x0aa00aa0, 8,  0x81000000 );
  TEST_DDR2_OP( 5, lw, sw, 0xa00aa00a, 12, 0x81000000 );

  # Test with negative offset

  TEST_DDR2_OP( 6, lw, sw, 0x00aa00aa, -12, 0x81000000 );
  TEST_DDR2_OP( 7, lw, sw, 0xaa00aa00, -8,  0x81000000 );
  TEST_DDR2_OP( 8, lw, sw, 0x0aa00aa0, -4,  0x81000000 );
  TEST_DDR2_OP( 9, lw, sw, 0xa00aa00a, 0,   0x81000000 );

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
