\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: tftp.fth
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
id: @(#)tftp.fth 2.24 02/08/22
purpose: Trivial File Transfer Protocol (TFTP) implementation
copyright: Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ Trivial File Transfer Protocol

decimal

headerless

d# 128 instance buffer: tftp-file-buf
instance defer tftp-file
' tftp-file-buf to tftp-file

1 constant rrq-pkt
2 constant wrq-pkt
3 constant data-pkt
4 constant ack-pkt
5 constant err-pkt

struct ( tftp packet )
      2 field >opcode
      0 field >block#
      0 field >filename
      2 field >errorcode
      0 field >errmsg
d#  512 field >data
constant /tftp-packet

: opcode    ( -- )  active-struct@ >opcode ;
: block#    ( -- )  active-struct@ >block# ;
: filename  ( -- )  active-struct@ >filename ;
: errorcode ( -- )  active-struct@ >errorcode ;
: errmsg    ( -- )  active-struct@ >errmsg ;
: data      ( -- )  active-struct@ >data ;

d# 69 constant UP_TFTP

instance variable sid
instance variable did
instance variable this-block
instance variable #retries
instance variable #packet

false instance value first-try?

-1 instance value tftp-retries

: too-many-tftp-retries?  ( -- flag )  \ flag true if too many retries
   #retries @  tftp-retries u>=
;

: .merror  ( -- )
   use-server?  use-dhcp @  or  if
     ." TFTP Error: " errmsg dup cstrlen type
     abort
   then
   UP_TFTP did !        \ Unlock from server
;

: $cstrput  ( from-adr,len to-adr -- end-adr )
   3dup swap move   ( from-adr,len to-adr )
   swap +  nip      ( end-adr-1 )
   0 over c!        ( end-adr-1 )
   1+
;

: setup-request  ( file-name-str  rrq-pkt/wrq-pkt -- )
   0 this-block !
   packet-to-send active-struct !
   1 sid +!
   UP_TFTP did !        ( file-name  rrq-pkt/wrq-pkt )
   opcode be-w!    ( file-name-str )
   filename $cstrput ( mode-adr )
   " octet" rot $cstrput
   packet-to-send  -  #packet !
;

: setup-read-request  ( file-name-string -- )
   rrq-pkt setup-request
   1 this-block +!
;

: setup-write-request  ( file-name-string -- )
   wrq-pkt setup-request
;

: setup-ack-packet  ( -- )
   packet-to-send  active-struct !
   ack-pkt opcode be-w!
   this-block @  block#  be-w!
   4 #packet !
   1 this-block +!
;

: send-packet  ( tftp-adr tftp-len -- #sent )
   did @ his-udp-port !
   sid @ my-udp-port !
   ( tftp-adr tftp-len ) prepare-udp-packet ( len )
   transmit dup 0=  if
      ." TFTP send failed. Check Ethernet cable and transceiver" cr
   then                     ( #sent )
   d# 4000 set-timeout
;

0 instance value error-packet        \ Buffer address

: send-error-packet  ( -- )
   /tftp-packet alloc-mem to error-packet
   did @ >r
   udp-source-port be-w@ did !  \ set the udp-source-port to the port indicated
                              \ in the received error packet.
   error-packet  active-struct !
   err-pkt opcode be-w!
   5 ( Unknown transfer ID )  errorcode be-w!
   " Unknown source address" errmsg $cstrput  ( end-address )
   error-packet  tuck  -     ( packet-adr len )
   send-packet  drop
   r>  did !                 \ restore the previous did
   error-packet  /tftp-packet free-mem
;

: unlock-dest-ip-en-addr ( -- )
   use-server?  use-router?  use-dhcp @  or or if  exit  then
   broadcast-ip-addr his-ip-addr 4 cmove
   broadcast-en-addr his-en-addr 6 cmove
;

: lock-dest-ip-en-addr ( -- )
   active-struct @
   dup /ip-header - active-struct !
   ip-source-addr his-ip-addr 4 cmove
   /ether-header negate active-struct +!
   en-source-addr his-en-addr 6 cmove
   active-struct !
   his-ip-addr server-ip-addr 4 cmove
;

\ Check source port against destination id.
\ If it mismatches, error unless did is currently 69
: bad-src-port?  ( -- error )  \ assumes active-struct is udp
   false
   udp-source-port be-w@  did @  <>  if
      did @  UP_TFTP =  if
         udp-source-port be-w@  did !         \ Lock onto his port
         his-ip-addr broadcast-ip-addr?  if
            lock-dest-ip-en-addr              \ Lock onto dest ip & ether addresses
         then
      else  drop true
      then
   then
;

\ Check block number.  Assumes active-struct is tftp.
: bad-block#?  ( -- error? )  block# be-w@  this-block @ <>  ;

: send-current-packet  ( -- #sent )  packet-to-send  #packet @  send-packet  ;

: receive-tftp-packet  ( -- [ tftp-pkt-adr tftp-pkt-len ] flag )
   begin
      receive-udp-packet 0=  if  false exit  then     ( udp-pkt udp-len )
      drop active-struct !                            ( )
      udp-dest-port be-w@  sid @  =
   until
   bad-src-port?  if  send-error-packet false exit  then
   active-struct @ /udp-header +         ( tftp-pkt-adr )
   udp-length be-w@  /udp-header -       ( tftp-pkt-adr tftp-len )
   true
;

: receive-data-packet ( -- [ data-adr data-len ] flag )
   begin
      receive-tftp-packet 0=  if  false exit  then    ( tftp-adr tftp-len )
      over active-struct !                            ( tftp-adr tftp-len )
      opcode be-w@ data-pkt <>  bad-block#?  or
   while
      opcode be-w@ err-pkt =  if  .merror  then
      2drop
   repeat                                              ( tftp-adr tftp-len )
   false is  first-try?
   nip data swap 4 -  true
;

: ?try-broadcast  ( -- )
   first-try?  if
      unlock-dest-ip-en-addr
      \ Relock the destination port number
      d# 69 did !
      \ Give the server to come back up. Delay
      \ re-broadcasting to avoid jaming up the net.
      #retries @  if  5000 ms  then
   then
;

: get-data-packet ( adr -- adr' more? )
   #retries off
   begin
      send-current-packet drop
      receive-data-packet
   0= while
      ?try-broadcast
      1 #retries +!
      #retries @ d# 10 /mod drop 0=  if
         ." Retrying ... Check TFTP server and network setup" cr
      then
      too-many-tftp-retries?  if
         ." TFTP retry count exceeded" cr false exit
      then
   repeat

   \ Copy data from packet to our buffer at addr
   >r over r@ cmove  ( adr )

   r@ +           ( adr' )
   r> d# 512 =    ( adr' more? )
;

: need-router?  ( -- flag )
    server-ip-addr be-l@  on-my-net?  0=
;

: tftp-init  ( -- )
   true is first-try?
   packet-to-send 0=  if
      /tftp-packet alloc-mem to packet-to-send
      /udp-pseudo-hdr alloc-mem to udp-pseudo-hdr
   then
   get-msecs  h# 0ffff and  sid !  \ "random" number
;

: tftp-close  ( -- )
   packet-to-send /tftp-packet free-mem
   0 to packet-to-send
   udp-pseudo-hdr /udp-pseudo-hdr free-mem
   0 to udp-pseudo-hdr
;

headers
: tftpread  ( adr file-name -- size )
   tftp-init            ( adr file-name )
   reserve-buffer       ( adr file-name )
   setup-read-request   ( adr )
   dup                  ( adr adr )
   begin
      get-data-packet   ( adr adr' more? )
   while
      show-progress setup-ack-packet
   repeat               ( adr adr' )
   \ Send the final acknowledge.  Don't send if receive error.
   too-many-tftp-retries? 0= if
      setup-ack-packet
      send-current-packet drop   \ ignore errors
   then
   swap -
   release-buffer
   tftp-close too-many-tftp-retries? if ." tftp failed" abort then
;

headerless

\ previous definitions

\ *** New routines for tftpwrite ***

: receive-ack-packet  ( -- [ ack-packet-adr ack-len ] flag )
        \ flag is true if good packet.  other entries only if flag true
   receive-tftp-packet  ( [ tftp-packet-adr tftp-len ] flag )
   0=  if  false exit  then   ( packet-adr len )
   over active-struct !

   \ Check packet type
   opcode be-w@  err-pkt =  if  .merror 2drop false exit  then
   opcode be-w@  ack-pkt  <>  if
     ." Got a non-ack packet"  2drop false exit
   then

   bad-block#?  if  2drop false   else  nip data swap 4 -  true  then
;

: get-ack-packet  ( -- ack-received? )
   #retries off
   begin
      send-current-packet
      receive-ack-packet   ( [ ack-packet-adr ack-len ] flag )
   0= while
      1 #retries +!

\ XXX we need to be able to retry the whole transaction at a higher
\ level, so we should exit more gracefully than we do here.

      too-many-tftp-retries?  if  ." receive failed" false exit  then
   repeat   2drop true
;

: setup-data-packet  ( adr sizeleft -- adr' sizeleft' done? )
   dup 0<  if true exit then
   packet-to-send active-struct !
   data-pkt opcode be-w!
   1 this-block +!
   this-block @ block# be-w!    ( adr sizeleft )
   2dup  d# 512 min           ( adr sizeleft adr size<=512 )
   dup  4 + #packet !
   data swap cmove
   d# 512 -   \ decrease size remaining
   swap d# 512 + swap   \ adjust addr for remaining data
   false
;

headers

: tftpwrite  ( adr size file-name -- )
   tftp-init             ( adr size )
   reserve-buffer        ( adr size )
   setup-write-request   ( adr size )
   begin
      get-ack-packet if
         setup-data-packet  ( adr' sizeleft' done? )
      else true             \ error exit from loop
      then
   until  2drop
   release-buffer
   tftp-close
;
