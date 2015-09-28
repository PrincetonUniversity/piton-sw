\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: debugm.fth
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
id: @(#)debugm.fth 1.14 07/06/05 10:54:49
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.
\ Copyright 1990 Bradley Forthware
\ Machine-dependent support routines for Forth debugger.

\dtc [define] T32_KERNEL
[ifdef] T32_KERNEL
hex

headerless
: low-dictionary-adr  ( -- adr )  origin  ;

nuser debug-next  \ Pointer to "next"
headers
vocabulary bug   bug also definitions
headerless
nuser 'debug   \ code field for high level trace
nuser <ip      \ lower limit of ip
nuser ip>      \ upper limit of ip
nuser cnt      \ how many times thru debug next

label _flush_cache  ( -- )
   %o7 8  %g0  jmpl
   nop
end-code

label _disable_cache  ( -- )
   %o7 8  %g0  jmpl
   nop
end-code

\ Change all the next routines in the indicated range to jump through
\ the user area vector
code slow-next  ( high low -- )
\ \dtc   _disable_cache call  nop
\dtc				\ Low address in tos
\dtc   sp  scr  pop		\ High address in scr
\dtc   h# e006e000  sc2  set	\ First word of "next":
\dtc				\ ld [%i3+0], %l0
\dtc   h# 81c40002  sc3  set	\ Second word of "next":
\dtc				\ jmp %l0, %g2, %g0
\dtc 64\ h# e058e000  sc4  set	\ Template for first word of replacement "next"
\dtc				\ ldx [%g3+0],%l0
\dtc 32\ h# e000e000  sc4  set	\ Template for first word of replacement "next"
\dtc				\ ld [%g3+0], %l0
\dtc   sc4  'user# debug-next  sc4  add  \ add user number (up nnn scr ld)
\dtc   h# 81c42000  sc5  set	\ Second word of replacement "next" (scr jmpl):
\dtc				\ jmp %l0, 0, %g0
\dtc   h# 80000000  sc7  set	\ Third word of replacement "next" (nop):
\dtc				\ add %g0, %g0, %g0
\dtc   begin
\dtc      tos scr  cmp		\ Loop over addresses from low to high
\dtc   u< while  nop
\dtc      tos 0  sc6  ld
\dtc      sc6    sc2  cmp
\dtc      = if  nop
\dtc         tos 4  sc6  ld
\dtc         sc6    sc3  cmp
\dtc         = if  nop
\dtc            sc4  tos 0  st 	tos  0   iflush
\dtc            sc5  tos 4  st	tos  4   iflush
\dtc            sc7  tos 8  st	tos  8   iflush
\dtc         then
\dtc      then
\dtc      tos 4  tos  add
\dtc   repeat  nop
\ \dtc   _flush_cache call  nop
\dtc   sp   tos  pop
c;

\ Change all the next routines in the indicated range to perform the
\ in-line next routine
code fast-next  ( high low -- )
\ \dtc   _disable_cache call  nop
\dtc				\ Low address in tos
\dtc   sp  scr  pop		\ High address in scr
\dtc   h# e006e000  sc2  set	\ First word of "next":
\dtc				\ ld [%i3+0], %l0
\dtc   h# 81c40002  sc3  set	\ Second word of "next":
\dtc				\ jmp %l0, %g2, %g0
\dtc 64\ h# e058e000  sc4  set	\ Template for first word of replacement "next":
\dtc				\ ldx [%g3+0],%l0
\dtc 32\ h# e000e000  sc4  set	\ Template for first word of replacement "next":
\dtc				\ ld [%g3+0], %l0
\dtc   sc4  'user# debug-next  sc4  add  \ add user number (up nnn scr ld)
\dtc   h# 81c42000  sc5  set	\ Second word of replacement "next" (scr jmpl):
\dtc				\ jmp %l0, 0, %g0
\dtc   h# b606e004  sc7  set	\ Third word of "next":
\dtc				\ add %i3, 4, %i3
\dtc   begin
\dtc      tos scr  cmp		\ Loop over addresses from low to high
\dtc   u< while  nop
\dtc      tos 0  sc6  ld
\dtc      sc6    sc4  cmp
\dtc      = if  nop
\dtc         tos 4  sc6  ld
\dtc         sc6    sc5  cmp
\dtc         = if  nop
\dtc            sc2  tos 0  st	tos  0   iflush
\dtc            sc3  tos 4  st	tos  4   iflush
\dtc            sc7  tos 8  st	tos  8   iflush
\dtc         then
\dtc      then
\dtc      tos 4  tos  add
\dtc   repeat  nop
\ \dtc   _flush_cache call  nop
\dtc   sp   tos  pop
c;

label normal-next
   \ This is slightly different from the normal next (the order of
   \ the registers in the jmpl instruction is reversed) so that it
   \ won't be clobbered by slow-next
   ip 0      scr  ld
   base scr  %g0  jmpl
   ip 4      ip   add
end-code

label debnext
   'user <ip  scr  nget
   ip         scr  cmp
   u>= if  nop
      'user ip>  scr  nget
      ip         scr  cmp
      u<= if  nop
         'user cnt  scr  nget
         scr 1      scr  add
	 scr  'user cnt  nput
         scr        2    cmp
	 = if  nop
            %g0             'user cnt  nput
            normal-next origin -  scr  set	\ Relative address
            scr base              scr  add	\ Absolute address
            scr      'user debug-next  nput
            'user 'debug          scr  ld	\ This is a token, not absolute
            scr base              %g0  jmpl
            nop
         then
      then
   then
   \ This is slightly different from the normal next (the order of
   \ the registers in the jmpl instruction is reversed) so that it
   \ won't be clobbered by slow-next
   ip 0      scr  ld
   base scr  %g0  jmpl
   ip 4      ip   add
end-code

\ Fix the next routine to use the debug version
: pnext   (s -- )  debnext debug-next !  ;

\ Turn off debugging
: unbug   (s -- )  normal-next debug-next !  ;

headers

forth definitions
unbug

[then]
