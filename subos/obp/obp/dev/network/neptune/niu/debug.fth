\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: debug.fth
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
id: @(#)debug.fth 1.1 07/01/23
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

external

: .addrs ( -- )
   ." rbuf0: 0x" rbuf0 .h cr
   ." rmd0: 0x" rmd0 .h cr
   ." rcd0: 0x" rcd0 .h cr
   ." tbuf0: 0x" tbuf0 .h cr
   ." tmd0: 0x" tmd0 .h cr
   ." io-rbuf0: 0x" io-rbuf0 .h cr
   ." io-rmd0: 0x" io-rmd0 .h cr
   ." io-rcd0: 0x" io-rcd0 .h cr
   ." io-tbuf0: 0x" io-tbuf0 .h cr
   ." io-tmd0: 0x" io-tmd0 .h cr
;

0 value regcounter

: type-with-leading ( align str,len char -- )
   >r rot over - r>		( str,len leading char )
   swap 0 ?do dup emit loop	( str,len char )
   drop type			(  )
;

: type-with-leading-val ( align val char -- )
   ."  0x" >r (u.) r> type-with-leading
;

: .regline ( addr str,len -- addr ) 
   d# 20 -rot bl type-with-leading	( addr )
   regcounter dup 1+ to regcounter	( addr counter )
   /x * over +	 			( addr addr' )
   d# 16 over >physical drop		( addr addr' align phys )
   ascii 0 type-with-leading-val	( addr addr' )
   x@ d# 16 swap			( addr align val )
   ascii 0 type-with-leading-val	( addr )
   cr
;

: .dmc ( -- )
   0 to regcounter
   map-regs 
   dmc
   " RXDMA_CFIG1" .regline
   " RXDMA_CFIG2" .regline
   " RBR_CFG_A" .regline
   " RBR_CFG_B" .regline
   " RBR_KICK" .regline
   " RBR_STAT" .regline
   " RBR_HDH" .regline
   " RCR_CFG_A" .regline
   " RCR_CFG_B" .regline
   " RCR_STAT_A" .regline
   " RCR_STAT_B" .regline
   " RCR_STAT_C" .regline
   " RX_DMA_ENT_MSK" .regline
   " RX_DMA_CTL_STAT" .regline
   " RCR_FLSH" .regline
   drop 0 to regcounter 
   dmc h# 90 +
   " RX_MISC" .regline
   " RX_DMA_CTL_STAT_DBG" .regline
   drop 0 to regcounter 
   dmc h# 40000 +
   " TX_RNG_CFIG" .regline
   drop 0 to regcounter 
   dmc h# 40010 +
   " TX_RING_HDL" .regline
   " TX_RING_KICK" .regline
   " TX_ENT_MSK" .regline
   " TX_CS" .regline
   drop 0 to regcounter 
   dmc h# 40040 +
   " TX_DMA_PRE_ST" .regline
   " TX_RNG_ERR_LOGH" .regline
   " TX_RNG_ERR_LOGL" .regline
   drop
;

: .fzc_dmc ( -- ) 
   0 to regcounter
   map-regs 
   fzc_dmc h# 20000 +
   " RX_LOG_PAGE_VLD" .regline
   " RX_LOG_MASK1" .regline
   " RX_LOG_VALUE1" .regline
   " RX_LOG_MASK2" .regline
   " RX_LOG_VALUE2" .regline
   " RX_LOG_PAGE_RELO1" .regline
   " RX_LOG_PATE_RELO2" .regline
   drop 0 to regcounter 
   fzc_dmc h# 40000 +
   " TX_LOG_PAGE_VLD" .regline
   " TX_LOG_MASK1" .regline
   " TX_LOG_VALUE1" .regline
   " TX_LOG_MASK2" .regline
   " TX_LOG_VALUE2" .regline
   " TX_LOG_PAGE_RELO1" .regline
   " TX_LOG_PATE_RELO2" .regline
   " TX_LOG_PAGE_HDL" .regline
   0 to regcounter h# 5000 +
   " TX_ADDR_MD" .regline
   drop
;

: show-xmac-config ( -- )
    XMAC_CONFIG@        ( val )
    ." ---------- XMAC_CONFIG -----------" cr
    dup ."     reg val = " u. cr
    dup tx_enable        and if ."     b0 tx-enable"      cr then 
    dup stretch_mode     and if ."     b1 stretch_mode"   cr then
    dup var_min_ipg_en   and if ."     b2 var_min_ipg_en" cr then
    dup always_no_crc    and if ."     b3 always_no_crc"  cr then
    dup warning_msg_en   and if ."     b7 warning_msg_en" cr then 
    dup RxMacEnable      and if ."     b8 RxMacEnable"    cr then 
    dup Promis           and if ."     b9 Promis"         cr then 
    dup PromiscuousGroup and if ."     b10 PromiscuousGroup" cr then
    dup ErrCheckDisable  and if ."     b11 ErrCheckDisable" cr then
    dup rx_crc_chk_dis   and if ."     b12 rx_crc_chk_dis"  cr then
    dup ReserveMultcast  and if ."     b13 ReserveMultcast" cr then
    dup rx_code_violation_chk_dis and if ."     b14 rx_code_violation_chk_dis" cr then
    dup hash_filter_en and if       ."     b15 hash_filter_en" cr then 
    dup addr_filter_en and if       ."     b16 addr_filter_en" cr then
    dup strip_crc      and if       ."     b17 strip_crc"      cr then
    dup mac2ipp_pkt_cnt_en   and if ."     b18 mac2ipp_pkt_cnt_en"   cr then
    dup Receive_Pause_Enable and if ."     b19 Receive_Pause_Enable" cr then
    dup Pass_flow_control_frames and if ."    Pass_flow_control_frames" cr then
    dup force_LED_on_   and if ."     b21 force_LED_on"    cr then
    dup led_polarity_   and if ."     b22 led_polarity"    cr then
    dup sel_por_clk_src and if ."     b23 sel_por_clk_src" cr then
    ."      --- MacXif Configuration ---" cr
    dup tx_output_en    and if ."     b24 tx_output_en" cr then
    dup loopback        and if ."     b25 loopback"     cr then
    dup lfs_disable     and if ."     b26 lfs_disable"  cr then
    dup mii_gmii_mode_mask and 0= if ."     bits28:27 = 00 xgmii mode" cr then
    dup mii_gmii_mode=gmii and if    ."     mii_gmii_mode=gmii" cr then
    dup mii_gmii_mode=mii  and if    ."     mii_gmii_mode=mii" cr then
    dup mii_gmii_mode=gmii and   \ Illegal if both gmii and mii are on
    dup mii_gmii_mode=mii  and and if ."     mii_gmii_mode=illegal" cr then
    dup xpcs_bypass           and if ."     xpcs_bypass" cr then
    dup 1G_pcs_bypass         and if ."     1G_pcs_bypass" cr then
        sel_clk_25mhz         and if ."     sel_clk_25mhz" cr then
    ." ----------------------------------" cr
;

