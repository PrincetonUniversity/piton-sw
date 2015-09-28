\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: dfill.fth
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
\ dfill.fth 2.5 94/05/30
\ Copyright 1985-1990 Bradley Forthware

\ Doubleword fill.  This is the fastest way of filling memory on a SPARC.
\ This is primarily used for clearing memory to initialize the parity.

headers
code cfill  (s start-addr count char -- )
			\ char in tos
   sp 0 /n*  scr  nget	\ count in scr
   sp 1 /n*  sc1  nget	\ start in sc1

   ahead	\ jump to the until  branch
   nop
   begin
      tos  sc1 scr  stb
   but then
      scr 1  scr  subcc
   0< until
      nop		\ Delay slot

   sp 2 /n*   tos  nget
   sp 3 /n*   sp   add
c;

code wfill  (s start-addr count shortword -- )
			\ char in tos
   sp 0 /n*  scr  nget	\ count in scr
   sp 1 /n*  sc1  nget	\ start in sc1

   ahead	\ jump to the until  branch
   nop
   begin
      tos  sc1 scr  sth
   but then
      scr 2  scr  subcc
   0< until
      nop		\ Delay slot

   sp 2 /n*   tos  nget
   sp 3 /n*   sp   add
c;

code lfill  (s start-addr count longword -- )
			\ char in tos
   sp 0 /n*  scr  nget	\ count in scr
   sp 1 /n*  sc1  nget	\ start in sc1

   ahead	\ jump to the until  branch
   nop
   begin
      tos  sc1 scr  st
   but then
      scr 4  scr  subcc
   0< until
      nop		\ Delay slot

   sp 2 /n*   tos  nget
   sp 3 /n*   sp   add
c;
headerless
here lastacf -  constant /lfill

\ For this implementation, count must be a multiple of 32 bytes, and
\ start-addr must be aligned on an 8-byte boundary.

headers
code dfill  (s start-addr count odd-word even-word -- )
   tos   sc2  move	\ even-word in sc2
   sp    sc3  pop	\ odd-word in sc3
   sp    scr  pop	\ count in scr
   sp    sc1  pop	\ start in sc1
   sp    tos  pop	\ fix stack

64\ \ XXXX merge sc2 and sc3 into sc2 XXXXX

   scr  0  cmp
   <> if
   nop
      begin
32\      sc2  sc1 0       std
64\      sc2  sc1 0       stx
         scr d# 32  scr   subcc	\ Try to fill pipeline interlocks
32\      sc2  sc1 8       std
64\      sc2  sc1 8       stx
	 sc1 d# 32  sc1   add
32\      sc2  sc1 d# -16  std
64\      sc2  sc1 d# -16  stx
      0<= until
32\      sc2  sc1 d# -08  std
64\      sc2  sc1 d# -08  stx
   then
c;
headerless
here lastacf -  constant /dfill

\ We can also scrub parity errors by reading and writing memory.
\ This is slower than just clearing it, but it preserves the previous
\ contents, which is nice after Unix has crashed

code ltouch  ( adr len -- )
    tos  sc1  move        \ count in sc1
    sp   sc2  pop       \ adr in sc2
    sp   tos  pop

    sc1  0    cmp
    <> if
    nop

       begin
          sc1 4     sc1       subcc
          sc2  sc1  sc4       ld
       0<= until
          sc4       sc2 sc1   st

    then
c;
here lastacf -  constant /ltouch

code dtouch  ( adr len -- )
    tos  sc1  move        \ count in sc1
    sp   sc2  pop  	\ adr in sc2
    sp   tos  pop

    sc1  0    cmp
    <> if
    nop

       begin
          sc1 8     sc1       subcc
32\       sc2  sc1  sc4       ldd
64\       sc2  sc1  sc4       ldx
       0<= until
32\       sc4       sc2 sc1   std
64\       sc4       sc2 sc1   stx

    then
c;
here lastacf -  constant /dtouch
headers
