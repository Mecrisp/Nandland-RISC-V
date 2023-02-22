/*
 * start.S
 *
 * PicoRV32 startup code
 *
 * Copyright (C) 2019-2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: MIT
 */

   .section .text.start
   .global _start
_start:

   # Copy data section
   la a0, _sidata
   la a1, _sdata
   la a2, _edata
   bge a1, a2, end_init_data
loop_init_data:
   lw a3, 0(a0)
   sw a3, 0(a1)
   addi a0, a0, 4
   addi a1, a1, 4
   blt a1, a2, loop_init_data
end_init_data:

   # BSS zero-init
   la a0, _sbss
   la a1, _ebss
   bge a0, a1, end_init_bss
loop_init_bss:
   sw zero, 0(a0)
   addi a0, a0, 4
   blt a0, a1, loop_init_bss
end_init_bss:

   # Set stack pointer to end of heap
   li sp, 0x0400

   # Call main
   call main

   # Trap here should main return
trap:
   j trap
