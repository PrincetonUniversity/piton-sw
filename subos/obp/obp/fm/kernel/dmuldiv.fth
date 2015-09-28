\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: dmuldiv.fth
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
\ dmuldiv.fth 1.4 95/04/19
\ Copyright 1994 FirmWorks

\ Extended precision multiplication and division

\ alias um*  u*x  ( u1 u2 -- ud )

/n-t 4 * constant bits/half-cell
/n-t 8 * constant bits/cell

: scale-up    ( -- )  bits/half-cell <<  ;
: scale-down  ( -- )  bits/half-cell >>  ;
: split-halves  ( n -- low-half high-half )
   dup 1 scale-up 1- and  swap scale-down
;

\ This is the elementary school long-division algorithm, base 2^^16 (on a
\ 32-bit system) or 2^32 (on a 64-bit system).
\ It depends on the assumption that "/" can accurately divide a single-cell
\ (i.e. 32 or 64 bit) number by a half-cell (i.e. 16 or 32 bit) number.
\ Each "digit" is a half-cell number; thus the dividend is a 4-digit
\ number "ABCD" and the divisor is a 2-digit number "EF".

\ It would be interesting to compare the performance of this to a
\ "bit-banging" non-restoring division loop.
: um/mod  ( ud u -- urem uquot )
   2dup u>=  if                    \ Overflow; return max-uint for quotient
      0=  if  0 /  then            \ Force divide by zero trap
      2drop   0 -1  exit           ( 0 max-u )
   then                            ( ud u )

   \ Split the divisor into two 16-bit "digits"
   dup split-halves		   ( ud u ulow uhigh )

   \ If the high "digit" of the divisor is zero, we can skip a lot
   \ of the steps.  In this case, we only have to worry about the
   \ middle two digits of the dividend in developing the quotient.
   ?dup 0=  if                     ( ud u ulow )

      \ Approximate the high digit of the quotient by dividing the "BC"
      \ digits by the "F" digit.  The answer could by low by one, but if
      \ so it will be fixed in the next step.
      2over swap scale-down swap scale-up + over /  scale-up
				   ( ud u ulow guess<< )

      \ Multiply the trial quotient by the divisor
      rot over um*                 ( ud ulow guess<< udtemp )

      \ Subtract the trial product from the dividend, giving the remainder
      2swap >r >r  d-  drop        ( error )  ( r: guess<< ulow )

      \ Divide the remainder by the divisor, giving the rest of the
      \ quotient.
      dup r@ u/mod nip             ( error guess1 )
      r> r>                        ( error guess1 ulow guess<< )

      \ Merge the two halves of the quotient
      2 pick + >r                  ( error guess1 ulow ) ( r: uquot )

      \ Calculate the remainder
      * -  r>                      ( urem uquot )
      exit
   then                            ( ud u ulow uhigh )

   \ The high divisor digit is non-zero, so we have to deal with
   \ both digits, dividing "ABCD" by "EF".

   \ Approximate the high digit of the quotient.
   3 pick over u/mod nip           ( ud u ulow uhigh guess )

   \ Reduce guess by one if "E" = "A"
   dup 1 scale-up =  if  1-  then  ( ud u ulow uhigh guess' )

   \ Multiply the trial quotient by the divisor
   3 pick over scale-up um*        ( ud u ulow uhigh guess' ud.temp )

   \ Subtract the trial product from the dividend, giving the remainder
   >r >r 2rot r> r> d-             ( u ulow uhigh guess' d.resid )

   \ If the remainder is negative, add the divisor and reduce the trial
   \ quotient by one.  The following loop executes at most twice.
   begin  dup 0<  while            ( u ulow uhigh guess' d.resid )
      rot 1- -rot                  ( u ulow uhigh guess+ d.resid )
      4 pick scale-up 4 pick d+    ( u ulow uhigh guess+ d.resid' )
   repeat                          ( u ulow uhigh guess+ +d.resid )

   \ Now we have the correct high quotient digit; save it for later
   rot scale-up >r                 ( u ulow uhigh +d.resid ) ( r: q.high )

   \ Repeat the above process, using the partial remainder as the
   \ dividend.  Ulow is no longer needed
   3 roll drop                     ( u uhigh +d.resid )

   \ Trial quotient digit...
   2dup scale-up swap scale-down + 3 roll u/mod nip
                                   ( u +d.resid guess1 ) ( r: q.high )
   dup 1 scale-up =  if  1-  then  ( u +d.resid guess1' )

   \ Trial product
   3 pick over um*                 ( u +d.resid guess1' d.err )

   \ New partial remainder
   rot >r d-                       ( u d.resid' )  ( r: q.high guess1' )

   \ Adjust quotient digit until partial remainder is positive
   begin  dup 0<  while            ( u d.resid' )  ( r: q.high guess1' )
     r> 1- >r                      ( u d.resid' )  ( r: q.high guess1' )
     2 pick m+                     ( u d.resid'' ) ( r: q.high guess1' )
   repeat                          ( u +d.resid )  ( r: q.high guess1' )

   \ Discard divisior and high cell of quotient (which must be zero)
   rot 2drop                       ( u.rem )

   \ Merge quotient digits
   r> r> +                         ( u.rem u.quot )
;
: sm/rem  ( d n -- rem quot )
   0                           ( d n sign )
   2 pick 0<  if               ( d n sign )
      1+  2swap dnegate 2swap  ( +d n sign )
   then                        ( +d n sign )
   over 0<  if                 ( +d n sign )
      2+  swap negate swap     ( +d +n sign )
   then                        ( +d +n sign )
   >r um/mod r>                ( u.rem u.quot sign )
   case
      1 of  swap negate swap negate  endof  \ -dividend, +divisor
      2 of  negate                   endof  \ +dividend, -divisor
      3 of  swap negate swap         endof  \ -dividend, -divisor
   endcase
;
: fm/mod  ( d.dividend n.divisor -- n.rem n.quot )
   2dup xor 0<  if        \ Fixup only if operands have opposite signs
      dup >r  sm/rem                                ( rem' quot' r: divisor )
      over  if  1- swap r> + swap  else  r> drop  then
      exit
   then
   \ In the usual case of similar signs (i.e. positive quotient),
   \ sm/rem gives the correct answer
   sm/rem   ( n.rem' n.quot' )
;

: m*  ( n1 n2 -- d )
   2dup xor >r  abs swap  abs um*  r> 0<  if  dnegate  then
;
: */mod  ( n1 n2 n3 -- n.mod n.quot )  >r m* r> fm/mod  ;
: */  ( n1 n2 n3 -- n4 )  */mod nip  ;
