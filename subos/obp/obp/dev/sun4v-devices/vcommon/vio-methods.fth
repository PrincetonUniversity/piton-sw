\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: vio-methods.fth
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
id: @(#)vio-methods.fth 1.3 06/12/21
purpose: This file contains methods shared by VIO devices
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless
fload ${BP}/dev/utilities/cif.fth
headerless
0 value		nego-good?
0 value		current-vio-dev
defer claim   ( align size virt -- base )     0 " claim" do-cif is claim
defer release ( size virt -- )  0 " release" do-cif is release

defer send-vio-ver-msg ( -- ok? )  ' false  is send-vio-ver-msg
defer send-vio-ack-msg ( buf ack -- ok? )   ' drop  is send-vio-ack-msg
defer vio-compatible-ver? ( buf - yes? )    ' noop  is vio-compatible-ver?
defer retrieve-packet ( buf len -- #bytes ) ' drop  is retrieve-packet
defer send-vio-attr ( -- ok? )    ' false  is send-vio-attr
defer send-vio-rdx  ( -- ok? )    ' false  is send-vio-rdx
defer update-vd-disk-type ( buf -- )  ' drop is update-vd-disk-type

\ Fill in buffer with VIO msg tag information
: set-vio-msg-tag  ( type subtype env buf -- )
   tuck >vio-subtype-env w!		( type subtype buf )
   tuck >vio-subtype c!			( type buf )
   >vio-msgtype c!			( )
;

\ Get VIO msg tags
: get-vio-msg-tag  ( buf -- env subtype type )
   dup >vio-subtype-env w@		( buf env )
   swap dup >vio-subtype c@		( env buf subtype )
   swap >vio-msgtype c@
;

\ Check if the tags match each other
: vio-tag-match?  ( env' stype' type' env stype type -- match? )
  3 pick = >r 3 pick = r> and >r 3 pick = r> and nip nip nip
;

\ Fill in version numbers
: set-vio-msg-ver  ( devt minor major buf -- )
   tuck >vio-ver-major w!		( devt minor buf )
   tuck >vio-ver-minor w!		( devt buf )
   >vio-dev-type c!			( )
;

: round-up   ( value mod -- value' )  1- tuck + swap invert and  ;

\ This word is called by version-negotiation
\ Return different status for different pkts received
: handle-ver-response  ( buf subtype --  ok? done? )
   case                                         ( buf subtype )
      vio-subtype-info of                       ( buf )
         nego-good? if 
            vio-subtype-ack send-vio-ack-msg    ( ok )
            drop true true exit 		( true true )
	 then

         dup vio-compatible-ver? if             ( buf )
            vio-subtype-ack send-vio-ack-msg    ( ok )
            drop true true
         else cmn-warn[ " Version incompatible!" ]cmn-end
            vio-subtype-nack send-vio-ack-msg	( ok )
            drop false true 			( false true )
	 then
      endof

      vio-subtype-ack  of                       ( buf )
         true to nego-good?
         drop true true 			( true true )
      endof

      vio-subtype-nack  of
         drop false true			( false true )
      endof

      ( default )
      \ Unknown subtype, skip
      nip false false rot			( false false subtype )
   endcase
;

\ Read from LDC channel
\    ACK -> set good version, continue
\    NACK -> exit with error status
\    VER-INFO ->
\       good version -> ack, exit with good status, otherwise:
\       = our version  -> ack, exit with good status
\       <> our version -> nack back msg, continue
\    no more msg -> exit with error status
: version-negotiation  ( buf -- ok? )
   send-vio-ver-msg 0= if
      cmn-warn[ " Version-negotiation: Can't send version message!"
      ]cmn-end
      drop false exit			( false ) 
   then
   0 to nego-good?
   begin                                ( buf )
      dup /vio-ver-msg retrieve-packet  ( buf alen )
      dup /vio-ver-msg = if             ( buf alen )
         drop dup >vio-msgtype c@       ( buf type )
         vio-msg-type-ctrl = if         ( buf )

            dup dup >vio-subtype c@     ( buf buf subtype )
            handle-ver-response         ( buf ok? done? )
            if nip exit then 		( ok? )

         \ Not control type of message, skip to next one
         else				( buf ) 
	    false 			( buf false )
	 then

      else \ received data len not good ( buf alen )

         \ Garbage, skip
         if 				( buf )
	    false                       ( buf false )

         \ No more pkts to receive
         else 				( buf )
	    drop false exit 		( !ok )
	 then				( ok? )
      then				( buf alen )
   until				( buf )
;

0 value received-rdx?		\ received RDX from server
0 value received-rdx-ack?	\ recieved ACK for our own RDX message

\ A full duplex channel is established when two conditions have been met:
\    1. We've received and RDX from the server and sent an ACK.
\    2. We're recieved an ACK for our own RDX packet.
\ VSW requires that both 1 and 2 be completed.
\ VDS requires only step 2 (in fact early versions do not send an RDX at all)
\ In order to support both old and new versions of VDS we set the recieved-rdx?
\ flag to true for VDS so that if we don't receive an RDX we will fall through
\ the begin-until loop once we've received our RDX-ACK and continue on.

\ Newer versions of VDS that require a full-duplex channel will hold off on
\ issuing an RDX-ACK until they've sent their own RDX and received an ACK thus
\ keeping OBP in this loop until the negotiation is complete.
: complete-rdx-handshake  ( buf -- yes? )
   0 to received-rdx?
   0 to received-rdx-ack?
   current-vio-dev vdev-disk-client = if		( buf )
      true to received-rdx?				( buf )
   then							( buf )
   begin						( buf )
      dup /vio-msg-tag retrieve-packet if		( buf )
         dup get-vio-msg-tag 				( buf env stype type )
	 vio-rdx vio-subtype-ack vio-msg-type-ctrl 
	 vio-tag-match? if				( buf )
	    true to received-rdx-ack?			( buf )
	 then						( buf )
         dup get-vio-msg-tag 				( buf env stype type )
	 vio-rdx vio-subtype-info vio-msg-type-ctrl 
	 vio-tag-match?  if 				( buf )
	    dup vio-subtype-ack send-vio-ack-msg drop	( buf )		
	    true to received-rdx?			( buf )
	 then
      else 		\ retrieve-packet returns 0, no more packets
         drop false exit				( false )
      then						( buf )
      received-rdx? received-rdx-ack? and		( buf done? )
   until						( buf )
   drop true						( true )
;

\ Send RDX and expect server side RDX
: handle-vio-rdx  ( buf -- ok? done? )
   dup send-vio-rdx  if                   	( buf )
      complete-rdx-handshake if				(  ) 
	 true true				( true true )
      else 
	 false true 				( false true )
      then
   else
      cmn-warn[ " Can't send RDX message!" ]cmn-end
      drop false true 				( false true )
   then
;

\ Read from LDC channel
\    ACK ->  continue
\    NACK -> exit with error status
\    ATTR-INFO -> ack 
\        -> send RDX, wait for responding RDX
\                    -> Arrived: exit with good status
\                    -> Not arrived: exit with error status
\    no more msg -> exit with error status
: handle-attr-response  ( buf subtype -- ok? done? )
   case							( buf subtype )
      vio-subtype-info of                      		( buf )
         dup vio-subtype-ack send-vio-ack-msg drop    	( buf )
         dup >vio-subtype-env  w@                       ( buf env )
         vio-attr-info = if				( buf )
            current-vio-dev vdev-disk-client = if               
               dup update-vd-disk-type 			( buf )
            then
         then
         handle-vio-rdx					( ok? done? )
         true to nego-good?
      endof

      vio-subtype-ack   of			( buf )
         dup >vio-subtype-env w@		( buf env )
         vio-attr-info = if 			( buf )
            current-vio-dev vdev-disk-client = if               
               dup update-vd-disk-type 		( buf )
            then

            \ Check if RDX not sent, send now
            nego-good? if			( buf )
               drop true true			( true true )
            else				( buf )
               handle-vio-rdx
            then
         else					( buf )
            drop false false			( false false )
         then
      endof

      vio-subtype-nack  of			( buf )
         drop false true			( false true )
      endof

      ( default ) \ skip unexpected types
      nip false false rot 			( false false subtype )
   endcase					
;

\ Send attr packet, handle responses
: vio-exchange-attr  ( buf len -- ok? )
   send-vio-attr 0= if                          ( buf len )
      cmn-warn[ " Can't send attribute message!" ]cmn-end
      2drop false exit				( false ) 
   then

   0 to nego-good?
   begin                                        ( buf len )
      2dup retrieve-packet 2dup               	( buf len alen len alen )
      =   if					( buf len alen )
         drop over >vio-msgtype c@		( buf len type )
         vio-msg-type-ctrl = if                 ( buf len )

            over dup >vio-subtype c@		( buf len buf subtype )
            handle-attr-response                ( buf len ok? done? )
            if nip nip exit then		( ok? )

         \ Not CTRL type of msg, skip to next one
         else 					( buf len )
	    false 				( buf len false )
	 then

      else \ received data len not good         ( buf len alen )

         \ Garbage, skip
         if 					( buf len )
	    false				( buf len false )

         \ No more pkts to receive, alen = 0
         else 					( buf len )
	    2drop false exit 			( !ok )
	 then
      then
   until
;

: fill-in-vio-cookie  ( cadr #ck len buf -- )
   2swap 0 do				( len buf cadr )
      swap dup rot                      ( len buf buf cadr )
      dup x@                            ( len buf buf cadr cookie )
      rot >ldc-mem-caddr x!             ( len buf cadr )
      over >ldc-mem-csize               ( len buf cadr buf' )
      3 pick pagesize min 8 round-up 	( len buf cadr buf' len' )
      dup >r 				( len buf cadr buf' len' ) ( R: len' )
      swap x!				( len buf cadr ) ( R: len' )
      rot r> - -rot			( len'' buf cadr )
      8 + swap /ldc-mem-cookie +        ( len'' cadr' buf'' )
      swap				( len'' buf'' cadr' )
   loop 2drop drop
;

