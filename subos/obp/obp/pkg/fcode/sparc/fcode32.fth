\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: fcode32.fth
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
id: @(#)fcode32.fth 1.15 06/10/26
purpose: 
copyright: Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headers

code 2l->n ( l1 l2 -- x1 x2 )
   tos 0  tos   sra
   sp  0  scr   ldx
   scr 0  scr   sra
   scr    sp 0  stx
c;

: l-$number ( adr len -- true | n false )  swap n->l swap  $number ;

: l-move ( adr1 adr2 cnt -- )  rot n->l rot n->l rot n->l  move  ;
: l-fill ( adr cnt byte -- )  rot n->l rot n->l rot  fill  ;

: lcpeek ( adr -- { byte true } | false )  n->l  cpeek  ;
: lwpeek ( adr -- { byte true } | false )  n->l  wpeek  ;
: llpeek ( adr -- { byte true } | false )  n->l  lpeek  ;

: lcpoke ( byte adr -- ok? )  n->l  cpoke  ;
: lwpoke ( byte adr -- ok? )  n->l  wpoke  ;
: llpoke ( byte adr -- ok? )  n->l  lpoke  ;

: lb?branch  ( [ <mark ] -- [ >mark ] )

   \ New feature of IEEE 1275
   state @ 0=  if  ( flag )
      l->n  if  get-offset drop  else  skip-bytes  then
      exit
   then

   compile l->n

   get-offset 0<  if  ( )
      \ The get-backward-mark is needed in case of the following valid
      \ ANS Forth construct:    BEGIN  .. WHILE .. UNTIL .. THEN
      get-backward-mark  [compile] until
   else
      [compile] if
   then
; immediate

code l+! ( n addr -- )
      tos 0    tos  srl
      sp       scr  get
\dtc  tos      sc1  lget

\itc  tos 0    sc1  lduh
\itc  tos 2    sc2  lduh
\itc  sc1 10   sc1  sll
\itc  sc1 sc2  sc1  add
      bubble
      sc1 scr  sc1  add
\dtc   sc1      tos   lput
\itc   sc1  tos 2     sth
\itc   sc1 10   sc1   srl
\itc   sc1  tos 0     sth
   sp  1 /n*  tos  nget
   sp  2 /n*  sp   add
c;

code l>>a     ( n1 cnt -- n2 )
   sp       scr  pop
   scr tos  tos  sra
c;
code lrshift  ( n1 cnt -- n2 )
   sp  scr       pop
   scr tos  tos  srl
c;

: lb(of)     ( marks -- marks )
   drop-offset  +level compile 2l->n -level  [compile] of
; immediate
: lb(do)     ( -- )
   drop-offset  +level compile 2l->n -level  [compile]  do
; immediate
: lb(?do)    ( -- )
   drop-offset  +level compile 2l->n -level  [compile]  ?do
; immediate
: lb(+loop)  ( -- )
   drop-offset  +level compile l->n -level  [compile] +loop
; immediate

transient
also assembler definitions
: compare
   sp  scr  pop
   scr tos  cmp
;
: leaveflag  ( condition -- )
\ macro to assemble code to leave a flag on the stack
   if  ,%icc
   0  tos  move   \ Delay slot
      -1 tos move
   then
;
previous definitions
resident
warning @ warning off
\ Note: l0= and l= clash with the link defs in kernport.fth
code l0=  ( n -- f )  tos test  0=  leaveflag c;
code l0<> ( n -- f )  tos test  0<> leaveflag c;
code l0<  ( n -- f )  tos test  0<  leaveflag c;
code l0<= ( n -- f )  tos test  <=  leaveflag c;
code l0>  ( n -- f )  tos test  >   leaveflag c;
code l0>= ( n -- f )  tos test  0>= leaveflag c;

code l<   ( n1 n2 -- f )  compare <   leaveflag c;
code l>   ( n1 n2 -- f )  compare >   leaveflag c;
code l=   ( n1 n2 -- f )  compare 0=  leaveflag c;
code l<>  ( n1 n2 -- f )  compare <>  leaveflag c;
code lu>  ( n1 n2 -- f )  compare u>  leaveflag c;
code lu<= ( n1 n2 -- f )  compare u<= leaveflag c;
code lu<  ( n1 n2 -- f )  compare u<  leaveflag c;
code lu>= ( n1 n2 -- f )  compare u>= leaveflag c;
code l>=  ( n1 n2 -- f )  compare >=  leaveflag c;
code l<=  ( n1 n2 -- f )  compare <=  leaveflag c;
warning !

: l-between ( n1 n2 n3 -- flag )  >r over l<= swap r> l<= and  ;
: l-within  ( n1 n2 n3 -- flag )  over - >r - r> lu<  ;
: l-max     ( n1 n2 -- max )  2dup l< if  swap  then  drop  ;
: l-min     ( n1 n2 -- min )  2dup l> if  swap  then  drop  ;
: l-abs     ( n -- |n| )  dup l0< if  negate  then  ;

code l-@   ( addr -- n )
      tos 0    tos  srl
\dtc  tos 0     tos  ld
\itc  tos 2     scr  lduh   tos 0   tos  lduh
\itc  tos h# 10 tos  sll    scr tos tos  add
c;

code l-!   ( n addr -- )
    tos 0    tos  srl
    sp  0  scr  nget
\dtc   scr     tos 0   st
\itc   scr     tos 2  sth
\itc   scr 10  scr    srl
\itc   scr     tos 0  sth

   sp 1 /n*  tos  nget
   sp 2 /n*  sp   add
c;

code l2@  ( addr -- d )
    tos 0    tos  srl
    tos /n   sc1  lduh
    tos /n 2 +   scr  lduh  sc1 10   sc1  sll   scr sc1  sc1  add
    tos /n 4 +   scr  lduh  sc1 10   sc1  sllx  scr sc1  sc1  add
    tos /n 6 +   scr  lduh  sc1 10   sc1  sllx  scr sc1  scr  add

    scr      sp   push

    tos  0  sc1  lduh
    tos 2   scr  lduh  sc1 10   sc1  sll  scr sc1  sc1  add
    tos 4   scr  lduh  sc1 10   sc1  sllx  scr sc1  sc1  add
    tos 6   scr  lduh  sc1 10   sc1  sllx

    scr  sc1  tos  add
c;
code l2!  ( d addr -- )
    tos 0    tos  srl
    sp  0   scr    nget
    bubble

    scr   tos 6  sth  scr 10  scr  srlx
    scr   tos 4  sth  scr 10  scr  srlx
    scr   tos 2  sth  scr 10  scr  srl
    scr   tos 0  sth

    sp  /n  scr    nget

    bubble

    scr   tos /n 6 + sth  scr 10  scr  srlx
    scr   tos /n 4 + sth  scr 10  scr  srlx
    scr   tos /n 2 + sth  scr 10  scr  srl
    scr   tos /n 0 + sth

    sp  2 /n*   tos    nget
    sp  3 /n*   sp     add
c;

code ll@  ( addr -- l ) \ longword aligned
    tos 0    tos  srl
    tos tos lget
c;
code ll!  ( n addr -- )
    tos 0    tos  srl
    sp  0  scr  nget
    bubble
    scr   tos 0 st
    sp  1 /n*  tos  nget
    sp  2 /n*  sp   add
c;

code l<w@ ( addr -- w )
    tos 0  tos  srl
    tos 0  tos  ldsh
    tos 0  tos  sra
c;

code lw@  ( addr -- w ) \ 16-bit word aligned
    tos 0    tos  srl
    tos 0  tos  lduh
c;

code lw!  ( w addr -- )
   tos 0    tos  srl
   sp  0  scr  nget
   bubble
   scr   tos 0 sth
   sp 1 /n*  tos  nget
   sp 2 /n*  sp   add
c;

code lc@  ( addr -- c )
    tos 0    tos  srl
    tos 0  tos  ldub
c;
code lc!  ( c addr -- )
    tos 0    tos  srl
    sp  0  scr  nget
    bubble
    scr   tos 0 stb
    sp  1 /n*  tos  nget
    sp  2 /n*  sp   add
c;

code lon ( addr -- )
      tos  0 tos   srl
      -1   scr     move
\dtc  scr  tos 0   st
\itc  scr  tos 0   sth
\itc  scr  tos 2   sth
       sp  tos     pop
c;
code loff ( addr -- )
       tos  0 tos  srl
\dtc   %g0  tos 0  st
\itc   %g0  tos 0  sth
\itc   %g0  tos 2  sth
        sp  tos    pop
c;

: lbase  ( -- adr ) +level  compile base   compile la1+  -level  ; immediate
: l#out  ( -- adr ) +level  compile #out   compile la1+  -level  ; immediate
: l#line ( -- adr ) +level  compile #line  compile la1+  -level  ; immediate
: lspan  ( -- adr ) +level  compile span   compile la1+  -level  ; immediate

code lrl@  ( addr -- l ) \ longword aligned
    tos 0    tos  srl
    tos tos lget
c;
code lrl!  ( n addr -- )
    tos 0    tos  srl
    sp  0  scr  nget
    bubble
    scr   tos 0 st
    sp  1 /n*  tos  nget
    sp  2 /n*  sp   add
c;

code lrw@  ( addr -- w ) \ 16-bit word aligned
    tos 0    tos  srl
    tos 0  tos  lduh
c;

code lrw!  ( w addr -- )
   tos 0    tos  srl
   sp  0  scr  nget
   bubble
   scr   tos 0 sth
   sp 1 /n*  tos  nget
   sp 2 /n*  sp   add
c;

code lrb@  ( addr -- c )
    tos 0    tos  srl
    tos 0  tos  ldub
c;
code lrb!  ( c addr -- )
    tos 0    tos  srl
    sp  0  scr  nget
    bubble
    scr   tos 0 stb
    sp  1 /n*  tos  nget
    sp  2 /n*  sp   add
c;

\ Double word stuff we need to implement with 32-bit only math.
code ld+  ( x1 x2 -- x3 )
   sp 0 /n*  sc1   nget		\ x2.low
   sp 2 /n*  sc3   nget		\ x1.low
   sp 1 /n*  sc2   nget		\ x1.high
   sp 2 /n*  sp    add		\ Pop args
   sc3 sc1  sc1    addcc	\ x3.low
   sc2 tos  tos    addc		\ x3.high
   sc1      sp 0   nput		\ Push result (x3.high already in tos)
c;
code ld-  ( x1 x2 -- x3 )
   sp 0 /n*  sc1   nget		\ x2.low
   sp 2 /n*  sc3   nget		\ x1.low
   sp 1 /n*  sc2   nget		\ x1.high
   sp 2 /n*  sp    add		\ Pop args
   sc3 sc1  sc1    subcc	\ x3.low
   sc2 tos  tos    subc		\ x3.high
   sc1      sp 0   nput		\ Push result (x3.high already in tos)
c;

: l-u/mod ( u1 u2 -- u.rem u.quot )	n->l swap n->l swap u/mod ;
: l-/mod  ( n1 n2 -- n.rem n.quot )	l->n swap l->n swap /mod ;

headerless

\ The following is from obp/fm/kernel/dmuldiv.fth and obp/fm/kernel/dmul.fth:

/l 4 * constant bits/half-l
: l-scale-up    ( n -- h )  bits/half-l <<  ;
: l-scale-down  ( n -- h )  bits/half-l >>  ;
alias l-split-halves lwsplit
: l-half*  ( h1 h2 -- low<< high )  * l-split-halves  swap l-scale-up swap  ;

headers

\ Implement:
\
\ AB * CD = BD + (BC + DA)<<bits/half-cell + AC<<bits/cell
\
\ Where A, B, C, D are half "l" (or 16 bit in this case) values.

: lum*	( n1 n2 -- xlo xhi )
   l-split-halves   rot l-split-halves	( b a d c )

   \ Easy case - high halves are both 0, so result is just BD
   2 pick over or  0=  if  drop nip * 0	 exit  then

   3 pick 2 pick  * 0 2>r		( b a d c )  ( r: d.low )

   \ Check for C = 0 and optimize if so
   dup	if				( b a d c )  ( r: d.low )
      \ C is not zero, so compute and add BC<<
      3 pick  over l-half*
      2r> ld+ 2>r			( b a d c )  ( r: d.intermed )

      \ We are done with B
      2swap nip				( d c a )
      \ Check for A = 0 and optimize if so
      dup  if				( d c a )
	 \ A is not zero, so compute and add DA<< and AC<<<
	 rot over l-half*		( c a da.low da.high )
	 2r> ld+ 2>r			( c a ) ( r: d.intermed' )
	 * 0 swap 2r> ld+
      else
	 \ A is zero, so we are finished
	 3drop	2r>
      then
   else
      \ C is zero, so all we have to do is compute and add DA<<
      drop rot drop			( a d )	 ( r: d.low )
      l-half*				( low1 high1 )
      2r> ld+
   then
   n->l
;
\ This is the elementary school long-division algorithm, base 2^^16 (on a
\ 32-bit system) or 2^32 (on a 64-bit system).
\ It depends on the assumption that "/" can accurately divide a single-cell
\ (i.e. 32 or 64 bit) number by a half-cell (i.e. 16 or 32 bit) number.
\ Each "digit" is a half-cell number; thus the dividend is a 4-digit
\ number "ABCD" and the divisor is a 2-digit number "EF".

\ It would be interesting to compare the performance of this to a
\ "bit-banging" non-restoring division loop.
: l-um/mod  ( ud u -- urem uquot )
   2dup u>=  if                    \ Overflow; return max-uint for quotient
      0=  if  0 /  then            \ Force divide by zero trap
      2drop   0 -1  n->l exit      ( 0 max-u )
   then                            ( ud u )

   \ Split the divisor into two 16-bit "digits"
   dup l-split-halves		   ( ud u ulow uhigh )

   \ If the high "digit" of the divisor is zero, we can skip a lot
   \ of the steps.  In this case, we only have to worry about the
   \ middle two digits of the dividend in developing the quotient.
   ?dup 0=  if                     ( ud u ulow )

      \ Approximate the high digit of the quotient by dividing the "BC"
      \ digits by the "F" digit.  The answer could by low by one, but if
      \ so it will be fixed in the next step.
      2over swap l-scale-down swap l-scale-up + over /  l-scale-up
				   ( ud u ulow guess<< )

      \ Multiply the trial quotient by the divisor
      rot over lum*                ( ud ulow guess<< udtemp )

      \ Subtract the trial product from the dividend, giving the remainder
      2swap >r >r  ld-  drop       ( error )  ( r: guess<< ulow )

      \ Divide the remainder by the divisor, giving the rest of the
      \ quotient.
      dup r@ l-u/mod nip           ( error guess1 )
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
   3 pick over l-u/mod nip          ( ud u ulow uhigh guess )

   \ Reduce guess by one if "E" = "A"
   dup 1 l-scale-up =  if  1-  then  ( ud u ulow uhigh guess' )

   \ Multiply the trial quotient by the divisor
   3 pick over l-scale-up lum*       ( ud u ulow uhigh guess' ud.temp )

   \ Subtract the trial product from the dividend, giving the remainder
   >r >r 2rot r> r> ld-             ( u ulow uhigh guess' d.resid )

   \ If the remainder is negative, add the divisor and reduce the trial
   \ quotient by one.  The following loop executes at most twice.
   begin  dup 0<  while            ( u ulow uhigh guess' d.resid )
      rot 1- -rot                  ( u ulow uhigh guess+ d.resid )
      4 pick l-scale-up 4 pick ld+ ( u ulow uhigh guess+ d.resid' )
   repeat                          ( u ulow uhigh guess+ +d.resid )

   \ Now we have the correct high quotient digit; save it for later
   rot l-scale-up >r                 ( u ulow uhigh +d.resid ) ( r: q.high )

   \ Repeat the above process, using the partial remainder as the
   \ dividend.  Ulow is no longer needed
   3 roll drop                     ( u uhigh +d.resid )

   \ Trial quotient digit...
   2dup l-scale-up swap l-scale-down + 3 roll l-u/mod nip
                                   ( u +d.resid guess1 ) ( r: q.high )
   dup 1 l-scale-up =  if  1-  then  ( u +d.resid guess1' )

   \ Trial product
   3 pick over lum*                ( u +d.resid guess1' d.err )

   \ New partial remainder
   rot >r ld-                       ( u d.resid' )  ( r: q.high guess1' )

   \ Adjust quotient digit until partial remainder is positive
   begin  dup 0<  while            ( u d.resid' )  ( r: q.high guess1' )
     r> 1- >r                      ( u d.resid' )  ( r: q.high guess1' )
	 \ There is no l-m+, so use "0< ld+" instead 
     2 pick dup 0< ld+		   ( u d.resid'' ) ( r: q.high guess1' )
   repeat                          ( u +d.resid )  ( r: q.high guess1' )

   \ Discard divisior and high cell of quotient (which must be zero)
   rot 2drop                       ( u.rem )

   \ Merge quotient digits
   r> r> +                         ( u.rem u.quot )
;

\ Need to fix # and #s

: l-mu/mod (s d n1 -- rem d.quot )
   >r  0  r@  l-um/mod  r>  swap  >r  l-um/mod  r>
;
: l-#   (s ud1 -- ud2 )
   base @ l-mu/mod			( nrem ud2 )
   rot     >digit  hold			( ud2 )
;
: l-#s  (s ud -- 0 0 )  begin   l-#  2dup or  0=  until  ;

transient
vocabulary fcode32
also fcode32 definitions

alias ,     l,
alias /n    /l
alias na+   la+
alias cell+ la1+
alias cells /l*
alias b?branch lb?branch
alias +!       l+!
alias >>a      l>>a
alias rshift   lrshift
alias b(of)    lb(of)
alias b(do)    lb(do)
alias b(?do)   lb(?do)
alias b(+loop) lb(+loop)
alias 0=       l0=
alias 0<>      l0<>
alias 0<       l0<
alias 0<=      l0<=
alias 0>       l0>
alias 0>=      l0>=
alias <        l<
alias >        l>
alias =        l=
alias <>       l<>
alias u>       lu>
alias u<=      lu<=
alias u<       lu<
alias u>=      lu>=
alias >=       l>=
alias <=       l<=
alias between  l-between
alias within   l-within
alias max      l-max
alias min      l-min
alias abs      l-abs
alias @        l-@
alias !        l-!
alias 2@       l2@
alias 2!       l2!
alias l@       ll@
alias l!       ll!
alias <w@      l<w@
alias w@       lw@
alias w!       lw!
alias c@       lc@
alias c!       lc!
alias on       lon
alias off      loff
alias base     lbase
alias #out     l#out
alias #line    l#line
alias span     lspan

alias rl!      lrl!
alias rl@      lrl@
alias rw!      lrw!
alias rw@      lrw@
alias rb!      lrb!
alias rb@      lrb@

alias $number  l-$number
alias move     l-move
alias fill     l-fill
alias cpeek    lcpeek
alias wpeek    lwpeek
alias lpeek    llpeek
alias cpoke    lcpoke
alias wpoke    lwpoke
alias lpoke    llpoke

alias d+       ld+
alias d-       ld-
alias um*      lum*
alias um/mod   l-um/mod
alias u/mod    l-u/mod
alias /mod     l-/mod

alias #        l-#
alias #s       l-#s

previous definitions
resident

headerless
variable token-table0-64
variable token-table2-64
variable token-table0-32
variable token-table2-32

token-tables 0 ta+ token@ token-table0-64 token!
token-tables 0 ta+  !null-token

token-tables 2 ta+ token@ token-table2-64 token!
token-tables 2 ta+  !null-token

headers
also fcode32 definitions
fload ${BP}/pkg/fcode/primlist.fth		\ Codes for kernel primitives
fload ${BP}/pkg/fcode/sysprims-nofb.fth	\ Codes for system primitives
fload ${BP}/pkg/fcode/obsfcod2.fth
fload ${BP}/pkg/fcode/sysprm64.fth
fload ${BP}/pkg/fcode/regcodes.fth
previous definitions

token-tables 0 ta+ token@ token-table0-32 token!
token-tables 2 ta+ token@ token-table2-32 token!

headers
: fcode-32 ( -- )
   token-table0-32 token@ token-tables 0 ta+ token!
   token-table2-32 token@ token-tables 2 ta+ token!
;

: fcode-64 ( -- )
   token-table0-64 token@ token-tables 0 ta+ token!
   token-table2-64 token@ token-tables 2 ta+ token!
;

fcode-64

stand-init: Chose fcode32 mode
   fcode-32
;
