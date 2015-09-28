\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: retained.fth
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
id:  @(#)retained.fth 1.1 06/12/13
purpose: 
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ With the present firmware stack retained memory DOES NOT work on sun4v
\ systems.  One reason (among others) is that soft resets are translated to
\ power-cycle events.  However we cannot remove the cif because Solaris will
\ panic without it.  This file attempts to fake up the cif in as benign a way
\ as possible.  Memory is of course not retained across resets, however, at
\ runtime OBP allows a client program to allocate named chunks of memory,
\ and keeps track of them in case they are asked for again.  It does not
\ assume that a certain physical address for the retained table of contents
\ will always be available like its sun4u counterpart.  Instead it just
\ allocates a virtual page at stand-init time.

\ Until retained memory is fixed or redesigned for sun4v machines this is
\ our compromise.  See withdrawn FWARC case 2006/049 for a possible solution.

headerless
0 value retained

\  R  E  T  A  I  N  E  D
h# 52.45.54.41.49.4e.45.44 constant retained-magic0
h# 64.65.6e.69.61.74.65.72 constant retained-magic1

pagesize constant /retained
16meg    constant retained-min-align

: map-in-retained ( -- vadr )
   /retained alloc-mem
;
: retained@ ( offset -- n ) retained + x@  ;
: retained! ( n offset -- ) retained + x!  ;

struct
h# 20 field >retained-name
h# 08 field >retained-base-pa
h# 08 field >retained-size
h# 08 field >retained-count
h# 08 field >retained-align
constant /retained-struct

: retained-base-pa@ ( adr -- pa.lo )  >retained-base-pa x@  ;
: retained-base-pa! ( pa.lo adr -- )  >retained-base-pa x!  ;

: retained-size@ ( adr -- size )  >retained-size x@  ;
: retained-size! ( size adr -- )  >retained-size x!  ;

: retained-count@ ( adr -- count )  >retained-count x@  ;
: retained-count! ( count adr -- )  >retained-count x!  ;

: retained-align@ ( adr -- align )  >retained-align x@  ;
: retained-align! ( align adr -- )  >retained-align x!  ;

: free-retained-slot ( offset -- )
   0 swap >retained-name x!
;

: retained-bounds ( -- end,start )
   retained  /retained /retained-struct /string  bounds
;
: find-free-retained-slot ( -- offset true | false )
   retained-bounds  ?do
      i >retained-name cstrlen  0=  if
	 i  unloop true  exit
      then
   /retained-struct +loop  false
;

: mark-retained ( -- )
   retained-magic0 dup  h# 20 retained!
   -1 xor               h# 18 retained!
   retained-magic1 dup  h# 28 retained!
   -1 xor               h# 10 retained!
;

: init-retained ( -- )
    map-in-retained to retained				( )
    mark-retained					( )
;

: $find-retained ( name$ -- offset true | false )
   retained-bounds  ?do
      2dup i >retained-name cscount $=  if  ( name$ )
	 2drop  i  unloop true  exit
      then
   /retained-struct +loop  2drop false
;

: $release-retained ( name$ -- )
   $find-retained  if			( offset )
      >r				(  )  ( r: offset )
      r@ retained-base-pa@  obmem	( pa.lo pa.hi )
      r@ retained-size@			( pa.lo pa.hi size )
      mem-release			(  )
      r>  free-retained-slot		(  )
   then
;

: $new-retained ( name$ size align -- )
   2dup 2>r  mem-claim  2r> 2swap  ( name$ size align pa.lo pa.hi )
   find-free-retained-slot  if     ( name$ size align pa.lo pa.hi offset )
      >r  drop                     ( name$ size align pa.lo ) ( r: offset )
      r@ retained-base-pa!         ( name$ size align ) ( r: offset )
      r@ retained-align!           ( name$ size )       ( r: offset )
      r@ retained-size!            ( name$ )            ( r: offset )
      true r@ retained-count!      ( name$ )            ( r: offset )
      r> >retained-name swap cmove (  )
   else                            ( name$ size align pa.lo pa.hi )
      2>r drop 2r> rot mem-release ( name$ )
      2drop			   (  )
   then                            (  )
;

: alloc-retained ( name$ size align -- pa.lo pa.hi false  |  true )
   retained-min-align  round-up swap   ( name$ align' size )
   mmu-pagesize        round-up swap   ( name$ size' align' )

   2>r 2dup $find-retained  if  ( name$ offset ) ( r: size align )
      dup retained-size@     ( name$ offset osize ) ( r: size align )
      over retained-align@   ( name$ offset osize oalign ) ( r: size align )
      2r@  d=  if            ( name$ offset ) ( r: size align )
	 \ prev size/align are same
	 true over retained-count!      ( name$ offset ) ( r: size align )
	 r>   over retained-align!      ( name$ offset ) ( r: size )
	 r>   swap retained-size!       ( name$ )
      else                              ( name$ offset ) ( r: size align )
	 \ prev size/align were different
	 drop 2dup $release-retained    ( name$ )  ( r: size align )
	 2dup 2r> $new-retained         ( name$ )
      then                              ( name$ )
   else                                 ( name$ ) ( r: size align )
      \ This is the first time for this name
      2dup 2r> $new-retained            ( name$ )
   then                                 ( name$ )
   $find-retained  if                   ( offset )
      retained-base-pa@ obmem  false    ( ok )
   else                                 (  )
      true                              ( failed )
   then					( pa.lo pa.hi false | true )
;

headers

" /memory" find-device
   caps @ caps off
   : SUNW,retain ( cname size align -- pa.lo pa.hi )
      ?dup  if				( cname size align )
	 rot cscount 2swap	        ( name$ size align )
	 alloc-retained			( pa.lo pa.hi false | true )
      else				( cname pa.lo pa.hi size )
	 \ Deprecate align=0 support
         true				( true )
      then  throw			( pa.lo pa.hi )
   ;
   : SUNW,free-retain ( cname -- )
      cscount $release-retained
   ;
   caps !
device-end

stand-init: Init Retained memory
   init-retained
;
