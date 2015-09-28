\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bitops.fth
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
\ bitops.fth 2.2 90/09/03
\ Copyright 1985-1990 Bradley Forthware

\ id bitops.fth 1.1 88/06/02
 
code bitset  ( bit# array -- )
			\ Adr in tos
   sp       scr  pop	\ Bit# in scr
   h# 80    sc1  move	\ Mask
   scr 7    sc2  and	\ Bit Shift count
   scr 3    sc4  srl    \ Byte offset in sc4
   tos sc4  sc3  ldub   \ Get the byte
   sc1 sc2  sc1  srl    \ Interesting bit in sc1
   sc1 sc3  sc3  or	\ Set the appropriate bit
   sc3  tos sc4  stb    \ Put the byte back
   sp       tos  pop	\ Clean up stack
c;
code bitclear ( bit# array -- )
			\ Adr in tos
   sp       scr  pop	\ Bit# in scr
   h# 80    sc1  move	\ Mask
   scr 7    sc2  and	\ Bit Shift count
   scr 3    sc4  srl    \ Byte offset in sc4
   tos sc4  sc3  ldub   \ Get the byte
   sc1 sc2  sc1  srl    \ Interesting bit in sc1
   sc3 sc1  sc3  andn	\ Clear the appropriate bit
   sc3  tos sc4  stb    \ Put the byte back
   sp       tos  pop	\ Clean up stack
c;
code bittest ( bit# array -- flag )
			\ Adr in tos
   sp       scr  pop	\ Bit# in scr
   h# 80    sc1  move	\ Mask
   scr 7    sc2  and	\ Bit Shift count
   scr 3    sc4  srl    \ Byte offset in sc4
   tos sc4  sc3  ldub   \ Get the byte
   sc1 sc2  sc1  srl    \ Interesting bit in sc1
   sc1 sc3  sc3  andcc	\ Clear the appropriate bit
   0<>  if
   false    tos  move	\ Expect false (delay slot)
      true  tos  move	\ True
   then
c;
