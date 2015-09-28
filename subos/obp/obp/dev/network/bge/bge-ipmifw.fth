\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bge-ipmifw.fth
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
id: @(#)bge-ipmifw.fth 1.1 06/05/11
purpose: 
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ BCM57xx IPMI/ASF firmware support
\
\ BCM57xx support the ASF and IPMI features through the optional firmware
\ running on the on-chip RISC processors. When enabled, the IPMI/ASF
\ firmware expects the fcode driver to handshake with the firmware of 
\ various driver events like load, unload, reset, and suspend operations
\ of the driver. The fcode driver and the IPMI/ASF Firmware use SW Event
\ (bit 14, SW Event 7) within the RX CPU Event Register (h# 6810) and a 
\ portion of the device internal memory, for communications between the 
\ two entities.
\
\ Following support is needed in the load & unload operations of the
\ fcode driver:
\ 
\ Fcode driver Load operation:
\ o Pause IPMI/ASF firmware and wait for ACK
\ o Write bootcode magic (h# 4B657654) to memory address h# B50
\ o Reset core clocks (exists in current code)
\ o Write Fcode driver state 'Start' (h# 1) to h# C04
\ o Wait for complement of bootcode magic (h# 4B657654) [or timeout]
\ o Continue with MAC initialization
\
\ Fcode driver Unload/Shutdown operation:
\ o Pause IPMI/ASF firmware and wait for ACK
\ o Write bootcode magic (h# 4B657654) to memory address h# B50
\ o Disable state machines (exists in current code)
\ o Reset core clocks (to restart the IPMI/ASF firmware)
\ o Wait for complement of bootcode magic (h# 4B657654) [or timeout]
\ o Write Fcode driver state 'Unload' (h# 2) to h# C04
\

headers

\ BCM57xx bootcode fw mailbox
h# b50      constant bootcode-mbox	\ Bootcode magic addr
h# 4b657654 constant bootcode-magic	\ Magic "KevT" written to h# B50
					\ by bootcode

\ IPMI/ASF firmware status mailbox and states
h# c00      constant ipmifw-status-mbox
1           constant ipmifw-running
2           constant ipmifw-paused

\ Pause command to IPMI/ASF fw
2           constant fcode-pause-fw

\ Fcode driver state mailbox and states
h# c04      constant fcode-state-mbox
1           constant fcode-state-start
2           constant fcode-state-unload

\ Used before actual reset/init code executes
: enable-mem-access ( -- )
   h# c h# 68 my-lset		\ Ensure expected endianness
   6 4  my-w!			\ Enable Memory Space Decode
   2 h# 4000 breg-bset		\ Enable MAC Memory Arbitrator
;

\ Check for BCM57xx bootcode fw magic "KevT"
: valid-bootcode-magic?  ( -- true | false )
   h# b54 nicmem@ bootcode-magic =
;

\ Check if IPMI/ASF fw has been enabled
: ipmifw-enabled?  ( -- true | false )
   valid-bootcode-magic? if
      h# b58 nicmem@ 1 h# 7 << and 0<>     ( true | false )
   else
      false
   then
;

\ Get IPMI/ASF fw state
: ipmifw-state@  ( -- state ) ipmifw-status-mbox nicmem@ ;

\ Display current status of IPMI/ASF fw
: ipmifw-status   ( -- )
   cr ." IPMI/ASF firmware status: "
   ipmifw-enabled? if ." Enabled - " else ." Disabled - " then
   ipmifw-state@ case
      ipmifw-running of ." Running" endof
      ipmifw-paused  of ." Paused"  endof
      ." (state) " dup .d
   endcase cr
;

\ Enable the SW Event 7 - bit[14] - of RX CPU Event register (h# 6810)
\ to notify IPMI/ASF fw about the command sent to it via mailbox
: set-sw-event  ( -- )
   h# 6810 breg@ 1 d# 14 << or    ( bits )
   h# 6810 breg!
;

\ Read the SW Event 7 - bit[14] - from RX CPU Event register (h# 6810)
: get-sw-event  ( -- bit )  h# 6810 breg@ d# 14 >> 1 and ;

\ Write cmd to IPMI/ASF fw mailbox and set the SW event notice
: ipmifw-mbox!  ( cmd -- ) h# b78 nicmem! set-sw-event ;

\ Write the magic value "KevT" to bootcode mailbox
: bootcode-sig! ( -- ) bootcode-magic bootcode-mbox nicmem! ;

\ Wait for complement of bootcode-magic as response
: check-bootcode-compl ( -- )
   d# 100 0 do
      bootcode-mbox nicmem@			( magic )
      bootcode-magic h# ffff.ffff xor = if
         unloop exit
      then
      d# 5 ms
   loop
;

\ Inform IPMI/ASF fw about fcode driver state
: state-sig! ( state -- )
   ipmifw-enabled? if
      fcode-state-mbox nicmem!
   else
      drop
   then
;

\ Send pause cmd to IPMI/ASF fw only when it is in 'running' state. Used
\ during reset, open, close calls.
: pause-ipmifw ( -- )
   ipmifw-state@ ipmifw-running = if
      fcode-pause-fw ipmifw-mbox!	\ send pause cmd
      d# 100 0 do
         get-sw-event 0= if unloop exit then
         d# 5 ms
      loop
   then
;
