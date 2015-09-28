\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: double.fth
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
id: @(#)double.fth 1.3 04/02/02 10:01:53
purpose: 
copyright: Copyright 2003-2004 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 1985-1994 Bradley Forthware
copyright: Use is subject to license terms.

code (dlit) ( -- d )
   tos sp push
    \t16   ip 0 tos lduh
    \t16   tos d# 16 tos slln   ip 2 scr lduh   tos scr tos add
64\ \t16   tos d# 16 tos sllx   ip 4 scr lduh   tos scr tos add
64\ \t16   tos d# 16 tos sllx   ip 6 scr lduh   tos scr tos add
    \t32   ip tos lget
64\ \t32   tos d# 32 tos sllx   ip /l scr ld    tos scr tos add
   ip ainc
   tos sp push
    \t16   ip 0 tos lduh
    \t16   tos d# 16 tos slln   ip 2 scr lduh   tos scr tos add
64\ \t16   tos d# 16 tos sllx   ip 4 scr lduh   tos scr tos add
64\ \t16   tos d# 16 tos sllx   ip 6 scr lduh   tos scr tos add
    \t32   ip tos lget
64\ \t32   tos d# 32 tos sllx   ip /l scr ld    tos scr tos add
   ip ainc
c;

\ Double-precision arithmetic
code dnegate  ( d# -- d#' )
( 0 L: ) mloclabel dneg1
   sp 0      scr   nget
   %g0 scr   scr   subcc
   %g0 tos   tos   subx
   scr       sp 0  nput
c;

code dabs  ( dbl.lo dbl.hi -- dbl.lo' dbl.hi' )
   tos  %g0  %g0  subcc
   ( 0 B: ) dneg1 0< brif
   nop
c;

\ Words that need to be defined in high-level belong in  fm/kernel/double.fth
\  : dmax  ( d1 d2 -- d3 )  2over 2over  d-  nip 0<  if  2swap  then  2drop  ;

code d+  ( x1 x2 -- x3 )
   sp 0 /n*  sc1   nget		\ x2.low
   sp 2 /n*  sc3   nget		\ x1.low
   sp 1 /n*  sc2   nget		\ x1.high
   sp 2 /n*  sp    add		\ Pop args
   sc3 sc1  sc1    addcc	\ x3.low
32\   sc2 tos  tos    addx	\ x3.high
64\   sc2 tos  tos    add	\ x3.high
64\   u>=  if annul  tos  1  tos  add
64\   then
   sc1      sp 0   nput		\ Push result (x3.high already in tos)
c;
code d-  ( x1 x2 -- x3 )
   sp 0 /n*  sc1   nget		\ x2.low
   sp 2 /n*  sc3   nget		\ x1.low
   sp 1 /n*  sc2   nget		\ x1.high
   sp 2 /n*  sp    add		\ Pop args
   sc3 sc1  sc1    subcc	\ x3.low
32\   sc2 tos  tos    subx	\ x3.high
64\   sc2 tos  tos    sub	\ x3.high
64\   u>=  if annul  tos  1  tos  sub
64\   then
   sc1      sp 0   nput		\ Push result (x3.high already in tos)
c;
