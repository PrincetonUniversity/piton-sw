\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: methods.fth
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
id: @(#)methods.fth 1.6 07/06/22
purpose: Implements Logical Domain Communication methods
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ The LDC protocol document can be found at
\ http://cpubringup.sfbay.sun.com/twiki/pub/LDoms/ArchDesign/vio.txt

headerless

false value debug-ldc?
false value debug-ldc-pkt?

fload ${BP}/dev/utilities/cif.fth
defer claim     0 " claim" do-cif is claim
defer release   0 " release" do-cif is release

fload  ${BP}/dev/sun4v-devices/ldc/ldc-struct.fth
fload  ${BP}/arch/sun4v/hv-errcode.fth

pagesize invert 1+ value page#mask     

d# 5000	value 	#hcall-retries	\ mod by 5, ~1000 ms (1 sec.)

h# 80 	constant 	fast-trap
h# 2000 constant	mapt-size

1 	value major-version  		\ major and minor numbers
0 	value minor-version  		\ used during version negotiation
0 	value possible-version		\ intermediate storage for version

0 	value ldc-rx-qva		\ RX queue virtual address
0 	value ldc-tx-qva		\ TX queue virtual address
0 	value ldc-rx-qra		\ RX queue real address
0 	value ldc-tx-qra		\ TX queue real address
0 	value msgid			\ our msgid
0 	value rmsgid			\ his msgid received
0 	value my-ackid			\ my ack id
0 	value my-chan-id		\ channel id

0 	value receive-buf		\ receieve buffer pointer
0 	value map-table-va		\ map table va exported to HV
0 	value map-table-ra		\ map table ra exported to HV
0 	value mt-cookie-addr		\ Internal cookie table

0 	value env-wrapper
0 	value #pkts-to-write		\ No of packets to write

\ Current receive queue pointers
0 	value	rx-headp		\ RX queue head pointer
0 	value	rx-tailp		\ RX queue tail pointer

\ Current send queue pointers
0 	value	tx-headp		\ TX queue head pointer
0 	value	tx-tailp		\ TX queue head pointer

0	value	resources-available?	\ Do not aquire resources on every open

\ Default xfer mode is unreliable mode
ldc-mode-unreliable   value	ldc-xfer-mode

\ Convert virtual address to real address
: >ra ( va -- ra )
   dup >physical drop		( vaddr papage )
   swap page#mask invert and or ( ra )
;

\ Code below is needed so FCODE can handle 64 bit addresses
: xrshift ( x n -- x' )
   swap xlsplit rot				( lo hi n )
   dup d# 32 >=  if				( lo hi n )
      rot drop 0 swap d# 32 -			( lo' 0 n' )
   then						( lo' hi' n' )
   2dup rshift >r				( lo' hi' n' ) ( r: res.hi )
   1 over lshift 1-  rot and			( lo' n' bits )
   d# 32 2 pick - lshift  -rot rshift or	( res.lo )
   r>						( res.lo res.hi ) ( r: )
   lxjoin					( x' )
;

: x=  ( x1 x2 -- =? )  - xlsplit or 0=  ;

\ number of interations through wait-1ms? before delay
5 constant wait-mod

\ Wait 1 ms if i is 5, 10, 15, ... (not if i=0)
: wait-1ms?  ( i -- )
   ?dup if  
      wait-mod mod  0=  if  1 ms  then  
   then
;

\ The "status" values are defined by sun4v APIs.  See API specification
\ for details

\ %o0 - ldc_channel
\ %o1 - base raddr
\ %o2 - #entries 
\ #entries = 0 unconfigures the queue
\ Configure LDC RX Queue
: hcall-ldc-rx-qconf  ( chid addr #ents -- status  )
   3 1 tt-ldc-rx-qconf fast-trap htrap
;

\ %o0 - ldc_channel
\ %o1 - base raddr
\ %o2 - #entries 
\ Configure LDC TX Queue
: hcall-ldc-tx-qconf  ( chid addr #ents -- status  )
   3 1 tt-ldc-tx-qconf fast-trap htrap
;

\ arg0 channel (%o0)
\ ret0 status (%o0)
\ ret1 base raddr (%o1)
\ ret2 #entries (%o2)
\ Get LDC RX Queue Info
: hcall-ldc-rx-qinfo  ( chid -- #ents base status )
   1 3 tt-ldc-rx-qinfo fast-trap htrap
;

\ arg0 channel (%o0)
\ ret0 status (%o0)
\ ret1 base raddr (%o1)
\ ret2 #entries (%o2)
\ Get LDC TX Queue Info
: hcall-ldc-tx-qinfo  ( chid -- #ents base status )
   1 3 tt-ldc-tx-qinfo fast-trap htrap
;

\ arg0 channel (%o0)
\ ret0 status (%o0)
\ ret1 head offset (%o1)
\ ret2 tail offset (%o2)
\ ret3 channel state (%o3) UP-1, DOWN-0
\ Get LDC RX state
: hcall-ldc-rx-get-state  ( chid -- state tail head status )
   1 4 tt-ldc-rx-get-state fast-trap htrap	( state tail head status )
;

\ arg0 channel (%o0)
\ ret0 status (%o0)
\ ret1 head offset (%o1)
\ ret2 tail offset (%o2)
\ ret3 channel state (%o3) UP-1, DOWN-0
\ Get LDC TX state
: hcall-ldc-tx-get-state  ( chid -- state tail head status )
   1 4 tt-ldc-tx-get-state fast-trap htrap	( state tail head status )
;

\ arg0 channel (%o0)
\ arg1 head offset (%o1)
\ ret0 status (%o0)
\ Set LDC RX Queue Head
: hcall-ldc-rx-set-qhead  ( chid head -- status )
   2 1 tt-ldc-rx-set-qhead fast-trap htrap
;

\ arg0 channel (%o0)
\ arg1 tail offset (%o1)
\ ret0 status (%o0)
\ Set LDC TX Queue Tail
: hcall-ldc-tx-set-qtail  ( chid tail -- status )
   2 1 tt-ldc-tx-set-qtail fast-trap htrap
;

\ %o0 - channel
\ %o1 - base RA of map_table (-1 disables mapping for given channel)
\ %o2 - table entries
\ Binds the identified table with the given LDC
: hcall-ldc-set-map-table  ( chid table-ra ent# -- status )
   3 1 tt-ldc-set-map-table fast-trap htrap
;

\ Input:
\ %o0 = channel
\ %o1 = flags
\ %o2 = cookieaddr
\ %o3 = raddr
\ %o4 = length
\ Output:
\ %o0 = status
\ %o1 = actual length copied
\ Copy in/out the data from the given cookie_addr for length 
\ bytes (multiple of 8) to/from the real address given.
\ For EOK actual length copied is returned.
: hcall-ldc-copy  ( chid direction caddr raddr len -- bytes status )
   5 2 tt-ldc-copy fast-trap htrap
;

\ Get LDC RX state, retry if HV-EWOULDBLOCK is returned
: ldc-rx-get-state  ( chid -- state tail head status )
   >r 0 0 0 0 r> #hcall-retries 0 do		( state tail head status chid )
      >r 2drop 2drop r@ 			( chid ) ( R: chid )
      hcall-ldc-rx-get-state			( state tail head status )
      dup HV-EWOULDBLOCK <>  if			( state tail head status ) 
         r> drop unloop exit			( state tail head status )
      then					( state tail head status )
      r>  i wait-1ms?				( state tail head status chid )
   loop  drop					( state tail head status )
;

\ Get LDC TX state, retry if HV-EWOULDBLOCK is returned
: ldc-tx-get-state  ( chid -- state tail head status )
   >r 0 0 0 0 r> #hcall-retries 0 do		( state tail head status chid )
      >r 2drop 2drop r@ 			( chid ) ( R: chid )
      hcall-ldc-tx-get-state			( state tail head status )
      dup HV-EWOULDBLOCK <>  if			( state tail head status )
         r>  drop  unloop exit			( state tail head status )
      then					( state tail head status )
      r>  i wait-1ms?				( state tail head status chid )
   loop  drop					( state tail head status )
;

\ Set LDC RX Queue Head, retry if HV-EWOULDBLOCK is returned
: ldc-rx-set-qhead  ( chid head -- status )
   0 #hcall-retries 0 do 				( chid head status )
      drop 2dup						( chid head chid head )
      hcall-ldc-rx-set-qhead				( chid head status )
      dup HV-EWOULDBLOCK <>  if				( chid head status )
         nip nip unloop exit				( status )
      then
      i wait-1ms?					( chid head status )
   loop							( chid head status )
   nip nip						( status )
;

\ Set LDC TX Queue Tail, retry if HV-EWOULDBLOCK is returned
: ldc-tx-set-qtail  ( chid tail -- status )
   0 #hcall-retries 0 do				( chid tail status )
      drop 2dup					( chid tail chid tail )
      hcall-ldc-tx-set-qtail			( chid tail status )
      dup HV-EWOULDBLOCK <>  if			( chid tail status )
         nip nip unloop exit			( status )
      then
      i wait-1ms?				( chid tail status )
   loop						( chid tail status )
   nip nip					( status )
;
      

: dump-hv-qptrs  ( tail hd -- tail hd )
   debug-ldc? if
      2dup ." head: " u. ." tail: " u. cr
   then
;

: dump-hv-qinfo  ( -- )
   debug-ldc? if
      my-chan-id  hcall-ldc-rx-qinfo ." Hypervisor rx qinfo -- status: " . 
      ." base addr: " u. ." ent#: " u. cr
      my-chan-id  hcall-ldc-tx-qinfo ." Hypervisor tx qinfo -- status: " . 
      ." base addr: " u. ." ent#: " u. cr
   then
;

: dump-ldc-initinfo ( -- )
   debug-ldc? if
      ." Channel ID: " my-chan-id u.
      ." Rcv-qva: " ldc-rx-qva u.
      ." Send-qva: " ldc-tx-qva u. cr
   then
;

\ Update Hypervisor Queue head we are working on
: set-ldc-rx-qhead  ( headvirtual -- status )
   ldc-rx-qva - my-chan-id swap 		( id head )
   debug-ldc-pkt? if 2dup ." Set qhead: " ." Head: " u. ." id: " u. cr then
   ldc-rx-set-qhead	 			( status )
;

\ Update TX tail, wrap around if needed
: update-tx-qtail  ( --  )
   tx-tailp /ldc-msg-pkt +				( tail' )
   ldc-tx-qva tuck - ldc-queue-size mod 		( txq rem )
   + to tx-tailp					( )
;

\ Update Hypervisor TX Queue tail
: set-ldc-tx-qtail  ( tailv -- status )
   ldc-tx-qva - my-chan-id swap 	( id tail-off )
   debug-ldc-pkt? if 2dup ." Set qtail: " ." tail: " u. ." id: " u. cr then
   ldc-tx-set-qtail			( status ) 
;

\ Register with Hypervisor our Queue configuration (id, qsize, qraddr)
: ldc-init-qconf  ( -- error? )
   my-chan-id ldc-rx-qra ldc-queue-entries	( id rxra #ent )
   hcall-ldc-rx-qconf				( rx-flag )
   debug-ldc? if dup ." RX qconf returned: " u. cr then

   my-chan-id ldc-tx-qra ldc-queue-entries	( rx-flag id txra #ent )
   hcall-ldc-tx-qconf				( rx-flag tx-flag )
   debug-ldc? if dup ." TX qconf returned: " u. cr then
   or						( error? )

   \ TX queue head/tail pointer may not be 0 after previous unconfigure
   >r my-chan-id ldc-tx-get-state 	( up? tl hd status ) ( R: error? )
   r> or nip rot drop swap		( error?' tl )
   ldc-tx-qva + to tx-tailp
;

\ Check the requested LDC transfer mode, returns true if reliable mode
: ldc-reliable-mode?  ( -- yes? )
   ldc-xfer-mode ldc-mode-reliable =
;

\ Loop till TX head=tail or receives an error
\ status <> 0 means an error
: wait-for-txq-drain  ( -- status )
   #hcall-retries 0 do				( )
      my-chan-id ldc-tx-get-state		( up? tl hd status )
      dup HV-EOK <>  if 
         dup					( up? tl hd status status )
         cmn-note[
            " hcall TX get state returns error: %d" ]cmn-end 
         nip nip nip unloop exit		( status )
      then					(  up? tl hd HV-EOK )
      >r = if 					( up? ) ( R: HV-EOK )
          drop r> unloop exit			( HV-EOK )
       else					( up? ) ( R: HV-EOK )
	  ldc-up <> if				( R: HV-EOK )
	     \ LDC is not up, no need to waste time looping
	     LDC-NOTUP r> drop unloop exit	( LDC-NOTUP )
	  then
          r> drop				( )
       then
      i wait-1ms?				( )
   loop
   true
;

\ Send Control packets to Hypervisor
: ldc-send-ctrl-pkt  ( --  error? )
   ldc-xfer-mode  tx-tailp >ldc-env c! 		( )

   debug-ldc-pkt? if 
      ." Packet to be sent:" cr
      tx-tailp h# 40 " dump" evaluate cr 
   then

   update-tx-qtail				( )

   tx-tailp set-ldc-tx-qtail			( status )
   dup HV-EOK <>  if 				( status )
      exit 
   else
      drop					( )
   then						( )

   wait-for-txq-drain				( status )
;

\ For reliable mode transfer, set up the ackid field appropriately
: setup-more-header ( ctrl type -- )
   tx-tailp tuck >ldc-type c!			( ctrl tail )
   over ldc-ver = if				( ctrl tail )
      possible-version over >ldc-version l! 	( ctrl tail )
   else
      \ msgid are not exchanged until version negotiation is complete
      msgid over >ldc-msgid l!			( ctrl tail )
      msgid 1+ to msgid				( ctrl tail )
   then

   tuck >ldc-ctrl c! 				( tail )
   ldc-info over >ldc-stype c!			( tail )

   ldc-reliable-mode?  if			( tail )
      my-ackid swap >ldc-ackid l!		( )
   else
      drop					( )
   then
;

: send-ctrl-pkts  ( ctrl -- status )
   ldc-ctrl-type setup-more-header		( )
   ldc-send-ctrl-pkt
;

: send-version-packet  ( major minor -- status )
   swap wljoin to possible-version
   ldc-ver send-ctrl-pkts
;

: ldc-send-rts-pkt  ( -- status )
   ldc-rts send-ctrl-pkts
;

: ldc-send-rtr-pkt  ( -- status )
   ldc-rtr send-ctrl-pkts 
;

: ldc-send-rdx-pkt  ( -- status )
   ldc-rdx send-ctrl-pkts 
;

: ldc-send-ack-pkt  ( -- status )
   tx-tailp					( pkt ) 
   ldc-data-type 	over >ldc-type c!	( pkt )
   msgid 		over >ldc-msgid l!	( pkt )
   ldc-ack		over >ldc-stype c!	( pkt )
   my-ackid		swap >ldc-ackid l!	(  )
   msgid 1+ to msgid				(  )
   ldc-send-ctrl-pkt 				( status )
;

: ldc-set-data-pkt  ( -- )
   ldc-rts ldc-data-type			( ctrl type )
   setup-more-header				( )
;

\ Copy LDC formatted data into TX queue, return actual len of data written
: cp-to-txq  ( addr len -- len' )
   ldc-set-data-pkt				( addr len )
   max-ldc-payload min tuck			( len' addr len' )
   dup env-wrapper or tx-tailp >ldc-env c!	( len' addr len' )
   tx-tailp ldc-data-off + swap move         	( len' )
   update-tx-qtail				( len' )
;

: add-to-receive-buf  ( addr len multi? -- )
   if tuck receive-buf w@		( len addr len len' )
      dup >r + receive-buf w! r> 	( len addr len' )
      receive-buf + 2+ rot cmove
   else
      dup receive-buf tuck 		( addr len rbuf len rbuf )
      w! 2+ swap cmove
   then
;
 
: advance-to-next-pkt ( hdv -- hdv' )
   /ldc-msg-pkt + 				( nhdv )
   ldc-rx-qva tuck - ldc-queue-size mod 	( rxq rem )
   +
;

\ Check both head & tail ptrs are less than queue size
: bad-ptrs?  ( p1 p2 -- bad? )
   ldc-queue-size tuck 			( p1 ent p2 ent )
   <= -rot <= and 0= 
;

\ wait at least "timeout" ms for an incoming packet
: wait-for-packet  ( timeout -- [status false|tail hd true] )
   debug-ldc-pkt? if ." Start to wait for incoming packets..." cr then
   wait-mod * 0  do				( )
      my-chan-id  ldc-rx-get-state 		( up? tail hd status )
      dup HV-EOK <>  if 
         cmn-warn[ " Can't get RX queue state! " ]cmn-end ( up? tl hd status )
         nip nip nip false unloop exit		( status false )
      then
      >r					( up? tail hd ) ( R: status )
      \ Check channel state
      rot ldc-up <> if 
	 \ LDC is not up, return with LDC-NOTUP and failure status
	 r> 3drop LDC-NOTUP false unloop exit ( ldc-state false )
      then

      2dup <>  if				( tail hd ) ( R: status )
         2dup bad-ptrs?  if 			( tail hd ) ( R: status ) 
            cmn-warn[ " Bad queue pointers, Head: Tail: " cmn-append
            (u.) cmn-append  (u.) cmn-append ]cmn-end 	( )
            r> false unloop exit		( EOK false )
         then
         debug-ldc-pkt? if			( tail hd ) ( R: status )
            ." Got packets!" 2dup ." head: " u. ." tail: " u. cr
         then					( tail hd ) ( R: status )
         r> drop true unloop exit		( tail hd true )
      then					( tail hd ) ( R: status )
      r> 3drop 					( )
      i wait-1ms? 
   loop
   HV-EOK false 
;

\ Search until a CTRL packet is found or no more pkts in the queue,
\ drop data packets on the way
: scan-for-ctrl-pkt  ( -- pkt true | false )
   begin
      d# 1000 				\ 1 second timeout
      wait-for-packet if			( tail hd )
         nip ldc-rx-qva + dup			( hdv hdv )
         advance-to-next-pkt			( hdv hdv' ) 
         set-ldc-rx-qhead drop dup		( hdv hdv )
         >ldc-type c@ ldc-ctrl-type = if 	( hdv )
            true exit				( hdv true )
         else 
	    LDC-NOTUP = if
	       cmn-warn[ " Scaning for contol packet but LDC is not Up!" ]cmn-end
            then
            false 
         then
      else					( status ) 
	 debug-ldc? if ." Didn't receive any ctrl packets! " cr then
	 drop false exit
      then					( false )
   until 
;

\ Check received msgid is not less than or = a packet we've already received
\ if my-ackid = 0, do not check as the msgid does not HAVE to start at 1
: ldc-check-msgid  ( hdv -- ok? )
   >ldc-msgid l@ dup 			(  rmsgid rmsgid )
   my-ackid <= my-ackid 0<> and if	(  rmsgid )
      cmn-warn[ " Received LDC packet out of sequence (msgid)!" ]cmn-end 
      drop false exit			( false )
   then
   to my-ackid true			( true )
;

\ Is this packet a version ack/nack?
: version-response?  ( pkt -- version-pkt? )
   dup >ldc-ctrl c@ ldc-ver = if			( pkt )
      >ldc-stype c@ ldc-nack over =			( stype nack? )
      swap ldc-ack = or					( ack/nack? )
   else
      drop 0
   then      
;

: parse-version-pkt  ( pkt -- major minor nack? )
   dup >ldc-version l@ lwsplit swap		( pkt major minor )
   rot >ldc-stype c@ ldc-nack =
;

: receive-version-packet  (  -- [ major minor nack? false ] | true )
   begin
      scan-for-ctrl-pkt			( pkt true | 0 )
   while
      dup version-response? if		( pkt )
        parse-version-pkt false exit	( major minor nack? error? )
      else
         drop				( )
      then
   repeat
   true
;

: set-negotiated-version  ( major minor -- error? )
   over major-version > dup if
      nip nip
      cmn-warn[ " Negotiated LDC version greater than is supported" ]cmn-end
   else
      -rot
      to minor-version
      to major-version
   then
;

\ Negotiate a common ldc version between the endpoints.
\ Current code assumes that we support ALL VERSIONS lower than our own
: version-handshake  ( -- error? )
   major-version minor-version 		( major minor )
   send-version-packet if
      true exit				( true ) 
   then
   begin
      receive-version-packet if		( [ major' minor' nack? ] | [  ] )
         true exit			( true )
      then				( major' minor' nack? )
   while				( major' minor' )
      over 0= if  			( major' minor' )
         2drop true exit		( true )
      then				( major' minor' )
      send-version-packet if		( )		
         true exit			( true )
      then
   repeat
   set-negotiated-version		( error? )
;

\ Send RTS, to receive a RTR pkt
: ldc-handshake  ( -- error? )
   version-handshake ?dup if  exit  then
   ldc-send-rts-pkt 0= if 
      begin
         scan-for-ctrl-pkt if		( hdv )

            debug-ldc-pkt? if
               dup /ldc-msg-pkt " dump" evaluate cr 
	    then

            dup >ldc-ctrl c@ ldc-rtr = 		( hdv RTR? )
            over >ldc-env c@ ldc-xfer-mode =	( hdv RTR?  mode? )
            and if				( hdv )
	       drop
               ldc-send-rdx-pkt if
                  cmn-warn[ " RDX sent error!" ]cmn-end 
                  true 				( true )
               else
                  false 			( false )
               then
               exit				( error? )
            else 
	      drop false 			( false )
	    then
         else 
            cmn-warn[ " Didn't receive RTR pkt! " ]cmn-end
            true exit 				( true )
         then
      until
   else
      cmn-note[ " RTS pkt sent error!" ]cmn-end true		( true )
   then
;

\ Always mark the start bit for the first packet
: mark-start-pkt  ( -- ) 
   env-wrapper start-pkt-bit or to env-wrapper
;

: mark-last-pkt  ( -- ) 
   env-wrapper stop-pkt-bit or to env-wrapper 
;
 
: clear-env-wrapper  ( -- )  0 to env-wrapper ;

: reset-receive-buf  ( -- ) 
   0 receive-buf w!
;

: get-multi-bits  ( hdv -- val )  >ldc-env c@ multi-bit-mask and ;

\ Both start & stop bit are set
: single-data-pkt?  ( hdv -- true? ) get-multi-bits multi-bit-mask =  ;

\ Only start bit is set
: start-data-pkt?  ( hdv -- true? ) get-multi-bits start-pkt-bit and ;

\ stop bit is set
: stop-data-pkt?  ( hdv -- true? ) get-multi-bits stop-pkt-bit and ;

: ldc-data-pkt?  ( hdv -- true? ) >ldc-type c@  ldc-data-type = ;

: ldc-data-ack?  ( hdv -- true? )
   dup ldc-data-pkt? swap >ldc-stype c@ ldc-ack = and
;

\ only data packets with stype=info should be included in the datagram
: ldc-data-info?  ( hdv -- true? )
  dup ldc-data-pkt? swap >ldc-stype c@ ldc-info = and
;

: cp-single-pkt  ( hdv multi -- )
   over ldc-data-off + 			( hdv multi adr )
   rot >ldc-env c@ pkt-size-mask and 	( multi adr len )
   rot add-to-receive-buf 
;

d# 1000 constant data-pkt-delay		\ timeout-in-milliseconds

\ Check to see if there is data available in receiving queue
: data-in-queue?  ( -- hdv true|status false )
   rx-tailp rx-headp tuck		( hdv tailv hdv )
   <> if
      dup 				( hdv hdv )
      advance-to-next-pkt to rx-headp
      true 				( hdv true )
   else					( hdv )
      set-ldc-rx-qhead			( status )
      dup HV-EOK <>  if 		( status )
         false exit 			( status false )
      else				( status )
         drop				( )
      then
      data-pkt-delay wait-for-packet if	( tail hd )
         ldc-rx-qva + 
         to rx-headp 
         ldc-rx-qva + to rx-tailp
         rx-headp dup			( hdv hdv )
         advance-to-next-pkt to rx-headp
         true				( hdv true )
      else 
	 debug-ldc? if ." Didn't receive any data packets! " cr then
         false 				( status false )
      then
   then   

  dup if
      ldc-reliable-mode? if		\ Currently OBP just emits warnings
         over ldc-check-msgid drop	\ upon out-of-sequence packet errors
      then				\ We should probably reset the 
   then					\ connection and start over. (TO-DO)
;

\ Locate a Start pkt, once found, go through Cont pkts, until Stop pkt.
\ Throw away all received pkts if msgid is out of sequence or Stop pkt
\ isn't received. 
: cp-multi-pkts  ( hdv -- status )
   \ Scan for a Start data pkt
   begin
      dup start-data-pkt? 0= if			( hdv )
         drop data-in-queue? if			( hdv' )
            false				( hdv' false )
         else 					( status )
            exit 				( status )
         then					( hdv )
      else
         true 
      then					( hdv true )
   until					( hdv )

   0 cp-single-pkt				( )

   begin					( )
      data-in-queue? 0= if			( status )
	 cmn-warn[ " Didn't receive stop pkt! " ]cmn-end
	 reset-receive-buf exit			( status )
      then					( status )

      rmsgid 1+ to rmsgid			( hdv )
      dup true cp-single-pkt			( hdv )

      dup stop-data-pkt? if			( hdv )
         drop rx-headp set-ldc-rx-qhead exit 	( status )
      then
      drop 
   again
;

\ Process data pkts, skip ctrl or error type of pkts
: read-data-pkts  ( -- status )
   reset-receive-buf
   data-pkt-delay wait-for-packet if	( tail hd )
      ldc-rx-qva + 			( tail hd' )
      to rx-headp 			( tail )
      ldc-rx-qva + to rx-tailp		( )
   else 
      debug-ldc? if ." Didn't receive any data packets! " cr then
      exit 				( status )
   then

   \ Scan for data type of pkts
   begin
      data-in-queue? if			( hdv ) 
	 dup ldc-data-info? if		( hdv )
            true			( hdv true )
         else 
            drop false			( false ) 
         then				( false )
      else 
         exit 				( status )
      then				( )
   until

   dup single-data-pkt? if		( hdv )
      0 cp-single-pkt 			( )
      rx-headp set-ldc-rx-qhead 	( status )
   else					( hdv )
      cp-multi-pkts 			( status )
   then 
;

\ Set rx-headp to rx-tailp, throw away any un-read pkts
: ldc-reset-rcv-queue  ( -- )
   my-chan-id ldc-rx-get-state		( state tail hd status )
   drop over <> if 			( state tail )
      ldc-rx-qva + set-ldc-rx-qhead 	( state status' )
   then 
   2drop 
;

\ Reset RX queue, Drain TX queue
\ Exit if queue empty, down or error
: unregister-queues  ( -- )  
   ldc-reset-rcv-queue
   my-chan-id ldc-rx-qra 0 hcall-ldc-rx-qconf hvcheck if
      cmn-warn[ " Did not unconfigure LDC RX queue" ]cmn-end
   then

   #hcall-retries 0 do
      my-chan-id ldc-tx-get-state		( state tail head status )
      if 3drop 
         cmn-note[ " Unable to get TX queue state!" ]cmn-end
         unloop exit				(  ) 
      then					( state tail head )
      rot drop					( tail head )
      = if					(  )
         my-chan-id ldc-tx-qra 0 hcall-ldc-tx-qconf hvcheck if
            cmn-warn[ " Did not unconfigure LDC TX queue" ]cmn-end
         then
         unloop exit 				(  )
      then

      \ Print the message every 50 loops
      debug-ldc?    i d# 50 /mod drop 0= and   if 
         cmn-note[ " Waiting for TX queue drain..." ]cmn-end 
      then
      2 ms 
   loop
;

\ free send & receive memory buffer
: release-qresources  ( -- )
   unregister-queues

   ldc-queue-size  ldc-rx-qva  release
   ldc-queue-size  ldc-tx-qva  release
;

\ Check if the RA is already registered in the map-table
: addr-already-mapped?  ( ra -- mapped? )
   ldcmtbl-ra-shift << 
   map-table-va x@ mt-ra-mask and x= 
;

\ Add RA into map-table, increment RA with 'pagesize' for the next table entry
: add-map-table-entries  ( ra ent# -- )
   swap pagesizeshift xrshift swap			( pfn ent# -- )
   map-table-va over /ldc-mt-ent *  erase			( pfn ent# -- )
   0 do							( pfn )
      dup ldcmtbl-ra-shift << mt-entry-misc or		( pfn ent )
      map-table-va i /ldc-mt-ent *  +  >ldc-mt-ent1 x!	( pfn )
      pagesize pagesizeshift xrshift +			( pfn' )
   loop drop
;

\ Map table is channel specific, allows us to prebuild cookie table
\ 'num' is the maximum number of cookies we expect to use
\ each cookie entry is 8-byte in length ( addr + 8 -> next cookie addr' )
\ Correspondent to each entry in the map-table
: prebuild-cookie-table  ( num -- )
   mt-cookie-addr swap 0 do			( addr )
      pagesize8K cookie-pgsz-shift <<		( addr cookie' )
      \ table_idx field
      i pagesizeshift << or			( addr cookie ) 
      over x! 8 +				( addr' )
   loop drop
;

headers

: channel-reconfigured?  ( -- reconfigured? )
   my-chan-id hcall-ldc-rx-qinfo drop	( #rxents rxbase )
   ldc-rx-qra x=			( #rxents rxbase=? )
   swap ldc-queue-entries = 		( rxbase=? #rxents=? )
   and 0=				( rx-changed? )

   my-chan-id hcall-ldc-tx-qinfo drop	( rx-ch? #txents txbase )
   ldc-tx-qra x=			( rx-ch? #txents txbase=? )
   swap ldc-queue-entries = 		( rx-ch? txbase= #txents= )
   and 0= 				( rx-changed? tx-changed? )
   or					( reconfigured? )
;

\ Default to unreliable mode, change to non-default for reliable mode
: set-ldc-mode-related  ( -- )
   ldc-reliable-mode?   if
      debug-ldc? if ." LDC is in reliable transfer mode." cr then
      ['] max-ldc-payload-reli is max-ldc-payload
      /ldc-data-reli to ldc-data-off
   then
;

: ldc-copy-in  ( buf cookie size -- len hvstatus )
   0 0 #hcall-retries 0 do		( buf cookie size len hvstatus )
      2drop 3dup			( buf cookie size buf cookie size )
      >r swap >r >r my-chan-id ldc-mcopy-in ( buf cookie size chid direction )
					    ( r: size buf cookie )
      r> r> >ra r> hcall-ldc-copy 	( buf cookie size len hvstatus )
      dup HV-EWOULDBLOCK <>  if		( buf cookie size len hvstatus )
         >r >r 3drop r> r> unloop exit	( len hvstatus )
      then				( buf cookie size len hvstatus ) 
      i wait-1ms?			( buf cookie size len hvstatus )
   loop					( buf cookie size len hvstatus )
   >r >r 3drop r> r>			( len hvstatus ) 
;

\ Add Real address lists into the map table
\ Return the cookie table addr and number of cookies needed
: ldc-add-map-table-entries  ( va size -- cookie-adr cookie# )
   >r >ra r> pagesize /mod				( ra rem quot )
   swap if 1+ then					( ra ent# )
   over addr-already-mapped? if				( ra ent# )
      nip mt-cookie-addr swap exit 			( cookie-addr ent# )
   then							( ra ent# )
   tuck add-map-table-entries				( ent# )
   mt-cookie-addr swap 					( cookie-addr ent# )
   debug-ldc? if 
      map-table-va ." map-table: " dup u. h# 60 " dump" cr evaluate
   then
;

: bind-map-table  ( -- status )
   0 #hcall-retries 0 do				( status )
      drop my-chan-id map-table-ra mapt-size 3 xrshift 
      hcall-ldc-set-map-table				( status )
      dup HV-EWOULDBLOCK <>  if				( status )
         unloop exit					( status )
      then
      i wait-1ms?					( status )
   loop							( status )
;

\ Check if there is a data packet available
: ldc-pkt-available? ( -- pkt? )
   1 wait-for-packet if 			( tail hd )
      2drop true				( true )
   else 
      drop false 				( false )
   then						( pkt? )
;

: allocate-resources  ( -- )
   /x pagesize  0 claim to receive-buf		(  )
   /x mapt-size 0 claim dup to map-table-va	( va )
   >ra to map-table-ra				(  )
   debug-ldc? if				(  )
      ." map-table addr: " map-table-va u. cr	(  )
   then						(  )
   /x mapt-size 0 claim to mt-cookie-addr	(  )

   ldc-queue-size dup 0 claim			( va )
   dup to ldc-rx-qva				( va )
   >ra to ldc-rx-qra				(  )

   ldc-queue-size dup 0 claim			( va )
   dup to ldc-tx-qva				( va )
   >ra to ldc-tx-qra				(  )

   true to resources-available?			(  )
;

: scrub-resources  ( -- )
   receive-buf    pagesize	 erase		(  )
   map-table-va   mapt-size	 erase		(  )
   mt-cookie-addr mapt-size	 erase		(  )
   ldc-rx-qva     ldc-queue-size erase		(  )
   ldc-tx-qva     ldc-queue-size erase		(  )
;

: ldc-open ( channel-id mode -- ok? )
   debug-ldc? if
      ." LDC: open: " cr			( channel-id mode )
      ." LDC: mode = " dup u. cr		( channel-id mode )
      ." LDC: channel = " over u. cr		( channel-id mode )
   then						( channel-id mode )

   to ldc-xfer-mode				( channel-id )
   to my-chan-id 				(  )

   0 to msgid					(  )
   0 to my-ackid				(  )

   \ Do not reacquire resources on a second open (channel reset)
   resources-available? if			(  )
      scrub-resources				(  )
   else
      allocate-resources			(  )
   then						(  )

   num-cookies prebuild-cookie-table		(  )
   set-ldc-mode-related				(  )
   ldc-init-qconf				( error? )  
   ldc-handshake or				( error? )
   bind-map-table or if
      debug-ldc? if ." LDC: init error! " cr then
      false					( false )
   else
      true                                      ( true )
   then
   
   dump-hv-qinfo
   dump-ldc-initinfo
;

: ldc-close ( -- )
   release-qresources 
   pagesize receive-buf release
   mapt-size map-table-va release
   mapt-size mt-cookie-addr release
   false to resources-available?
   debug-ldc? if ." LDC: closed. " cr then
;


\ Read data pkts into the receive-buf, data length read is stored in the 
\ first word of receive-buf
: ldc-read  ( buf len -- rd status )
   read-data-pkts -rot 			( status buf len )
   receive-buf w@ ?dup if 		( status buf len rd )
      debug-ldc-pkt? if
         dup receive-buf 2+ swap 	( status buf len rd addr rd )
         cr ." Received packet: " cr " dump" evaluate cr 
      then				( status buf len rd )
      -rot 2 pick 			( status rd buf len rd )
      min receive-buf 2+ -rot move	( status rd )
   else 				( status buf len )
      2drop 0 
   then					( status 0 )
   swap					( rd status )

   \ If this is reliable mode (and we actually recieved a packet)
   \ ack the last message read
   over 0<> ldc-reliable-mode? and if 
      ldc-send-ack-pkt drop			( len status )
   then
;

: ldc-write  ( addr len -- nbytes status )
   dup max-ldc-payload /mod swap	( addr len quot rem )
   if 1+ then 				( addr len #pkts )
   to #pkts-to-write			( addr len )

   tuck  #pkts-to-write 0 do		( len addr len )
      i 0= if mark-start-pkt then	( len addr len )
      i #pkts-to-write 1- = if		( len addr len )
         mark-last-pkt			( len addr len )
      then				( len addr len )
      2dup cp-to-txq			( len addr len len' )

      tuck - >r + r>			( len addr' len'' )
      clear-env-wrapper			( len addr' len'' )
   loop

   2drop				( len )
   tx-tailp set-ldc-tx-qtail		( len status )
   dup HV-EOK <>  if 			( len status )
      nip 0 swap exit 			( 0 error )
   else
      drop				( len )
   then					( len )
					( len )
   wait-for-txq-drain			( len status )
;


headerless
