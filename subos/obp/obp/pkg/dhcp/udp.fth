\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: udp.fth
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
id: @(#)udp.fth 2.11 02/08/22
purpose: Simple User Datagram Protocol (UDP) implementation
copyright: Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

decimal

headerless
17 constant UDP

instance variable my-udp-port
instance variable his-udp-port

struct ( udp-header )
   2 field >udp-source-port
   2 field >udp-dest-port
   2 field >udp-length
   2 field >udp-checksum
constant /udp-header

: udp-source-port  ( -- adr )  active-struct@  >udp-source-port ;
: udp-dest-port    ( -- adr )  active-struct@  >udp-dest-port ;
: udp-length       ( -- adr )  active-struct@  >udp-length ;
: udp-checksum     ( -- adr )  active-struct@  >udp-checksum ;

struct ( udp-pseudo-hdr )
   4 field udp-src-addr
   4 field udp-dst-addr
   2 field udp-protocol-id
   2 field udp-len-copy
constant /udp-pseudo-hdr

0 instance value packet-to-send   \ buffer used by TFTP & DHCP to format pkts
0 instance value udp-pseudo-hdr

\ fill-udp-pseudo-hdr assumes active-struct points to the appropriate
\ udp packet.
: fill-udp-pseudo-hdr  ( -- )
   /ip-header negate active-struct +!
   udp-pseudo-hdr                             ( udp-pseudo-addr )
   ip-source-addr over udp-src-addr 4 cmove   ( udp-pseudo-addr )
   ip-dest-addr   over udp-dst-addr 4 cmove   ( udp-pseudo-addr )
   UDP over udp-protocol-id be-w!             ( udp-pseudo-addr )
   /ip-header active-struct +!                ( udp-pseudo-addr )
   udp-length be-w@  swap udp-len-copy be-w!  (  )
;

\ udp-checksum assumes active-struct points to the appropriate udp packet.
: calc-udp-checksum  ( -- checksum )
   fill-udp-pseudo-hdr
   0 udp-checksum be-w!
   0 udp-pseudo-hdr /udp-pseudo-hdr  (oc-checksum)  ( chksum' )
   active-struct @  udp-length be-w@  oc-checksum   ( chksum  )
;

: bad-udp-checksum? ( -- bad? )
\   udp-checksum?  0=  if  false exit  then
   udp-checksum be-w@  dup  if  ( checksum )
      calc-udp-checksum  <>   ( bad? )
   then                       ( bad? )
;

: prepare-udp-packet ( data-addr data-len -- total-len )
   dup  /udp-header +            ( data-addr data-len udp-len )
   dup  /ip-header  +            ( data-addr data-len udp-len ip-len )
   dup  /ether-header + >r       ( rs: total-len )
   *buffer @   active-struct !
      my-en-addr   en-source-addr  6 cmove
      his-en-addr  en-dest-addr    6 cmove
      IP_TYPE  en-type be-w!

   /ether-header active-struct +!
      h# 45    ip-version c!    ( 45 is ip version 4, length 5 longwords )
      0        ip-service c!
      ( ... ip-len ) ip-length be-w!
      ip-sequence @  ip-id     be-w!    1 ip-sequence +!
      0        ip-fragment be-w!
      ttl @    ip-ttl      c!
      UDP      ip-protocol c!
      0        ip-checksum be-w!
      my-ip-addr     ip-source-addr 4 cmove
      his-ip-addr   ip-dest-addr   4 cmove
      0 active-struct @  /ip-header  oc-checksum   ip-checksum  be-w!

   /ip-header active-struct +!
      my-udp-port  @  udp-source-port be-w!
      his-udp-port @  udp-dest-port   be-w!
      ( ... udp-len ) udp-length      be-w!
\      0 udp-checksum  be-w!

   /udp-header active-struct @ +     ( data-addr data-len buffer-addr )
      swap cmove
      udp-checksum?  if  calc-udp-checksum  else  0  then    ( udp-chksum )
      udp-checksum be-w!

      r>     ( total-len )
;

: receive-udp-packet  ( -- [ udp-packet-adr udp-len ] flag )
   \ flag non-zero if packet received.  other entries only if good packet
   begin
      receive-ip-packet  0= if  false exit  then  ( ip-adr ip-len )

      swap active-struct !
      ip-protocol c@ UDP <> dup 0=  if    \ Filter out non-UDP packets ..
         drop  /ip-header active-struct +!
         bad-udp-checksum?                \ .. and bad UDP packets
      then
   while
      drop
   repeat   ( ip-len )
   active-struct @  swap /ip-header -   true
;
headers
