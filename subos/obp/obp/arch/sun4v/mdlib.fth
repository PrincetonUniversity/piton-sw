\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: mdlib.fth
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
id: @(#)mdlib.fth 1.3 07/02/12
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

fload ${BP}/arch/sun4v/mdnode.fth

headerless

: md-prop-match? ( prop name$ type -- match? )
   -rot  2swap						( name$ prop type )
   over mde-type over =  swap -1 =  or  if		( name$ prop )
      mde-name $=		 			( match? )
   else							( name$ prop )
      3drop false					( false )
   then							( match? )
;

headers

: md-node-name  ( entry -- $name )  mde-name ;
: md-prop-name  ( entry -- $name )  mde-name ;

: md-prop-type ( entry -- type )  mde-type ;

: md-next-node ( node -- nextnode | 0 )
   ?dup 0=  if						( )
      md-nodeblk					( nodeblk )
   else							( node )
      >mde-next unaligned-x@  mde-index>adr		( node' )
   then							( node' )
   md-noops-skip					( nextnode )
   dup mde-type  MD_LIST_END =  if
      drop 0
   then							( nextnode | 0 )
;

: md-next-prop ( node prev -- nextprop | 0 )
   ?dup if  nip  then  /md-entry +		( mdentry )
   md-noops-skip				( nextprop )
   dup mde-type MD_NODE_END =  if
      drop 0
   then						( nextprop | 0 )
;

: md-find-prop ( node name$ type -- prop | 0 )
   >r  rot  r>  swap			( name$ type node )
   dup 0 md-next-prop			( name$ type node prop )
   begin  dup  while			( name$ type node prop )
      tuck 2>r				( name$ type prop ) ( r: node prop )
      2over 3 pick md-prop-match? if	( name$ type )
         3drop 2r> nip exit		( prop )
      then				( name$ type )
      2r>  over swap md-next-prop	( name$ type prop nextprop ) ( r: ) 
   repeat  2drop 3drop 0		( 0 )
;

: md-decode-prop  ( prop -- $data,type | val,type | 0 )
   dup mde-type						( prop type )
   dup case						( prop type type )
      MD_PROP_VAL	of  swap mde-value swap  endof	( val type )
      MD_PROP_STR	of  swap mde-data 1- rot endof	( buf,len type )
      MD_PROP_DATA	of  swap mde-data rot	 endof	( buf,len type )
      MD_PROP_ARC	of  swap mde-value 
			    mde-index>adr swap	 endof	( node type)
      ( prop type type )    nip nip 0 swap		( 0 type )
   endcase
;

headerless

: md-nametag ( mdetype index len -- nametag )
   rot d# 56 <<  swap d# 48 << or  or
;

: md-find-name ( name$ -- index true | false )
   md-nameblk					( name$ nameblk )
   md-nameblksz 0  ?do				( name$ nameblk )
      3dup i + dup cstrlen  dup 1+ >r  $=  if	( name$ nameblk ) ( r: incr )
         r> 2drop 2drop i true unloop exit	( index true )
      then  r>					( name$ nameblk incr ) ( r: )
   +loop  3drop false				( false )
;

headers

: md-find-node  ( node|0 $name -- node|0 )
   tuck 					( node len $name )
   md-find-name 0= if
      2drop 0 exit				( 0 )
   then						( node len index )
   swap MD_NODE -rot				( node type index len )
   md-nametag swap				( nametag node )
   begin					( nametag node )
      md-next-node dup				( nametag next next )
   while					( nametag next )
      2dup mde-nametag@ =			( nametag next match? )
      if  nip exit  then			( next )
   repeat
   nip						( 0 )
;


headerless

: md-next-fwd  ( node fwd|0 -- entry|0 )
   begin
      over swap md-next-prop dup	( node next )
   while
      dup mde-type MD_PROP_ARC = if	( node next )
         dup mde-name " fwd" $= if	( node next )
            nip exit			( entry )
         then				( node next )
      then				( node next )
   repeat
   nip					( 0 )
;

headers

: md-applyto-fwds  ( ??? acf node -- ??? )
   0 				        ( ?? acf node 0 )
   begin
      2dup md-next-fwd nip dup		( ?? acf node next-fwd|0 next-fwd|0 )
   while
      dup mde-value mde-index>adr	( ?? acf node next-fwd fwd-node ) 
      -rot 2>r swap >r r@		( ?? fwd-node acf )
      catch ?dup if
         r> 2r> 3drop throw
      then
      r> 2r>				( acf node next-fwd )
   repeat   
   3drop				(  )
;

: md-root-node  ( -- node )  0 " root" md-find-node  ;

: md-get-required-prop  ( node $name -- [val type] | [buf len type] )
   3dup -1 md-find-prop ?dup if
      nip nip nip md-decode-prop		( [val type] | [buf len type] )
   else
      rot md-node-name 2swap			( $name $prop )
      cmn-fatal[ " Missing required property: %s " cmn-append
                 " in node %s"			   ]cmn-end
   then
;

\ This function temporarily sets md-data to some other MD stored in memory
\ an md-pointer value of 0 means use the guest-md
\ !IMPORTANT! - When using this function, ALWAYS reset the md-data pointer back
\ to the guest-md using the command '0 md-set-working-md' when finished
: md-set-working-md  ( md-pointer -- )
   ?dup if
      to md-data 
   else
      guest-md to md-data
   then
;

headerless
