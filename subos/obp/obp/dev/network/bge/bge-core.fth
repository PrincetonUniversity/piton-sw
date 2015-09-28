\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bge-core.fth
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
id: @(#)bge-core.fth 1.6 07/05/31
purpose: Core routines
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

instance variable txpi		\ Transmit Ring Producer Index
instance variable rrci		\ Receive Return Ring Consumer Index

: txci@  ( -- txci )  status-blk 1 >status-tx-ci-n local-w@ ;
: txpi@  ( -- txpi )  txpi @ ;
: txpi!  ( data -- )  txpi ! ;

: rrpi@  ( -- rrpi )  status-blk 1 >status-rx-pi-n local-w@ ;
: rrci@  ( -- rrci )  rrci @ ;
: rrci!  ( data -- )  rrci ! ;

instance variable nextstdbd  \ Pointer to next RX producer ring descriptor
instance variable nextrrbd   \ Pointer to next RX completion ring descriptor
instance variable nexttxbd   \ Pointer to next TX message descriptor

\ Get current rx completion/tx message descriptor ring pointer (on CPU side).
: nexttxbd@  ( -- txbdadr )  nexttxbd @  ;
: nextrrbd@  ( -- rrbdadr )  nextrrbd @  ;
: nextstdbd@  ( -- stdbd-adr )  nextstdbd @  ;

\ Set current rx completion/tx message descriptor ring pointer (on CPU side).
: nexttxbd!  ( txbdadr -- )  nexttxbd ! ;
: nextrrbd!  ( rrbdadr -- )  nextrrbd ! ;
: nextstdbd!  ( stdbd-adr -- )  nextstdbd !  ;

headers	      \ Useful Debug routines

: force-coal  ( -- )		\ force DMA Coalesce
   8 h# 3c00 breg-bset
;

: status-buf  ( -- adr len )
   cpu-dma-base >dma-status-blk /status-blk
;

: mask-broadcast  ( -- )	\ drop broadcast packets...
   h# c200.0000	  h# 480 breg!
   h# 8600.0004	  h# 488 breg!
;

headerless

: enter-isr  ( -- )
   cpu-dma-base >dma-status-blk >status-tag local@ d# 24 << hpm-im0 breg!
;

: exit-isr  ( -- )
   0 hpm-im0 breg!
;

\ RX return consumer ring address calculations
: rrci>rrbdadr ( n -- adr )  /rxring mod /rxbd *  rrbd0 + ;
: rrbdadr>rrci ( adr -- n )  rrbd0 - /rxbd / /rxring mod  ;

\ TX producer ring address calculations
: txpi>txbdadr ( n -- adr )  /txring mod /txbd *  txbd0 +  ;
: txbdadr>txpi ( adr -- n )  txbd0 - /txbd  /  /txring mod ;

\ Standard Rx producer ring address calculations
: stdpi>stdadr  ( n -- adr )  /std-ring mod /rxbd * std0 + ;
: stdadr>stdpi  ( adr -- n )  std0 - /rxbd / /std-ring mod ;

\ RX buffer address calculations
: rxbuf#>rxbufadr ( n -- adr )  #rxbufs mod /rxbuf * rxbuf0 +  ;
: txbuf#>txbufadr ( n -- adr )  #txbufs mod /txbuf * txbuf0 +  ;

\ TX descriptor fields
: txlength@ ( txbdadr -- len )     >txbd-len local-w@ ;
: txlength! ( len txbdadr -- )     >txbd-len local-w! ;

: txbufptr@ ( txbdadr -- adr )    drop txbuf0 ;  \ ## Only 1 tx buffer needed
: txbufptr! ( bufptr txbdadr -- )  2drop ;  \ ##  Only 1 tx buffer needed

\ RX descriptor fields
: rxbufptr! ( bufptr rmdadr -- )  >rxbd-host-adr local-x! ;
: rxbufptr@ ( rmdadr -- bufptr )  >rxbd-host-adr local-x@ ;

\ Sync DMA address 
: sync-buf ( cpu-adr size -- )  over cpu>io-adr swap dma-sync ;

\ TX descriptor initialization
: txbd-init ( txbuf len txbdadr -- )
   >r
   r@	>txbd-len		local-w!
   cpu>io-adr r@ >txbd-host-adr	local-x!
   h# 84      r@ >txbd-flags	local-w!	\ Coalesce now, packet-end flag
   0	      r@ >txbd-rsvd	local-w!
   0	      r@ >txbd-vlan	local-w!
   r> /txbd sync-buf
;

: rxlength@ ( rrbdadr -- len )  >rxbd-len local-w@ ;

: rrci>pkt-len ( rrbdd# -- pkt-len )
    rrci>rrbdadr rxlength@
;

: rrci>pkt-adr ( rrci -- pkt-adr )
   rrci>rrbdadr >rxbd-host-adr local-x@ io>cpu-adr
;

: init-std-rbd  ( rxbufadr rxbufsize stdadr -- ) 
   >r
   r@ stdadr>stdpi
   r@		>rxbd-index	local-w!
   r@		>rxbd-len	local-w!
   r@		>rxbd-host-adr	local-x!
   0 r@		>rxbd-type	local-w!
   0 r@		>rxbd-flags	local-w!
   0 r@		>rxbd-ip-cksum	local-w!
   0 r@		>rxbd-tcp-cksum	local-w!
   0 r>		>rxbd-err-flags	local-w!
;

false instance value restart?   \ To flag serious errors
defer restart-net  ( -- ok? )   \ To reinitialize after a serious error
['] true to restart-net 

instance variable rxerr-status   \ RXBD error status

: rxerr-status@  ( -- data ) rxerr-status @ ;
: rxerr-status!  ( data -- ) rxerr-status ! ;

: txmac-status@  ( -- data )  h# 460 breg@ ;

: receive-errors?  ( rxbdadr -- data )
   dup >rxbd-flags local-w@ rxbd-flags.frame-err and 0<> ( rxbdadr error? )
   swap >rxbd-err-flags local-w@ and			 ( error-data )
   dup rxerr-status!
; 

: transmit-errors? ( -- data )
   txmac-status@  h# 30 and
;

\ Display transmit errors
: .transmit-errors ( -- )
   transmit-errors?
   dup h# 10 and if  cmn-error[ " TX Underrun" ]cmn-end  then
   h# 20 and if  cmn-error[ " TX Overrun" ]cmn-end  then
;

\ Display receive errors
: .receive-errors ( -- )
   rxerr-status@
   dup rxbd-err.bad-crc and if	    cmn-error[ " RX Bad CRC"            ]cmn-end then
   dup rxbd-err.coll-detect and if  cmn-error[ " RX Collision Detected" ]cmn-end then
   dup rxbd-err.link-lost and if    cmn-error[ " RX Link Lost"          ]cmn-end then
   dup rxbd-err.phy-err and if	    cmn-error[ " RX Phy Error"          ]cmn-end then
   dup rxbd-err.odd-nibble and if   cmn-error[ " RX Odd # of Nibbles"   ]cmn-end then
   dup rxbd-err.mac-abort and if    cmn-error[ " RX Mac Abort"          ]cmn-end then
   dup rxbd-err.too-small and if    cmn-error[ " RX Packet < 64 bytes"  ]cmn-end then
   dup rxbd-err.truncated and if    cmn-error[ " RX Packet Truncated"   ]cmn-end then
   rxbd-err.giant and if	    cmn-error[ " RX Packet > MTU Size"  ]cmn-end then
;

\ Clear TX error bits in cached values and registers
: clear-tx-errors ( -- )
   h# 460 dup breg@ h# 30 or swap breg!
;

\ Clear RX error status
: clear-rx-errors ( -- )
   0 rxerr-status!
;

: get-tx-buffer ( -- txbufptr )
   nexttxbd@ txbufptr@
;

\ Update mailbox Producer Index and Standard Producer Index
: to-next-rrbd ( -- )
   nextstdbd@ stdadr>stdpi dup hpm-spr-pi breg!
   1+ stdpi>stdadr nextstdbd!
;

\ Get free buffer address and Initialize the next Standard Buffer Descriptor
: reclaim-buffer ( rrbdadr -- )
   rrbdadr>rrci rrci>pkt-adr cpu>io-adr /rxbuf 
   nextstdbd@ init-std-rbd
;

: ownership@  ( rbdadr -- pkt-waiting? )
   rrbdadr>rrci /rxring mod rrpi@ <>
;

: return-buffer ( stdbdadr -- )
   reclaim-buffer
   to-next-rrbd
;

: receive-ready? ( -- pkt-waiting? )
   nextrrbd@  dup /rxbd  sync-buf        \ Sync before looking at descriptor
   ownership@
;

: receive ( -- pkt-handle pkt pktlen )
   enter-isr
   nextrrbd@ dup rrbdadr>rrci			( rrci )
   dup hpm-rrci0 breg!				( rrci )
   dup 1+ rrci>rrbdadr nextrrbd!		( rrci )
   dup rrci>rrbdadr				( rrci rrbd-adr )

   \ Drop packet on receive errors
   receive-errors? if				( rrci )
      .receive-errors  clear-rx-errors		( rrci )
      restart?  if  restart-net drop  then
      rrci>pkt-adr 0 exit			( pkt-adr 0 )
   then						( rrci )

   dup rrci>pkt-adr swap rrci>pkt-len		( pktadr pktlen )
   2dup sync-buf				( pktadr pktlen )
   exit-isr
;

\ *** Main transmit routines ***

: transmit-complete?  ( -- complete? )	\ Complete when the txpi=txci+1 
   txpi@ 				( txpi-1 )
   txci@ /txring mod =			( txpi-1 txci )
;

: send-wait ( -- ok? )
   d# 4000 get-msecs +
   begin
      dup get-msecs >=
      transmit-complete? 0= and 0=
   until
   drop transmit-complete?	\ last try
   dup 0=  if 
      " Timeout waiting for transmit completion" diag-type-cr 
      true to restart?
   then
;

: transmit ( txbuf len -- ok? )
   enter-isr					( txbuf len )
   2dup sync-buf				( txbuf len )
   nexttxbd@ txbd-init				( )
   nexttxbd@ txbdadr>txpi 1+ /txring mod	( txpi )
   dup hpm-txpi0 breg!				( txpi )
   dup txpi!					( txpi )
   txpi>txbdadr nexttxbd!			( )
   send-wait					( ok? )
   transmit-errors?  if
      .transmit-errors  clear-tx-errors drop false
      restart?  if  restart-net drop  then
   then
   exit-isr
;


: net-on  ( -- ok? )
   #rxbufs stdpi>stdadr nextstdbd! \ next uninitialized stdbd
   txbd0 nexttxbd!
   rrbd0 nextrrbd!
   init-mac 0= 
;

: disable-sm  ( timeout register -- ) \ Disable state machine
   >r
   2 r@ breg-bclear
   begin
      r@ breg@ 2 and over 0<> and
   while
      1- 1 ms
   repeat r> 2drop
;

: disable-rx-sms  ( -- )
   2	h# 468	disable-sm		\ RX mac
   2	h# 2c00	disable-sm		\ RX BD Initiator
   2	h# 2000	disable-sm		\ RX List Placement
   2	h# 3400	disable-sm		\ RX List Selector
   2	h# 2400	disable-sm		\ RX Data BD Initiator
   2	h# 2800	disable-sm		\ RX Data Completion
   2	h# 3000	disable-sm		\ RX BD Completion
;

: disable-tx-sms  ( -- )
   2	h# 1400	disable-sm		\ TX BD Selector
   2	h# 1800	disable-sm		\ TX BD Initiator
   2	h# 0c00	disable-sm		\ TX Data Initiator
   4	h# 4800	disable-sm		\ Read DMA
   2	h# 1000	disable-sm		\ Tx Data Completion
   2	h# 6400	disable-sm		\ DMA Completion
   2	h# 1c00	disable-sm		\ TX BD Completion
   2	h# 045c	disable-sm		\ TX Mac
;

: disable-mem-sms  ( -- )
   2	h# 3c00	disable-sm		\ Host Coalescing
   4	h# 4c00	disable-sm		\ DMA Write Mode
   2	h# 3800	disable-sm		\ MBUF Cluster

[ifdef] ipmifw-support
   \ Do not issue FTQ reset when IPMI/ASF fw is enabled
   ipmifw-enabled? not if
[then]
   h# ffff.ffff	h# 5c00	breg!		\ FTQ reset register
   0		h# 5c00 breg!		
[ifdef] ipmifw-support
   then
[then]

   2	h# 4400	disable-sm		\ Buffer Manager
   2	h# 4000	disable-sm		\ Memory Arbitrator
;

\ To properly shutdown, the we have to disable several state machines
\ in the proper order.

: net-off  ( -- )

[ifdef] ipmifw-support
   ipmifw-enabled? if
      pause-ipmifw			\ Pause IPMI/ASF fw
      bootcode-sig!			\ Write bootcode magic KevT
   then
[then]

   disable-rx-sms	\ Disable Receive State Machines
   disable-tx-sms	\ Disable Transmit State Machines
   disable-mem-sms	\ Disable Memory State Machines
   2 h# 6808 breg!	\ Clear interrupt state

[ifdef] ipmifw-support
   enable-mem-access			\ Ensure endianness, mem space, arbtr
   ipmifw-enabled? if
      reset-core-clks			\ GRC reset - restarts IPMI/ASF fw
      enable-mem-access			\ Ensure endianness, mem space, arbtr
      check-bootcode-compl		\ Check bootcode compliment ~KevT
      fcode-state-unload state-sig!	\ send fcode driver unload notice
   then
[else]
   reset-core-clks			\ leave MAC in reset state
[then]

;

