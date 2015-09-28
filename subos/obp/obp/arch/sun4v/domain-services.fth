\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: domain-services.fth
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
id: @(#)domain-services.fth 1.8 07/06/22
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ FWARC 2006/055

vocabulary domain-services
also domain-services definitions

headerless

fload ${BP}/arch/sun4v/ds-h.fth

also ldc

-1 value cached-ldc-id

\ node = domain-services-port
\ return pointer to the id property in the accociated channel endpoint
: get-endpoint-id  ( node -- id | -1 )
   " fwd" ascii a md-find-prop ?dup if				( arc )
      md-decode-prop drop " id" ascii v md-find-prop ?dup if	( prop )
         md-decode-prop drop exit				( id )
      then
   then
   -1			\ error
;

0 value found-channel?

\ if this is a domain-service port attempt to open it unless we've already
\ opened a port.  node = domain-service-port
: open-ds-channel  ( node -- )
   cached-ldc-id -1 <> if  drop exit  then			( node )
   dup md-node-name " domain-services-port" $= if		( node )
      get-endpoint-id dup -1 <> if				( id )
         true to found-channel?
	 dup ldc-mode-reliable ldc-open if			( id )
	    to cached-ldc-id exit				(  )
	 then							( id )
      then							( id )
   then								( node )
   drop								(  )
;

\ When operating on the default MDs OBP uses a private channel
: try-openboot-channel  ( -- error? )
   md-root-node " openboot" md-find-node ?dup if		( node )
      ['] open-ds-channel swap md-applyto-fwds			(  )
   then								(  )
   \ if we haven't cached an id then the open failed
   cached-ldc-id -1 =						( error? )
;

\ When operating on zeus MDs Openboot  may use 1 of 2 centrally located
\ channels depending on whether it is the primary domain or a guest
: try-other-channels  ( -- error? )
   md-root-node " domain-services" md-find-node ?dup if		( node )
      ['] open-ds-channel swap md-applyto-fwds			(  )
   then								(  )
   \ if we haven't cached an id then the opens failed
   cached-ldc-id -1 =						( error? )
;

\ Find and bring up the domain services LDC channel
\ if we are reopening, the channel will be cached so skip the search
: init-ldc-channel (  -- error? )
   cached-ldc-id -1 <> if					(  )
      cached-ldc-id ldc-mode-reliable ldc-open 0=		( error? )
   else								(  )
      0 to found-channel?
      try-openboot-channel dup if				( error? )
         found-channel? 0= if
            try-other-channels and					( error? )
         then
      then							( error? )
   then								( error? )
;   

: ldc-channel-reconfigured?  ( -- reconfigured? )
   channel-reconfigured?
;

\ send a domain service packet over the ldc channel
: send-ds-pkt  ( buf len -- error? )
   tuck ldc-write ?dup if			( len len' status )
      dup LDC-NOTUP = if			( len len' status )
      	 DS-CLOSED to domain-service-state	( len len' status )
      then					( len len' status )
      -rot 2drop 				( error  )
   else						( len len' )
      <> 					( error? )
   then						( error? )
;

\ receive a domain service packet from the ldc channel
\ wait up to 1 second for a response
: receive-ds-pkt  ( buf len -- error? )
   \ Re-try 10 times, @ 10 seconds as lower layer tries for 1 sec
   d# 10				( buf len timeout )
   begin				( buf len timeout )
      1 ms 1- dup			( buf len timeout timeout )
   while
      -rot 2dup ldc-read ?dup if	( timeout buf len len' status )
	 nip				( timeout buf len status )
	 LDC-NOTUP = if			( timeout buf len )
	    DS-CLOSED to domain-service-state	(  )
	    3drop LDC-NOTUP exit	( LDC-NOTUP )
         then				( timeout buf len )
      else				( timeout buf len len' )
         if				( timeout buf len )
            3drop 0 exit		( 0 )
         then				( timeout buf len )
      then				( timeout buf len )
      rot				( buf len timeout )
   repeat
   3drop -1				( error )
;

\ assemble a domain service version packet
: assemble-init-req  ( major minor  -- size )
   ds-pkt-buffer			( major minor buf )
   DS-INIT-REQ over msg-type!		( major minor buf )
   /ds-init-req over payload-len!	( major minor buf )
   >payload				( major minor payload )
   tuck >init-minor-ver w!		( major payload )
   tuck >init-major-ver w!		( buf )
   payload>pkt dup pkt-size@		( buf size )
;

\ wait for a domain service version response
: wait-for-init-resp  ( -- buf len error? )
   ds-pkt-buffer /ds-hdr /ds-init-ack +	( buf len )
   begin
      2dup receive-ds-pkt dup 		( buf len error? error? )
      LDC-NOTUP = if			( buf len error? )
	 cmn-warn[ 
	    " Waiting for DS init response but LDC is Not Up!"
	 ]cmn-end			( buf len error? )
	 exit				( buf len LDC-NOTUP )
      then				( buf len error? )
      0=
   while
      over >msg-type l@				( buf len type )
      dup DS-INIT-ACK  = if  drop 0  exit  then	( buf len  0 )
          DS-INIT-NACK = if      -1  exit  then	( buf len -1 )
   repeat
   -1						( buf len -1 )
;

: init-ack?  ( type -- ack? )  DS-INIT-ACK =  ;

\ parse domain service version response
: parse-init-req  ( pkt len -- major/minor type )
   drop dup >msg-type l@ tuck			( type pkt type )
   init-ack? if
      >payload >init-ack-minor-vers w@		( type minor )
   else
      >payload >init-nack-major-vers w@		( type major )
   then
   swap						( major/minor type )
;

\ assemble and send a domain service version request
: ds-init-request  ( major minor -- major/minor type 0 | error )
   assemble-init-req   			( buf size )
   send-ds-pkt ?dup if  		( error )
      dup LDC-NOTUP = if 
	 cmn-warn[ " Sending DS Init request but LDC is NOT Up!" ]cmn-end
      then				( LDC-NOTUP )
      exit  				( error )
   then					( error )
   wait-for-init-resp ?dup 0= if	( buf len )
      parse-init-req 0			( major/minor type 0 )
   else					( buf len error? )
      -rot 2drop			( error )
   then					( major/minor type 0 | error )
;

\ This can later be turned into a begin while loop that handles
\ multiple versions... however right now only 1.0 is supported
: ds-init-handshake  ( -- error? )
   ds-major ds-minor			( major minor )
   ds-init-request ?dup if  exit  then	( major/minor type | error? )
   init-ack? if	
      to ds-minor 0			( 0 )
   else
      drop -1				( error )
   then
;

\ initialize domain-services protocal link
: ds-init  ( -- error? )
   init-ldc-channel ?dup 0= if
      ds-init-handshake dup if
         cmn-note[ 
         " Unable to complete Domain Service protocol version handshake" 
         ]cmn-end
      then
   then
   dup if
      \ If error is LDC reset then leave the state as DS-CLOSE
      dup LDC-NOTUP <> if
         DS-ERROR to domain-service-state
      then
      cmn-warn[ " Unable to connect to Domain Service providers" ]cmn-end
   else
      DS-OPEN to domain-service-state
   then
;

\ assemble a particular service registration version request
: assemble-reg-req  ( major minor svc-handle $svc-id -- buf len )
   ds-pkt-buffer			( major minor svc-handle $svc-id pkt )
   DS-REG-REQ over msg-type!		( major minor svc-handle $svc-id pkt )
   over /ds-reg-req + over payload-len! ( major minor svc-handle $svc-id pkt )
   >payload				( major minor svc-handle $svc-id pay )
   -rot 2 pick >reg-svc-id swap move	( major minor svc-handle payload )
   tuck >reg-svc-handle x!		( major minor payload )
   tuck >reg-minor-ver w!		( major payload )
   tuck >reg-major-ver w!		( payload )
   payload>pkt dup pkt-size@		( buf len )
;

\ wait for a service registration version response
: wait-for-reg-resp  ( -- buf len error? )
   ds-pkt-buffer /ds-hdr /ds-reg-ack +		( buf len )
   begin
      2dup receive-ds-pkt dup			( buf len error? error? )
      LDC-NOTUP = if 				( buf len error? )
	 cmn-warn[ 
	    " Waiting for DS registration response but LDC is Not Up!"
	 ]cmn-end				( buf len error? )
         exit					( buf len LDC-NOTUP )
      then					( buf len error? )
      0=
   while
      over >msg-type l@				( buf len type )
      dup DS-REG-ACK  = if  drop 0  exit  then	( buf len  0 )
          DS-REG-NACK = if      -1  exit  then	( buf len -1 )
   repeat
   -1						( buf len -1 )
;

\ assemble a service unregistration request
: assemble-unreg-req  ( svc-handle -- pkt size )
   ds-pkt-buffer			( svc-handle pkt )
   DS-UNREG over msg-type!		( svc-handle pkt )
   /ds-unreg-req over payload-len!	( svc-handle pkt )
   tuck >payload >unreg-svc-handle x!	( pkt )
   dup pkt-size@			( pkt len )
;

\ wait for service unregistration response
: wait-for-unreg-resp  ( -- error? )
   ds-pkt-buffer /ds-hdr /ds-unreg-req +	( buf len )
   begin
      2dup receive-ds-pkt dup 			( buf len error? error? )
      LDC-NOTUP = if				( buf len error? )
         cmn-warn[ 
	    " Waiting for DS unregister response but LDC is Not Up!"
         ]cmn-end				( buf len error? )
	 -rot 2drop exit			( LDC-NOTUP )
     then					( buf len error? )
     0=
   while
      over >msg-type l@				( buf len type )
      dup DS-UNREG-ACK  = if  3drop 0  exit  then	( 0 )
          DS-UNREG-NACK = if  2drop      -1 exit  then	( -1 )
   repeat
   2drop -1					( -1 )
;

: reg-ack?  ( type -- ack? )  DS-REG-ACK =  ;

\ parse a service registration request-response
: parse-reg-req  ( pkt len -- major/minor type )
   drop dup >msg-type l@ tuck			( type pkt type )
   reg-ack? if
      >payload >regack-minor-vers w@		( type minor )
   else
      >payload >regnack-major-vers w@		( type major )
   then
   swap						( major/minor type )
;

\ assemble and send a service registration request
: ds-reg-request  ( $svc-id svc-handle major minor -- major/minor type 0 | error )
   assemble-reg-req   			( buf size )
   send-ds-pkt ?dup  if 
      dup LDC-NOTUP = if		( LDC-NOTUP )
	 cmn-warn[ " Sending DS Reg request but LDC is Not Up!" ]cmn-end
      then				( LDC-NOTUP )
      exit				( error )
   then					( error )
   wait-for-reg-resp ?dup if		( buf len error )
      -rot 2drop 			( error )
   else
      parse-reg-req reg-ack? 0		( major/minor ack? 0 )
   then
;

\ assemble a domain service data packet
: assemble-data-pkt  ( buf len svc-handle -- pkt len' )
   ds-pkt-buffer			( buf len svc-handle pkt )
   DS-DATA over msg-type!		( buf len svc-handle pkt )
   tuck >payload >data-svc-handle x!	( buf len pkt )
   over /ds-data + over payload-len!	( buf len pkt )
   >payload /ds-data + swap move	( )
   ds-pkt-buffer 			( pkt )
   dup pkt-size@			( pkt len )
; 

\ extracts start and length of a Data pkt
: data-payload  ( pkt -- payload-buf payload-len )
   dup >payload /ds-data + 		( pkt payload-buf )
   swap payload-len@ /ds-data -		( payload-buf payload-len )
;

\ receive a data packet from the domain-service channel 
\ (only copy payload to buf)
: wait-for-data-pkt  ( buf len svc-handle -- len' 0 | error )
   ds-pkt-buffer rot 			( buf svc-handle pkt len )
   /ds-hdr + /ds-data + 		( buf svc-handle pkt len' )
   begin
      2dup receive-ds-pkt ?dup if	( buf svc-handle pkt len status )
         >r 2drop 2drop r> exit		( error )
      then				( buf svc-handle pkt len )
      over msg-type@ DS-DATA = if	( buf svc-handle pkt len )
         -rot 2dup >payload 		( buf len svc-handle pkt svc-h pay )
         >data-svc-handle x@ = if	( buf len svc-handle pkt )
            rot -1			( buf svc-handle pkt len -1 )
         else
            rot 0			( buf svc-handle pkt len 0 )
         then
      else
         0				( buf svc-handle pkt len 0 )
      then				( buf svc-handle pkt len good? )
   until				( buf svc-handle pkt len )
   drop nip data-payload		( buf payload payload-len )
   >r swap r@ move r> 0			( len' 0 )
;

\ Bring up domain service channel unless it's in the ERROR state
: check-domain-service-state  ( -- error? )
   \ If we think the channel is open, but some other entity (Solaris)
   \ has reconfigured it, we play it safe and tranistion to an error state
   domain-service-state DS-OPEN = if
      ldc-channel-reconfigured? if
         DS-ERROR to domain-service-state
      then
   then

   domain-service-state case
      DS-OPEN 		of	 0	endof
      DS-CLOSED		of ds-init	endof
      DS-ERROR		of 	-1	endof
   endcase
;

headers

\ Wrap buffer in a domain service packet and send it on the specified channel
: send-ds-data  ( buf len svc-handle -- error? )
   check-domain-service-state if  
      3drop -1 exit					( -1 )  
   then
   assemble-data-pkt					( pkt len )
   send-ds-pkt						( error? )
;

\ Receive a data packet from the specified channel
: receive-ds-data  ( buf len svc-handle -- len' 0 | error )
   check-domain-service-state if
      3drop -1 exit					( -1 )
   then							( buf len svc-handle )
   wait-for-data-pkt					( len' 0 | error )
;

\ Register a particular domain service
\ Don't print an error message because there may be a backup service available
: register-domain-service ( maj min svc-han $svc-id -- maj/min ack? 0 | error )
   check-domain-service-state if  
      3drop 2drop -1 exit  	( -1 )
   then				( maj min svc-han $svc-id )
   ds-reg-request		( maj/min ack? 0 | error )
;

\ unregister a particular domain service
: unregister-domain-service  ( svc-handle -- error? )
   check-domain-service-state if  
      drop -1 exit  			( -1 )
   then					( svc-handle )
   assemble-unreg-req			( pkt size )
   send-ds-pkt ?dup 0= if		(  )		
      wait-for-unreg-resp		( error? )
   else
      dup LDC-NOTUP = if		( LDC-NOTUP )
         cmn-warn[ " Sending Unreg request but LDC is Not Up!" ]cmn-end
      then				( LDC-NOTUP )
   then					( error? )
;

previous		\ ldc

previous definitions	\ domain-services

