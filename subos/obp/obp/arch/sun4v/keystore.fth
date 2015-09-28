\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: keystore.fth
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
id: @(#)keystore.fth 1.4 07/04/10
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ FWARC 2006/523

vocabulary keystore
also keystore definitions

headerless

1 		value key-major
0 		value key-minor
h# 4f42504b4559 value key-svc-handle	\ OBPKEY

\ Keystore Data Message
struct
   /l	field >key-cmd
constant /key-hdr

\ Keystore Data Response
struct
   /l   field >key-response
constant /key-response

\ Keystore Updates Response
struct
   /l   field >key-updates-response
   /l   field >key-updates-size
constant /key-updates-hdr

/key-hdr /key-response + constant /key-response-pkt

d# 1024 constant MAX-VAR-SIZE
MAX-VAR-SIZE /key-hdr + buffer: key-buf

also domain-services
MAX-DS-PAYLOAD constant MAX-UPDATES-SIZE \ that OBP can currently handle
previous

0 value keystore-updates-buf		\ allocated on the fly for MD updates
0 value keystore-backup?	\ Differentiate between the two services

: key-cmd!  	   	( cmd pkt -- )  	>key-cmd l!  ;
: key-cmd@  	   	( pkt -- cmd )  	>key-cmd l@  ;
: >key-payload     	( pkt -- payload-adr )  /key-hdr +  ;
: key-response@  	( pkt -- response )  	>key-payload >key-response l@ ;
: >key-updates-payload	( pkt -- payload-adr )
   >key-payload /key-updates-hdr +
;
: keystore-updates-size@ ( pkt -- size )  /key-hdr + >key-updates-size l@ ; 


\ message types
0 	constant KEYSTORE-SET-REQ
1	constant KEYSTORE-DELETE-REQ
2	constant KEYSTORE-SET-RESP
3	constant KEYSTORE-DELETE-RESP

4	constant KEYSTORE-UPDATES-REQ
5	constant KEYSTORE-UPDATES-RESP

\ Response Result Codes
0	constant KEYSTORE-SUCCESS
1	constant KEYSTORE-NO-SPACE
2	constant KEYSTORE-INVALID-KEY
3	constant KEYSTORE-INVALID-VAL
4	constant KEYSTORE-NOT-PRESENT

\ To coordinate handoffs between Solaris and OBP the state of the 
\ domain-service channel is stored away.  If OBP needs to use the channel
\ after it has been closed it will attempt to re-register its needed service
0 constant KEY-CLOSED
1 constant KEY-OPEN
2 constant KEY-ERROR

KEY-CLOSED value key-service-state

\ Domain-service interfaces
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
: $keystore  		( -- $ )  " keystore"(00)"  ;
: $keystore-backup	( -- $ )  " keystore-backup"(00)"  ;

\ Both init-primary-service and init-secondary-service can be changed
\ to begin/while loops with multiple calls to reigster-domain-service
\ however right now we only support 1.0 so if we get a nack that's it.
: init-primary-service  ( -- error? )    
   key-major key-minor key-svc-handle $keystore
   register-domain-service ?dup 0= if 			( maj/min ack? )
      nip 0=						( nack? )
   then
   dup 0= if  0 to keystore-backup?  then
;

: init-secondary-service  ( -- error? )  
   key-major key-minor key-svc-handle $keystore-backup
   register-domain-service ?dup 0= if 			( maj/min ack? )
      nip 0=						( nack? )
   then
   dup 0= if  -1 to keystore-backup?  then
;

\ Attempt to Register one of the two keystore services
: key-init  ( -- error? )
   init-primary-service dup if			( error? )
      drop init-secondary-service		( error? )
   then						( error? )
   dup if
      KEY-CLOSED to key-service-state
   else
      KEY-OPEN to key-service-state
   then
;

\ Unregister the keystore service
: key-close  ( -- )
   key-service-state KEY-OPEN <> if exit then		(  )
   key-svc-handle unregister-domain-service ?dup if	(  )
      \ If LDC is not up then it has been reset, treat this as closed LDC
      \ which can be re-opened for later operations.
      LDC-NOTUP = if					(  )
         KEY-CLOSED to key-service-state		(  )
      else						(  )
         KEY-ERROR to key-service-state			(  )
      then						(  )
   else							(  )
      KEY-CLOSED to key-service-state			(  )
   then							(  )
   key-svc-handle 1+ to key-svc-handle	\ new handle in case of re-register
;

\ Bring up the keystore channel unless it is in the ERROR state
: check-key-channel-state  ( -- error? )
   key-service-state case
      KEY-OPEN 		of	 0	endof
      KEY-CLOSED	of key-init	endof
      KEY-ERROR		of 	-1	endof
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

\ Wrap set data in a keystore packet to be sent to the domain services layer
: assemble-set-pkt  ( $data $name -- pkt len )
   cat-with-nulls tuck key-buf			( $payload pkt )
   KEYSTORE-SET-REQ over key-cmd!		( payload-len $payload pkt )
   >key-payload swap move			( payload-len )
   key-buf swap /key-hdr +			( pkt len )
;

\ Wrap unset data to be sent to the domain services layer
: assemble-unset-pkt  ( $name -- pkt len )
   to-cstr tuck key-buf				( name-len $name pkt )
   KEYSTORE-DELETE-REQ over key-cmd!		( name-len $name pkt )
   >key-payload swap move			( name-len )
   key-buf swap /key-hdr +			( pkt len )
;

\ Request any updates from the SP since it last created an MD
: assemble-updates-req-pkt  ( -- pkt len )
   keystore-updates-buf			( pkt )
   KEYSTORE-UPDATES-REQ over key-cmd!	( pkt )
   /key-hdr				( pkt len )
;

: key-response?  ( cmd -- key-response? )
   dup KEYSTORE-DELETE-RESP = swap KEYSTORE-SET-RESP = or
;

: key-updates-response?  ( cmd -- ldv-updates-response? )
   KEYSTORE-UPDATES-RESP =
;

\ Wait for keystore response request
: wait-for-key-response  ( -- error )
   key-buf						( buf )
   begin
      dup /key-response-pkt key-svc-handle 		( buf buf len handle )
      receive-ds-data ?dup if				( buf len' | buf error )
         dup LDC-NOTUP  if
	    cmn-warn[ " Waiting for key response but LDC is Not Up!" ]cmn-end
	    \ Mark the service closed so that it can be opened again
            KEY-CLOSED to key-service-state		(  )
         then						( buf error )
         nip exit					( error )
      else						( buf len )
         /key-response-pkt <> if			( buf )
            cmn-warn[ 
	       " No Keystore response from Domain Service Providor "
	    ]cmn-end
            drop -1 exit				( -1 )
         then						( buf )
      then
      dup key-cmd@ key-response?			( buf response? )
   until

   key-response@ case
      KEYSTORE-SUCCESS 	of  0 				endof
      KEYSTORE-NO-SPACE 	of  " No Space"		endof
      KEYSTORE-INVALID-KEY	of  " Invalid Key Name" endof
      KEYSTORE-INVALID-VAL	of  " Invalid Value"	endof
      KEYSTORE-NOT-PRESENT	of  " Key not Present" 	endof
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
  keystore-updates-buf					( buf )
   begin
      dup MAX-UPDATES-SIZE key-svc-handle		( buf buf len handle )
      receive-ds-data ?dup if				( buf len' | buf error )
         dup LDC-NOTUP = if				( buf error )
	    cmn-warn[
	       " Waiting for Keystore Response but LDC is Not Up!"
	    ]cmn-end
	    \ Mark the service closed so that it can be opened again
            KEY-CLOSED to key-service-state		(  )
         then						( buf error )
         nip exit					( error )
      else						( buf len )
         0= if						( buf )
            drop -1 exit				( -1 )
         then						( buf )
      then
      dup key-cmd@ key-updates-response?		( buf response? )
   until						( buf )
   keystore-updates-size@ MAX-UPDATES-SIZE > dup if
      cmn-warn[ " Keystore error - Updates MD too large " ]cmn-end
   then
;


headers

: keystore-set  ( $data $name --  )
   check-key-channel-state if  
      cmn-warn[ " Unable to store Security key" ]cmn-end
      2drop 2drop exit
   then
   assemble-set-pkt			( pkt len )
   key-svc-handle send-ds-data ?dup if	(   | status )
      LDC-NOTUP = if 		( )
         cmn-warn[ " Sending Keystore Set request but LDC is Not Up!" ]cmn-end
	 \ Mark the service closed so that it can be opened again
         KEY-CLOSED to key-service-state	(  )
      else
         key-close				( )
      then
      cmn-warn[ " Keystore Set request failed!" ]cmn-end
      exit				( )
   then					( )
   wait-for-key-response if
      cmn-warn[ " Unable to store security key" ]cmn-end
   then
   key-close
;

: keystore-delete  ( $name -- )
   check-key-channel-state if  
      cmn-warn[ " Unable to Delete Security key" ]cmn-end
      2drop exit
   then
   assemble-unset-pkt			( buf len )
   key-svc-handle send-ds-data ?dup if	(  | status )
      LDC-NOTUP = if 		( )
         cmn-warn[ " Sending Keystore Delete request but LDC is Not Up!" ]cmn-end
         \ Mark the service closed so that it can be opened again
         KEY-CLOSED to key-service-state	(  )
      else
         key-close				( )
      then
      cmn-warn[ " Keystore Delete request failed!" ]cmn-end
      exit				( )
   then					( )
   wait-for-key-response if
      cmn-warn[ " Unable to Delete security key" ]cmn-end
   then
   key-close
;

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

\ Load security keys from the "keystore" MD node.  We do this before
\ initializing the domain service to avoid redundant keystore-set calls
: get-keystore  ( -- )
   0 " keystore" md-find-node ?dup 0= if  exit  then
   0						( node 0 )
   begin
      over swap get-next-str-prop ?dup		( [ node prop prop ] | [ node 0 ] )
   while
      dup md-decode-prop drop			( node prop $data )
      2 pick md-prop-name			( node prop $data $name )
      2swap convert-key drop			( node prop $name data,len )
      (set-security-key) drop			( node prop )
   repeat
   drop
;

\ Load keystore updates from a mini MD
\ 1. Set keys as they appear under the keystore node
\ 2. If the entry name is the reserved word "_delete"... delete the given
\    in the property data field
: update-keystore  (  -- )
   keystore-updates-buf >key-updates-payload md-set-working-md
   0 " keystore" md-find-node ?dup if
      0					( node 0 )
      begin
	 over swap get-next-str-prop ?dup ( [ node prop prop ] | [ node 0 ] )
      while
	 dup md-decode-prop drop	( node prop $data )
	 2 pick md-prop-name		( node prop $data $name )
	 2dup " _delete" $= if		( node prop $data $name )
	    \ len 0 key = delete
	    drop 0 (set-security-key)	( node prop error? )
	    drop			( node prop )
	 else
	    2swap convert-key drop	( node prop $name data,len )
	    (set-security-key) drop	( node prop )
	 then				( node prop )
       repeat
       drop				(  )
    then
    0 md-set-working-md			\ This Line is VERY IMPORTANT
;

\ Request a "mini'MD" from the SP that contains any changes to the
\ keystore MD node since it last created a guest MD
: get-keystore-updates  ( -- )
   check-key-channel-state if
      exit
   then
   \ Only meaningful when talking to the SP
   keystore-backup? if
      MAX-UPDATES-SIZE alloc-mem to keystore-updates-buf
      assemble-updates-req-pkt		( pkt len )
      key-svc-handle send-ds-data ?dup if  (  | status )
         LDC-NOTUP = if 		( )
	    cmn-warn[
	       " Sending Keystore Update request but LDC is Not Up!"
	    ]cmn-end
	    \ Mark the service closed so that it can be opened again
            KEY-CLOSED to key-service-state	( )
         else
            key-close				( )
         then
	 cmn-warn[ " Error sending Keystore Updates request" ]cmn-end
	 keystore-updates-buf MAX-UPDATES-SIZE free-mem
	 exit				(  )
      then				(  )
      wait-for-updates-response 0= if	(  )
	 update-keystore		(  )
      then				(  )
      keystore-updates-buf MAX-UPDATES-SIZE free-mem
   then					(  )
   key-close				(  )
;

previous		\ ldc

headerless

stand-init: Security Key Domain Service Init
   get-keystore
   get-keystore-updates
   ['] keystore-set    is key-set
   ['] keystore-delete is key-delete
;

previous definitions

