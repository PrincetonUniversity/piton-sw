\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: traps.fth
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
\ traps.fth 2.6 94/05/04
\ Copyright 1985-1990 Bradley Forthware

hex

headers
code %i6!  ( n -- )  tos %i6 move  sp tos pop  c;
code %i7!  ( n -- )  tos %i7 move  sp tos pop  c;
code %o6!  ( n -- )  tos %o6 move  sp tos pop  c;
code %o6@  ( n -- )  tos sp push  %o6 tos move  c;
code tbr@  ( -- adr )  tos sp push  tos rdtbr  c;
code tbr!  ( adr -- )  tos 0  wrtbr  sp tos pop  c;
code psr@  ( -- n )  tos sp push  tos rdpsr  c;
code psr!  ( n -- )  tos 0  wrpsr  sp tos pop  c;
code wim@  ( -- n )  tos sp push  tos rdwim  c;
code wim!  ( n -- )  tos 0  wrwim  sp tos pop  c;
code y@  ( -- n )  tos sp push  tos rdy  c;
code y!  ( n -- )  tos 0 wry  sp tos pop  c;
: cwp!  ( window# -- )  psr@  h# 1f invert and  or  psr!  ;
: cwp@  ( -- window# )  psr@  h# 1f and  ;
: pil@  ( -- priiority )  psr@  h# f00 and  8 >>  ;
: pil!  ( priority -- )  8 <<  psr@  h# f00 invert and  or  psr!  ;
alias spl pil!  ( priority -- )
headerless

: traps-on   ( -- )  psr@ h# 20 or         psr!  ;
: traps-off  ( -- )  psr@ h# 20 invert and psr!  ;

: setl4  ( n -- setlow sethi )
   dup 0a >> ( n hibits ) h# 29000000 +  ( n sethi )
   swap h# 3ff and h# a8052000 +  swap
;

h# 10 constant /vector
: vector-adr  ( vector# -- adr )  /vector *  tbr@ h# ffff.f000 and  +  ;

defer vector-l! ( l adr -- )  ' l! is vector-l!
headers

: vector!  ( handler-adr trap# -- )
   vector-adr                        ( handler trap-entry-adr )
   swap setl4                        ( trap-entry-adr setlow sethi )
   2 pick vector-l!                  ( trap-entry-adr setlow )
   over la1+ vector-l!               ( trap-entry-adr )	\ handler %l4 set
   h# 81c52000 over 2 la+ vector-l!  ( trap-entry-adr )	\ %l4 0  %g0 jmpl
   h# a1480000 over 3 la+ vector-l!  ( trap-entry-adr )	\ %l0 rdpsr
   drop
;

\ Assumes handler was installed with vector!
: vector@  ( trap# -- handler-adr )
   vector-adr                    ( trap-adr )
   dup l@  h# 0a <<              ( trap-adr hibits )
   swap la1+ l@  h# 3ff and  or  ( handler-adr )
;
