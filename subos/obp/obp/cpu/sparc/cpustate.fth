\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: cpustate.fth
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
id: @(#)cpustate.fth 2.11 99/04/16
purpose: Buffers for saving program state
copyright: Copyright 1990 Sun Microsystems, Inc.  All Rights Reserved

\ cpustate.fth 2.9 94/08/25
\ Copyright 1985-1990 Bradley Forthware

headers
\ Data structures defining the CPU state saved by a breakpoint trap.
\ This must be loaded before either catchexc.fth or register.fth,
\ and is the complete interface between those 2 modules.

\ Offset into the register save array of the window register save area.
\ During compilation, we use this as an allocation pointer for the
\ global register save area, and then when we're finished allocating
\ global registers, it's final value will be the offset to the the
\ window register save area.
headerless
0 value window-registers

headers
\ A place to save the CPU registers when we take a trap
defer cpu-state ( -- adr ) ' 0 to cpu-state \ Pointer to CPU state save area

\ Compile-time allocator for saved register space
transient
: allocate-reg  ( -- offset )
   window-registers  dup na1+  to window-registers
;
resident

headerless
: >state  ( offset -- adr )  cpu-state  +  ;

h# 40 constant ua-size

0 value pssave		\ A place to save the Forth data stack
0 value rssave		\ A place to save the Forth return stack

headers
defer .exception	\ Display the exception type
defer handle-breakpoint	\ What to do after saving the state
8 constant #windows	\ # of windows implemented
