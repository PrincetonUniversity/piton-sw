\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: xmac.fth
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
id: @(#)xmac.fth 1.2 07/03/21
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

: xmac-init-protocol-param-regs  ( -- )
   h#  2d0a03  xmac-ipg!    \ Inter Packet Gap 0
   h# 4002040  xmac-min!    \ Min Frame Size
   h#     5ee  xmac-max!    \ Max Frame & Burst Size
;
\ 2d0a03 = 0010 1101 0000 1010 0000 0011
\ bits[ 2:0]  ipg_value    =0x3 : 12~15B IPG for xgmii
\ bits[15:8]  ipg_value1   =0xa :    12B IPG for mii/gmii
\ bits[20:16] stretch ratio=0xd  
\ bits[23:21] stretch const=0x1  
\
\ 4002040 = 0100 0000 0000 0010 0000 0100 0000 
\ bits[ 9:0]   TxMinPacketSize   0x40  64B 
\ bits[17:10]  SlotTime          0x8   64 byte time
\ bits[19:18]  Reserved (assume) 0x0
\ bits[29:20]  RxMinPacketSize   0x40  64B


\ For an MAC addr=aa:bb:cc:dd:11:22, the three registers
\ should be set as follows,
\ XMAC_ADDR0=11:22, XMAC_ADDR1=cc:dd, XMAC_ADDR2=aa:bb
\
: xmac-init-macaddr-regs  ( -- )
   mac-address           ( addr len )
   drop                  ( addr )

   dup  c@ 8 lshift      ( addr aa00 )  \ aa: most significant mac byte
   over 1 + c@ or        ( addr aabb ) 
   xmac-addr2!           ( addr )

   dup  2 + c@ 8 lshift  ( addr cc00 )
   over 3 + c@ or        ( addr ccdd ) 
   xmac-addr1!           ( addr )
   
   dup  4 + c@ 8 lshift  ( addr 1100 )   
   swap 5 + c@ or        ( 1122 ) 
   xmac-addr0!           ( )

   \ Alternate addresses (XMAC_ADDRx, x = 3 ~ 50)
   d# 48 0 do 0 i xmac-addr-i! loop

   \ Disable comparison with alternate MAC addr by clearing the register.
   0 xmac-addr-cmpen!	
;

\ The 5 XMAC addr filter and mask registers starting at offset 0x818
: xmac-init-address-filter-regs  ( -- )
   3 0 do 0 i xmac-add-filt-i! loop
   0 xmac-add-filt12-mask!  
   0 xmac-add-filt00-mask!  
;

\ The 16 hash table registers starting at offset 0x840
: xmac-init-hashtable-regs  ( -- )
   d# 16 0 do 0 i xmac-hash-tbl-i!  loop
;

: xmac-init-counters  ( -- )
   0 rxmac-bt-cnt!      \ etherStatsOctes
   0 rxmac-bt-frm-cnt!  \ etherStatsBroadcastPkt
   0 rxmac-mc-frm-cnt!  \ etherStatsMulticastPkt
   0 rxmac-frag-cnt!    \ Receive Fragments Counter
   0 rxmac-hist-cnt1!   \ etherStatsPkts64Bytes , Histogram Cnt1 
   0 rxmac-hist-cnt2!   \ etherStatsPkts127Bytes 
   0 rxmac-hist-cnt3!   \ etherStatsPkts128to255Bytes
   0 rxmac-hist-cnt4!   \ etherStatsPkts256to511Bytes
   0 rxmac-hist-cnt5!   \ etherStatsPkts512to1023Bytes
   0 rxmac-hist-cnt6!   \ etherStatsPkts1024to1522Bytes
   0 rxmac-mpszer-cnt!  \ Maximun Packet Length Error
   0 rxmac-crc-er-cnt!  \ RxMAC CRC Error Counter
   0 mac-cd-vio-cnt!    \ Rx Code Violation Counter
   0 rxmac-al-er-cnt!   \ Alignment Error Counter
   0 txmac-frm-cnt!     \ Transmit Frame Coutner
   0 txmac-byte-cnt!    \ Transmit Byte Coutner
   0 link-fault-cnt!    \ Link Fault Counter
   0 rxmac-hist-cnt7!   \ etherStatsPkts1523 and more bytes cnt	
;

: init-xmac  ( -- )
   xmac-init-protocol-param-regs \ XMAC_IPG, XMAC_MIN, XMAC_MAX
   xmac-init-macaddr-regs        \ XMAC_ADDR...
   xmac-init-address-filter-regs \ XMAC_ADD_FILT, XMAC_ADD_FILT12_MASK  
                                 \ XMAC_ADD_FILT00_MASK  
   xmac-init-hashtable-regs      \ XMAC_HASH_TBL
   xmac-init-counters            \ Many counter regs like TxMAC_FRM_CNT

   xmac-config@				( val )
   link-is-up? if               	( val )
      mac-mode xmac-loopback <> if	( val )
         xmac-tx-output-en or		( val )
      then				( val )
      xmac-led-polarity or		( val )
   then					( val )

   mac-mode normal <>  			( val )
   mac-mode 2xgf-ext-loopback <> and if 
      \ Turn on promiscuous for internal loopback 
      promis or				( val )
      promis-group or       		( val )
   then					( val )
   
   portmode 10gig < if    		( val )      
      lfs-disable or			( val )
   then					( val )
   
   strip-crc  or			( val )
   xmac-config!				(  )

   \ During link initialization, it's possible for the remote_fault_detected
   \ bit to become set, which will prevent any transmits from happening. The
   \ register clears automatically on reads.
   xrxmac-status@ drop
;


\ Wait for the self clear bit0 and bit1 of XTxMAC_SW_RST reg to be 
\ self cleared
: wait-xmac-tx-rst  ( -- flag )
   xtxmac-sw-rst@ xtxmac-reg-rst xtxmac-soft-rst or and 0= 
;


\ Wait for the self clear bit1 of XRxMAC_SW_RST to be cleared
: wait-xmac-rx-rst  ( -- flag )
   xrxmac-sw-rst@ xrxmac-reg-rst xrxmac-soft-rst or and 0= 
;


: reset-xmac  ( -- ok? )  
   xtxmac-sw-rst@ xtxmac-reg-rst or xtxmac-soft-rst or xtxmac-sw-rst! 
   d# 100 ['] wait-xmac-tx-rst  wait-status
   dup 0=  if cmn-error[ " reset-xmac tx failed" ]cmn-end exit then
   drop

   xrxmac-sw-rst@ xrxmac-reg-rst or xrxmac-soft-rst or xrxmac-sw-rst!
   d# 100 ['] wait-xmac-rx-rst  wait-status
   dup 0=  if cmn-error[ " reset-xmac rx failed" ]cmn-end then
;


\ This is for selecting clock before we do reset-xmac. Do not
\ try to initialize non-clock related parameters here because
\ they will be wiped out by reset-xmac later.
\ 
: init-xmac-xif  ( -- ) 

   0    \ Put a 0 on stack to start building XIF part of XMAC_CONFIG  
        \ So sel_por_clk_src is guaranteed to be 0  (PRM says "SW 
        \ should always set sel_por_clk_src to 0 after POR" )

   portmode 1g-copper = if   		( val )
      1g-pcs-bypass or 	   		( val )
   then    				( val )

   \ Set XMAC to loopback mode BEFORE we do XMAC SW reset.  
   \ By contrast, XPCS loopback must be set AFTER XPCS reset.
   mac-mode xmac-loopback = if		( val )
      loopback or   			( val )
   then    				( val )

   portmode 1g-copper = if   		( val )
      chosen-speed 100Mbps = if \ Select internally generated 2.5MHz
         sel-clk-25mhz or       \ clock for 100MHz operation
      then   				( val )
   then			   		( val )
   xmac-config!				(  )

   \ Set Port Mode.
   xmac-config@   	 		( val )
   mii-gmii-mode-mask invert and    	( val )

   portmode case	   		( val )
      10g-fiber  of mii-gmii-mode=xgmii or endof
      10g-copper of mii-gmii-mode=xgmii or endof
      1g-copper  of
         chosen-speed case
            1000Mbps of mii-gmii-mode=gmii or endof
             100Mbps of mii-gmii-mode=mii  or endof
              10Mbps of mii-gmii-mode=mii  or endof
         endcase 
      endof   				( val )
   endcase		   		( val )
   xmac-config! 			(  )
;

\    Hostinfo tells which RDC Table should be used after a incoming
\ frame's MAC address matchs one of the 20 possible cases (16 alternative
\ MAC address, unique address, hash-hit, flow control and filter match)
\ For Fcode driver, we only need to set the hostinfo for unique MAC address
\ match, which is hostinfo17. But we do the same setting for flow control 
\ match because the checking for that match can not be disabled.
\ (Only alternative addr, hash-hit and filter-match can be disabled)
\    We use p-th RDC Table for port p. 
\    This word also disables comparison with 16 alternate MAC addresses, 
\ and the check for hash-hit and address filter hit.
\    See PRM 22.3.11
\
: xmac-init-hostinfo ( -- )
   d# 20 0 do 
      port mpr or i xmac-host-infox! 
   loop

   0 xmac-addr-cmpen!   \ Disable comparison with 16 alter addresses

   \ Disable checking for hash hit and filter address
   xmac-config@ hash-flt-en addr-flt-en or invert and xmac-config!
;

\ Enable both Tx and Rx
\
: enable-xmac ( -- )
   xmac-config@ tx-enable or rxmac-en or 	( val )
   var-min-ipg-en invert and			( val )
   mac-mode xmac-loopback <> if			( val )
      xmac-tx-output-en or 			( val )
   then						( val )
   xmac-config! 				(  )
;

\ Read XPCS control1 register and check the self clearing reset bit 15
: xpcs-reset-complete? ( -- flag ) xpcs-control1@ sw-reset and 0= ;

: wait-xpcs-reset  ( -- ok? ) d# 700 [']  xpcs-reset-complete? wait-status ;

\ As recommended by the reset sequence in the MAC PRM, set bit 15 of 
\ BASE10G_CONTROL1 to reset the xpcs module. This is a self clearing bit
\
: (reset-xpcs)     ( -- ok? )
   sw-reset xpcs-control1! 
   wait-xpcs-reset
;

\ Try to reset xpcs multiple times within 10 sec if necessary.
\
\ In PCS case, reset-pcs actually resets the 1G optical
\ transceiver. It is not clear, however, whether this reset-xpcs 
\ also resets the 10G bcm8704 optical transceiver interfacing with 
\ the xpcs layer.  
\
: reset-xpcs ( -- ok? )   
   d# 10000 get-msecs +	 false		( timeout flag )
   begin				( timeout flag )
      over timed-out? 0= over 0= and	( timeout flag continue? )
   while				( timeout flag )
      (reset-xpcs) if drop true then	( timeout flag )
   repeat				( timeout flag )
   nip dup 0=  if 			( flag )
      cmn-warn[ " xpcs software reset failed" ]cmn-end
   then					( flag )
;

\ Make sure that xpcs_bypass is 0 so that we use internal xpcs.
\
\ Although we must set xmac loopback BEFORE resetting xmac,
\ we can not set xpcs loopback before xpcs software reset because
\ XPCS software reset will wipe out the xpcs loopback setting. 
\
: init-xpcs  ( -- ok? )
   reset-xpcs
   mac-mode xpcs-loopback = if
      xpcs-control1@ csr-loopback or xpcs-control1!
   then  
;

: enable-xpcs  
   xpcs-cfg-vendor1@ xpcs-en or tx-buf-en or
   xpcs-cfg-vendor1!
;

: check-10g-user-inputs ( -- ok? )
   case user-speed
      auto-speed  of true  endof
      10Gbps      of true  endof
      1000Mbps    of false endof
      100Mbps     of false endof
      10Mbps      of false endof
   endcase
   case user-duplex
      auto-duplex of true  endof
      full-duplex of true  endof
      half-duplex of false endof
   endcase
   and dup 0= if
      user-speed user-duplex .link-speed,duplex ." is not supported" cr
      set-default-link-params
   then
;

: update-xmac-tx-err-stat     ( -- )
   xtxmac-status@ xmac-tx-degrade-errs and
   tx-xmac-err-status or to tx-xmac-err-status
;

: update-xmac-rx-err-stat     ( -- )
   xrxmac-status@ rx-oflow and
   rx-xmac-err-status or
   dup 0<> if
      cmn-error[ dup " RxMACOverflow = %x" ]cmn-end then
   to rx-xmac-err-status
;

: .xmac-tx-err       ( -- )
   tx-xmac-err-status underflow       and 0<> if ." TxMacUnderflow"   cr then
   tx-xmac-err-status opp-max-pkt-err and 0<> if ." OppMaxPktSizeErr" cr then
   tx-xmac-err-status overflow        and 0<> if ." TxMacOverflow"    cr then
;

: .xmac-rx-err       ( -- )
   rx-xmac-err-status rx-oflow and 0<> if ." RxMacOverflow" cr then
;

: clear-xmac-tx-err  ( -- ) 
   tx-xmac-err-status xmac-tx-degrade-errs invert and
   to tx-xmac-err-status
;

: clear-xmac-rx-err   ( -- )
   rx-xmac-err-status rx-oflow invert and
   to rx-xmac-err-status
;

: disable-xmac-intr   ( -- )
   \ XMAC has Tx_/Rx_xMac Mask Register that is bit-by-bit corresponds
   \ to the layout of Tx/RxMAC Status Register. Set the bits to 0
   \ so that none of them will generate interrupt
   0 xtxmac-stat-msk!
   0 xrxmac-stat-msk!
;
