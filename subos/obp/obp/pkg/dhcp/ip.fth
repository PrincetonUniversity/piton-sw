\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ip.fth
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
id: @(#)ip.fth 2.12 02/08/22
purpose: Simple Internet Protocol (IP) implementation
copyright: Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ Internet protocol (IP).

decimal

headerless

struct ( ip-header )
   1 field >ip-version
   1 field >ip-service
   2 field >ip-length
   2 field >ip-id
   2 field >ip-fragment
   1 field >ip-ttl
   1 field >ip-protocol
   2 field >ip-checksum
   4 field >ip-source-addr
   4 field >ip-dest-addr
constant /ip-header

: ip-version     ( -- adr )  active-struct@ >ip-version ;
: ip-service     ( -- adr )  active-struct@ >ip-service ;
: ip-length      ( -- adr )  active-struct@ >ip-length ;
: ip-id          ( -- adr )  active-struct@ >ip-id ;
: ip-fragment    ( -- adr )  active-struct@ >ip-fragment ;
: ip-ttl         ( -- adr )  active-struct@ >ip-ttl ;
: ip-protocol    ( -- adr )  active-struct@ >ip-protocol ;
: ip-checksum    ( -- adr )  active-struct@ >ip-checksum ;
: ip-source-addr ( -- adr )  active-struct@ >ip-source-addr ;
: ip-dest-addr   ( -- adr )  active-struct@ >ip-dest-addr ;

instance variable ttl   d# 64 ttl !  \ RFC 1700 recommended IP default TTL
instance variable ip-sequence

instance variable my-ip-addr
instance variable his-ip-addr

instance variable server-ip-addr
instance variable router-ip-addr
instance variable subnet-mask

false instance value use-server?
false instance value use-router?

decimal
h# 800 constant IP_TYPE

create broadcast-ip-addr  h# ff c,  h# ff c,  h# ff c,  h# ff c,

: ip=  ( ip-addr1  ip-addr2 -- flag  )   4 comp  0=  ;

\ either h# ffffffff or h# 0 is broadcast ip addr
: broadcast-ip-addr?   ( adr-buf -- flag )
   dup broadcast-ip-addr  ip=  swap be-l@  0=  or
;

: ip-addr-match? ( -- flag )
   \ If we know the server's IP address, silently discard packets 
   \ from other hosts
   his-ip-addr broadcast-ip-addr? 0=  if
      his-ip-addr ip-source-addr ip=  0=  if  false exit  then
   then

   \ Accept IP broadcast packets
   ip-dest-addr broadcast-ip-addr?  if  true exit  then

   \ Accept every packet if we dont know our IP address yet
   my-ip-addr broadcast-ip-addr?  if  true exit  then

   \ We know our IP address; filter packets to other destinations
   ip-dest-addr my-ip-addr ip=
;

: receive-ip-packet  ( -- [ ip-packet-adr ip-len ] flag )
   begin
      IP_TYPE receive-ethernet-packet 0=  if  false exit  then  ( adr len )
      drop /ether-header +  active-struct !                     ( )
      ip-addr-match?
   until                                                        ( )
   active-struct@  ip-length w@  true                           ( adr len true )
;

: my-netid  ( -- netid )
   my-ip-addr be-l@  subnet-mask be-l@  and  ( netid )
;

: on-my-net?  ( ip# -- flag )
   subnet-mask broadcast-ip-addr?  if  drop true exit  then  ( ip# )
   ( ip# ) subnet-mask be-l@  and   ( dest-netid )
   my-netid  =
;

: .in  ( byte -- )  .d bs emit ." ." ;
: .inetaddr  ( n -- )   lbsplit .in .in .in .d ;

headers
