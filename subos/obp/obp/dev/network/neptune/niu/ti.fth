\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ti.fth
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
id: @(#)ti.fth 1.1 07/01/23
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

\ See PRM1.0 Section 23.6 for the recommended TI serdes 
\ initialization sequence.
\
\ The bits of register MIF_FRAME_OUTPUT_REG is as follows,
\ RSVD              63:32
\ frame_msb         31:16  16 MS bits of an MDIO frame (see below)
\ frame_lsb_output  15:0   16 LS bits of an MDIO frame (see below)
\ IEEE 802.3 Clause45 MDIO Frame Reg Fields
\   ST:    Start of Frame, ST=00 for Clause45, ST=01 for Clause22
\   OP:    Operation Code,
\   PRTAD: Port Addr
\   DEVAD: Device Addr
\   TA:    Turnaround(time)

\ Frame     ST     OP      PRTAD   DEVAD   TA     ADDRESS/DATA
\        [31:30] [29:28] [27:23] [22:18] [17:16] [15:0]
\ Address   00     00      PPPPP  EEEEE    10   aaaaaaaaaaaaaaaa 
\ Write     00     01      PPPPP  EEEEE    10   dddddddddddddddd 
\ Read      00     11      PPPPP  EEEEE    Z0   dddddddddddddddd 
\ Post-read 00     10      PPPPP  EEEEE    Z0   dddddddddddddddd 
\
\ According to PRM Rev1.2 Section  22.7.0.15 The two TI serdes
\ use the following parameters 
\                      PRTAD    DEVAD   Address Offset
\    HedWig Serdes 0   5'h00    5h'1E     16'h800016'
\    HedWig Serdes 1   5'h01    5h'1E     16'h800016'
\ So
\  Addr-P0  00     00      00000  11110    10 = 007a.AAAA
\  Addr-P1  00     00      00001  11110    10 = 00Fa.AAAA
\ Write-P0  00     01      00000  11110    10 = 107a.DDDD
\ Write-P1  00     01      00001  11110    10 = 10Fa.DDDD
\  Read-P0  00     11      00000  11110    10 = 307a.DDDD
\  Read-P1  00     11      00001  11110    10 = 30Fa.DDDD
\
\ For example,   
\ 007a.8000 below = 00 00 00000 11110 10 1000000000000000
\ means ST=0, OP=0 (addressing), PRTAD=0, DEVAD=11110=0x1E, 
\ TA=10, ADDR_BASE=0x8000.  
\       
\ TI Serdes Register Map in the PRM is as follows,
\ 0x000                   ESR_TI_PLL_CFG_L_REG
\ 0x001                   ESR_TI_PLL_CFG_H_REG
\ 0x002                   ESR_TI_PLL_STS_L_REG
\ 0x003                   ESR_TI_PLL_STS_H_REG
\ 0x004                   ESR_TI_TEST_CFG_L_REG
\ 0x005                   ESR_TI_TEST_CFG_H_REG
\ 0x100 + (chan x 4)      ESR_TI_TX_CFG_L_REG_ADDR (chan 0~7)
\ 0x100 + (chan x 4) + 1  ESR_TI_TX_CFG_H_REG_ADDR (chan 0~7)
\ 0x100 + (chan x 4) + 2  ESR_TI_TX_STS_L_REG_ADDR (chan 0~7)
\ 0x100 + (chan x 4) + 3  ESR_TI_TX_STS_H_REG_ADDR (chan 0~7)
\ 0x120 + (chan x 4)      ESR_TI_RX_CFG_L_REG_ADDR (chan 0~7)
\ 0x120 + (chan x 4) + 1  ESR_TI_RX_CFG_H_REG_ADDR (chan 0~7)
\ 0x120 + (chan x 4) + 2  ESR_TI_RX_STS_L_REG_ADDR (chan 0~7)
\ 0x120 + (chan x 4) + 3  ESR_TI_RX_STS_H_REG_ADDR (chan 0~7)
\ So ADDR=0x8000 in 007a.8000 means selecting ESR_TI_PLL_CFG_L_REG
\

h# 1e constant devad=ti  \ Dev Addr of Texax Instrument Serdes

: init-internal-serdes   ( -- )     
   \ N2 port0 uses TI HedWig0 (serdes0) channel 0,1,2,3
   \ ESR_TI_PLL_CFG_L_REG.  Enable PLL, Set PLL multiple=0001b
   port devad=ti
   h# 9f01 h# 8100 2over clause45-write \ ESR_TI_TX_CFG_L_REG, chan=0
         0 h# 8101 2over clause45-write \ ESR_TI_TX_CFG_H_REG, chan=0
   h# 9f01 h# 8104 2over clause45-write \ ESR_TI_TX_CFG_L_REG, chan=1
         0 h# 8105 2over clause45-write \ ESR_TI_TX_CFG_H_REG, chan=1
   h# 9f01 h# 8108 2over clause45-write \ ESR_TI_TX_CFG_L_REG, chan=2
         0 h# 8109 2over clause45-write \ ESR_TI_TX_CFG_H_REG, chan=2
   h# 9f01 h# 810c 2over clause45-write \ ESR_TI_TX_CFG_L_REG, chan=3
         0 h# 810d 2over clause45-write \ ESR_TI_TX_CFG_H_REG, chan=3
   h# 9101 h# 8120 2over clause45-write \ ESR_TI_RX_CFG_L_REG, chan=0
         8 h# 8121 2over clause45-write \ ESR_TI_RX_CFG_H_REG, chan=0
   h# 9101 h# 8124 2over clause45-write \ ESR_TI_RX_CFG_L_REG, chan=1
         8 h# 8125 2over clause45-write \ ESR_TI_RX_CFG_H_REG, chan=1
   h# 9101 h# 8128 2over clause45-write \ ESR_TI_RX_CFG_L_REG, chan=2
         8 h# 8129 2over clause45-write \ ESR_TI_RX_CFG_H_REG, chan=2
   h# 9101 h# 812c 2over clause45-write \ ESR_TI_RX_CFG_L_REG, chan=3
         8 h# 812d 2over clause45-write \ ESR_TI_RX_CFG_H_REG, chan=3
   h#    b h# 8000 2swap clause45-write
;

headerless
