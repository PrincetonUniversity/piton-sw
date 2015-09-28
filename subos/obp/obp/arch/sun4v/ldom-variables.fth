\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ldom-variables.fth
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
id: @(#)ldom-variables.fth 1.6 07/09/12
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ FWARC 2006/055 and 2006/086

vocabulary ldom-variables
also ldom-variables definitions

headerless

1 		value ldv-major
0 		value ldv-minor
h# 4f42504c4456 value ldv-svc-handle	\ OBPLDV

\ LDOM Variable Data Message
struct
   /l	field >ldv-cmd
constant /ldv-hdr

\ LDOM Variable Data Respnse
struct
   /l   field >ldv-response
constant /ldv-response

\ LDOM Variable Updates Response
struct
   /l   field >ldv-updates-response
   /l	field >ldv-updates-size
constant /ldv-updates-hdr

/ldv-hdr /ldv-response + constant /ldv-response-pkt

d# 1024 constant MAX-VAR-SIZE
MAX-VAR-SIZE /ldv-hdr + buffer: ldv-buf

also domain-services
MAX-DS-PAYLOAD constant MAX-UPDATES-SIZE \ that OBP can currently handle
previous

0 value ldv-updates-buf		\ allocated on the fly for MD updates

0 value var-config-backup?	\ Differentiate between the two services

: ldv-cmd!  	   	( cmd pkt -- )  	>ldv-cmd l!  ;
: ldv-cmd@  	   	( pkt -- cmd )  	>ldv-cmd l@  ;
: >ldv-payload     	( pkt -- payload-adr )  /ldv-hdr +  ;
: ldv-response@  	( pkt -- response )  	>ldv-payload >ldv-response l@ ;
: >ldv-updates-payload	( pkt -- payload-adr )
   >ldv-payload /ldv-updates-hdr +
;
: ldv-updates-size@	( pkt -- size ) /ldv-hdr + >ldv-updates-size l@ ;

\ message types
0 	constant VAR-CONFIG-SET-REQ
1	constant VAR-CONFIG-DELETE-REQ
2	constant VAR-CONFIG-SET-RESP
3	constant VAR-CONFIG-DELETE-RESP

4	constant VAR-CONFIG-UPDATES-REQ
5	constant VAR-CONFIG-UPDATES-RESP

\ Response Result Codes
0	constant VAR-CONFIG-SUCCESS
1	constant VAR-CONFIG-NO-SPACE
2	constant VAR-CONFIG-INVALID-VAR
3	constant VAR-CONFIG-INVALID-VAL
4	constant VAR-CONFIG-NOT-PRESENT

\ To coordinate handoffs between Solaris and OBP the state of the 
\ domain-service channel is stored away.  If OBP needs to use the channel
\ after it has been closed it will attempt to re-register its needed service
0 constant LDV-CLOSED
1 constant LDV-OPEN
2 constant LDV-ERROR

LDV-CLOSED 	value ldv-service-state

\ By default when OBP requires the use of the LDOM variable service
\ it will first register it, then use it, then unregister.
true 		value ldv-unreg-on-complete?

\ Domain-service interfaces:
\ Send buffer on the given service channel
: send-ds-data  ( buf len svc-handle -- error? )
   [ also domain-services ] send-ds-data [ previous ]
;

\ Receive a packet of at most len from the given service channel
: receive-ds-data  ( buf len svc-handle -- len' 0 | error )
   [ also domain-services ] receive-ds-data [ previous ]
;
\ Attempt to register $svc-id with svc-handle.  Returns error/ack/nack
: register-domain-service ( maj min svc-han $svc-id -- maj/min ack? 0 | -1 )
   [ also domain-services ] register-domain-service [ previous ]
;

\ Unregister the domain service negotiated on svc-handle
: unregister-domain-service  ( svc-handle -- error? )
   [ also domain-services ] unregister-domain-service [ previous ]
;

also ldc

\ service IDs with Null Character embedded
: $var-config  		( -- $ )  " var-config"(00)"  ;
: $var-config-backup	( -- $ )  " var-config-backup"(00)"  ;

\ Both init-primary-service and init-secondary-service can be changed
\ to begin/while loops with multiple calls to reigster-domain-service
\ however right now we only support 1.0 so if we get a nack that's it.
: init-primary-service  ( -- error? )    
   ldv-major ldv-minor ldv-svc-handle $var-config
   register-domain-service  ?dup 0= if 			( maj/min ack? )
      nip 0=						( nack? )
   then
   dup 0= if  0 to var-config-backup?  then
;

: init-secondary-service  ( -- error? )  
   ldv-major ldv-minor ldv-svc-handle $var-config-backup
   register-domain-service ?dup 0= if 			( maj/min ack? )
      nip 0=						( nack? )
   then
   dup 0= if  -1 to var-config-backup?  then
;

\ Attempt to Register one of the two LDOM variable services
: ldv-init  ( -- error? )
   init-primary-service dup if			( error? )
      drop init-secondary-service		( error? )
   then						( error? )
   dup if
      LDV-CLOSED to ldv-service-state
   else
      LDV-OPEN to ldv-service-state
   then
;

\ Unregister the LDOM variable service
: ldv-close  ( -- )
   ldv-service-state LDV-OPEN <> if  exit  then		(  )
   ldv-svc-handle unregister-domain-service ?dup if	(  )
      \ If LDC is not up then it has been reset, treat this as closed LDC
      \ which can be re-opened for later operations.
      LDC-NOTUP = if					(  ) 
  	 LDV-CLOSED to ldv-service-state 		(  )
      else						(  )
         LDV-ERROR to ldv-service-state			(  )
      then						(  )
   else							(  )
      LDV-CLOSED to ldv-service-state			(  )
   then							(  )
   ldv-svc-handle 1+ to ldv-svc-handle	\ new handle in case of re-register
;

\ Bring up the ldom variable channel unless it is in the ERROR state
: check-ldv-channel-state  ( -- error? )
   ldv-service-state case
      LDV-OPEN 		of	 0	endof
      LDV-CLOSED	of ldv-init	endof
      LDV-ERROR		of 	-1	endof
   endcase
;

\ Store string as a null-terminated string and return pointer past the 
\ terminating null character.
: $cstrput ( str len dest-adr -- end-adr )
   swap  2dup ca+ >r  move  0 r@ c!  r> ca1+
;

d# 1024 buffer: str-buf

\ " foo" " bar" becomes " foo"(00)"bar"(00)"
: cat-with-nulls ( str len str2 len2 -- str' len' )
   dup 3 pick + >r
   str-buf $cstrput $cstrput drop
   str-buf r> 2+
;

\ add trailing 0
: to-cstr  ( buf len -- buf' len' )
   tuck str-buf $cstrput drop		( len )
   str-buf swap 1+			( buf len' )
;

\ Wrap set data in an LDV packet to be sent to the domain services layer
: assemble-set-pkt  ( $data $name -- pkt len )
   cat-with-nulls tuck ldv-buf			( $payload pkt )
   VAR-CONFIG-SET-REQ over ldv-cmd!		( payload-len $payload pkt )
   >ldv-payload swap move			( payload-len )
   ldv-buf swap /ldv-hdr +			( pkt len )
;

\ Wrap unset data to be sent to the domain services layer
: assemble-unset-pkt  ( $name -- pkt len )
   to-cstr tuck ldv-buf				( name-len $name pkt )
   VAR-CONFIG-DELETE-REQ over ldv-cmd!		( name-len $name pkt )
   >ldv-payload swap move			( name-len )
   ldv-buf swap /ldv-hdr +			( pkt len )
;

\ Request any updates from the SP since it last created an MD
: assemble-updates-req-pkt  ( -- pkt len )
   ldv-updates-buf				( pkt )
   VAR-CONFIG-UPDATES-REQ over ldv-cmd!		( pkt )
   /ldv-hdr					( pkt len )
;

: ldv-response?  ( cmd -- ldv-response? )
   dup VAR-CONFIG-DELETE-RESP = swap VAR-CONFIG-SET-RESP = or
;

: ldv-updates-response?  ( cmd -- ldv-updates-response? )
   VAR-CONFIG-UPDATES-RESP =
;

\ Note that the VAR-CONFIG-NOT-PRESENT error is ignored.  This error
\ might be triggered when a user does a set-default on a variable that's 
\ already a default
: wait-for-ldv-response  ( -- error )
   ldv-buf						( buf )
   begin
      dup /ldv-response-pkt ldv-svc-handle		( buf buf len handle )
      receive-ds-data ?dup if				( buf len' | buf error )
         dup LDC-NOTUP = if				( buf error )
	    cmn-warn[
	       " Waiting for LDOM Variable response but LDC is Not Up!"
	    ]cmn-end
	    \ Mark this service as closed so that it can be opened again
	    LDV-CLOSED to ldv-service-state		( buf error )
	 then						( buf error )
	 nip exit					( error )
      else
         /ldv-response-pkt <> if			( buf )
            cmn-warn[
	       " No LDOM Variable response from Domain Service Providor "
	    ]cmn-end
            drop -1 exit				( -1 )
         then						( buf )
      then
      dup ldv-cmd@ ldv-response?			( buf response? )
   until

   ldv-response@ case
      VAR-CONFIG-SUCCESS 	of  0 				endof
      VAR-CONFIG-NO-SPACE 	of  " No Space"			endof
      VAR-CONFIG-INVALID-VAR	of  " Invalid Variable" 	endof
      VAR-CONFIG-INVALID-VAL	of  " Invalid Value"		endof
      VAR-CONFIG-NOT-PRESENT    of  0 				endof
      0 swap
   endcase
   dup if
      cmn-warn[ ]cmn-end -1
   then
;

\ The updates response could be large.  The domain-service interface layer
\ should be updated to handle variable length packets until it is, we default
\ to the current max size of an OBP domain-service packet (8K)
: wait-for-updates-response  ( -- error )
  ldv-updates-buf					( buf )
   begin
      dup MAX-UPDATES-SIZE ldv-svc-handle		( buf buf len handle )
      receive-ds-data ?dup if				( buf len' | buf error )
         dup LDC-NOTUP = if				( buf error )
	    cmn-warn[ 
	       " Waiting for LDOM Variable updates but LDC is Not Up!"
	    ]cmn-end
	    \ Mark this service as closed so that it can be opened again
	    LDV-CLOSED to ldv-service-state		( buf error )
         then						( buf error )
         nip exit					( error )
      else						( but len' )
         0= if						( buf )
            drop -1 exit				( -1 )
         then						( buf )
      then
      dup ldv-cmd@ ldv-updates-response?		( buf response? )
   until						( buf )
   \ if the MD is larger than we can handle return error
   ldv-updates-size@ MAX-UPDATES-SIZE >	dup if		( error? )
      cmn-warn[ " LDOM Variable Updates Error - MD too large " ]cmn-end
   then
;

MAX-VAR-SIZE buffer: ascii-buffer-str

\ Return true if the LDOM variable being set is a byte array, false otherwise.
\ Currently, oem-logo is the only byte-array LDOM variable that users can modify
\ from Openboot. Any future byte-array variables will need to be added to the
\ check in this method.
: byte-variable? ( name-str name-len -- byte? )
   " oem-logo" $=
;

\ Convert a byte array to an ASCII string
: byte-var>ascii ( data1-addr data1-len -- data2-str data2-len )
   dup 2* -rot                         ( data2-len data1-str data1-len )
   0 ?do                               ( data2-len data1-str )
      dup i + c@                       ( data2-len data1-str byte )
      dup h# f and swap h# f0 and 4 >> ( data2-len data1-str u1 u2 )
      ascii-buffer-str i 2* +          ( data2-len data1-str u1 u2 data2-str )
      tuck swap (u.) rot swap move     ( data2-len data1-str u1 data2-str )
      1+ swap (u.) rot swap move       ( data2-len data1-str )
   loop                                ( data2-len data1-str )
   drop ascii-buffer-str swap          ( data2-str data2-len )
;

\ Convert an ascii string into a byte variable
: ascii>byte-var ( data1-str data1-len -- data2-str data2-len )
   dup 2/ -rot                         ( data2-len data1-str data1-len)
   0 ?do                               ( data2-len data1-str )
      dup i + 2 $number drop           ( data2-len data1-str byte )
      ascii-buffer-str i 2/ + c!       ( data2-len data1-str )
   2 +loop                             ( data2-len data1-str )
   drop ascii-buffer-str swap          ( data2-str data2-len )
;

: setenv-ldoms-var ( data-str data-len name-str name-len -- )
   2dup byte-variable? if
      2swap ascii>byte-var 2swap
   then
   $silent-setenv
;

headers

: ldom-variable-set  ( $data $name --  )
   2dup byte-variable? if
      2 pick 2* MAX-VAR-SIZE > if
         cmn-warn[ " byte array LDOM Variable exceeds maximum length." ]cmn-end
         2drop 2drop exit
      then
      2swap byte-var>ascii 2swap
   else
      2 pick MAX-VAR-SIZE > if
         cmn-warn[ " LDOM Variable exceeds maximum length." ]cmn-end
         2drop 2drop exit
      then
   then
   check-ldv-channel-state if  
      cmn-warn[ " Unable to update LDOM Variable" ]cmn-end
      2drop 2drop exit
   then
   assemble-set-pkt			( pkt len )
   ldv-svc-handle send-ds-data ?dup if	( status )
      LDC-NOTUP = if			(  )
         cmn-warn[
	    " Sending LDOM Variable Set request but LDC is Not Up!"
         ]cmn-end
	 \ Mark this service as closed so that it can be opened again
	 LDV-CLOSED to ldv-service-state  ( )
      else				(  )
         ldv-unreg-on-complete? if	(  )
            ldv-close			(  )
         then				(  )
      then				(  )
      cmn-warn[ " Error sending LDOM Variable Set request" ]cmn-end
      exit
   then
   wait-for-ldv-response if
      cmn-warn[ " Unable to set LDOM Variable" ]cmn-end
   then
   ldv-unreg-on-complete? if
      ldv-close
   then
;

: ldom-variable-delete  ( $name -- )
   check-ldv-channel-state if
      cmn-warn[ " Unable to update LDOM Variable" ]cmn-end
      2drop exit
   then
   assemble-unset-pkt			( pkt len )
   ldv-svc-handle send-ds-data ?dup if	( status )
      LDC-NOTUP = if			(  )
         cmn-warn[
	    " Sending LDOM Variable Delete request but LDC is Not Up!"
         ]cmn-end
	 \ Mark this service as closed so that it can be opened again
	 LDV-CLOSED to ldv-service-state  (  )
      else				(  )
         ldv-unreg-on-complete? if	(  )
            ldv-close			(  )
         then				(  )
      then				(  )
      cmn-warn[ " LDOM Variable Delete request failed!" ]cmn-end
      exit
   then
   wait-for-ldv-response if
      cmn-warn[ " Unable to Delete LDOM Variable" ]cmn-end
   then
   ldv-unreg-on-complete? if
      ldv-close
   then
;

headerless

\ Get the next string property in MD node
: get-next-str-prop  ( node prop -- ent|0 )
   begin				( node prop )
      over swap md-next-prop dup	( node prop,prop|0,0 )
   while
      dup md-prop-type ascii s = if	( node prop )
         nip exit			( prop )
      then				( node prop )
   repeat
   nip					( 0 )
;

\ Load nvram variables from the "variables" MD node
\ 1. Entry is an update to an existing variable... update variable
\ 2. Entry is an unknown variable... ignore
: get-md-variables  ( -- )
   0 " variables" md-find-node ?dup 0= if  exit  then  
   0					( node 0 )
   begin
      over swap get-next-str-prop ?dup	( [ node prop prop ] | [ node 0 ] )
   while
      dup md-decode-prop drop		( node prop $data )
      2 pick md-prop-name		( node prop $data $name )
      2dup $getenv if			( n p $data $name )
         2drop 2drop			( node prop )
      else				( n p $data $name $value )
         2drop  			( n p $data $name )
         setenv-ldoms-var		( node prop)
      then   
   repeat
   drop
;

: mem64-enabled-in-md? ( -- true | false )
   0 " openboot" md-find-node ?dup if                   	( node )
      " pci-mem64-support" ascii v md-find-prop ?dup if  	( prop )
         md-decode-prop drop exit                        		( data | 0 )
      then
  then
  false
;

: update-mem64-default ( -- )
   mem64-enabled-in-md? if
      " true"
   else
      " false"
   then 
   " pci-mem64?" $silent-change-default
;

\ Load nvram variables from a mini MD
\ 1. Entry is an update to an existing variable... update variable
\ 2. Entry is an unknown variable... ignore
\ 3. Entry is reserved word "_delete"... set-default on variable in prop-data
: update-ldom-variables  (  -- )
   ldv-updates-buf >ldv-updates-payload md-set-working-md
   0 " variables" md-find-node ?dup if
      0					( node 0 )
      begin
	 over swap get-next-str-prop ?dup ( [ node prop prop ] | [ node 0 ] )
      while
	 dup md-decode-prop drop	( node prop $data )
	 2 pick md-prop-name		( node prop $data $name )
	 2dup " _delete" $= if		( node prop $data $name )
	    2drop $set-default		( node prop )
	 else
	    2dup $getenv if		( n p $data $name )
	       2drop 2drop		( node prop )
	    else			( n p $data $name $value )
	       2drop  			( n p $data $name )
	       setenv-ldoms-var		( node prop)
	    then			( node prop )
	 then				( node prop )
       repeat
       drop				(  )
    then
    0 md-set-working-md			\ This Line is VERY IMPORTANT
;

\ Request a "mini-MD" from the SP that contains any ldom variable changes
\ since it created the guest MD
: get-variable-updates  ( -- )
   check-ldv-channel-state if			(  )
      cmn-warn[ " Unable to get LDOM Variable Updates" ]cmn-end
      exit					(  )
   then						(  )
   \ Only meaningful when talking to the SP
   var-config-backup? if			(  )
      MAX-UPDATES-SIZE alloc-mem to ldv-updates-buf	(  )
      assemble-updates-req-pkt			( pkt len )
      ldv-svc-handle send-ds-data ?dup if	( status )
         LDC-NOTUP = if				(  )
            cmn-warn[
	       " Sending LDOM Variable Update request but LDC is Not Up!"
            ]cmn-end
	    \ Mark this service as closed so that it can be opened again
	    LDV-CLOSED to ldv-service-state	(  )
         else					(  )
            ldv-unreg-on-complete? if		(  )
               ldv-close			(  )
            then				(  )
         then					(  )
         cmn-warn[ " LDOMs Variable Update request failed!" ]cmn-end
         ldv-updates-buf MAX-UPDATES-SIZE free-mem 	(  )
         exit					(  )
      then					(  )
      wait-for-updates-response 0= if		(  )
	 update-ldom-variables			(  )
      else
         cmn-warn[ " LDOMs Variable Update request failed!" ]cmn-end
      then					(  )
      ldv-updates-buf MAX-UPDATES-SIZE free-mem (  )
   then
   ldv-unreg-on-complete? if			(  )
      ldv-close					(  )
   then						(  )
;

previous		\ ldc

\ read ldom-variables from the MD and then ask for updates from the
\ domain-service providor if we are using the var-config-backup service.
\ Variables may have changed since the guest MD has been created
stand-init: LDOM variable init
   update-mem64-default
   get-md-variables
   get-variable-updates
   ?secure
   [ also nvdevice ]
   ['] ldom-variable-set    is variable-set
   ['] ldom-variable-delete is variable-unset
   [ previous ]
;

previous definitions

headers
\ Rather than register and unregister the LDOM Variable service
\ for an ldom-variable-delete of EVERY variable keep the service
\ registered until the set-defaults command is complete.
overload: set-defaults  ( -- )
   [ also ldom-variables ]
   false to ldv-unreg-on-complete?	\ keep the service registered
   set-defaults				\ set-defaults
   ldv-close				\ unregister the service
   true to ldv-unreg-on-complete?   	\ back to standard proceedure
   [ previous ]
;

headerless
