\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: memlist.fth
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
id: @(#)memlist.fth 1.9 06/11/01
purpose: 
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

external
headers

fload ${BP}/dev/utilities/64bit-ops.fth

\ This struct has to be 64-bit aligned
\ since some of the components are 64-bit in size.
struct
   /n field >next-node
   /n +				\ alignment padding
   /x field >mem.adr
   /x field >mem.size
constant /memnode

0 value memlist
0 value prev-node
0 value next-node

\ Some of the functions in this file are called from other places 
\ in pci probe code and are likely to be passed paramerters which 
\ are sign-extended. Hence we need to convert those into unsigned 
\ number until we have a better solution albiet tokenizer fix.
\ Here are the list of functions,
\  - free-memrange
\  - allocate-memrange
\  - set-node
\  - round-node-up
\  - round-node-down
\  - split-node

\
\ This routine expects to be called with a valid node, not a pointer to a node
\
: (find-node)  ( ??? node acf -- ?? prev-node this-node|0 )
   0 >r >r			( ?? this )		( r: 0 acf )
   begin			( ?? this )		( r: prev acf )
      r@ over >r		( ?? this acf )		( r: prev acf this )
      execute			( ?? acf flag )		( r: prev acf this )
      r> swap if		( ?? this )		( r: prev acf )
         r> r>			( ?? this acf prev )	( r: -- )
         nip swap exit		( ?? prev this|0 )	( r: -- )
      else			( ?? this )		( r: prev acf )
         r> r>			( ?? this acf prev )	( r: -- )
         drop			( ?? this acf )		( r: -- )
         swap >r		( ?? acf )		( r: prev )
         r@ >next-node @	( ?? acf this )		( r: prev )
         swap >r		( ?? this )		( r: prev acf )
      then			( ?? this )		( r: prev acf )
   dup 0= until 		( ?? this )		( r: prev acf )
   r> drop			( ?? this )		( r: prev )
   r> swap			( ?? prev this )	( r: -- )
;

: find-node  ( ?? list acf -- ?? )
   >r						( ?? list ) ( r: acf )
   dup to memlist				( ?? ) ( r: acf )
   @ r> (find-node)				( ?? prev this|0 )
   to next-node					( ?? prev )
   to prev-node					( ?? )
;

: delete-after  ( prev-node -- deleted-node )
   dup >next-node @ tuck			( next prev next )
   >next-node @ swap !				( next )
;

: insert-after  ( new-node-adr prev-node-adr -- )
   >next-node					( new &prev->next )
   tuck @					( &prev->next new next )
   over >next-node !				( &prev->next new )
   swap !					( -- )
;


: set-node  ( size adr -- node )
   unsigned-x swap unsigned-x swap
   /memnode alloc-mem				( adr size node )
   dup  >next-node off				( adr size node )
   tuck >mem.adr x!				( node )
   tuck >mem.size x!				( adr node)
;

: free-node ( node --  )  /memnode free-mem ;

: node-range ( node -- adr size )     dup >mem.adr x@  swap >mem.size x@  ;
: prev-start ( -- adr )			prev-node >mem.adr x@  ;
: node-end   ( node -- adr )		node-range +  ;

\ Is 'adr' less that the address in the node?
: lower?  ( adr node -- adr flag )  >mem.adr x@ over x>=  ;


: merged-lower? ( size adr -- [ size adr false ] | true )
   prev-node  if				( size adr )
      dup prev-node node-end x= if		( size adr )
         drop prev-node >mem.size +x!		( -- )
         true exit				( true )
      then					( size adr )
   then						( size adr )
   false					( size adr false )
;

: merged-upper? ( size adr -- [ size adr false ] | true )
   next-node if					( size adr )
      2dup + next-node >mem.adr x@ x= if	( size adr )
         next-node >mem.adr x!			( size -- )
         next-node >mem.size +x!		( -- )
         true exit				( true )
      then					( size adr )
   then						( size adr )
   false					( size adr false )
;

: free-memrange  ( adr size list -- )
   >r unsigned-x swap unsigned-x r>		( size adr list )
   dup @ if					( adr size list )
      ['] lower?  find-node			( -- )
   else						( size adr list )
      -rot set-node swap ! exit			( -- )
   then						( -- )

   \ Error check to catch attempts to free already-free memory.
   next-node if
      2dup swap bounds swap			( size adr lo hi )
      next-node >mem.adr x@ -rot xwithin	( size adr flag )
      if					( size adr flag )
        ." Freeing memory that is already free: " .x .x cr
        abort					( -- )
      then					( -- )
   then						( size adr )

   merged-lower? if					( -- )
      \ We attempted to merge the lower node and it worked
      \ Now we need to check the upper
      prev-node node-range swap			( size adr )
      merged-upper? if				( -- )
         \ We merged upper and lower addresses.
         next-node >mem.size x@ prev-node >mem.size x!
         prev-node delete-after			( node )
         free-node				( -- )
      else					( size adr )
         2drop					( -- )
      then					( -- )
      exit					( -- )
   else						( size adr )
      merged-upper? if				( -- )
         exit					( -- )
      then					( -- )      
   then						( size adr )

   set-node					( node )
   prev-node if					( -- )
      prev-node insert-after			( -- )
   else						( node )
      next-node over >next-node !		( -- )
      memlist !					( -- )
   then
;

: round-node-up ( node align memlist  -- )
   swap unsigned-x swap				( node align memlist )
   to memlist >r				( node )
   dup >mem.adr x@ dup r> round-up		( node mem mem1 )
   2dup x<> if					( node mem mem1 )
      tuck					( node mem1 mem mem1 )
      over -					( node mem1 mem diff )
      tuck memlist free-memrange		( node mem1 diff )
      >r 					( node mem1 )
      over >mem.adr x!				( node )
      r> negate swap >mem.size +x!		( -- )
   else						( node mem mem1 )
      3drop					( -- )
   then						( -- )
;

: round-node-down ( node align memlist -- )
   swap unsigned-x swap				( node align memlist )
   to memlist >r				( node )
   dup node-end					( node end )
   dup r> round-down				( node end end' )
   2dup x<> if					( node end end' )
      tuck -					( node end' len )
      tuck					( node len end' len )
      memlist free-memrange			( node len )
      negate swap >mem.size +x!			( -- )
   else						( node end end' )
      3drop					( -- )
   then						( -- )
;

\
\ And now the code to carve holes in the list.
\
: suitable?  ( align size node-adr -- alignment size flag )
   >r r@ >mem.adr x@  2 pick round-up		( align size aligned-adr )
   r> node-range -rot -				( align size node-size waste )
   2dup x<=  if  2drop false  exit  then	( align size node-size waste )
   -						( align size aln-node-size )
   over x>=					( align size flag )
;   

: allocate-memrange  ( alignment size list -- phys-adr false | true )
   rot unsigned-x rot unsigned-x rot		( alignment size list ) 
   dup @ if
      ['] suitable?  find-node			( align size )
   else
      3drop true exit				( true )
   then

   next-node 0=  if  2drop true  exit  then	( aln size )

   \ simple check first..
   \ is this exactly the right size?  
   dup next-node >mem.size x@ x= if		( aln size )
      \ the size matches..
      2drop					( -- )
      prev-node ?dup if				( -- )
         delete-after				( node )
      else					( -- )
         next-node dup >next-node @ memlist !	( adr node )
      then					( adr node )
      dup >mem.adr x@ swap			( adr node )
      free-node					( adr )
      false exit				( -- adr false )
   then

   \ OK we need to snip a node
   swap						( size aln )
   over next-node >mem.size x@ swap - >r	( size aln len' )
   next-node >mem.adr x@ dup >r			( size aln adr )
   over round-up				( size aln adr' )
   dup r> x= if					( size aln adr' )
      \ We can take the space from the front
      \ of the node, leaving the remainder
      r> next-node >mem.size x!			( size aln adr' )
      -rot					( adr size aln )
      drop next-node >mem.adr +x!		( adr )
      false					( adr false )
      exit					( --  adr false )
   then						( size aln adr' )

   \ OK we've exhausted the easy cases
   \ Now we get to create a new node to describe the remainder
   dup next-node >mem.adr x@ -			( size aln adr' diff )
   dup next-node >mem.size x!			( size aln adr' diff )
   \ First node is truncated now.
   rot drop r> swap -				( size adr' diff )
   -rot dup >r +				( diff adr' )
   over x0<> if					( diff adr' )
      set-node next-node insert-after		( -- )
   else						( diff adr' )
      2drop					( -- )
   then						( -- )
   r> false					( adr false )
;


: biggest? ( largest node -- largest flag )
   over if					( largest node )
      over >mem.size x@				( largest node size1 )
      over >mem.size x@ x>= if			( largest node )
         drop					( largest )
      else					( largest node )
         nip					( largest' )
      then					( largest' )
   else						( largest node )
      nip 					( largest false )
   then	 false					( largest flag )
;

: get-biggest-node ( memlist-ptr -- node )
   0 swap					( biggest memlist-ptr )
   dup @ if					( biggest memlist-ptr )
      ['] biggest? find-node			( biggest )
   else						( 0 memlist-ptr )
      drop					( 0 )
   then						( biggest )
;

: last-node? ( node -- flag )  >next-node @ 0= ;

: get-last-node ( memlist-ptr -- prev last )
   dup @ if					( memlist-ptr )
      ['] last-node? find-node			( -- )
      prev-node next-node 			( prev next )
   else						( memlist-ptr )
      drop 0 0					( 0 0 )
   then						( prev last )
;

: found-node? ( want current -- flag ) over = ;

\
\ This doesn't free the selected node, just cuts it from the list.
\
: remove-selected-node ( node memlistptr -- fail? )
   ['] found-node? find-node drop next-node 0= dup if exit then
   prev-node ?dup if
      delete-after drop
   else
      next-node >next-node @ memlist !
   then
   next-node if  0 next-node >next-node !  then
;

\ release all the nodes in this list.
: free-list ( node -- )
   begin					( node )
     dup while					( node )
        dup >next-node @			( node next )
        swap free-node				( node )
   repeat  drop					( -- )
;

\ split node at address
: split-node ( adr node -- prev next )
   swap unsigned-x swap			( adr node )
   2dup node-range over + within if 	( adr node )
      2dup >mem.adr x@ -		( adr node diff )
      over >mem.size x@ over - 		( adr node diff next.len )
      -rot over >mem.size x!		( adr next.len node )
      -rot swap set-node		( node next )
   else
      nip dup 			( node node )
   then
;

