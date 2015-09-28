\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: boot.fth
\ 
\ Copyright (c) 2006 Sun Microsystems, Inc. All Rights Reserved.
\ 
\  - Do no alter or remove copyright notices
\ 
\  - Redistribution and use of this software in source and binary forms, with 
\    or without modification, are permitted provided that the following 
\    conditions are met: 
\ 
\  - Redistribution of source code must retain the above copyright notice, 
\    this list of conditions and the following disclaimer.
\ 
\  - Redistribution in binary form must reproduce the above copyright notice,
\    this list of conditions and the following disclaimer in the
\    documentation and/or other materials provided with the distribution. 
\ 
\    Neither the name of Sun Microsystems, Inc. or the names of contributors 
\ may be used to endorse or promote products derived from this software 
\ without specific prior written permission. 
\ 
\     This software is provided "AS IS," without a warranty of any kind. 
\ ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, 
\ INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A 
\ PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY EXCLUDED. SUN 
\ MICROSYSTEMS, INC. ("SUN") AND ITS LICENSORS SHALL NOT BE LIABLE FOR 
\ ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR 
\ DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES. IN NO EVENT WILL SUN 
\ OR ITS LICENSORS BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA, OR 
\ FOR DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE 
\ DAMAGES, HOWEVER CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, 
\ ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF 
\ SUN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
\ 
\ You acknowledge that this software is not designed, licensed or
\ intended for use in the design, construction, operation or maintenance of
\ any nuclear facility. 
\ 
\ ========== Copyright Header End ============================================
id: @(#)boot.fth 2.16 07/06/05
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved.
copyright: Use is subject to license terms.

\ ident	"@(#)boot.fth	2.16	07/06/05 SMI"

\ Version for running Forth as a Unix user process

\ Boot code (cold and warm start).  The cold start code is executed
\ when Forth is initially started.  Its job is to initialize the Forth
\ virtual machine registers.  The warm start code is executed when Forth
\ is re-entered, perhaps as a result of an exception.

hex

only forth also labels also meta also definitions

0 constant main-task

headerless

\ Stuff initialized at cold start time

nuser memtop		\ The top of the memory used by Forth
headers
0 value #args		\ The process's argument count
0 value  args		\ The process's argument list
headerless
label cold-code  ( -- )

\ called with   forth_startup(header-adr, functions, mem_end, &gargc, &gargv)
\ 				 %i0	    %i1	      %i2	%i3	%i4

\ Get some registers
   %o6 -10 /l*  %o6  save   \ Propagate stack pointer to new frame

\ Find the base address
   here-t 4 +       call    \ Absolute address of next instruction
   here-t 4 - base  set	    \ Relative address of this instruction
   %o7 base   base  sub	    \ Base address of Forth kernel

\ Allocate high memory for the stacks and stuff, starting at memtop and
\ allocating downwards.  %i2 is the allocation pointer.

   %i2              %l6  move	\ We'll need this later for memtop

\ Find the user area size from the header
   %i0 8            %l4  ld	\ Data size = user area size in %l4

\ Allocate the RAM copy of the User Area
   %i2 %l4          %i2  sub
   %i2              up   move	\ Set user pointer

   'body main-task  %l3  set	\ Allow the exception handler to find the
   base %l3         %l5  add	\ user area by storing the address of the
32\  up             %l5 2  sth	\ main user area in the "constant" main-task
32\  up th 10       %l3    srl
32\  %l3            %l5 0  sth

64\  up             %l5 6  sth \ main user area in the "constant" main-task
64\  up    th 10    %l3    srlx
64\  %l3            %l5 4  sth
64\  %l3   th 10    %l3    srlx
64\  %l3            %l5 2  sth
64\  %l3   th 10    %l3    srlx
64\  %l3            %l5 0  sth

\ Copy the initial User Area image to the RAM copy
   %i0 4            %l3  ld	\ Text size = offset to start of data
   base  %l3        %l3  add	\ Init-up pointer in %l3

   begin
      %l4  4   %l4  subcc
      %l3 %l4  %l5  ld
   0= until
      %l5   up %l4  st		\ Delay slot

\ Now the user area has been copied to the proper place, so we can set
\ some important user variables whose inital values are determined at
\ run time.

\ Set the value of #args and args
   %i3     'user #args   nput
   %i4     'user args    nput

\ Top of memory and dictionary limit
   %l6    'user memtop  nput

\ Set the up0 user variable
   up        'user up0  nput

\ Establish the return stack and set the rp0 user variable
   %i2       rp          move	\ Set rp
   rp        'user .rp0  nput
   %i2 rs-size-t   %i2   sub    \ allocate space for the return stack

\ Establish the Parameter Stack
   %i2       'user .sp0  nput
   %i2  /n   sp          add	\ /n accounts for the top of stack register

   %i2 ps-size-t   %i2   sub	\ Allocate the stuff on the stack

\t16 h# 1.0000     %l6  set
\t16 %l6 tshift-t  %l6  sll
\t16 %l6 base      %l6  add	\ limit is origin + (64K << tokenshift)
   %l6    %i2           cmp
   u< if  nop
      %l6 %i2           move
   then
  %i2    'user limit   nput

\ Save the address of the system call table in the user variable syscall-vec
  %i1  up syscall-user# nput

\ Set the dictionary pointer
   %i0 4     %l0         ld	\ Text size
   base %l0  %l0         add    \ Base + text
   %l0       'user dp    nput   \ Set dp

\ Enter Forth
   'body cold      ip    set
   ip base         ip    add
c;

headers
