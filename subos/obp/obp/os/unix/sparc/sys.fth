\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: sys.fth
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
id: @(#)sys.fth 2.20 07/06/05 10:54:56
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.
\ Copyright 1985-1990 Bradley Forthware

\ Very-low-level interfaces to the Sun 4.2 BSD version of Unix
\ These routines may have to be rewritten for other flavors of
\ Unix, because the mechanism for doing system calls may differ.
\ The names and the stack diagrams should not need to change, however.

\ The wrapper is expected to implement the forth stack semantics of the
\ routines and match the stack direction.
\
decimal

headerless

/l ualloc-t  dup equ syscall-user#
headers
user syscall-vec   \ long address of system call vector
headerless

nuser sysretval

\ I/O for running under Unix with a C program providing actual I/O routines

headers
meta
0 [if]
code syscall? ( call# -- ok? )	\ For backwards compatibility
   'user syscall-vec   %l0  nget
   bubble
32\ tos 2		tos	slln		\ multiply by 4
64\ tos 3		tos	slln		\ multiply by 8
   %l0 tos		%l0	ld		\ Address of routine
   %l0 %g0		%g0	subcc
   0=  if
      %g0  1		tos	sub		\ (delay)
      %g0		tos	move
   then
c;
[then]

code syscall ( ?? call# -- ?? )	\ For backwards compatibility
				\ Get address of system call table
   'user syscall-vec	%l0	nget
   bubble
32\ tos 2		tos	slln		\ multiply by 4
64\ tos 3		tos	slln		\ multiply by 8
   %l0 tos		%l0	nget		\ Address of routine
   sp			tos	pop
   tos			%o0	move		\ Get some arguments
   sp  0 /n*		%o1	nget
   sp  1 /n*		%o2	nget
   sp  2 /n*		%o3	nget
   sp  3 /n*		%o4	nget
   sp  4 /n*		%o5	nget
   %g2			%l2	move
   %g3			%l3	move
   %g4			%l4	move
   %g5			%l5	move
   %g6			%l6	move
   %g7			%l7	move
   %l0 %g0		%o7	jmpl
   %g1			%l1	move		\ Delay slot

   %l1			%g1	move
   %l2			%g2	move
   %l3			%g3	move
   %l4			%g4	move
   %l5			%g5	move
   %l6			%g6	move
   %l7			%g7	move

   %o0  'user sysretval		nput	\ Save the result

c;

\ A syscall wrapper that uses the stack so that the wrapper can return
\ data on the forth stacks.
\
code fsyscall ( ?? call# -- ?? )
   'user syscall-vec	%l0	nget
   bubble
32\ tos 2		tos	slln		\ multiply by 4
64\ tos 3		tos	slln		\ multiply by 8
   %l0 tos		%l0	nget		\ Address of routine
   sp			%o0	move
   %g2			%l2	move
   %g3			%l3	move
   %g4			%l4	move
   %g5			%l5	move
   %g6			%l6	move
   %g7			%l7	move
   %l0 %g0		%o7	jmpl
   %g1			%l1	move		\ Delay slot

   %l1			%g1	move
   %l2			%g2	move
   %l3			%g3	move
   %l4			%g4	move
   %l5			%g5	move
   %l6			%g6	move
   %l7			%g7	move
   %o0			sp	move		\ new stack pointer
   sp			tos	pop
c;

: retval   ( -- return_value )     sysretval @  ;
: lretval  ( -- l.return_value )   sysretval @ n->l ;

headers
nuser errno	\ The last system error code
headerless

: error?  ( return-value -- return-value error? )
   dup 0< dup  if  15 syscall retval errno !  then   ( return-value flag )
;

headers
\ Depends on null-termination of Forth strings
overload: cstr  ( pstr -- cstr )  1+  ;

\ Rounds down to a block boundary.  This causes all file accesses to the
\ underlying operating system to occur on disk block boundaries.  Some
\ systems (e.g. CP/M) require this; others which don't require it
\ usually run faster with alignment than without.
hex
headerless

chain: unix-init-io
   install-wrapper-io

   \ Don't poll the keyboard under Unix; block waiting for a key
   ['] (key              ['] key            (is
;
' unix-init-io is init-io

: unix-init ;  \ Environment initialization chain
' unix-init is init-environment
decimal
headers
