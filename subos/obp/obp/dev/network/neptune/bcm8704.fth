\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bcm8704.fth
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
id: @(#)bcm8704.fth 1.1 07/01/23
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved.
copyright: Use is subject to license terms.

headerless

\ BCM8704 is a Broadcom optical transceiver.  It interfaces with the
\ Neptune via a XAUI provided by the LSI Logic serdes.

\ Registers and Bits Definitions
      0 constant phyxs-ctrl-reg	
      1 constant phyxs-contorl-rst
h#    a constant receive-sig-detect
      1 constant glob-pmd-rx-sig-ok
h#   20 constant 10gbase-r-pcs-status-reg
      1 constant pcs-10gbase-r-pcs-blk-lock
h#   18 constant phyxs-xgxs-lane-status-reg
h# 1000 constant xgxs-lane-align-status
h# c800 constant user-ctrl-reg
h# c803 constant user-pmd-tx-ctrl-reg
h# 80c6 constant user-rx2-ctrl1-reg		
h# 80d6 constant user-rx1-ctrl1-reg
h# 80e6 constant user-rx0-ctrl1-reg
      8 constant bcm5464-neptune-port-addr-base
      8 constant neptune-port-addr-base
d#   16 constant n2-port-addr-base
      1 constant pma-pmd-dev-addr
      3 constant pcs-dev-addr
      3 constant user-dev3-addr
      4 constant phyxs-addr
      4 constant user-dev4-addr

: prtad ( -- x' ) 
   niu? if
      n2-port-addr-base
   else
      neptune-port-addr-base
   then
   port +
;

\
\ The bits of register MIF_FRAME_OUTPUT_REG is as follows,
\ RSVD              63:32
\ frame_msb         31:16  16 MS bits of an MDIO frame
\ frame_lsb_output  15:0   16 LS bits of an MDIO frame

\ IEEE 802.3 Clause45 MDIO Frame Reg Fields
\   ST:    Start of Frame, ST=00 for Clause45, ST=01 for Clause22
\   OP:    Operation Code, 
\   PRTAD: Port Addr
\   DEVAD: Device Addr
\   TA:    Turnaround(time) 
\
\ Frame     ST     OP      PRTAD   DEVAD    TA    ADDRESS/DATA
\        [31:30] [29:28]  [27:23] [22:18] [17:16]    [15:0]
\ Address   00     00      PPPPP   EEEEE    10    aaaaaaaaaaaaaaaa
\ Write     00     01      PPPPP   EEEEE    10    dddddddddddddddd
\ Read      00     11      PPPPP   EEEEE    Z0    dddddddddddddddd
\ Post-read 00     10      PPPPP   EEEEE    Z0    dddddddddddddddd
\
\ PRTAD is a hardware implementation detail
\ Various bcm8704 registers have different DEVAD.  Registers 
\ with addresses 0xC800 and C803 belong to DEVAD=3, the other
\ registers belong to DEVAD=4.  
\
\ So for the registers with address offset C80x, we have,
\                  ST  OP  PRTAD  DEVAD TA
\  P0 Addr  C80x:  00  00  01000  00011 10 = 040E.AAAA
\  P0 WR to C80x:  00  01  01000  00011 10 = 140E.DDDD
\  P0 RD    C80x:  00  11  01000  00011 10 = 340E.XXXX
\  P1 Addr  C80x:  00  00  01001  00011 10 = 048E.AAAA
\  P1 WR to C80x:  00  01  01001  00011 10 = 148E.DDDD
\  P1 Rd    C80x:  00  11  01001  00011 10 = 348E.XXXX
\
\ And for the register with address offset 80x6, we have,
\                  ST  OP  PRTAD  DEVAD TA
\  P1 Addr  80x6:  00  00  01001  00100 10 = 0492.AAAA
\  P1 WR to 80x6:  00  01  01001  00100 10 = 1492.DDDD
\  P1 Rd    80x6:  00  11  01001  00100 10 = 3492.XXXX
\ AAAA = 16bits addr, DDDD = 16bits data, XXXX=don't care
\


\ Check the following 3 bits to see if 10G link is up or down
\  Device 1 Register  0xA bit0
\  Device 3 Register 0x20 bit0
\  Device 4 Register 0x18 bit12
\
: check-3-link-status-bits ( -- link-up? )
   prtad pma-pmd-dev-addr receive-sig-detect clause45-read              
   glob-pmd-rx-sig-ok and 0<>		( rx-sig ) 

   prtad pcs-dev-addr 10gbase-r-pcs-status-reg clause45-read              
   pcs-10gbase-r-pcs-blk-lock and 0<>	( rx-sig pcs-blk-lock )

   prtad phyxs-addr phyxs-xgxs-lane-status-reg clause45-read              
   xgxs-lane-align-status and 0<>	( rx-sig-ok? pcs-blk-lock link-aligned )
 
   mac-mode case			( rx-sig-ok? pcs-blk-lock link-aligned )

      xmac-loopback of
         \ Only care about link-aligned? in this case
         nip nip			( flag )
      endof

      xpcs-loopback of 
         \ Ignore rx-sig-ok? and pcs-blk-lock?
         nip nip			( flag )
      endof

      serdes-ewrap-loopback of 
         \ In serdes-ewrap-loopback mode, link-aligned? is false.
         \ Ignore it so loopback will not fail for a wrong reason
         drop and			( flag )
      endof

      \ link is up only if all 3 flag bits are set
      \ link=up? = rx-sig-ok? && pcs-blk-lock? && link-align. 
      and and				( flag )

   endcase
   0<>
;

: 10g-fiber-link-up?  ( -- up? )
    d# 3000 ['] check-3-link-status-bits wait-status
;

: wait-phyxs-ctrl-rst  ( -- flag )
   prtad phyxs-addr phyxs-ctrl-reg clause45-read 
   phyxs-contorl-rst and 0=  \ reset cleared if done
;

: wait-for-transceiver-rst  ( -- ok? )
   d# 500 ['] wait-phyxs-ctrl-rst wait-status
;

: setup-bcm8704-xcvr  ( -- ok? )
   \ Reset the transceiver
   prtad phyxs-addr phyxs-ctrl-reg clause45-read 
   phyxs-contorl-rst or
   phyxs-ctrl-reg prtad phyxs-addr clause45-write 
   wait-for-transceiver-rst 0= if
      cmn-note[ " broadcom8704 reset timeout." ]cmn-end
      false exit
   then
   0 to link-is-up?      \ Clear the flag after reset

   \ Write 0x7fbf is required by Broadcom
   h# 7fbf user-ctrl-reg prtad user-dev3-addr clause45-write 
 
   \ Set to 0x164
   h# 164 user-pmd-tx-ctrl-reg prtad user-dev3-addr clause45-write
   
   \ According to Broadcom's instruction, SW needs to read
   \ back these registers twice after writing.
   prtad user-dev3-addr 2dup		( addr1 addr2 addr1 addr2 )
   user-ctrl-reg			( addr1 addr2 addr1 addr2 addr3 )
   3dup clause45-read drop 		( addr1 addr2 addr1 addr2 addr3 )
   clause45-read drop			( addr1 addr2 )
   user-pmd-tx-ctrl-reg			( addr1 addr2 addr4 )
   3dup clause45-read drop		( addr1 addr2 addr4 )
   clause45-read drop			(  )

   10g-fiber-link-up?  \ Poll for 3 seconds

   dup 0= if cmn-note[ " link-up check failed" ]cmn-end then
;
