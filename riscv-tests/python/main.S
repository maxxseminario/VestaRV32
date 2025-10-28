# Automatically generated main.S for RV32UI tests
.section .text.start
.globl _start
_start:
    la sp, _stack_end
    jal ra, test_rv32ui
    li a0, 0
    jal exit

.section .text
test_rv32ui:
    jal ra, addi
    jal ra, add
    jal ra, andi
    jal ra, and
    jal ra, auipc
    jal ra, beq
    jal ra, bge
    jal ra, bgeu
    jal ra, blt
    jal ra, bltu
    jal ra, bne
    jal ra, jalr
    jal ra, jal
    jal ra, lb
    jal ra, lbu
    jal ra, ld_st
    jal ra, lh
    jal ra, lhu
    jal ra, lui
    jal ra, lw
    jal ra, ma_data
    jal ra, main
    jal ra, ori
    jal ra, or
    jal ra, sb
    jal ra, sh
    jal ra, simple
    jal ra, slli
    jal ra, sll
    jal ra, slti
    jal ra, sltiu
    jal ra, slt
    jal ra, sltu
    jal ra, srai
    jal ra, sra
    jal ra, srli
    jal ra, srl
    jal ra, st_ld
    jal ra, sub
    jal ra, sw
    jal ra, xori
    jal ra, xor
    ret

.section .data
.align 4
_stack_start:
    .space 4096
_stack_end:

.globl exit
exit:
    li a7, 93
    ecall
    j exit
