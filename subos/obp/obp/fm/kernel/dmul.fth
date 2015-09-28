\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: dmul.fth
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
\ dmul.fth 1.1 95/03/04
\ Copyright 1994 FirmWorks

\ AB * CD = BD + (BC + DA)<<bits/half-cell + AC<<bits/cell
: half*  ( h1 h2 -- low<< high )  * split-halves  swap scale-up swap  ;
: um*  ( n1 n2 -- xlo xhi )
   split-halves   rot split-halves   ( b a d c )

   \ Easy case - high halves are both 0, so result is just BD
   2 pick over or  0=  if  drop nip * 0  exit  then

   3 pick 2 pick  * 0 2>r            ( b a d c )  ( r: d.low )

   \ Check for C = 0 and optimize if so
   dup  if			     ( b a d c )  ( r: d.low )
      \ C is not zero, so compute and add BC<<
      3 pick  over half*
      2r> d+ 2>r                     ( b a d c )  ( r: d.intermed )

      \ We are done with B
      2swap nip                      ( d c a )
      \ Check for A = 0 and optimize if so
      dup  if                        ( d c a )
         \ A is not zero, so compute and add DA<< and AC<<<
         rot over half*              ( c a da.low da.high )
         2r> d+ 2>r                  ( c a ) ( r: d.intermed' )
         * 0 swap 2r> d+
      else
         \ A is zero, so we are finished
         3drop  2r>
      then
   else
      \ C is zero, so all we have to do is compute and add DA<<
      drop rot drop                  ( a d )  ( r: d.low )
      half*                          ( low1 high1 )
      2r> d+
   then
;
