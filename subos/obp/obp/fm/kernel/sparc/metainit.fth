\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: metainit.fth
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
\ id: @(#)metainit.fth 2.7 02/05/02
\ purpose: 
\ Copyright 1985-1990 Bradley Forthware
\ Copyright 1995-2002 Sun Microsystems, Inc.  All Rights Reserved
\ Copyright Use is subject to license terms.

\ Metacompiler initialization

\ Debugging aids

0 #words ! h# 2a0 threshold ! 10 granularity ! warning-t on

forth definitions

metaon
meta definitions

\ We want the kernel to be romable, so we put variables in the user area
:-h variable  ( -- )  nuser  ;-h
alias \m  \

initmeta

\ Allocate space for the target image
th 22000 alloc-mem h# 1000 round-up target-image

\ org sets the lowest address that is used by Forth kernel.
hex

0.0000 org  0.0000
   voc-link-t a-t!

200 equ ps-size

assembler

\ This is at the first location in the Forth image.

\ init-forth is the initialization entry point.  It should be called
\ exactly once, with arguments (dictionary_start, dictionary_size).
\ init-forth sets up some global variables which allow Forth to locate
\ its RAM areas, including the data stack, return stack, user area,
\ cpu-state save area, and dictionary.

hex
mlabel cld
   9000 always brif annul	\ The address will be fixed later.
   nop				\ Delay slot
   nop
   nop
[ifdef] miniforth?
\ truncated traptable
64\   100 10 - 0 ?do unimp /l +loop
[else]
64\   8000 10 - 0 ?do unimp /l +loop
[then]

meta
