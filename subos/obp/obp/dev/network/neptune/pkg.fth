\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: pkg.fth
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
id: @(#)pkg.fth 1.1 07/01/23
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

defer open-hook   ' noop to  open-hook
defer close-hook  ' noop to  close-hook

0 value obp-tftp

: init-obp-tftp ( tftp-args$ -- okay? )
   " obp-tftp" find-package if  
      open-package  
   else  
      cmn-warn[ " Cannot open obp-tftp package" ]cmn-end
      2drop 0
   then
   dup to obp-tftp
;

: init-txc ( -- )
  \ Bind channel selected by my-dma-chan to this port's TXC
  1 chan# lshift port txc-port-dma-p!

  \ Clear DMA_LENGTH, which is the number of bytes transmitted by DMA.
  \ This register is cleared on reads.
  chan# txc-dma-max-len-i@ drop

  port txc-debug!  \ Select debug for the used port

  \ Set TXC_ENABLED (bit 4) of TXC_CONTROL to enable TXC. Set
  \ p-th bit to enable only the engine for port p
  txc-enabled 1 port lshift or txc-control!
;

: use-gmii?  ( -- flag )
   portmode 1g-copper = if phy-sr@ physr.ext-status and 0<> else false then
;

: publish-post-open-properties ( -- )
   user-speed  case
      auto-speed of   " auto" endof
        10Mbps   of     " 10" endof
       100Mbps   of    " 100" endof
      1000Mbps   of   " 1000" endof
        10Gbps   of  " 10000" endof
   endcase  
   encode-string " speed" property

   user-duplex	case
      auto-duplex  of " auto" endof
      half-duplex  of " half" endof
      full-duplex  of " full" endof
   endcase
   encode-string " duplex" property

   portmode 1g-copper = if 
      use-gmii? if
         user-link-clock  case
            auto-link-clock   of " auto"   endof
            master-link-clock of " master" endof
            slave-link-clock  of " slave"  endof
         endcase
         encode-string " link-clock" property
      then
   then
;

\ Tx-header is very important. Even if we set CKSUM_EN_PKT_TYPE to 0
\ to disable checksum, TOT_XFER_LEN should still be set correctly.
\ That is because the Neptune expects this number to be TR_LEN (of
\ the Tx descriptor)  minus 16
\ bits[63:62]  CKSUM_EN_PKT_TYPE  0: No op, do not do checksum, 01 TCP, 10 UDP
\ bits61       IP_VER 0=IPv4  1=IPv61
\ bit57        LLC
\ bit56        VLAN
\ bits[55:52]  IHL
\ bit[51:48]   L3START
\ bit[45:40]   L4START
\ bit[37:32]   L4STUFF
\ bit[29:16]   TOT_XFER_LEN

struct
   2 field >pad-rsvd0
   2 field >tot-xfer-len-rsvd1
   1 field >l4stuff-rsvd2
   1 field >l4start-rsvd3
   1 field >l3start-ihl
   1 field >vlan-llc-rsvd4-ip-ver-cksum-en-pkt-type
   8 field >rsvd5
constant /tx-header

/tx-header buffer:  tx-header


: make-tx-header ( ether-frame-len -- )
   wbflip tx-header >tot-xfer-len-rsvd1 w!
      \ b31:30 = RSVD=b00
      \ b29:16 = tot-xfer-len = /loopback-pkt - tx-header
      \ = /dst-src-macs + /ether-type  + /loopback-data

   0 tx-header >pad-rsvd0 w!   \ b15:3=RSVD=0,  b2:0=PAD=0

   19 tx-header >l4stuff-rsvd2 c!
      \ b39:38=RSVD=b00.  b37:32 L4STUFF = (14+20+16)/2 = 25 =0x19
      \ L4STUFF is where the tcp checksum is, which is at
      \ 16 from the begining of TCP's first byte

   11 tx-header >l4start-rsvd3 c!
      \ b47:46=RSVD=b00.  b45:40=L4START = (6+6+2+20)/2 = 17=0x11

   57 tx-header >l3start-ihl   c!
      \ b55:52 IHL  IP header = 5 (5x4B=20B)
      \ b51:48 L3START=[6(DA)+6(SA)+2(type)]/2 = 7

   0 tx-header >vlan-llc-rsvd4-ip-ver-cksum-en-pkt-type c!
      \ b63:62=CKSUM_EN_PKT_TYPE=1=TCP cksum. b61=IP_VER=0=IPv4
      \ b63:62=CKSUM_EN_PKT_TYPE=0=No cksum. b61=IP_VER=0=IPv4
      \ b60:58=RSVD=b000, b57=LLC = 0  b56=VLAN = 0

   0 tx-header >rsvd5 x!     \ First 8B of Tx header is RSVD
;


external

\ XMAC and BMAC do not support padding, so the driver needs to
\ ensure that the ethernet frame is minimun 60 bytes (Ethernet
\ standard requires a minimun 46B of payload. 46B plus 12B dest 
\ and src MAC addresses and 2B ether-type = 60B)
\
: write ( appl-buf len -- #sent )
   link-up? 0=  if
      cmn-note[ " Link down, restarting network initialization" ]cmn-end
      restart-net if
          2drop 0 exit
      then
   then                ( appl-buf len )
   tbuf0 swap          ( appl-buf tbuf-cpu-adr len )

   \ If the packet from upper layer is shorter than 60B, then 
   \ fill out the first 60 bytes of tbuf with zeros so that all 
   \ the padding bytes will be zeros.
   dup /min-ether-len < if       ( appl-buf tbuf-cpu-adr len )
      over /min-ether-len erase  ( appl-buf tbuf-cpu-adr len )  
   then                         

   2dup        ( appl-buf tbuf-cpu-adr len tbuf-cpu-adr len )
   >r >r       ( appl-buf tbuf-cpu-adr len )( R: len tbuf-cpu-adr )

   \ Construct tx-header required by Neptune
   dup /min-ether-len < if 
      /min-ether-len make-tx-header
   else 
      dup make-tx-header   ( appl-buf tbuf-cpu-adr len )
   then

   \ First copy the tx-header just constructed by make-tx-header
   over tx-header swap     ( appl-buf tbuf-cpu-adr len tx-header tbuf-cpu-adr )
   /tx-header move         ( appl-buf tbuf-cpu-adr len ) 

   \ Next copy the ethernet frame passed down from upper layer
   swap /tx-header + swap  ( appl-buf tbuf-cpu-adr+16 len )
   move                    (  )( R: len tbuf-cpu-adr )
   r> r>                   ( tbuf-cpu-adr len )( R: )
   tuck                    ( len tbuf-cpu-adr len )

   dup /min-ether-len < if 
      drop /min-ether-len 
   then                    ( len tbuf-cpu-adr LEN ) 
   /tx-header +            ( len tbuf-cpu-adr LEN' )

   \ Application data has been copied from application data buffer 
   \ to the 4K Tx block buffer pointed by nexttmd.  The data is appended
   \ to Tx header and may be followed by some zero padding bytes if the 
   \ data size is < 60.  Now send data out to the network
   \
   transmit 0= if  
      drop 0  
   then                    ( #sent )
;

: read ( buf len -- -2 | actual-bytes-read )
   rcr-has-pkt? if                ( buf len )
      get-pkt-addr&len-from-rcr   ( buf len nextrcdaddr pkt-cpu-adr pktlen )
      swap full-header + swap     ( buf len nextrcdaddr pkt-cpu-adr' pktlen ) 
                                  \ pkt-cpu-adr' = pkt-cpu-adr+18 
      ?dup if              ( buf len nextrcdaddr pkt-cpu-adr' pktlen )
         rot >r            ( buf len pkt-cpu-adr' pktlen )( R: nextrcdaddr ) 
         rot               ( buf pkt-cpu-adr' pktlen len )
         min               ( buf pkt-cpu-adr' min[pktlen,len] )
         >r                ( buf pkt-cpu-adr' )( R: nextrcdaddr min )
         swap              ( pkt-cpu-adr' buf )( R: nextrcdaddr min )  
         r@                ( pkt-cpu-adr' buf min )( R: nextrcdaddr min )  
         move r> r>        ( min nextrcdaddr )( R: )
      else                 ( buf len nextrcdaddr pkt-cpu-adr' )
         drop              ( buf len nextrcdaddr )
         nip nip 0 swap    ( 0 nextrcdaddr )  
      then
      return-rx-buffer     ( min|0 ) 
   else
      2drop 0              \ drop buf and len and put a 0 on stack
   then
   ?dup 0= if -2 then      \ Upper layer wants to see -2 if we got 0
;

: close  ( -- )
   obp-tftp ?dup if close-package then
   pio if 
      resetall
      unmap-resources  
   then
   close-hook
;

: open ( -- ok? )
   make-path
   open-hook
   map-resources
   my-args parse-devargs     ( tftp-args$ )
   init-obp-tftp 0= if close false exit then

   check-user-inputs if
      niu? 0= if
         set-ldg
      then
      init-txc
      init-fflp
      bringup-link ?dup 0= if close false exit then
      publish-post-open-properties
      mac-address encode-bytes  " mac-address" property
   else
      unmap-resources
      false 
   then
;


: load  ( adr -- len ) 
   " load" obp-tftp $call-method
;

: reset  ( -- )
   pio if
      resetall
      unmap-resources
   else
      map-regs resetall
      unmap-regs
   then
;

headerless
