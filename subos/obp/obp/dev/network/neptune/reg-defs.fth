\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: reg-defs.fth
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
id: @(#)reg-defs.fth 1.1 07/01/23
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved.
copyright: Use is subject to license terms.

headerless

: bmac!     ( data offset -- )  bmac2 + bmac-offset + rx! ;
: bmac@     ( offset -- data )  bmac2 + bmac-offset + rx@ ;

: dmc!      ( data offset -- )  dmc + rx! ;
: dmc@      ( offset -- data )  dmc + rx@ ;

: esr!      ( data offset -- )  esr + rx! ;
: esr@      ( offset -- data )  esr + rx@ ;

: fzc-dmc!  ( data offset -- )  fzc-dmc + rx! ;
: fzc-dmc@  ( offset -- data )  fzc-dmc + rx@ ;

: fzc-prom@ ( offset -- data )  fzc-prom + rx@ ;
: fzc-prom! ( data offset -- )  fzc-prom + rx! ;

: fzc-zcp@  ( offset -- data )  fzc-zcp + rx@ ;
: fzc-zcp!  ( data offset -- )  fzc-zcp + rx! ;

: mif@      ( offset -- data )  mif + rx@ ;
: mif!      ( data offset -- )  mif + rx! ;

: pcs!      ( data offset -- )  pcs0 + pcs-offset  + rx! ;
: pcs@      ( offset -- data )  pcs0 + pcs-offset  + rx@ ;

: xmac!     ( data offset -- )  xmac0 + xmac-offset + rx! ;
: xmac@     ( offset -- data )  xmac0 + xmac-offset + rx@ ;

: xpcs!     ( data offset -- )  xpcs0 + xpcs-offset + rx! ;
: xpcs@     ( offset -- data )  xpcs0 + xpcs-offset + rx@ ;

: fzc-ipp@  ( offset -- data )  fzc-ipp + rx@ ;
: fzc-ipp!  ( data offset -- )  fzc-ipp + rx! ;


\ ----------------- ESR (Serdes) ------------------
: enet-serdes0-pll-config! ( data -- ) h# 10 esr! ;
: enet-serdes0-pll-config@ ( -- data ) h# 10 esr@ ;
: enet-serdes0-control!    ( data -- ) h# 18 esr! ;
: enet-serdes0-control@    ( -- data ) h# 18 esr@ ;
: enet-serdes0-test-cfg!   ( data -- ) h# 20 esr! ;
: enet-serdes0-test-cfg@   ( -- data ) h# 20 esr@ ;
: enet-serdes1-pll-config! ( data -- ) h# 28 esr! ;
: enet-serdes1-pll-config@ ( -- data ) h# 28 esr@ ;
1 6 lshift constant half-rate-3
1 5 lshift constant half-rate-2
1 4 lshift constant half-rate-1
1 3 lshift constant half-rate-0
1 2 lshift constant fbdiv-2
1 1 lshift constant fbdiv-1
  1        constant fbdiv-0

: enet-serdes1-control!    ( data -- ) h# 30 esr! ;
: enet-serdes1-control@    ( -- data ) h# 30 esr@ ;
: enet-serdes1-test-cfg!   ( data -- ) h# 38 esr! ;
: enet-serdes1-test-cfg@   ( -- data ) h# 38 esr@ ;

: esr-internal-signals@   ( -- data ) h# 800 esr@ ;
h# 33e0000f constant	p0-bits-mask
h# 0c1f00f0 constant	p1-bits-mask
h# 20000000 constant	serdes-rdy0-p0
h# 10000000 constant	detect0-p0
h# 08000000 constant	serdes-rdy0-p1	
h# 04000000 constant	detect0-p1
h# 02000000 constant	xserdes-rdy-p0
h# 01000000 constant	xdetect-p0-ch3
h# 00800000 constant	xdetect-p0-ch2
h# 00400000 constant	xdetect-p0-ch1
h# 00200000 constant	xdetect-p0-ch0
h# 00100000 constant	xserdes-rdy-p1
h# 00080000 constant	xdetect-p1-ch3
h# 00040000 constant	xdetect-p1-ch2
h# 00020000 constant	xdetect-p1-ch1
h# 00010000 constant	xdetect-p1-ch0

\ --------------------- Tx -----------------------------------------
: tx-rng-cfig-i! ( data i -- ) h# 200 * h# 4.0000 + dmc! ;
#tmds 3 rshift d# 48 lshift constant len=64    \ tx ring size=64

: tx-ring-hdl-i@  ( i -- data ) h# 200 * h# 4.0010 + dmc@ ;
: tx-ring-hdl-i!  ( data i -- ) h# 200 * h# 4.0010 + dmc! ;
: tx-ring-kick-i@ ( i -- data ) h# 200 * h# 4.0018 + dmc@ ;
: tx-ring-kick-i! ( data i -- ) h# 200 * h# 4.0018 + dmc! ;

: tx-ent-msk-i! ( data i -- ) h# 200 * h# 4.0020 + dmc! ;
h# 80ff constant tx-dma-ent-dis-msk 
\  80FF is the OR of following mask bits (0=enable, 1=disable)
\  bit 15  MK_MSK       
\  bit  7  MBOX_ERR_MSK
\  bit  6  PKT_SIZE_ERR_MKS
\  bit  5  TX_RING_OFLOW_MSK
\  bit  4  PREF_BUF_ECC_ERR_MSK
\  bit  3  NACK_PREF_MSK 
\  bit  2  NACK_PKT_RD_MSK 
\  bit  1  CONF_PART_ERR_MSK
\  bit  0  PKT_PRT_ERR

: tx-cs-i@  ( i -- data ) h# 200 * h# 4.0028 + dmc@ ;
: tx-cs-i!  ( data i -- ) h# 200 * h# 4.0028 + dmc! ;
1 d# 31 lshift constant  rst      
1 d# 30 lshift constant  rst-state
1 d# 28 lshift constant  stop-n-go
1 d# 27 lshift constant  sng-state 
1 d# 15 lshift constant  mk 
1     5 lshift constant  tx-ring-oflow 
1     4 lshift constant  pref-buf-par-err
1     3 lshift constant  nack-pref 
1     2 lshift constant  nack-pkt-rd 
1     1 lshift constant  conf-part-err 
1              constant  pkt-prt-err 
h# 3F          constant  tx-dma-fatal-errs \ OR above bits[0:5]


\ Partition support
: tx-log-page-vld-i!    ( data i -- ) h# 200 * h# 4.0000 + fzc-dmc! ;
: tx-log-mask1-i!       ( data i -- ) h# 200 * h# 4.0008 + fzc-dmc! ;
: tx-log-value1-i!      ( data i -- ) h# 200 * h# 4.0010 + fzc-dmc! ;
: tx-log-mask2-i!       ( data i -- ) h# 200 * h# 4.0018 + fzc-dmc! ;
: tx-log-value2-i!      ( data i -- ) h# 200 * h# 4.0020 + fzc-dmc! ;
: tx-log-page-relo1-i!  ( data i -- ) h# 200 * h# 4.0028 + fzc-dmc! ;
: tx-log-page-relo2-i!  ( data i -- ) h# 200 * h# 4.0030 + fzc-dmc! ;
: tx-log-page-hdl-i!    ( data i -- ) h# 200 * h# 4.0038 + fzc-dmc! ;
: tx-addr-md!           ( data -- )            h# 4.5000   fzc-dmc! ; 
: tdmc-inj-par-err!     ( data -- )            h# 4.5040   fzc-dmc! ;
: tdmc-dbg-sel!         ( data -- )            h# 4.5080   fzc-dmc! ;
: tdmc-training-vector! ( data -- )            h# 4.5088   fzc-dmc! ;


\ ----------------- Rx -------------------------
: rxdma-cfig1-i@ ( i -- data ) h# 200 * 0 + dmc@ ;
: rxdma-cfig1-i! ( data i -- ) h# 200 * 0 + dmc! ;
1 d# 31 lshift constant rxdma-en 
1 d# 30 lshift constant rxdma-rst
1 d# 29 lshift constant rxdma-qst

: rxdma-cfig2-i! ( data i -- ) h# 200 * 8 + dmc! ;
0 constant offset=0 
4 constant offset=128 
2 constant offset=64 
1 constant full-hdr 

: rbr-cfig-a-i!	 ( data i -- ) h# 200 * h# 10 + dmc! ;

: rbr-cfig-b-i!	 ( data i -- ) h# 200 * h# 18 + dmc! ;
0 d# 24 lshift constant bksize=4k
1 d# 24 lshift constant bksize=8k
2 d# 24 lshift constant bksize=16k
3 d# 24 lshift constant bksize=32k
1 d# 23 lshift constant vld2
1 d# 15 lshift constant vld1
1 d#  7 lshift constant vld0
0 d# 16 lshift constant bufsz2=2k
1 d# 16 lshift constant bufsz2=4k
2 d# 16 lshift constant bufsz2=8k
3 d# 16 lshift constant bufsz2=16k
0 d#  8 lshift constant bufsz1=1k
1 d#  8 lshift constant bufsz1=2k
2 d#  8 lshift constant bufsz1=4k
3 d#  8 lshift constant bufsz1=8k
0              constant bufsz0=256
1              constant bufsz0=512
2              constant bufsz0=1k
3              constant bufsz0=2k 

: rbr-kick-i!  ( data i -- ) h# 200 * h# 20 + dmc! ;
: rbr-stat-i@  ( i -- data ) h# 200 * h# 28 + dmc@ ;
: rbr-hdh-i@   ( i -- data ) h# 200 * h# 30 + dmc@ ;
: rbr-hdl-i@   ( i -- data ) h# 200 * h# 38 + dmc@ ;

: rcrcfig-a-i! ( data i -- ) h# 200 * h# 40 + dmc! ;

: rcrcfig-b-i! ( data i -- ) h# 200 * h# 48 + dmc! ;
1 d# 16 lshift constant pthres=1 
1 d# 15 lshift constant entout      \ PRM: MUST ENABLE 
1              constant timeout=1 

: rcrstat-a-i@ ( i -- data ) h# 200 * h# 50 + dmc@ ;
: rcrstat-b-i@ ( i -- data ) h# 200 * h# 58 + dmc@ ;
: rcrstat-c-i@ ( i -- data ) h# 200 * h# 60 + dmc@ ;

: rx-dma-ent-msk-i! ( data i -- ) h# 200 * h# 68 + dmc! ;
h# 3f.7fff constant rx-dma-ent-disable-mask
\ 3F.7FFF is the OR all the following bits
\ bit 21  BR_TIMEOUT \ 0=enable 1=disable
\ bit 20  RSP_CNT_ERR
\ bit 19  BYTE_EN_BUS
\ bit 18  RSP_DAT_ERR
\ bit 17  RCR_ACK_ERR
\ bit 16  DC_FIFO_ERR
\ bit 14  RCRTHRES 
\ bit 13  RCRTObit 
\ bit 12  RCR_SHA_PAR 
\ bit 11  RBR_PRE_PAR
\ bit 10  PORT_DROP_PKT
\ bit  9  WRED_DROP
\ bit  8  RBR_PRE_EMTY
\ bit  7  RCR_SHADOW_FULL
\ bit  6  CONFIG_ERR 
\ bit  5  RCRINCON
\ bit  4  RCRFULL
\ bit  3  RBR_EMPTY
\ bit  2  RBRFULL
\ bit  1  RBRLOGPAGE
\ bit  0  CFIGLOGPAGE

: rx-dma-ctl-stat-i@  ( i -- data ) h# 200 * h# 70 + dmc@ ;
: rx-dma-ctl-stat-i!  ( data i -- ) h# 200 * h# 70 + dmc! ;
1 d# 53 lshift constant rbr-tmout
1 d# 52 lshift constant rsp-cnt-err 
1 d# 51 lshift constant byte-en-bus 
1 d# 50 lshift constant rsp-dat-err 
1 d# 49 lshift constant rcr-ack-err 
1 d# 48 lshift constant dc-fifo-err 
1 d# 47 lshift constant mex         
1 d# 46 lshift constant rcrthres 
1 d# 45 lshift constant rcrto 
1 d# 44 lshift constant rcr-sha-par 
1 d# 43 lshift constant rbr-pre-par 
1 d# 38 lshift constant config-err 
1 d# 37 lshift constant rcrincon 
1 d# 36 lshift constant rcrfull 
1 d# 35 lshift constant rbr-empty   \ write 1 to clear see PRM 
1 d# 34 lshift constant rbrfull 
1 d# 33 lshift constant rbrlogpage 
1 d# 32 lshift constant cfiglogpage 
h# 3f.1877 d# 32 lshift constant rx-dma-fatal-errs-mask \ above errors 
1 d# 16 lshift constant ptrread=1
1              constant pktread=1

: rcr-flsh-i@  ( i -- data ) h# 200 * h# 78 + dmc@ ;
: rcr-flsh-i!  ( data i -- ) h# 200 * h# 78 + dmc! ;

: rxmisc-i@    ( i -- data ) h# 200 * h# 90 + dmc@ ;
: rxmisc-i!    ( data i -- ) h# 200 * h# 90 + dmc! ;

\ ----------------- FZC_DMC ------------------
: rx-dma-ck-div!    ( data -- ) h#  0 fzc-dmc! ;
: def-pt0-rdc!      ( data -- ) h#  8 fzc-dmc! ;
: def-pt1-rdc!      ( data -- ) h# 10 fzc-dmc! ; 
: def-pt2-rdc!      ( data -- ) h# 18 fzc-dmc! ;
: def-pt3-rdc!      ( data -- ) h# 20 fzc-dmc! ;
: pt-drr-wt0!       ( data -- ) h# 28 fzc-dmc! ;
: pt-drr-wt1!       ( data -- ) h# 30 fzc-dmc! ;
: pt-drr-wt2!       ( data -- ) h# 38 fzc-dmc! ;
: pt-drr-wt3!       ( data -- ) h# 40 fzc-dmc! ;
: red-ran-init!     ( data -- ) h# 68 fzc-dmc! ;
1 d# 16 lshift constant opmode=1   \ Set to 1 to enable WRED 

: rx-addr-md!       ( data -- ) h# 70 fzc-dmc! ;
: rdmc-pre-par-err@ ( -- data ) h# 78 fzc-dmc@ ;
: rdmc-pre-par-err! ( data -- )	h# 78 fzc-dmc! ;
1 d# 15 lshift constant pre-par-err
1 d# 14 lshift constant pre-par-merr
h# c000        constant rdmc-pre-par-errs-mask   \ above 2 errors

: rdmc-sha-par-err@ ( -- data ) h# 80 fzc-dmc@ ;
: rdmc-sha-par-err! ( data -- ) h# 80 fzc-dmc! ;
1 d# 15 lshift constant sha-par-err
1 d# 14 lshift constant sha-par-merr
h# c000        constant rdmc-sha-par-errs-mask   \ above 2 errors

: rx-ctl-dat-fifo-stat@ ( -- data ) h# b8 fzc-dmc@ ;
: rx-ctl-dat-fifo-stat! ( data -- ) h# b8 fzc-dmc! ;
1     8 lshift constant id-mismatch
h# f  4 lshift constant zcp-eop-err
h# f           constant ipp-eop-err
id-mismatch zcp-eop-err or ipp-eop-err or constant rx-ctl-dat-fifo-errs-mask

: rdc-tbl-i! ( data i -- ) h#  8 * h# 1.0000 +  fzc-zcp! ; 

: rx-log-page-vld-i!   ( data i -- ) h# 40 * h# 2.0000 + fzc-dmc! ;
: rx-log-mask1-i!      ( data i -- ) h# 40 * h# 2.0008 + fzc-dmc! ; 
: rx-log-val1-i!       ( data i -- ) h# 40 * h# 2.0010 + fzc-dmc! ; 
: rx-log-mask2-i!      ( data i -- ) h# 40 * h# 2.0018 + fzc-dmc! ;
: rx-log-val2-i!       ( data i -- ) h# 40 * h# 2.0020 + fzc-dmc! ;
: rx-log-page-relo1-i! ( data i -- ) h# 40 * h# 2.0028 + fzc-dmc! ; 
: rx-log-page-relo2-i! ( data i -- ) h# 40 * h# 2.0030 + fzc-dmc! ; 
: rx-log-page-hdl-i!   ( data i -- ) h# 40 * h# 2.0038 + fzc-dmc! ; 
1 constant page0
2 constant page1

: rdc-red-para-i!      ( data i -- ) h# 40 * h# 3.0000 + fzc-dmc! ; 
d# 20 constant shift-thre-syn
d# 16 constant shift-win-syn
    4 constant shift-thre
    0 constant shift-win

: red-dis-cnt-i@ ( i -- data ) h# 40 * h# 3.0008 + fzc-dmc@ ;
: red-dis-cnt-i! ( data i -- ) h# 40 * h# 3.0008 + fzc-dmc! ;

\ ----------------- XMAC ------------------
\ These offset are for 64 bit mode
: xtxmac-sw-rst!   ( data -- )  h#  0 xmac! ;
: xtxmac-sw-rst@   ( -- data )  h#  0 xmac@ ;
2 constant xtxmac-reg-rst 
1 constant xtxmac-soft-rst

: xrxmac-sw-rst!   ( data -- )  h#  8 xmac! ;
: xrxmac-sw-rst@   ( -- data )  h#  8 xmac@ ;   
2 constant xrxmac-reg-rst 
1 constant xrxmac-soft-rst

: xtxmac-status!   ( data -- )  h# 20 xmac! ;   
: xtxmac-status@   ( -- data )  h# 20 xmac@ ;   
1 1 lshift constant underflow
1 2 lshift constant opp-max-pkt-err
1 3 lshift constant overflow
underflow opp-max-pkt-err or overflow or 
constant xmac-tx-degrade-errs

: xrxmac-status!   ( data -- )  h# 28 xmac! ;   
: xrxmac-status@   ( -- data )  h# 28 xmac@ ;   
2 constant rx-oflow

: xmac-ctrl-stat!  ( data -- )  h# 30 xmac! ;   
: xmac-ctrl-stat@  ( -- data )  h# 30 xmac@ ;   

: xtxmac-stat-msk! ( data -- )  h# 40 xmac! ;   
: xtxmac-stat-msk@ ( -- data )  h# 40 xmac@ ;   

: xrxmac-stat-msk! ( data -- )  h# 48 xmac! ;   
: xrxmac-stat-msk@ ( -- data )  h# 48 xmac@ ;   

: xmac-c-s-msk!    ( data -- )  h# 50 xmac! ;   
: xmac-c-s-msk@    ( -- data )  h# 50 xmac@ ;   

\ TxMac Configuration Registers
: xmac-config!     ( data -- )  h# 60 xmac! ;   
: xmac-config@     ( -- data )  h# 60 xmac@ ;   
          1  constant  tx-enable         
          2  constant  stretch-mode     
          4  constant  var-min-ipg-en  
          8  constant  always-no-crc  
h#       80  constant  warning-msg-en 
h#      100  constant  rxmac-en
h#      200  constant  promis 
h#      400  constant  promis-group  
h#      800  constant  err-chk-disable
h#     1000  constant  rx-crc-chk-dis  
h#     2000  constant  reserve-multcast
h#     4000  constant  rx-code-vio-chk-dis
h#     8000  constant  hash-flt-en
h#    10000  constant  addr-flt-en
h#    20000  constant  strip-crc
h#    40000  constant  mac2ipp-pkt-cnt-en
h#    80000  constant  rec-pause-en
h#   100000  constant  pass-flow-ctrl-frames
h#   200000  constant  xmac-force-led
h#   400000  constant  xmac-led-polarity
h#   800000  constant  sel-por-clk-src 

\ MacXif Configuration
h#  1000000  constant  xmac-tx-output-en
h#  2000000  constant  loopback
h#  4000000  constant  lfs-disable
h# 18000000  constant  mii-gmii-mode-mask \ bits28:27 00=xgmii 01=gmii 10=mii
          0  constant  mii-gmii-mode=xgmii 
h#  8000000  constant  mii-gmii-mode=gmii
h# 10000000  constant  mii-gmii-mode=mii
h# 18000000  constant  mii-gmii-mode=illegal
h# 20000000  constant  xpcs-bypass
h# 40000000  constant  1g-pcs-bypass
h# 80000000  constant  sel-clk-25mhz 

: xmac-ipg!         ( data -- )  h#  80 xmac! ;  
: xmac-min!         ( data -- )  h#  88 xmac! ;   
: xmac-max!         ( data -- )  h#  90 xmac! ;   
: xmac-addr0!       ( data -- )  h#  a0 xmac! ;   
: xmac-addr1!       ( data -- )  h#  a8 xmac! ;   
: xmac-addr2!       ( data -- )  h#  b0 xmac! ;   
: rxmac-bt-cnt@     ( -- data )  h# 100 xmac@ ;
: rxmac-bt-cnt!     ( data -- )  h# 100 xmac! ;
: rxmac-bt-frm-cnt@ ( -- data )  h# 108 xmac@ ;
: rxmac-bt-frm-cnt! ( data -- )  h# 108 xmac! ;
: rxmac-mc-frm-cnt@ ( -- data )  h# 110 xmac@ ;
: rxmac-mc-frm-cnt! ( data -- )  h# 110 xmac! ;
: rxmac-frag-cnt@   ( -- data )  h# 108 xmac@ ;
: rxmac-frag-cnt!   ( data -- )  h# 108 xmac! ;
: rxmac-hist-cnt1@  ( -- data )  h# 120 xmac@ ;
: rxmac-hist-cnt1!  ( data -- )  h# 120 xmac! ;
: rxmac-hist-cnt2@  ( -- data )  h# 128 xmac@ ;
: rxmac-hist-cnt2!  ( data -- )  h# 128 xmac! ;
: rxmac-hist-cnt3@  ( -- data )  h# 130 xmac@ ;
: rxmac-hist-cnt3!  ( data -- )  h# 130 xmac! ;
: rxmac-hist-cnt4@  ( -- data )  h# 138 xmac@ ;
: rxmac-hist-cnt4!  ( data -- )  h# 138 xmac! ;
: rxmac-hist-cnt5@  ( -- data )  h# 140 xmac@ ;
: rxmac-hist-cnt5!  ( data -- )  h# 140 xmac! ;
: rxmac-hist-cnt6@  ( -- data )  h# 148 xmac@ ;
: rxmac-hist-cnt6!  ( data -- )  h# 148 xmac! ;
: rxmac-mpszer-cnt! ( data -- )  h# 150 xmac! ;
: rxmac-crc-er-cnt! ( data -- )  h# 158 xmac! ;
: mac-cd-vio-cnt!   ( data -- )  h# 160 xmac! ;
: rxmac-al-er-cnt!  ( data -- )  h# 168 xmac! ;
: txmac-frm-cnt@    ( -- data )  h# 170 xmac@ ;
: txmac-frm-cnt!    ( data -- )  h# 170 xmac! ;
: txmac-byte-cnt@   ( -- data )  h# 178 xmac@ ;
: txmac-byte-cnt!   ( data -- )  h# 178 xmac! ;
: link-fault-cnt@   ( -- data )  h# 180 xmac@ ;
: link-fault-cnt!   ( data -- )  h# 180 xmac! ;
: rxmac-hist-cnt7@  ( -- data )  h# 188 xmac@ ;
: rxmac-hist-cnt7!  ( data -- )  h# 188 xmac! ;
: xmac-addr-cmpen!  ( data -- )  h# 208 xmac! ;   
: xmac-addr-i!      ( data idx -- ) /x * h# 218 + xmac! ;   
: xmac-add-filt-i!  ( data idx -- ) /x * h# 818 + xmac! ;
: xmac-add-filt12-mask! ( data -- ) h# 830 xmac! ;
: xmac-add-filt00-mask! ( data -- ) h# 838 xmac! ;
: xmac-hash-tbl-i!  ( data idx -- ) /x * h# 840 + xmac! ;
: xmac-host-infox! ( data x -- ) /x * h# 900 + xmac! ;

\ ---------------------- PIO ---------------------------
: fzc-pio@  ( offset -- data )  fzc-pio + rx@ ;
: fzc-pio!  ( data offset -- )  fzc-pio + rx! ;

: pio-ldsv@ ( offset -- data )  pio-ldsv + rx@ ;
: pio-ldsv! ( data offset -- )  pio-ldsv + rx! ;

\ Logical Device Group Number
: ldg-num-i! ( data i -- ) d# 8 * h# 20000 + fzc-pio! ;

\ Logical Device Group Interrupt Management
: ldgimgn-i@ ( i -- data ) d# 8192 * h# 18 + pio-ldsv@ ;
: ldgimgn-i! ( data i -- ) d# 8192 * h# 18 + pio-ldsv! ;
1 d# 31 lshift constant arm
    0 constant ldg0    \ Logic Device Group0
d# 63 constant ldg63   \ LDG for device errors.

\ ---------------------- XPCS ----------------
: xpcs-control1@ ( -- data ) 0 xpcs@ ;
: xpcs-control1! ( data -- ) 0 xpcs! ;
h# 8000 constant sw-reset
h# 4000 constant csr-loopback

: xpcs-status1@  ( -- data ) 8 xpcs@ ;
: xpcs-status1!  ( data -- ) 8 xpcs! ;

: xpcs-cfg-vendor1@   ( -- data )  h# 50 xpcs@ ;
: xpcs-cfg-vendor1!   ( data -- )  h# 50 xpcs! ;
1 constant xpcs-en
2 constant tx-buf-en

: xpcs-packet-counter@ ( -- data ) h# 68 xpcs@ ;

\ ----------------------- TXC ---------------------------------------------
: fzc-txc@ ( offset -- data )  fzc-txc + rx@ ;
: fzc-txc! ( data offset -- )  fzc-txc + rx! ;

: txc-dma-max-i! ( data chan -- ) h# 1000 * 0 + fzc-txc! ;

: txc-control! ( data -- ) h# 2.0000 fzc-txc! ;
h# 10 constant txc-enabled 

: txc-port-dma-p! ( data port -- ) h# 100 * h# 2.0028 + fzc-txc! ;

: txc-dma-max-len-i@ ( chan -- data ) h# 1000 * 8 + fzc-txc@ ;

: txc-debug!       ( data -- )    h# 2.0010 fzc-txc! ;
: txc-port-ctl-p!  ( data p -- )  h# 100 * h# 2.0020 + fzc-txc! ;

: txc-pkt-xmit-p@  ( p -- data )  h# 100 * h# 2.0038 + fzc-txc@ ;


\ ------------------ Classification ---------------------
: fzc-fflp@ ( offset -- data )  fzc-fflp + rx@ ;
: fzc-fflp! ( data offset -- )  fzc-fflp + rx! ;

: enet-vlan-tbl-i! ( data i -- ) 8 * fzc-fflp! ;

: tcam-key-0!        ( data -- ) h# 2.0090 fzc-fflp! ;

: tcam-key-mask-0!   ( data -- ) h# 2.00b0 fzc-fflp! ;


: tcam-ctl@    ( -- data ) h# 2.00d0 fzc-fflp@ ;
: tcam-ctl!    ( data -- ) h# 2.00d0 fzc-fflp! ;
0 d# 18 lshift constant  rwc-write
1 d# 18 lshift constant  rwc-read
2 d# 18 lshift constant  rwc-compare
0 d# 17 lshift constant  stat-start \ PRM Table19-17: "When 0 is
1 d# 17 lshift constant  stat-done  \ written to STAT, SW will init
                                    \ the (read/write) action, and
                                    \ will be set to 1 when the
                                    \ operation completes

: fflp-cfg-1@ ( -- data ) h# 2.0100 fzc-fflp@ ;

: fflp-cfg-1! ( data -- ) h# 2.0100 fzc-fflp! ;
1 d# 26 lshift constant  tcam-dis
4 d# 16 lshift constant  camlat=4
4              constant  err-dis
1              constant  llc-snap


\ ---------------- IPP ----------------------
: ipp-cfig-p@ ( p -- data ) ipp-step fzc-ipp@ ;
: ipp-cfig-p! ( data p -- ) ipp-step fzc-ipp! ;
1    d# 31 lshift constant soft-rst
h# 1ffff 8 lshift constant ipp-max-pkt-default
1        0 lshift constant ipp-enable

: ipp-pkt-dis-p@    ( p -- data ) ipp-step h# 20 + fzc-ipp@ ;
: ipp-pkt-dis-p!    ( data p -- ) ipp-step h# 20 + fzc-ipp! ;
: ipp-bad-cs-cnt-p@ ( p -- data ) ipp-step h# 28 + fzc-ipp@ ;
: ipp-bad-cs-cnt-p! ( data p -- ) ipp-step h# 28 + fzc-ipp! ;
: ipp-ecc-p@        ( p -- data ) ipp-step h# 30 + fzc-ipp@ ;
: ipp-ecc-p!        ( data p -- ) ipp-step h# 30 + fzc-ipp! ;
: ipp-int-stat-p@   ( p -- data ) ipp-step h# 40 + fzc-ipp@ ;
: ipp-int-stat-p!   ( data p -- ) ipp-step h# 40 + fzc-ipp! ;
1 d# 31 lshift constant sop-miss
1 d# 30 lshift constant eop-miss
1     2 lshift constant pfifo-und
sop-miss eop-miss or pfifo-und or constant ipp-int-stat-errs-mask

: ipp-msk-p!        ( data p -- ) ipp-step h# 48 + fzc-ipp! ;
h# ff  constant ipp-intr-msk
\ Value h# FF disable following interrupt conditions,
\ ECC_ERR_MX, DFIFO_EOP_SOP, DFIFO_UC, PFIFO_PAR, PFIFO_OVER, PFIFO_UND,
\ BAD_CS and PKT_DIS_CNT

: ipp-dfifo-rd-ptr-p@  ( p -- data ) ipp-step h# 110 + fzc-ipp@ ;
: ipp-dfifo-rd-ptr-p!  ( data p -- ) ipp-step h# 110 + fzc-ipp! ;

: ipp-dfifo-wr-ptr-p@  ( p -- data ) ipp-step h# 118 + fzc-ipp@ ;
: ipp-dfifo-wr-ptr-p!  ( data p -- ) ipp-step h# 118 + fzc-ipp! ;

\ FFLP Checksum info Register
: fflp-chksum-info@ ( p -- data ) ipp-step h# 130 + fzc-ipp@ ;
: fflp-chksum-info! ( data p -- ) ipp-step h# 130 + fzc-ipp! ;

\ IPP Ecc Control Register
: ipp-ecc-ctrl@     ( -- data ) h# 150 fzc-ipp@ ;
: ipp-ecc-ctrl!     ( data -- ) h# 150 fzc-ipp! ;


\ SPC (Serial PROM Controller)
\ 128 Registers for accessing 512 bytes of serial EEPROM
: spc-ncr-i@ ( i -- data ) 8 * h# 4.0020 + fzc-prom@ ;

\ -------------------------- MIF -----------------------------
defer phy@   \ clause22-read
defer phy!   \ clause22-write

\ Clause45 MIF Frame/Output Register
: mif-frame-output-reg@ ( -- data ) h# 18 mif@ ;
: mif-frame-output-reg! ( data -- ) h# 18 mif! ;
