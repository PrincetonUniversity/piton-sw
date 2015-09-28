\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: dhcp.fth
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
id: @(#)dhcp.fth 1.7 02/11/27
purpose: 
copyright: Copyright 1997-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

\ Dynamic Host Configuration Protocol (DHCP) RFC 2131, RFC 2132
\ Bootstrap Protocol (BOOTP) RFC 951, RFC 1542

decimal
struct ( bootp/dhcp packet )
   1 field    >bp-op            \ packet type: 1 = request, 2 = reply
   1 field    >bp-htype         \ hardware addr type
   1 field    >bp-hlen          \ hardware addr length
   1 field    >bp-hops          \ gateway hops
   4 field    >bp-xid           \ transaction ID
   2 field    >bp-secs          \ seconds since boot began
   2 field    >bp-unused
   4 field    >bp-ciaddr        \ client IP address
   4 field    >bp-yiaddr        \ 'your' IP address
   4 field    >bp-siaddr        \ server IP address
   4 field    >bp-giaddr        \ gateway IP address
  16 field    >bp-chaddr        \ client hardware address
  64 field    >bp-sname         \ server host name
 128 field    >bp-file          \ boot file name
   4 field    >bp-cookie	\ Magic cookie
  60 field    >bp-options	\ Can be longer, extending to end of packet
constant /dhcp-packet

: bp-op      ( -- adr ) active-struct@ >bp-op ;
: bp-htype   ( -- adr ) active-struct@ >bp-htype ;
: bp-hlen    ( -- adr ) active-struct@ >bp-hlen ;
: bp-hops    ( -- adr ) active-struct@ >bp-hops ;
: bp-xid     ( -- adr ) active-struct@ >bp-xid ;
: bp-secs    ( -- adr ) active-struct@ >bp-secs ;
: bp-ciaddr  ( -- adr ) active-struct@ >bp-ciaddr ;
: bp-yiaddr  ( -- adr ) active-struct@ >bp-yiaddr ;
: bp-siaddr  ( -- adr ) active-struct@ >bp-siaddr ;
: bp-giaddr  ( -- adr ) active-struct@ >bp-giaddr ;
: bp-chaddr  ( -- adr ) active-struct@ >bp-chaddr ;
: bp-sname   ( -- adr ) active-struct@ >bp-sname ;
: bp-file    ( -- adr ) active-struct@ >bp-file ;
: bp-cookie  ( -- adr ) active-struct@ >bp-cookie ;
: bp-options ( -- adr ) active-struct@ >bp-options ;

67 constant  BOOTPS
68 constant  BOOTPC

1  constant  BOOTREQUEST
2  constant  BOOTREPLY

\ DHCP Message types
1  constant  DHCPDISCOVER
2  constant  DHCPOFFER
3  constant  DHCPREQUEST
4  constant  DHCPDECLINE
5  constant  DHCPACK
6  constant  DHCPNAK
7  constant  DHCPRELEASE
8  constant  DHCPINFORM

\ DHCP State machine states
1  constant  init-state
2  constant  init-info-state
3  constant  requesting-state
4  constant  verify-state
5  constant  configured-state

instance variable dhcp-state

\ Generic BOOTP/DHCP option structure
struct ( bootp/dhcp-opt-header )
   1 field  >op-code
   1 field  >op-len
   0 field  >op-data
constant /dhcp-opt

: op-code ( -- adr ) active-struct >op-code ;
: op-len  ( -- adr ) active-struct >op-len ;
: op-data ( -- adr ) active-struct >op-data ;

\ RFC 1048 magic cookie 99.130.83.99
h# 63.82.53.63 constant boot-magic

\ Maximum possible size of BOOTP/DHCP packet
d# 1472 constant /dhcp-maxmsg

\ Base BOOTP/DHCP packet size - everything but the options, includes cookie
d# 240 constant bootp-base-pkt-size

instance variable xid

instance variable dhcp-pkt-type
instance variable offered-ip-addr
instance variable dhcp-server-id

instance variable max-dhcp-pkt-size
instance variable dhcp-sndlen		\ Actual length of packet to be sent

-1 instance value dhcp-retries
-1 instance value #max-retries

: dhcp-msg ( adr len -- )
   debug-dhcp?  if  type cr  else  2drop  then
;

: too-many-boot-retries?  ( -- flag )
   #retries @  #max-retries u>=
;

\ Construct class identifier from the root node's "name"
\ property, replacing commas with periods
d# 32 buffer:  my-class-id
: init-vend-class-id  ( -- )
   root-name$ ?dup  if
      my-class-id pack count  bounds
      do
         i c@  ascii ,  =  if  ascii . i c!  then
      loop
   else
      drop
   then
;

\
\ Construct client-identifier. This should be
\ 1) The clientid option specified on command line, if any; or
\ 2) the clientid options specified in "network-boot-args", if any; or
\ 3) the root node "dhcp-clientid" property, if it exists.
\
\ Only 3 is implemented currently. 1 and 2 are dependent upon
\ wanboot which implements 1) revised parameter parsing
\ and 2) "network-boot-args".
\
d# 32 buffer:  my-client-id
: init-client-id  ( -- )
   0 my-client-id c!
   dhcp-clientid-prop 0=  if        ( adr,len )
      my-client-id pack drop        ( )
   then
;

0 instance value bootreply-len
: store-bootreply ( -- )
    *buffer @  /ether-header +  /ip-header +  /udp-header +
    bootreply-len                   ( bootreply-pkt-adr pkt-len )
    dup  to selected-reply-size     ( bootreply-pkt-adr pkt-len )
    selected-bootreply swap  cmove  ( )
;

d# 128 constant /options-max
0 value next-option

: option, ( byte -- )
    next-option bp-options + c!   next-option 1+  to next-option
;

: start-options
    bp-options /options-max erase   0 to next-option
;

: add-option ( adr len code -- )
    option,  dup option,  bounds  ?do  i c@ option,  loop
;

: finish-options
    d# 255 option,
;

\  *  DHCPDECLINE messages MUST NOT include
\     -  option 57 (Max DHCP msg size)
\     -  option 60 (Class identifier)
\  *  DHCPREQUESTs and DHCPDECLINEs fill
\     -  option 50 (Requested IP address)
\     -  option 54 (DHCP server identifier)
\     identifying the offer being responded to
\  * All client messages MAY include option 61
\        (client identifier)
\
: set-dhcp-msg-type   ( -- )  dhcp-pkt-type         1  d# 53 add-option ;
: set-class-id        ( -- )  my-class-id       count  d# 60 add-option ;
: set-max-dhcp-pkt-sz ( -- )  max-dhcp-pkt-size     2  d# 57 add-option ;
: set-offered-ipaddr  ( -- )  offered-ip-addr       4  d# 50 add-option ;
: set-dhcp-server-id  ( -- )  dhcp-server-id        4  d# 54 add-option ;
: set-req-params-list ( -- )  " "(01 03 0c 2b)"        d# 55 add-option ;
: set-client-id       ( -- )
   my-client-id count ?dup if
      d# 61 add-option
   else
      drop
   then
;

: add-dhcp-options ( -- pktlen )
   start-options						( )
   set-dhcp-msg-type						( )
   dhcp-pkt-type c@  DHCPDECLINE <> if				( )
      set-class-id  set-req-params-list  set-max-dhcp-pkt-sz	( )
   then								( )
   dhcp-pkt-type c@ dup DHCPREQUEST = swap DHCPDECLINE = or if	( )
      set-dhcp-server-id   set-offered-ipaddr			( )
   then								( )
   set-client-id
   finish-options						( )
   bootp-base-pkt-size next-option +				( pktlen )
;

: setup-dhcp-pkt  ( pkt-type -- )
   BOOTPC my-udp-port  !
   BOOTPS his-udp-port !
   ( .. pkt-type ) dhcp-pkt-type  c!

   packet-to-send active-struct !
   packet-to-send  /dhcp-maxmsg  erase
   BOOTREQUEST  bp-op c!
   1 ( ARPHRD_ETHER ) bp-htype c!      \ Hardware address type
   6 bp-hlen c!                        \ Hardware address length
   xid @  bp-xid be-l!                 \ "Random" transaction ID
   my-ip-addr bp-ciaddr 4 cmove
   my-en-addr bp-chaddr 6 cmove
   boot-magic bp-cookie be-l!
   add-dhcp-options dhcp-sndlen !

   broadcast-ip-addr  his-ip-addr  4  cmove
   broadcast-en-addr  his-en-addr  6  cmove
;

: setup-discover-pkt  ( -- ) DHCPDISCOVER setup-dhcp-pkt  ;
: setup-inform-pkt    ( -- ) DHCPINFORM   setup-dhcp-pkt  ;
: setup-decline-pkt   ( -- ) DHCPDECLINE  setup-dhcp-pkt  ;
: setup-request-pkt   ( -- ) DHCPREQUEST  setup-dhcp-pkt  ;

: boot-magic?  ( -- flag )
   bp-cookie be-l@  boot-magic =
;

: c@++ ( adr -- adr+1 char )  dup ca1+ swap c@  ;

\ A 256 element array, indexed by DHCP option number. Each element
\ holds the pointer to "op-data". We interpret the options we are
\ interested in.

0 instance value options

: options-array ( index -- adr )  /n*  options + ;

\ Scan field for options
: field-scan ( adr len -- )
   over ca+  >r   ( adr ) ( r: end )
   begin
      dup r@  <=
   while
      c@++ case
         0      of                  endof
         d# 255 of   r> 2drop exit  endof
         ( default )
         >r c@++ over  r> options-array !  ca+  0
      endcase
   repeat
   r> 2drop
;

: option-overload-val ( -- val )    d# 52 options-array @  dup if  c@  then  ;

\ Determine options specified in the BOOTP/DHCP packet.
\ First scan the standard options fields. Then scan the specified additional
\ fields if "option overload" is set.
: scan-options  ( bootreply-pkt-adr bootreply-len -- )
   swap  active-struct !                  ( bootreply-len )
   0 options-array d# 256 /n*  erase      \ Havent read anything yet

   boot-magic?  if                        ( bootreply-len )

      \ Scan standard options fields
      bp-options swap  bootp-base-pkt-size -  field-scan

      \ Scan additional fields
      option-overload-val ?dup  if
         ( option-overload-val ) case
            \ "bp-file" holds options
            1  of   bp-file  d# 128 field-scan   endof
            \ "bp-sname" holds options
            2  of   bp-sname d# 64  field-scan   endof
            \ Both "bp-file" and "bp-sname" hold options
            3  of   bp-sname d# 192 field-scan   endof
         endcase
      then

   else
      drop
   then
;

: receive-bootreply  ( -- flag )    \ True if bootreply received
   begin
      receive-udp-packet  0=  if  false exit  then   ( udp-adr udp-len )
      swap active-struct !                ( udp-len )
      udp-dest-port be-w@  BOOTPC <>      ( udp-len flag )
      /udp-header active-struct +!
      bp-xid be-l@  xid @  <>  or         ( udp-len flag'  )
      bp-op c@ BOOTREPLY <>  or           ( udp-len flag'' )
   while
      drop
   repeat                                 ( udp-len   )
   /udp-header -                          ( bootp-len )
   dup to  bootreply-len                  ( bootp-len )
   active-struct @  swap                  ( bootreply-pkt bootreply-len )
   scan-options
   true
;

: bootreply-msg-type  ( -- val  )   d# 53 options-array @  dup  if  c@  then  ;

instance variable rn          \ Random number
instance variable dhcp-timeout-msecs

\ Retransmission delay is doubled with each transmission upto a maximum
\ of 64 seconds. Delay intervals are randomized by a period of +/- 1 second
: get-dhcp-retrans-time  ( -- n )
   rn @  d# 199961 *  d# 524287 +   h# 7FFFFFFF and  rn !
   rn @ d# 1000 /mod   2 /mod  drop   if  negate  then
   dhcp-timeout-msecs @  +   ( n )
   dhcp-timeout-msecs @ d# 64000 <  if
      dhcp-timeout-msecs dup  @  2*  swap !
   then
;

: send-dhcp-pkt  ( -- )
   packet-to-send dhcp-sndlen @  /dhcp-packet max	( pkt len )
   prepare-udp-packet					( len )
   transmit drop					( )
   get-dhcp-retrans-time set-timeout			( )
;

instance defer prepare-dhcp-pkt
instance defer receive-dhcp-reply

\ Basic DHCP packet exchange logic.
: dhcpcom  ( -- ok? )
   prepare-dhcp-pkt
   #retries off
   begin
      send-dhcp-pkt
      receive-dhcp-reply
   ?dup 0= while
      1 #retries +!
      ." Timeout waiting for BOOTP/DHCP reply. Retrying ... " cr
      too-many-boot-retries?  if  false exit  then
   repeat
;

\ Set "random" transaction ID and random number generator seed
: init-dhcp-xid  ( -- )
   my-en-addr 5 + c@  get-msecs  xor  dup  xid !  rn !
;

\ --------------------------  INIT state  -------------------------------

false  instance value bootp-config?

0 instance value best-offer-#points

: compute-offer-points ( - #points )
   0
   bootreply-msg-type if
      d# 30 +
      d# 43 options-array @  if  d# 80 +  then
   then
   boot-magic?  if
      d# 5 +
      d# 1  options-array @  if  d# 5 +  then
      d# 3  options-array @  if  d# 5 +  then
      d# 12 options-array @  if  d# 5 +  then
      bp-siaddr broadcast-ip-addr?  0=  if  d# 10 +  then
      d# 52 options-array @  0=  if
         bp-sname cstrlen 0<>  if  d# 10 +  then
         bp-file  cstrlen 0<>  if  d# 10 +  then
      then
   then
   debug-dhcp?  if
      ." This configuration has "  dup .d  ." points"  cr
   then
;

\ Accumulate replies from DHCP/BOOTP servers and pick the best offer.
: get-best-offer ( -- flag )
   0 to best-offer-#points  0 to selected-reply-size
   begin
      timeout? 0=
   while
      receive-bootreply if
         compute-offer-points                    ( #pts )
         dup best-offer-#points >  if
            to  best-offer-#points
            store-bootreply
         else  drop
         then
      then
   repeat
   selected-reply-size if
      selected-bootreply selected-reply-size  scan-options
      bootreply-msg-type DHCPOFFER <>  to bootp-config?
      true
   else
      false
   then
;

\ Decode contents of the selected BOOTP/DHCP reply.
: process-offer ( -- )
   selected-bootreply active-struct !
   bootp-config?  if
      \ Accepted BOOTP configuration. Read my IP address
      bp-yiaddr my-ip-addr 4 cmove
   else
      \ Received a DHCPOFFER. Record offered IP address and server identifier
      bp-yiaddr offered-ip-addr 4 cmove
      d# 54 options-array @ dhcp-server-id  4 cmove
   then
;

\ Broadcast DHCPDISCOVER messages and wait for configuration parameters from
\ a BOOTP/DHCP server. If a BOOTP configuration is selected, move to
\ CONFIGURED state; else, go through other states of DHCP state machine
: dhcp-init  ( -- )
   init-dhcp-xid
   " Requesting an IP address ... "  dhcp-msg
   ['] setup-discover-pkt  to  prepare-dhcp-pkt
   ['] get-best-offer to receive-dhcp-reply
   d# 8000 dhcp-timeout-msecs !
   dhcp-retries to #max-retries
   dhcpcom 0=  if
      ." BOOTP/DHCP retry count exceeded" cr  abort
   else
      process-offer
      bootp-config?  if   configured-state   else  requesting-state   then
      dhcp-state !
   then
;

\ ------------------------------- INIT-INFO state ---------------------------

: get-config-params ( -- rcvd? )    \ true if reply rcvd from BOOTP/DHCP server
   begin
      receive-bootreply 0=  if  false exit  then
      bootreply-msg-type dup 0=  swap DHCPACK =  or  ?dup
   until
;

\ Broadcast DHCPINFORM and move to CONFIGURED state once a DHCPACK/BOOTREPLY
\ is received. If no replies are received even after 4 tries, attempt to
\ proceed further in the booting process.
: dhcp-init-info  ( -- )
   init-dhcp-xid
   ['] setup-inform-pkt to prepare-dhcp-pkt
   ['] get-config-params to receive-dhcp-reply
   d# 4000 dhcp-timeout-msecs !
   4 to #max-retries
   dhcpcom 0=  if
      ." Unable to receive config params " cr
      ." Attempting to boot anyway! ... " cr
   else
      store-bootreply
   then
   configured-state  dhcp-state !
;

\ ---------------------------- REQUESTING state ---------------------------

: get-ack/nak-pkt  ( -- ack/nak-rcvd? )
   begin
      receive-bootreply 0=  if  false exit  then
      bootreply-msg-type dup  DHCPACK =  swap  DHCPNAK =  or  ?dup
   until
;

\ Broadcast DHCPREQUESTs and move to VERIFY state after a DHCPACK is
\ received. If no reply is received even after 4 tries, or if a
\ DHCPNAK is received, revert back to INIT state
: dhcp-requesting  ( -- )
   " Requesting offered parameters ..."  dhcp-msg
   ['] setup-request-pkt to prepare-dhcp-pkt
   ['] get-ack/nak-pkt  to receive-dhcp-reply
   d# 4000 dhcp-timeout-msecs !
   4 to #max-retries
   dhcpcom 0=   if
      ." Failed to receive config params" cr
      ." Restarting DHCP process ..." cr
      10.000 ms                             \ Wait for 10 seconds
      init-state dhcp-state !
   else
      bootreply-msg-type DHCPNAK =  if
         ." Server unable to satisfy request" cr
         ." Restarting DHCP process ..." cr
         init-state dhcp-state !
      else
         store-bootreply
         verify-state dhcp-state !
      then
   then
;

\ ------------------------ VERIFY state ----------------------------

\ Broadcast an ARP Reply announcing the IP address I am using and
\ clear outdated ARP cache entries on other machines.
: announce-my-addr  ( -- )
   my-ip-addr my-en-addr my-ip-addr my-en-addr ARP_REPLY ARP_TYPE
   send-arp/rarp-packet drop
;

: decline-offer ( -- )
   ['] setup-decline-pkt to prepare-dhcp-pkt
   ['] true to receive-dhcp-reply             \ Dont wait for a reply
   dhcpcom drop
;

: valid-ip-addr? ( -- valid? )
   " Validating IP address ..." dhcp-msg
   offered-ip-addr broadcast-en-addr my-ip-addr my-en-addr ARP_REQ ARP_TYPE
   send-arp/rarp-packet  drop
   arp-timeout-msecs set-timeout
   begin
      ARP_TYPE receive-ethernet-packet
   0<> while                                  ( adr len )
      drop /ether-header +  active-struct !
      arp-tpa my-ip-addr ip=  if              \ Addressed to me
         arp-opcode be-w@  ARP_REPLY =  if    \ ARP reply
	    debug-dhcp?  if
	       ." ARP Reply from: " arp-spa be-l@  .inetaddr
	       arp-sha .enaddr cr
	    then
            arp-spa offered-ip-addr ip=  if
               false  exit
            then
          then
      then
   repeat                                     ( )
   debug-dhcp?  if  ." No ARP Reply " cr  then
   true
;

\ Check if the offered IP address is already in use. If yes, decline
\ this offer and start all over again
: dhcp-verify  ( -- )
   valid-ip-addr?  if
      " Address validation successful ..." dhcp-msg
      offered-ip-addr my-ip-addr 4 cmove
      announce-my-addr
      configured-state dhcp-state !
   else
      ." IP address already in use by another client!" cr
      decline-offer
      ." Restarting DHCP ..." cr
      10.000 ms                    \ Wait for 10 seconds
      init-state dhcp-state !
   then
;

\ --------------------------------------------------------------------

\ Navigate through DHCP state machine till state = CONFIGURED
: try-dhcp  ( -- )
   \ Initialize DHCP client state
   my-ip-addr l@  0=  if  init-state  else  init-info-state  then  dhcp-state !

   begin
      dhcp-state @  case
         init-state            of   dhcp-init         endof
         init-info-state       of   dhcp-init-info    endof
         requesting-state      of   dhcp-requesting   endof
         verify-state          of   dhcp-verify       endof
         configured-state      of   exit              endof
      endcase
   again
;

\ Initialize network configuration parameters. Read subnet mask,
\ TFTP server and router's IP addresses and bootfilename, if they
\ haven't been specified as cmd line arguments, from the
\ selected bootreply.
: init-config-params  ( -- )
   selected-bootreply selected-reply-size  scan-options
   subnet-mask broadcast-ip-addr?  if
      d# 1  options-array @ ?dup  if  subnet-mask  4 cmove  then
   then
   router-ip-addr broadcast-ip-addr?  if
      d# 3  options-array @ ?dup  if  router-ip-addr 4 cmove  then
   then
   server-ip-addr broadcast-ip-addr?  if
      bp-siaddr server-ip-addr 4 cmove
   then
   tftp-file cstrlen 0=  if
      \ Read bootfilename from BOOTP/DHCP header OR from the
      \ "bootfile name" option if "option overload" is specified
      option-overload-val  if
         d# 67 options-array @  ?dup  if
            dup cstrlen tftp-file-buf pack drop
         then
      else
         bp-file dup cstrlen tftp-file-buf pack drop 
      then
   then
;

: init-dhcp  ( -- )
   /dhcp-maxmsg alloc-mem to packet-to-send
   /udp-pseudo-hdr alloc-mem is udp-pseudo-hdr
   d# 256 /n * alloc-mem  is options

   d# 1514 alloc-mem to selected-bootreply
   selected-bootreply d# 1514 erase

   /dhcp-maxmsg max-dhcp-pkt-size be-w!
   init-vend-class-id
   init-client-id
;

: dhcp-close  ( -- )
   packet-to-send /dhcp-maxmsg free-mem
   0 to packet-to-send
   udp-pseudo-hdr /udp-pseudo-hdr free-mem
   0 is udp-pseudo-hdr
   options d# 256 /n *  free-mem
   0 to options
   selected-bootreply d# 1514 free-mem
   0 to selected-bootreply
;

: .dhcp-params  ( -- )
   debug-dhcp?  if
      ." Client IP     : "  my-ip-addr be-l@  .inetaddr cr
      ." Server IP     : "  server-ip-addr be-l@  .inetaddr cr
      ." Router IP     : "  router-ip-addr be-l@  .inetaddr cr
      ." Subnet Mask   : "  subnet-mask be-l@  .inetaddr cr
      ." TFTP filename : "  tftp-file count type cr
      ." TFTP Retries  : "  tftp-retries .d cr
      ." DHCP Retries  : "  dhcp-retries .d cr
   then
;

headers

: do-dhcp  ( -- )
   reserve-buffer
   init-dhcp
   try-dhcp
   init-config-params
   publish-bootp-response
   my-client-id count ?dup if
      publish-dhcp-clientid
   else
      drop
   then
   dhcp-close
   release-buffer
   .dhcp-params
;
