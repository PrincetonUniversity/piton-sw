\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ctrace9.fth
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
id: @(#)ctrace9.fth 1.5 04/04/15 19:10:03
purpose: 
copyright: Copyright 1990-2004 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.
\ Copyright 1985-1990 Bradley Forthware

\ After a crash, displays a backtrace of C stack frames.
\ This assumes the stack format used by the Sun SPARC C compiler.

only forth also hidden also forth definitions

headers
defer .subname  ( adr -- )
headerless
' .x is .subname

: >reg  ( reg# -- addr )
   dup 3 >>  case
   0 of  addr %g0  size-of %g0  endof
   1 of  addr %o0  size-of %o0  endof
   2 of  addr %l0  size-of %l0  endof
   3 of  addr %i0  size-of %i0  endof
   endcase                 ( reg# base size )
   rot h# 7 and            ( base size reg# )
   over *                  ( base size offset )
   swap /l =  if
      + l@
   else
      + dup 1 and  if  V9_SP_BIAS +  then  x@
   then
;
: >ea  ( instruction -- address )
   dup  h# 1000 and  if                    ( instruction )  \ Immediate
      dup  d# 20 <<  d# 12 >>a             ( instruction immediate )
   else
      dup  h# 1f and >reg                  ( instruction regval )
   then
   swap d# 14 >>  h# 1f  and  >reg  +      ( target-address )
;
: decode-jmpl  ( instruction -- false  |  target true )
   dup h# 81f80000 and  h# 81c00000 =  if  >ea true  else  drop false  then
;
headers
: .subroutine  ( return-adr -- )  \ Show subroutine address
   dup pointer-bad?  over 0=  or  if  drop ." XXXXXXX " exit  then  ( return-adr )
   dup l@  h# c000.0000 and  h# 4000.0000  =  if       \ call instruction ?
      ." call "  dup l@  h# 3fff.ffff and  2 << l->n +  .subname
   else
      \ XXX decode the address specification from the jmpl
      \ if that address spec references OUT's or GLOBAL's, we can't
      \ be sure that it is correct.  The next window context contains
      \ the relevant registers.
      l@  decode-jmpl  if
         ." jmpl  "  .subname       \ indirect call (jmpl)
      else
         ." ????  "
      then
   then
;
headerless
: .2x  ( n -- )  push-hex  2 u.r  pop-base  ;
: .c-call  ( -- exit? )
   %o7 .subroutine  ."    from "  %o7 .subname  cr
   ."     " window# .2x  ."  w  %o0-%o7: ("
   %o0 .x  %o1 .x  %o2 .x  %o3 .x  %o4 .x  %o5 .x %o6 .x %o7 .x
   ." )"  cr
   cr exit?
;

headers
: ctrace  ( -- )   \ C stack backtrace
   state-valid @  0=  if   ." No saved state"  exit  then
   ." PC: "  %pc .subname cr
   ." Last leaf: "

   window#                                     ( previous-window# )
   0w  begin  .c-call (+w) or  until           ( previous-window# )
   set-window
;
