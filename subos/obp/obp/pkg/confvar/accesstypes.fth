\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: accesstypes.fth
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
id: @(#)accesstypes.fth 1.10 06/11/09
purpose:
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

variable config-buffer

: config-byte@	( apf -- byte )		config-adr c@  ;
: config-short@ ( apf -- short )	config-adr w@  ;
: config-xint@  ( apf -- double )	config-adr x@  ;
: config-int@	( apf -- int )		config-adr unaligned-l@  ;

: same-as-default? ( apf data len -- acf data,len,false | acf true )
   rot >r					( data len )
   r@ token@ -rot r@ nodefault? if		( acf data len' )
      r> drop false				( acf data len' false )
   else						( data len' acf )
      2dup r> >config-default swap comp if	( acf data len' )
         false					( acf ptr len false )
      else					( acf len ptr )
         2drop true				( acf true )
      then
   then
;

[ifdef] SUN4V

\ LDOM Variable hooks (FWARC 2006/055)
defer variable-set    ( $data $name -- )
defer variable-unset  ( $name -- )

: dont-set    ( $data $name -- )  2drop 2drop  ;
: dont-unset  ( $name -- )        2drop        ;

['] dont-set   is variable-set
['] dont-unset is variable-unset

: config-store ( apf adr len -- )
   options-open? 0= if  3drop  exit  then	( )
   2 pick body> >r
   same-as-default? if				( apf )
      3 perform-action				( )
      r@ >name name>string 			( $name ) 	( r: acf )
      variable-unset				( )       	( r: acf )
   else						( apf adr len )	( r: acf )
      rot set					( )		( r: acf )
      r@ get r@ decode ?dup 0= if		( addr len | addr ) ( r: acf )
         drop r@ get				( addr,len ) ( r: acf )
      then					( addr,len ) ( r: acf )
      r@ >name name>string			( $data $name )	( r: acf )
      variable-set				( ) ( r: acf )
   then						( ) ( r: acf )
   r> drop					( )
;

: null-config-string  ( -- adr len )  " "(00)"(00)" ;

\ Must still inform ldom-variable backing store of 0 length strings.. 
\ example: set-default nvramrc
: release-config-resource ( str 0 apf -- )  
   -rot 2drop null-config-string config-store
;

[else]

: config-store ( apf adr len -- )
   options-open? 0= if  3drop  exit  then	( )
   same-as-default? if				( apf adr,len )
      3 perform-action				( )
   else						( apf adr,len )
      rot set					( )
   then						( )
;

: release-config-resource ( str 0 apf -- )  token@ 3 perform-action  2drop  ;

[then]

: setup-data ( data apf -- apf adr data adr )  swap config-buffer tuck  ;

: config-byte! ( byte apf -- )		setup-data c! /c config-store  ;
: config-short! ( short apf -- )	setup-data w! /w config-store  ;
: config-int! ( int apf -- )		setup-data l! /l config-store  ;
: config-xint! ( int apf -- )		setup-data x! /x config-store  ;

: config-string@ ( apf -- str,len )
   dup get-config-buffer ?dup if		( apf adr,len )
      rot 2drop count				( adr,len )
   else						( apf adr )
      over nodefault? if			( apf adr )
         nip 0					( adr,0 )
      else					( apf adr )
         drop >config-default count		( adr,len )
      then					( adr,len )
   then						( adr,len )
;

: config-long-string@ ( apf -- str,len )
   dup get-config-buffer ?dup if		( apf adr,len )
      rot drop 1-				( adr,len )
   else						( apf adr )
      over nodefault? if			( apf adr )
         nip 0					( adr,0 )
      else					( apf adr )
         drop >config-default cscount		( adr,len )
      then					( adr,len )
   then						( adr,len )
;

: config-string! ( str,len apf -- )
   over if
      >r r@ >config-len 2- min			( str,len' )
      dup 2+ dup >r				( str len len' )
      alloc-mem pack				( mem )
      r> 2dup r> -rot				( mem len apf mem len )
      config-store				( mem len )
      free-mem					( -- )
   else						( str len apf )
      release-config-resource			( -- )
   then						( -- )
;

: config-long-string! ( str,len apf -- )
   over if
      >r r@ >config-len 1- min			( str,len' )
      dup 1+ dup >r  alloc-mem  place-cstr  r>	( mem len' )
      2dup r> -rot  config-store		( mem len' )
      free-mem					( )
   else						( str len apf )
      release-config-resource			( )
   then						( )
;

: config-getbytes ( apf -- adr,len )
   dup get-config-buffer ?dup if		( apf adr,len )
      rot drop					( adr,len )
      /w - swap wa1+ swap			( adr', len' )
   else						( apf adr )
      over nodefault? if			( apf adr )
         nip 0					( adr,0 )
      else					( apf adr )
         drop >config-default			( adr )
         dup wa1+ swap w@			( adr,len )
      then					( adr,len )
   then						( adr,len )
;

: config-setbytes ( adr len apf -- )
   over if					( adr len apf )
      >r r@ >config-len /w - min		( str,len' )
      dup /w + dup >r				( str len len' )
      alloc-mem dup >r				( str len mem )
      2dup w!					( str len mem )
      wa1+ swap move				( )
      r> r> 2dup r> -rot			( mem len apf mem len )
      config-store				( mem len )
      free-mem					( )
   else						( adr len apf )
      release-config-resource			( )
   then						( )
;
