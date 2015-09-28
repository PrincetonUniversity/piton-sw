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
id: @(#)double.fth 1.9 06/10/13 13:19:27
purpose: 
copyright: Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
copyright: Copyright 1994 FirmWorks
copyright: Use is subject to license terms.

headers
: 2literal   ( d -- )  swap  [compile] literal  [compile] literal  ; immediate
: 2variable  ( -- )  \ name  \  Run-time:  ( -- addr )
   2 /n* ualloc user
; 
\  In-dictionary variables are a leftover from the earliest FORTH
\  implementations.  They have no place in a ROMable target-system
\  and we are deprecating support for them; but Just In Case you
\  ever want to restore support for them, define the command-line
\  symbol:   in-dictionary-variables
[ifdef] in-dictionary-variables
   [ifnexist] 2variable
   : 2variable  ( "name" d -- )  create  0 , 0 ,  ;
   [then]
[then]

headerless
\ Double-word comparison support routines:

\ Conditional-double-"drop-or-nip":  If the supplied flag is true,
\ nip off the pair under the top pair, otherwise drop off the top pair
: ?2off ( d1.lo d2.lo d1.hi d2.hi flag -- d1.hi d2.hi | d1.lo d2.lo )
   if  2swap  then  2drop
;

\ Prepare for a double-word comparison.
\ Leave the relevant elements from the pair, i.e.,
\ if the "Hi"s are equal, leave the "Lo"s
: d(pre-compare) ( d1.lo,hi d2.lo,hi -- d1.hi d2.hi | d1.lo d2.lo )
  rot  swap				( d1.lo d2.lo d1.hi d2.hi )
  2dup <>  ?2off
;

headers

: d0=   ( d1 d2 -- flag )  or  0=  ;
: d=    ( d1 d2 -- flag )  d- d0=  ;
: d<>   ( d1 d2 -- flag )  d=  0=  ;
: d0<   ( d -- flag )   nip 0<  ;
: du<   ( ud1 ud2 -- flag )  d(pre-compare) u<  ;
: d<    ( d1 d2 -- flag )
   rot swap				( d1.lo d2.lo d1.hi d2.hi )
   2dup =  if				( d1.lo d2.lo d1.hi d2.hi )
      \ Both high values are equal.
      \ If negative we need to negate the low cells.
      drop 0<  if			( d1.lo d2.lo )
	 negate swap negate swap	( d1.lo d2.lo )
      then				( d1.lo d2.lo )
      u< exit
   then					( d1.lo d2.lo d1.hi d2.hi )
   < nip nip
;

[ifnexist] dnegate
\ defined in fm/kernel/sparc/double.fth
: dnegate  ( d -- -d )  0 0  2swap  d-  ;
[then]
[ifnexist] dabs
\ defined in fm/kernel/sparc/double.fth
: dabs     ( d -- +d )  2dup  d0<  if  dnegate  then  ;
[then]

[ifnexist] s>d 
\ defined in fm/kernel/sparc/kerncode.fth
: s>d   ( n -- d )  dup 0<  ;
[then]

: u>d   ( u -- d )  0  ;
: d>s   ( d -- n )  drop  ;

: (d.)  (  d -- adr len )  tuck dabs <# #s rot sign #>  ;
: (ud.) ( ud -- adr len )  <# #s #>  ;

: d.    (  d -- )     (d.) type space  ;
: ud.   ( ud -- )    (ud.) type space  ;
: ud.r  ( ud n -- )  >r (ud.) r> over - spaces type  ;

: d2*   ( xd -- xd*2 )  2*  over 0<  negate +  swap  2*  swap  ;
: d2/   ( xd -- xd/2 )
   dup 1 and				( d.lo d.hi d.hi-uf-bit )
   [ /n 8 * 1- ] literal lshift		( d.lo d.hi d.hi-uf )
   rot u2/ or				( d.hi d.lo' ) 
   swap 2/				( d.lo' d.hi' )
;

: dmax  ( xd1 xd2 -- )  2over 2over d<      ?2off  ;
: dmin  ( xd1 xd2 -- )  2over 2over d<  0=  ?2off  ;

: m+    ( d1|ud1 n -- )  s>d  d+  ;
: 2rot  ( d1 d2 d3 -- d2 d3 d1 )  2>r 2swap 2r> 2swap  ;
