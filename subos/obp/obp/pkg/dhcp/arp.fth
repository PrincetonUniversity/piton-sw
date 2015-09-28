\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: arp.fth
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
id: @(#)arp.fth 2.16 02/08/22
purpose: Address Resolution Protocol (ARP) and Reverse ARP (RARP)
copyright: Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ Address Resolution Protocol (ARP)
\   Given the local Ethernet address, finds a server's Ethernet address
\
\ Reverse Address Resolution Protocol (RARP)
\   Given the local Ethernet address, finds corresponding Internet address
\
\ These protocols are specific to both Ethernet and Internet, since
\ their purpose is to relate corresponding addresses from the two
\ families.

decimal

headerless
h# 806  constant ARP_TYPE
h# 8035 constant RARP_TYPE

\ Request structure shared between ARP and RARP

struct ( arp-packet)
   2 field >arp-hw       \ set to 1 for ethernet
   2 field >arp-protocol \ set to IP_TYPE
   1 field >arp-hwlen    \ set to 6 for ethernet
   1 field >arp-protolen \ set to 4 for IP
   2 field >arp-opcode   \ 1 arp req., 2 arp reply, 3 rarp req., 4 rarp reply
   6 field >arp-sha      \ sender hardware address
   4 field >arp-spa      \ sender protocol address
   6 field >arp-tha      \ target hardware address
   4 field >arp-tpa      \ target protocol address
constant /arp-packet

: arp-hw        ( -- adr ) active-struct@ >arp-hw ;
: arp-protocol  ( -- adr ) active-struct@ >arp-protocol ;
: arp-hwlen     ( -- adr ) active-struct@ >arp-hwlen ;
: arp-protolen  ( -- adr ) active-struct@ >arp-protolen ;
: arp-opcode    ( -- adr ) active-struct@ >arp-opcode ;
: arp-sha       ( -- adr ) active-struct@ >arp-sha ;
: arp-spa       ( -- adr ) active-struct@ >arp-spa ;
: arp-tha       ( -- adr ) active-struct@ >arp-tha ;
: arp-tpa       ( -- adr ) active-struct@ >arp-tpa ;

1 constant  ARP_REQ
2 constant  ARP_REPLY
3 constant  RARP_REQ
4 constant  RARP_REPLY

/ether-header /arp-packet +  constant  /ether+arp

\ Initial timeout for ARP/RARP packets set to 1 second
d# 1000 instance value arp-timeout-msecs

\ Common ARP/RARP request packet constructor
: send-arp/rarp-packet  ( target-ip target-en my-ip my-en req-type en-type -- ok? )
   *buffer @  active-struct !      \ Set the Ethernet header
   my-en-addr         en-source-addr  6 cmove
   broadcast-en-addr  en-dest-addr    6 cmove
   ( ... en-type )    en-type         be-w!

   /ether-header active-struct +!  \ Set the ARP/RARP protocol packet
   1       arp-hw be-w!
   IP_TYPE arp-protocol be-w!
   6       arp-hwlen    c!
   4       arp-protolen c!
   ( ... req-type )     arp-opcode   be-w!
   ( ... my-en-addr )   arp-sha 6 cmove
   ( ... my-ip-addr )   arp-spa 4 cmove
   ( ... target-en  )   arp-tha 6 cmove
   (     target-ip  )   arp-tpa 4 cmove

   /ether+arp  transmit
;

instance variable arp-timeout

\ Use exponential backoff (with maximum timeout of 32 seconds) between retries
: arp-backoff ( -- )  arp-timeout @  2*  d# 32000 min  arp-timeout ! ; 

: arpcom ( target-ip target-en my-ip my-en req-type en-type -- ok? )
   send-arp/rarp-packet  dup 0=  if
      ." ARP/RARP send failed.  Check Ethernet cable and transceiver." cr
      exit
   then
   arp-timeout @ set-timeout
;

: decode-arp-packet ( -- )
   arp-sha  his-en-addr 6 cmove         \ grab his ethernet address
;

: .arp/rarp-timeout ( -- )
   ." Timeout waiting for ARP/RARP packet" cr
;

: try-arp ( -- )
   his-ip-addr his-en-addr my-ip-addr my-en-addr ARP_REQ ARP_TYPE
   arpcom  if
      begin
         ARP_TYPE receive-ethernet-packet 0<>
      while                                       ( adr len )
         drop                                     ( adr )
         /ether-header +  active-struct !
         arp-tpa my-ip-addr ip=  if               \ Addressed to me
            arp-opcode be-w@  ARP_REPLY =  if     \ ARP reply
               decode-arp-packet  exit
            then
         then
      repeat                                      ( )
      .arp/rarp-timeout  arp-backoff
   then
;

headers

: do-arp ( -- )
   arp-timeout-msecs arp-timeout !
   reserve-buffer
   begin  his-en-addr broadcast-en-addr?  while  try-arp  repeat
   release-buffer
;

headerless

\ Handle incoming arp packets if we know our address
: arp-response  ( adr len -- )
   /ether+arp  <  if  drop exit  then               \ Packet length filter
   active-struct !
   en-type be-w@  ARP_TYPE  <>  if  exit  then      \ Packet type filter
   /ether-header active-struct +!                   \ Select ARP structure
   arp-protocol be-w@  IP_TYPE  <>  if  exit  then  \ Type filter

   \ sunmon code locks onto his Ethernet address here, but I don't
   \ think that is necessary, because we should only be ARP'ed if we
   \ haven't already found the correct IP address.

   arp-opcode be-w@ ARP_REQ <>  if  exit  then       \ Type filter
   arp-tpa  my-ip-addr  ip=  0=  if  exit  then      \ For somebody else?

   \ All the checks have succeeded, so we can send the reply
   ARP_REPLY arp-opcode be-w!
   arp-sha     arp-tha         6 cmove
   arp-sha
   /ether-header negate active-struct +!
               en-dest-addr    6 cmove
   my-en-addr  en-source-addr  6 cmove
   /ether-header active-struct +!
   my-en-addr  arp-sha         6 cmove         ( adr )
   arp-spa     arp-tpa         4 cmove
   my-ip-addr  arp-spa         4 cmove

   active-struct@ /ether-header -  /ether+arp  " write" $call-parent  drop
;
' arp-response is handle-broadcast-packet

: decode-rarp-packet ( -- )
   arp-tpa  my-ip-addr   4 cmove    \ grab my IP address
   arp-spa  his-ip-addr  4 cmove    \ grab his IP address
   arp-sha  his-en-addr  6 cmove    \ grab his ethernet address
;

: try-rarp ( -- )
   broadcast-ip-addr my-en-addr my-ip-addr my-en-addr RARP_REQ RARP_TYPE
   arpcom  if
      begin
         RARP_TYPE receive-ethernet-packet 0<>
      while                                     ( adr len )
         drop                                   ( len )
         /ether-header +  active-struct !
         arp-tha my-en-addr 6 comp 0=           \ Addressed to me
         arp-opcode be-w@ RARP_REPLY =  and  if \ RARP reply
            decode-rarp-packet exit
         then
      repeat                                    ( )
      .arp/rarp-timeout  arp-backoff
   then
;

headers

: do-rarp  ( -- )
   arp-timeout-msecs arp-timeout !
   reserve-buffer
   begin  my-ip-addr l@ 0=  while  try-rarp  repeat
   release-buffer
;
