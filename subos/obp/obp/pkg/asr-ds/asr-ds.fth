\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: asr-ds.fth
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
id: @(#)asr-ds.fth 1.2 07/04/10
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

1 		value asr-major
0 		value asr-minor
h# 4153524f4250 value asr-svc-handle	\ ASROBP

\ ASR Query Request
struct
   /l	field >asr-cmd
constant /asr-hdr

\ ASR Query Response
struct
   /l   field >query-result
   /l   field >query-status
constant /query-response


d# 1024 /asr-hdr + constant /max-asr-response
/max-asr-response buffer: asr-buf

: asr-cmd!		( cmd pkt -- )  	>asr-cmd l!  ;
: asr-cmd@		( pkt -- cmd )  	>asr-cmd l@  ;
: >asr-payload		( pkt -- payload-adr )  /asr-hdr +  ;

\ message types
9 	constant ASR-QUERY-REQ
h# 19	constant ASR-QUERY-RES

\ ASR Result Codes
0	constant ASR-CMD-OK
1	constant ASR-CMD-FAILED

\ Query Response Status Codes
0	constant ASR-QUERY-ENABLED
1	constant ASR-QUERY-DISABLED

\ To coordinate handoffs between Solaris and OBP the state of the 
\ domain-service channel is stored away.  If OBP needs to use the channel
\ after it has been closed it will attempt to re-register its needed service
0 	constant ASR-CLOSED
1 	constant ASR-OPEN
2 	constant ASR-ERROR

ASR-CLOSED value asr-service-state

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
\ Note: for now only asr-backup service to VBSC is used...
: $asr  	( -- $ )  " asr"(00)"  ;
: $asr-backup	( -- $ )  " asr-backup"(00)"  ;

: init-service  ( -- error? )  
   asr-major asr-minor asr-svc-handle $asr-backup
   register-domain-service ?dup 0= if 			( maj/min ack? )
      nip 0=						( nack? )
   then
;

\ Attempt to Register asr service
: asr-init  ( -- error? )
   init-service				( error? )
   dup if
      ASR-CLOSED to asr-service-state
   else
      ASR-OPEN to asr-service-state
   then
;

\ Unregister the asr service
: asr-close  ( -- )
   asr-svc-handle unregister-domain-service ?dup if     (  )
      \ If LDC is not up then it has been reset, treat this as closed LDC
      \ which can be re-opened for later operations.
      LDC-NOTUP = if                                    (  )
         ASR-CLOSED to asr-service-state                (  )
      else                                              (  )
         ASR-ERROR to asr-service-state                 (  )
      then                                              (  )
   else							(  )
      ASR-CLOSED to asr-service-state			(  )
   then
   asr-svc-handle 1+ to asr-svc-handle	\ new handle in case of re-register
;

\ Bring up the asr channel unless it is in the ERROR state
: check-asr-channel-state  ( -- error? )
   asr-service-state case
      ASR-OPEN 		of	 0	endof
      ASR-CLOSED	of asr-init	endof
      ASR-ERROR		of 	-1	endof
   endcase
;

: asr-response?  ( cmd -- asr-response? )
   dup ASR-QUERY-RES = 
;

\ Wait for asr response request
: receive-asr-response  ( -- buf len 0 | error )
   asr-buf dup /max-asr-response asr-svc-handle ( buf buf len handle )
   receive-ds-data ?dup if			( buf len' | buf error )
      dup LDC-NOTUP = if			( buf error )
	 cmn-warn[ " Waiting for ASR response but LDC is Not Up!" ]cmn-end
         ASR-CLOSED to asr-service-state
      then					( buf error )
      nip					( error )
   else						( buf len' )
      dup 0= if					( buf len' )
         cmn-warn[ " No ASR response from Domain Service Providor " ]cmn-end
         2drop -1 exit				( -1 )
      then
      0						( buf len 0 )
   then						( buf len 0 | error )
;

: $cstrput ( str len dest-adr -- end-adr )
   swap  2dup ca+ >r  move  0 r@ c!  r> ca1+
;

d# 1024 buffer: str-buf

\ " foo" " bar" becomes " foo"(00)"bar"(00)"
: cat-with-nulls ( str len str2 len2 -- str' len' )
   2swap				( str2 len2 str len )
   dup 3 pick + >r			( str2 len2 str len ) ( r: len' )
   str-buf $cstrput $cstrput drop	(  )		      ( r: len' )
   str-buf r> 2+			( str' len' )
;


\ Wrap query data to be sent to the domain services layer
: assemble-query-pkt  ( $nexus $unit -- pkt len )
   cat-with-nulls				( $data )
   tuck asr-buf					( data-len $data pkt )
   ASR-QUERY-REQ over asr-cmd!			( data-len $name pkt )
   >asr-payload swap move			( data-len )
   asr-buf swap /asr-hdr +			( pkt len )
;

: asr-query  ( $nexus $unit -- $response 0 | -1 )
   check-asr-channel-state if			( $nexus $unit )
      2drop 2drop true exit			( true )
   then						( $nexus $unit )
   assemble-query-pkt				( buf len )
   asr-svc-handle send-ds-data ?dup if		( error |  )
      LDC-NOTUP = if
         cmn-warn[ " Sending ASR Query packets but LDC is Not Up!" ]cmn-end
	 \ Mark state to closed so that it can be re-opened later
	 ASR-CLOSED to asr-service-state
      then
      cmn-warn[ " Error sending ASR Query packets - transaction failed" ]cmn-end
      -1 exit
   then
   receive-asr-response	?dup if			( $pkt status )
      cmn-warn[ " Error receiving ASR Query Response" ]cmn-end
   else
      drop dup asr-cmd@ ASR-QUERY-RES = if	( pktbuf )
         >asr-payload /query-response 0		( $response 0 )
      else					( pktbuf )
         drop -1				( -1 )
      then					( $response 0 | -1 )
   then						( $response 0 | -1 )
;

previous 	\ LDC

headers

\      0   The device corresponding to the key is OK.
\ 	 (There is no asr-entry in the asr-db for the device.)
\     -1   The device corresponding to the key is disabled

: query  ( nexus$ unit$ -- status )
   asr-query if					(  )
      cmn-warn[ " ASR Query Failed - No Response" ]cmn-end
      0	\ probe the device anyway		( 0 )
   else						( $response )      
      drop dup >query-result l@			( buf result )
      ASR-CMD-FAILED = if			( buf )
         cmn-warn[ " ASR Query Failed - Command Failed" ]cmn-end
         drop 0	\ probe the device anyway	( 0 )
      else					( buf )
         >query-status l@			( status )

	\ At this time, VBSC only returns 0 for enabled and 1 for disabled
	\ OBP probing code treats status < 0 as "device disabled". The previous
	\ implementation of ASR had a very complex scheme for changing the 1
	\ from vbsc into a -1. That complexity was premature as VBSC never
	\ returned enough information to make complex decisions.  Until it does
	\ this code just treats any non-zero return status as "DISABLED"

         if  -1  else  0  then			( status' )
      then					( status' )
   then						( status' )
;

: open  ( -- okay? )
   check-asr-channel-state 0=
;

: close  ( -- )  
   asr-close
;
