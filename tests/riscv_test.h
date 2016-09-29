#ifndef _ENV_PICORV32_TEST_H
#define _ENV_PICORV32_TEST_H

#ifndef TEST_FUNC_NAME
#  define TEST_FUNC_NAME mytest
#  define TEST_FUNC_TXT "mytest"
#  define TEST_FUNC_RET mytest_ret
#endif

#define RVTEST_RV32U
#define TESTNUM x28
/*#define DIR_PRINT 0x10000000*/	/* For SPI-OUT*/
#define DIR_PRINT 0x0000432C	/* For UART*/
/*#define DIR_PRINT 0x00004600*/	/* For SEGMENT*/
#define IRQ_ADDR 0x00004370

#define RVTEST_CODE_BEGIN		\
	.text;				\
	.global TEST_FUNC_NAME;		\
	.global TEST_FUNC_RET;		\
TEST_FUNC_NAME:				\
	la	a0,test_name;	\
	lui	a2,DIR_PRINT>>12;	\
	ori a2,a2,%lo(DIR_PRINT);		\
.prname_next:				\
	lb	a1,0(a0);		\
	beq	a1,zero,.prname_done;	\
	sw	a1,0(a2);		\
	addi	a0,a0,1;		\
	jal	zero,.prname_next;	\
.prname_done:				\
	addi	a1,zero,'.';		\
	sw	a1,0(a2);		\
	sw	a1,0(a2);	\
	lui	a2,IRQ>>12;	\
	ori a2,a2,%lo(IRQ);		\
	li	a2,IRQ_ADDR;	\
	sw	a0,0(a2);		
	

#define RVTEST_PASS			\
PASSED:\
	lui	a0,DIR_PRINT>>12;	\
	ori a0,a0,%lo(DIR_PRINT);		\
	addi	a1,zero,'O';		\
	addi	a2,zero,'K';		\
	addi	a3,zero,'A';		\
	addi	a4,zero,'Y';		\
	addi	a5,zero,'\n';		\
	sw	a1,0(a0);		\
	sw	a2,0(a0);		\
	sw	a3,0(a0);		\
	sw	a4,0(a0);		\
	sw	a5,0(a0);		\
	jal	zero,PASSED;
	/*jal	zero,TEST_FUNC_RET;*/

#define RVTEST_FAIL			\
FAILURE: \
	lui	a0,DIR_PRINT>>12;	\
	ori a0,a0,%lo(DIR_PRINT);		\
	addi	a1,zero,'E';		\
	addi	a2,zero,'R';		\
	addi	a3,zero,'O';		\
	addi	a4,zero,'\n';		\
	mv		a5,zero;		\
	addi	a5,t3,48;	\
	sw	a1,0(a0);		\
	sw	a2,0(a0);		\
	sw	a2,0(a0);		\
	sw	a3,0(a0);		\
	sw	a2,0(a0);		\
	sw	a5,0(a0);		\
	sw	a4,0(a0);		\
	jal	zero,FAILURE;
	/*sbreak;*/

#define RVTEST_CODE_END \
test_name:				\
	.ascii TEST_FUNC_TXT;		\
	.byte 0x00;			\
	.balign 4;			\
IRQ:				\
	sbreak;			\
	jal zero,IRQ;				
#define RVTEST_DATA_BEGIN .balign 4;
#define RVTEST_DATA_END 

#endif
