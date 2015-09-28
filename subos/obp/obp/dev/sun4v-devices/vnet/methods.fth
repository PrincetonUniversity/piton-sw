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
id: @(#)methods.fth 1.5 07/06/22
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless

fload ${BP}/dev/sun4v-devices/ldc/methods.fth

false 	value	debug-vnet?
false 	value	debug-tcp?

fload ${BP}/dev/sun4v-devices/vcommon/vio-struct.fth
fload ${BP}/dev/sun4v-devices/vcommon/vio-methods.fth

vdev-net-client to current-vio-dev
h# 1000	value 	vnet-sid	\ Variable to hold sequence id
0 	value	vnet-seq 	\ seq# for the next request
0 	value	cur-vnet-seq	\ seq# of the current request
0 	value	vnet-tmpbuf
d# 200	value 	vnet-retries	\ Variable to hold number of retries
0	value   vnet-opened?	\ Variable to indicate if vnet has established
				\ connection with vswitch

d# 1514 constant  frame-size 

0 	value 	rx-buffer	\ Transmit buffer
0 	value 	tx-buffer	\ receive buffer

8 pagesize 0 claim to rx-buffer
8 pagesize 0 claim to tx-buffer

0 	value 	vnet-descr-buf	\ Variable to hold Vnet descritor buffer

/vnet-attr-msg /vnet-descr-msg max value /vnet-descr-buf
0 	value 	obp-tftp
0 	value 	ldc-up?		\ flag, Set if LDC is up

6 	buffer: mac-buf		\ Variable to hold MAC Address

0 	value	vn-ldcid	\ Variable to hold LDC id

: inspect-vnet-port-nodes  ( nptr -- )
   dup " switch-port" ascii v md-find-prop  if	( port-ptr ptr|0 )
      " fwd" ascii a md-find-prop		( ldc-nptr|0 )
      dup if
         md-decode-prop drop			( ldc-nptr )
         " id" ascii v md-find-prop 		( idptr|0 )
         dup if
            md-decode-prop drop to vn-ldcid
         else
            drop
         then
      else
         drop
      then
   else
      drop
   then
;

: look-for-vn-ldcid  ( -- )
   ['] inspect-vnet-port-nodes my-node md-applyto-fwds
;

look-for-vn-ldcid

: init-obp-tftp ( tftp-args$ -- okay? )
   " obp-tftp" $open-package  dup to obp-tftp		( pkg )
   if
      true
   else
      cmn-warn[ " Can't open OBP standard TFTP package"  ]cmn-end
      false
   then
;

\ The service domain may be down or rebooting...  Keep retrying for 5 minutes
: open-vnet-ldc (  -- error?  )
   get-msecs d# 300.000 + 		\ 5 minutes later
   begin					( finish-time )
      get-msecs over <				( finish-time keep-trying? )
   while					( finish-time )
      vn-ldcid ldc-mode-unreliable ldc-open if	( finish-time )
         true to ldc-up?			( finish-time )
         drop false exit			( false )
      then					( finish-time )
      cmn-warn[ 
         " Timeout connecting to virtual switch... retrying" 
      ]cmn-end
      d# 5000 ms				( finish-time )
   repeat
   cmn-warn[ " Unable to connect to virtual switch" ]cmn-end
   drop true					( true )
;

: close-vnet-ldc  ( -- )
   ldc-close 0 to ldc-up?
;

: receive-ready? ( -- ready? )
    ldc-pkt-available?
;

\ Only update seqid upon successful return because Solaris counter part
\ doesn't like new seqid if OBP higher level module do retries
: send-to-ldc  ( buf len -- #sent )
   debug-vnet? if
      cr ." vnet write : " 2dup swap u. u. cr 
   then
   0 vnet-retries 0 do                          ( buf len status )
      drop 2dup                                 ( buf len buf len )
      ldc-write			                ( buf len #sent status )
      dup HV-EOK  <>  if                        ( buf len #sent status )
         dup HV-EWOULDBLOCK <>  if              ( buf len #sent status )
            dup LDC-NOTUP = if			( buf len #sent status )
                cmn-warn[ " Sending packet to LDC but LDC is Not Up!" ]cmn-end
                2drop 2drop 0 unloop exit       ( 0 )
            then
            cmn-warn[ " Sending packet to LDC, status: %d" ]cmn-end
            3drop 0 unloop exit
         then
      else                                      ( buf len #sent status )
         cur-vnet-seq 1+ to vnet-seq
         drop nip nip unloop exit		( #sent )
      then
      nip                                       ( buf len status )
      \ Every 20 loops, roughly 20 seconds (ldc-write can take @ 1s),
      \ print a retrying message
      i 1+ d# 20 mod 0= if
         cmn-warn[
            " Timeout sending package to LDC ... retrying"
         ]cmn-end
      then
   loop                                         ( buf len status )
   3drop 0
   cmn-warn[ " Sending packet to LDC timed out!" ]cmn-end
;

: receive-from-ldc  ( buf len -- #bytes )  
   0 vnet-retries 0 do                          ( buf len status )
      drop 2dup                                 ( buf len buf len )
      ldc-read					( buf len alen status )
      dup HV-EOK  <>  if                        ( buf len alen status )
         dup HV-EWOULDBLOCK <>  if              ( buf len alen status )
            dup LDC-NOTUP = if			( buf len alen status )
                cmn-warn[ 
		   " Receiving packet from LDC but LDC is Not Up!"
                ]cmn-end
                2drop 2drop 0 unloop exit       ( 0 )
            then
            cmn-warn[ " Receiving packet from LDC, status: %d" ]cmn-end            3drop 0 unloop exit                 ( 0 )
         then
      else                                      ( buf len alen status )
	 \ If vnet-opened? is false and if we  get EOK with Length = 0 then
	 \ treat it as EWOULDBLOCK at LDC layer and just retry
         over vnet-opened? or  if		( buf len alen status )
            drop nip nip unloop exit		( alen )
         then
      then
      nip                                       ( buf len status )
      \ Every 20 loops, roughly 20 seconds (ldc-read can take @ 1s),
      \ print a retrying message
      i 1+ d# 20 mod 0= if
         cmn-warn[
            " Timeout receiving packet from LDC ... retrying"
         ]cmn-end
      then
   loop                                         ( buf len status )
   3drop 0
   cmn-warn[ " Receiving packet from LDC timed out!" ]cmn-end
;
' receive-from-ldc  is  retrieve-packet

: receive ( -- len' )
   rx-buffer frame-size receive-from-ldc
;

: ldc-copy-in  ( buf cookie size -- len )
   0 vnet-retries 0 do				( buf cookie size status )
      drop 3dup 
      ldc-copy-in				( buf cookie size len status )
      dup HV-EOK  <>  if
         dup HV-EWOULDBLOCK  <>  if
            cmn-warn[ " Vnet-copy-in: status: %d" ]cmn-end
            2drop 2drop 0 unloop exit
         then
      else
         drop nip nip nip unloop exit		( len )
      then					( buf cookie size len status )	
      nip
   loop						( buf cookie size status )
   2drop 2drop 0
   cmn-warn[ " ldc-copy-in timed out!" ]cmn-end
;

: send-vnet-ver-msg  ( -- ok? )
   vnet-descr-buf /vio-ver-msg erase

   \ vnet session id is only updated once during version negotiation
   vnet-sid 1+ dup to vnet-sid
   vnet-descr-buf  >vio-sid l!

   vio-msg-type-ctrl vio-subtype-info vio-ver-info
   vnet-descr-buf set-vio-msg-tag

   vdev-net-client vnet-minor vnet-major
   vnet-descr-buf set-vio-msg-ver

   vnet-descr-buf  /vio-ver-msg  send-to-ldc
   /vio-ver-msg =
;

' send-vnet-ver-msg is send-vio-ver-msg

\ The ack parameter may be ack or nack
: send-vnet-ack-msg  ( buf ack -- ok? )
   over >vio-subtype c!         		( buf )
   vnet-sid over  >vio-sid l!			( buf )
   /vio-ver-msg  send-to-ldc			( rlen )
   /vio-ver-msg =
;

' send-vnet-ack-msg is send-vio-ack-msg

: vnet-compatible-ver?  ( buf -- yes? )
   dup >vio-ver-major w@ vnet-major =                  ( buf flag1 )
   swap >vio-ver-minor w@ vnet-minor =                 ( flag1 flag2 )
   and
;

' vnet-compatible-ver? is vio-compatible-ver?

: get-vnet-mac  ( -- x )
   mac-buf x@ xlsplit swap lwsplit nip swap lwsplit -rot wljoin swap lxjoin
;

\ Send our attributes
: send-vnet-attr  ( -- ok? )
   vnet-descr-buf /vnet-attr-msg erase			( )

   vio-msg-type-ctrl vio-subtype-info vio-attr-info
   vnet-descr-buf set-vio-msg-tag			( )
   vnet-sid vnet-descr-buf  >vio-sid l!			( )

   vnet-descr-buf frame-size over >vnet-attr-mtu x!	( buf )
   1 over >vnet-ack-freq w!				( buf )

   get-vnet-mac over >vnet-attr-addr x!			( buf )
   addr-type-mac over  >vnet-addr-type c!		( buf )
   vio-desc-mode swap >vnet-xfer-mode c!		(  )

   vnet-descr-buf /vnet-attr-msg send-to-ldc		( rlen )
   /vnet-attr-msg =
;
' send-vnet-attr is send-vio-attr

: send-vnet-rdx  ( buf -- ok? )
  dup /vnet-attr-msg erase				( buf )
  >r vio-msg-type-ctrl vio-subtype-info vio-rdx
  r@ set-vio-msg-tag					( R: buf )
  vnet-sid r@ >vio-sid l!				( R: buf )
  r> /vnet-attr-msg send-to-ldc				( rlen )
  /vnet-attr-msg =
;

' send-vnet-rdx is send-vio-rdx

\ Stages: 
\ Version negotiation -> Vnet Attr info -> Dring info -> RDX
: init-vnet-conn  ( -- ok? )
   debug-vnet? if ." Vnet version negotiation... " cr then
   vnet-descr-buf  version-negotiation if
      debug-vnet? if ." Vnet Attr Exchange..." cr then
      vnet-descr-buf  /vnet-attr-msg  vio-exchange-attr if
         true exit
      then
   then
   false
;

\ Set up sid and seq
: set-descr-req-header  ( type stype env -- )
   vnet-descr-buf /vnet-descr-msg erase		( type stype env )

   vnet-descr-buf set-vio-msg-tag		(  )
   vnet-sid vnet-descr-buf  >vio-sid l!		(  )

   vnet-seq  vnet-descr-buf >vnet-seq x!	(  )
   vnet-seq to cur-vnet-seq			(  )
;

: send-descr-req  ( len -- ok? )
   vnet-descr-buf over	send-to-ldc  =		( ok? )
;

: fill-in-vnet-args  ( len cadr #ck -- )
   2dup 4 pick  vnet-descr-buf >vnet-cookie  ( len cadr #ck cadr #ck len buf )
   fill-in-vio-cookie  				 	 ( len cadr #ck )
   nip vnet-descr-buf tuck				 ( len buf #ck buf )
   >vnet-ctrl-#cookies l! 					 ( len buf )
   >vnet-ctrl-nbytes l!					 ( )
;

\ Fill in & send the cookie pkt, number of cookies may vary
: vnet-xmit-msg  ( len cadr #ck -- ok? )
   vio-msg-type-data vio-subtype-info vio-desc-data 
   set-descr-req-header					( len cadr #ck )
   dup 2swap rot					( #ck len cadr #ck )
   fill-in-vnet-args					( #ck )
   /ldc-mem-cookie * /vnet-descr-short +		( slen )
   send-descr-req					( ok? )
; 

\ map-table entry should be page aligned, copy output to tx-buffer and
\ add tx-buffer to the map table
: vnet-xmit  ( buf len -- #sent )
   tuck tx-buffer swap move			( len )
   debug-vnet? if
      ." vnet xmit buf: len: " tx-buffer 2dup u. u. cr over 
      " dump" evaluate 
   then
   tx-buffer 2dup over 				( len buf len buf len )
   ldc-add-map-table-entries			( len buf len cadr #ck )
   vnet-xmit-msg if				( len buf )
      drop 
   else
      cmn-warn[ " Can't send vnet write request!" ]cmn-end
      2drop 0 
   then
;

\ Check to see if tag DATA/INFO/OBP_DATA, ctrl flag is READY
: vnet-data-pkt?  ( -- yes? )
   vnet-descr-buf get-vio-msg-tag 		( env subt type )
   vio-desc-data vio-subtype-info vio-msg-type-data vio-tag-match? ( yes? )
;


\ If two cookies span contiguous pages the ldc framework will only give us
\ one extra-large cookie with a size that overflows into the next page
: supercookie?  ( ck -- supercookie? )
   dup  >ldc-mem-csize x@               ( ck total-size )
   swap >ldc-mem-caddr x@               ( total-size ck-adr )
   dup pagesize round-up swap - 	( total-size next-page )
   dup if				(  total-size next-page )
      \ total-size spans two pages?
      >  				( true|false )
   else  
      \ already page aligned
      nip 				( false )
   then
;

\ An ethernet frame (NON-JUMBO) can span at most 2 pages
\ so we split the cookie into hypervisor-edible cookies
: split-supercookie  ( ck -- ck0 sz0 ck1 sz1 )
   dup  >ldc-mem-csize x@ >r         ( ck )          ( r: total-size )
        >ldc-mem-caddr x@            ( ck0 )         ( r: total-size )
   dup pagesize round-up over -      ( ck0 sz0 )     ( r: total-size )
   2dup +			     ( ck0 sz0 ck1 ) ( r: total-size )
   over r> swap -		     ( ck0 sz0 ck1 sz1 )
;

\ recreate the vnet-descr-buf with the weenie cookies
: sort-supercookies  ( ck -- )
   dup supercookie? if
      split-supercookie 2swap		( ck1 sz1 ck0 sz0 )
      vnet-descr-buf 			( ck1 sz1 ck0 sz0 buf )
      2 over >vnet-ctrl-#cookies l!	( ck1 sz1 ck0 sz0 buf )
      >vnet-cookie			( ck1 sz1 ck0 sz0 buf )
      tuck >ldc-mem-csize x!		( ck1 sz1 ck0 buf )
      tuck >ldc-mem-caddr x!		( ck1 sz1 buf )
      /ldc-mem-cookie +			( ck1 sz1 buf' )
      tuck >ldc-mem-csize x!		( ck1 buf' )
           >ldc-mem-caddr x!
   else
      drop
   then
;

\ Read cookies, copy in data
\ Even though we have at most 2 cookies right now, put in a loop
\ so that it can handle more cookies in the future
: vnet-copy-in  ( buf len -- rlen )
   vnet-descr-buf >vnet-cookie sort-supercookies ( buf len )
   vnet-descr-buf >vnet-ctrl-nbytes l@		( buf len rlen )
   \ Copy multiple cookies
   min 0 -rot 					( rlen buf len' )
   vnet-descr-buf >vnet-ctrl-#cookies l@ 0 do 	( rlen buf len' )
      vnet-descr-buf >vnet-cookie 
      /ldc-mem-cookie i * +			( rlen buf len' addr )
      dup   >ldc-mem-caddr x@			( rlen buf len' addr ck )
      swap  >ldc-mem-csize x@			( rlen buf len' ck size )

      debug-vnet? if
         dup ." Retrieved cookie size: " u. cr 
      then

      rx-buffer -rot ldc-copy-in		( rlen buf len' clen )

      debug-vnet? if
         dup ." ldc copy in cookie size: " u. cr 
         rx-buffer over " dump" evaluate
      then

      \ For alignment, cookie size maybe bigger than requested size
      over min >r				( rlen buf len' ) ( R: clen' )
      over rx-buffer swap r@ move		( rlen buf len' ) ( R: clen' )
      r@ - swap r@ + rot r> +			( len'' buf' rlen' )
      -rot swap					( rlen' buf' len'' )
   loop 
   2drop					( rlen )
;

\ Send back ACK packet 
: vnet-send-ack  ( idx #ck -- )
   vio-msg-type-data vio-subtype-ack vio-desc-data 		( idx #ck )
   set-descr-req-header						( idx #ck )
   swap vnet-descr-buf >vnet-desc-hdl x!			( #ck )
   /ldc-mem-cookie * /vnet-descr-short +			( slen )
   send-descr-req drop
;

\ Read a packet if it's available, skip the ACK packets, for DATA packet,
\ Send an ACK packet after the memory content is retrieved.
: vnet-poll  ( buf len -- #rcvd )
   begin
      vnet-descr-buf /vnet-descr-msg retrieve-packet 	( buf len rlen )
      dup 0= if nip nip  exit then			( 0 )
      drop vnet-data-pkt?				( buf len yes? )
   until

   vnet-copy-in						( #rcvd )
   vnet-descr-buf dup >vnet-desc-hdl x@		( #rcvd buf idx )
   swap >vnet-ctrl-#cookies l@				( #rcvd idx #ck )
   vnet-send-ack					( #rcvd )
;

: short-send ( buf,len -- error? )
   tuck vnet-xmit 	( len #sent )
   <>
;

\ Dump pkts with 0x800 (IP), 0x11 (UDP) and port 0x44 (BOOTP/DHCP)
: dump-udp-bootp  ( pkt len -- pkt len )
   dup if					( pkt len )
      over d# 12 + w@  h# 800 =  if             ( pkt len )
         over d# 23 + c@ h# 11 =  if            ( pkt len )
            over d# 36 + w@  h# 44 = if
               ." udp pkt received!" cr 
               2dup " dump" evaluate cr  
            then
         then
      then
   then
;

\ offset 34: source port (2 bytes)
\        36: destination port (2 bytes)
\        38: seq number (4 bytes)
\        42: ack number (4 bytes)
: dump-tcp-headers ( pkt len -- pkt len )
   dup if							( pkt len )
      over d# 12 + w@  h# 800 =  if             		( pkt len )
         over d# 23 + c@ d# 6 =  if             		( pkt len )
            over d# 34 + w@ u. over d# 36 + w@ u. 
            over d# 38 + w@ >r over d# 40 + w@ r> wljoin u.
            over d# 42 + w@ >r over d# 44 + w@ r> wljoin u.  cr
         then
      then
   then
;

\ Allocate vnet descriptor buffer
: allocate-vnet-descr-buf
   8 /vnet-descr-buf 0 claim to vnet-descr-buf  (  )
;

\ Release and reset vnet descriptor buffer
: deallocate-vnet-descr-buf
   /vnet-descr-buf vnet-descr-buf release       (  )
   0 to vnet-descr-buf
;

external

: open ( -- ok? )
   open-vnet-ldc if				(  )
      false exit				( false )
   then

   " local-mac-address" get-my-property if      ( adr len | )
      cmn-warn[ " Can not find local-mac-address property" ]cmn-end
      false exit                                ( false )
   then                                         ( adr len )
   over mac-address comp 0= if                  ( adr len )
      \ Save a copy of mac address to mac-buf, used in vnet version negotiation
      2dup mac-buf swap cmove                   ( adr len )
      " mac-address" property                   (  )
   else                                         ( adr len )
      cmn-warn[ " MAC Address does not match local-mac-address, " cmn-append
         " Virtual Networks do not support variable local-mac-address? = false."
      ]cmn-end
      2drop false exit                          ( false )
   then

   allocate-vnet-descr-buf			(  )

   my-args init-obp-tftp 0=  if 
      deallocate-vnet-descr-buf			(  )
      close-vnet-ldc				(  )
      false exit 				( false )
   then

   init-vnet-conn 0= if				(  )
      deallocate-vnet-descr-buf			(  )
      obp-tftp ?dup if close-package then	(  )
      close-vnet-ldc				(  )
      false exit				( false )
   then
      
   debug-vnet? if				(  )
      ." mac-address shows: "			(  )
      mac-address bounds do i c@ u. loop cr	(  )
   then

   true to vnet-opened?				(  )
   true						( true )
;

: close ( -- )
   deallocate-vnet-descr-buf			(  )

   obp-tftp ?dup if close-package then
   ldc-up?  if 
      close-vnet-ldc
   then

   false to vnet-opened?
;

: read ( buf,len -- -2|len )
   receive-ready? 0= if 2drop -2 exit then

   over swap						( buf buf len )
   vnet-poll ?dup 0=  if  -2 then			( buf len' )

   debug-tcp? if					( buf len' )
      dump-udp-bootp					( buf len' )
      dump-tcp-headers					( buf len' )
      nip						( len' )
   else 
      nip						( len' )
   then
;

: write ( buf,len -- len )  
   vnet-xmit 
;

: load  ( adr -- len ) 
   " load" obp-tftp $call-method  
;

: watch-net ( -- )
   open 0= if exit then
   frame-size alloc-mem to vnet-tmpbuf

   ." Looking for Ethernet packets." cr
   ." '.' is a good packet.  'X' is a bad packet."  cr
   ." Type any key to stop."  cr

   begin
      key? 0=
   while
      receive-ready?  if
	 vnet-tmpbuf frame-size vnet-poll if  ." ."  else  ." X"  then
      then
   repeat
   key drop

   vnet-tmpbuf frame-size free-mem
   close
;

headerless
