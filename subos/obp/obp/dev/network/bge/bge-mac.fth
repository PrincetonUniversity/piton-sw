\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bge-mac.fth
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
id: @(#)bge-mac.fth 1.8 07/05/24
purpose: Initialization of the Mac
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headers

: enable-txmac ( -- )  2 h# 45c breg-bset ;
: enable-rxmac ( -- )  2 h# 468 breg-bset ;

\ Misc Host Control Register Operators
: mhcr@  ( -- data )		h# 68 my-l@ ;
: mhcr!	 ( data -- )		h# 68 my-l! ;
: mhcr-set  ( bits -- )		h# 68 my-lset ;
: mhcr-clear  ( bits -- )	h# 68 my-lclear ;

\ Mac Mode Register Operators
: mac-reg@  ( -- data )	h# 400 breg@ ;
: mac-reg!  ( data -- )	h# 400 breg! ;
: mac-reg-set  ( bits -- )	h# 400 breg-bset ;
: mac-reg-clear  ( bits -- )	h# 400 breg-bclear ;

\ Mac Mode Control Register Operators
: mode-ctrl@  ( -- data )	h# 6800 breg@ ;
: mode-ctrl!  ( data -- )	h# 6800 breg! ;
: mode-ctrl-set  ( bits -- )	h# 6800 breg-bset ;
: mode-ctrl-clear  ( bits -- )	h# 6800 breg-bclear ;

h# c  constant pci-swap
h# 36 constant dma-swap

\ On a chip reset some pci config space gets blown away
: save-pci-regs  ( -- )
   h# c	 my-b@ to pci-$line-size	\ Save PCI Cache Line Size
   2 	 my-w@ to pci-dev-id		\ Save PCI Device ID
\ The version id register at offset 8 in the PCI config space
\ is not actually initialised unless the seeprom is fitted
\ but this information is needed elsewhere for errata
\ application checks, so get the revision id from reg
\ 6a which is equivalent to bits 23:16 of reg 68 Miscellaneous
\ Host Control Register. Also include bits 27:24 so that Ax and
\ Bx steppings can be distinguished.
   h# 6a my-w@ h# fff and to pci-rev-id	\ Save asic revision id.
   h# d	 my-b@ to pci-max-latency
;

: clear-pci-status  ( -- )
   -1		6	my-w!		\ Clear PCI Error Status Reg
;
: pci-e?  ( devce-id -- flag )		\ 5721 currently the only "true" PCI-E
   BCM-5721 =				\ device
;

: bcm5714<reva2? ( -- flag )            \ true for BCM-5714 < A2 revision
   pci-dev-id BCM-5714 =                \ false otherwise
   h# 8 my-b@ h# a2 < and
;

: reset-core-clks  ( -- )
   pci-swap	        mhcr-set	\ Ensure expected endianness	
   6		4	my-w!		\ Enable Memory Space Decode
   3			mhcr-set	\ Disable and Clear Interrupts
   save-pci-regs			\ Save PCI regs cleared on clk reset
   0
   pci-dev-id pci-e? if
      1 d# 29 << or			\ Disable GRC Reset on PCI-E block
   then
   pci-dev-id BCM-5721 = if
      1 d# 26 << or			\ GPHY powerdown override
   then					\ BGE spec is wishy washy for BCM-5714

   1 or					\ reset bit or'd with device specific
					\ value from above
   h# 6804 breg-base + my-rl!		\ Reset Core Clocks (self-clearing)
   100 ms				\ PCI-E requires 100ms
   2			mhcr-set	\ Disable Interrupts
   bcm5714<reva2? if                    \ disable parity bit on BCM-5714 A1
      h# 106
   else
      h# 146
   then
   4	my-w!				\ Enable Memory Space Decode    
   clear-pci-status
   2		h# 42	my-wclear	\ Disable PCI-X Relaxed Ordering
;

: enable-mac-mem  ( -- )
   2		h# 4000	breg-bset	\ Enable MAC Memory Arbitrator
;

: mhcr-config  ( -- )
   h# 4c	mhcr-clear		\ Clear Endian swap bits before setting
   pci-swap	mhcr-set		\ Enable Endian word/byte swap

   enable-mac-mem			\ Enable MAC Memory Arbitrator

   h# 30	mhcr-set		\ Set PCI State to r/w, PCI Clk Control
   h# 102	mhcr-set		\ mask interrupts
   h# 200	mhcr-set		\ Enable tagged status messages
;

: clear-ints  ( -- )			\ Clear interrupts
  0		hpm-im0	breg!		\ clear interrupts
;

: disable-pxe  ( -- error? )
   \ General Communication Memory
   h# 4b657654 dup h# ffff.ffff xor >r	 \ magic disable number
   h# b50 nicmem!
   get-msecs begin			\ wait 750ms or until we see compliment
     h# b50 nicmem@ r@ = if
        r> 2drop 0 exit
      then
      get-msecs over - d# 750 >
   until
   r> 2drop -1
;

: restore-pci-regs  ( -- )
   pci-$line-size   h# c  my-b!
   pci-max-latency  h# d  my-b!
;

: clear-nic-mac-statistics
   h# b00 h# 300 do  0 i nicmem! 4  +loop	\ Clear Mac Stats Block 
;

: clear-host-mac-status  ( -- )
   cpu-dma-base >dma-status-blk /status-blk erase
;

: mode-ctrl-config  ( -- )
   h# 36	mode-ctrl-clear		\ Clear endian-swap bits before setting
   dma-swap	mode-ctrl-set		\ Enable DMA byte swapping
   h# 2.0000	mode-ctrl-set		\ Enable Host Based Send Rings
   h# 1.0000	mode-ctrl-set		\ Host Stack up (driver ready for rx?)
   h# 90.0000	mode-ctrl-set		\ Disable Psuedo Checksums
;

: nicmem-config  ( -- )
   \ All Default values taken directly from the PRM
   pci-dev-id BCM-5721 <> if		\ use default value for 5721
      h# 8000	h# 4408 breg!		\ Mbuf Pool Base Address (no sram)
   then
   h# 2000	h# 442c breg!		\ DMA Descriptor Pool Base Address
   h# 2000	h# 4430	breg!		\ DMA Descriptor Pool Len
   d# 40	h# 4410 breg!		\ Read DMA Mbuf Low Watermark
   pci-dev-id BCM-5704 = if
      d# 40	h# 4414 breg!		\ Mac Rx Mbuf Low Watermark
      h# 10000	h# 440c breg!		\ Mbuf Pool Len
   else
      d# 20	h# 4414 breg!		\ Mac Rx Mbuf Low Watermark
      pci-dev-id BCM-5721 <> if		\ use default value for 5721
         h# 18000	h# 440c breg!	\ Mbuf Pool Len
      then
   then
   d# 60	h# 4418	breg!		\ Mbuf High Watermark
   5		h# 4434 breg!		\ DMA Descriptor Low Watermark
   d# 10	h# 4438 breg!		\ DMA Descriptor High Watermark
;

: enable-buffer-manager  ( -- enabled? )
   6		h# 4400	breg-bset	\ Enable Buffer Manager
   get-msecs				\ begin poll for enabled (10ms)
   begin
      dup				( msecs msecs )
      h# 4400 breg@ 2 and		( msecs msecs enabled? )
      get-msecs rot - d# 20 >		\ get-msecs has 10ms grain. so wait 20
      or 0<>				( msecs enabled-or-timeup )
   until				\ !(enabled or timeup)
   drop h# 4400 breg@ 2 and		( enabled? )
;

: enable-ftqs  ( -- )
[ifdef] ipmifw-support
   \ Do not issue FTQ reset when IPMI/ASF fw is enabled
   ipmifw-enabled? not if
[then]
   h# ffff.ffff	h# 5c00 breg!		\ Enable internal hardare queues
   0		h# 5c00 breg!		\ first -1 then 0 to FTQ Register
[ifdef] ipmifw-support
   then
[then]
;

: disable-hst-coal  ( -- error? )
   0		h# 3c00	breg!	  \ Disable Host Coalescing
   get-msecs
   begin
     dup
     h# 3c00 breg@
     get-msecs rot - d# 30 < and 0=
   until
   drop h# 3c00 breg@
;

: setup-mac-registers  ( -- error? )
   mhcr-config				\ Setup the Misc Host control register
   clear-ints

   disable-pxe drop 0 if
      cmn-error[ " Unable to disable PXE firmware" ]cmn-end 
      -1 exit
   then

   0 mac-reg!				\ Clear Mac Mode Reg

   pci-dev-id pci-e? if
      h# 7c00 breg@
      1 d# 25 << or 
      h# 7c00 breg!		\ Enable Data FIFO Protect (PCI-E only)
   then

   restore-pci-regs
   clear-pci-status
   clear-host-mac-status
   clear-nic-mac-statistics

   h# 7600.000f	

   pci-dev-id dup BCM-5714 = 
   swap 	  BCM-5715 = or		\ 5714 and 5715 require we set:
   if  h# 8000 or  then  		\ ONE_DMA_AT_ONCE_LOCAL

   h# 6c  my-l!				\ Setup DMA Read/Write Ctrl

   mode-ctrl-config			\ Setup Mode Control register

   h# 6804 breg@
   d# 65 1 << or	
   h# 6804		breg!		\ 66Mhz local timer

   nicmem-config			\ Configure Controller memory

   enable-buffer-manager 0= if
      cmn-error[ " Unable to enable buffer manager" ]cmn-end 
      -1 exit
   then

   enable-ftqs				\ Enable Flow Through Queus
   false				\ No errors
;

: init-rx-rbd  ( rxbuf /rxbuf rxbdadr -- )
   >r
   r@		>rxbd-len	local-w!
   r@		>rxbd-host-adr	local-x!
   0 r@		>rxbd-index	local-w!
   0 r@		>rxbd-type	local-w!
   0 r@		>rxbd-flags	local-w!
   0 r@		>rxbd-ip-cksum	local-w!
   0 r@		>rxbd-tcp-cksum	local-w!
   0 r>		>rxbd-err-flags	local-w!
;

: init-std-rbds  ( -- )
   0 /std-ring bounds do			( )
      i #rxbufs < if				( )
         rxbuf0 i /rxbuf * + cpu>io-adr /rxbuf  ( rxbuf /rxbuf )
      else					( )
         0 0					( 0 0 )
      then					( rxbuf /rxbuf rxbdadr )
      std0 i /rxbd * +				( rxbuf /rxbuf rxbdadr )
      init-rx-rbd				( )
   loop
;

: init-std-ring  ( -- )
   0		h# 2450		breg!	\ Standard Ring Host address (high)
   std0 cpu>io-adr h# 2454	breg!	\ Standard Ring Host address (low)
   pci-dev-id BCM-5721 = if
      h# 200				\ Another BCM-5721 uniqueness
   else
      h# 600
   then

   d# 16 << h# 2458		breg!	\ Size and flags

   h# 6000      h# 245c		breg!	\ controller side ring adr
   2		h# 2c18		breg!	\ Standard Replenish Threshold
   0		hpm-spr-pi	breg!	\ init Standard mailbox
   init-std-rbds
;

: disable-mini-ring  ( -- )
   0		h# 2460		breg!	\ Mini Ring Host address high
   0		h# 2464		breg!
   h# 80 d# 16 << 2 or			\ 80 = size, 2 = disable
   ( reg-val )	h# 2468		breg!	\ Disable Mini Ring
   h# e000      h# 246c		breg!	\ ring adr
   d# 32	h# 2c14		breg!	\ Mini Replenish Threshold (in case)
   0		hpm-mini-pi	breg!	\ init mini mailbox
;

: disable-jmb-ring  ( -- )
   0		h# 2440		breg!	\ Jumbo Ring Host address high
   0		h# 2444		breg!	\ Jumbo Ring Host address low
   h# 2000 d# 16 << 3 or		\ 2000 = size, 3 = disabled,jumbo
   ( reg-val )	h# 2448		breg!	\ Disable Jumbo Ring
   h# 7000      h# 244c		breg!	\ ring adr
   d# 128	h# 2c1c		breg!	\ Jumbo Replensih Threshold (in case)
   0		hpm-jumbo-pi	breg!	\ init jumbo mailbox
;

: rcb-fill ( flags len nic-adr host-adr ring-adr -- )
   tuck >rcb-host-adr	nicmem-x!	(  flags len nic-adr ring-adr )
   tuck >rcb-nic-adr	nicmem!		(  flags len ring-adr )
   -rot d# 16 << or			( ring-adr len-flags )
   swap >rcb-len-flags	nicmem!		( len-flags ring-adr )
;

: disable-tx-ring  ( n -- )
   1- >r
   2 /txring				\ flag = disable, len = /txring
   4000 0				\ nic-adr = 4000, host-adr = 0
   r> /rcb * h# 100 +			\ controller side rcb address
   rcb-fill
;

: enable-tx-ring  ( n -- )
   1- >r
   0 /txring				\ no flags, len = /txring
   r@ /txbd * /txring * 4 / h# 4000 +	\ nic-adr algorithm from prm
   r@ /txring * txbd0 + cpu>io-adr	\ host ring address
   r> /rcb * h# 100 +			\ controller side rcb address
   rcb-fill
;

: disable-rx-ring  ( n -- )
   1- >r
   2 /rxring				\ flags = disable, len = /rxring
   0 0					\ nic-adr = 0, host-adr = 0
   r> /rcb * h# 200 +			\ contoller side rcb address
   rcb-fill
;

: enable-rx-ring  ( n -- )
   1- >r
   0 /rxring				\ flags = 0, len = /rxring
   0					\ nic-adr not used
   r@ /rxring * rrbd0 + cpu>io-adr	\ host side address
   r> /rcb * h# 200 +			\ controller side rcb address
   rcb-fill
;

: init-tx-rings  ( -- )
   1 d# 16 bounds do 
      i dup #txrings <= if 
         enable-tx-ring
      else
         disable-tx-ring 
      then
   loop
   h# 300 h# 80 bounds do  0 i nicmem! 4  +loop		\ clear tx host pis
   h# 380 h# 80 bounds do  0 i nicmem! 4  +loop		\ clear tx nic pis 
;

: init-rx-rings  ( n -- )
   1 d# 16 bounds do 
      i dup #rxrings <= if 
         enable-rx-ring
      else
         disable-rx-ring 
      then
   loop
;

: backoff-seed-init  ( -- )
   0 mac-address bounds do  i c@ +  loop h# 3ff and	( seed )
   h# 438 breg!		\ Random Backoff seed
;

: mac-adr-config  ( -- )
   backoff-seed-init
   0 mac-address bounds do  d# 8 << i c@ or  loop xlsplit	( lo hi )

   2dup h# 410 breg!
	h# 414 breg!

   2dup h# 418 breg!
	h# 41c breg!

   2dup h# 420 breg!
	h# 424 breg!

	h# 428 breg!
	h# 42c breg!
;

: set-loop-mode ( -- )
   h# 10 mac-reg-set		\ mac loopback
;

: set-promis-mode ( -- )
   h# 100 h# 468 breg-bset
;

: init-mac-mode  ( -- )
   mac-mode  case
      int-loopback  of  set-loop-mode    endof
      promiscuous   of  set-promis-mode  endof
   endcase
;

: init-mac  ( -- error? )

[ifdef] ipmifw-support
   enable-mem-access			\ Ensure endianness, mem space, arbtr
   ipmifw-enabled? if
      \ Delay needed to give enough time to IPMI/ASF fw to come alive
      \ before we send our state updates. This is handy with 'boot net'
      \ which does multiple open/close of net driver
      d# 2000 ms
      pause-ipmifw			\ Pause IPMI/ASF fw
      bootcode-sig!			\ Write bootcode magic "KevT"
   then
[then]

   reset-core-clks

[ifdef] ipmifw-support
   enable-mem-access			\ Ensure endianness, mem space, arbtr
   ipmifw-enabled? if
      fcode-state-start state-sig!	\ Notify our Start state to IPMI/ASF fw
      check-bootcode-compl		\ Check bootcode compliment ~KevT
   then
[then]

   setup-mac-registers if  -1 exit  then

   init-std-ring
   disable-jmb-ring
   disable-mini-ring
   
   init-tx-rings
   init-rx-rings

   mac-adr-config

   mtu-size	h# 43c	breg!	\ MTU size
   h# 2620	h# 464	breg!	\ IPG recommended value
   8		h# 500	breg!	\ Non matched packets to ring 1
   9		h# 2010	breg!	\ Rx List Configuration (???) ### MATCH SOLARIS
   h# ff.ffff	h# 2018	breg!	\ Rx List Placement Mask
   1		h# 2014 breg-bset \ Statistics enable
   h# ff.ffff	h# c0c	breg!	\ Statistics enable mask
   3		h# c08	breg-bset \ Statistics control register

   disable-hst-coal if
      cmn-error[ " Could not disable Host Coalescing for initialization" ]cmn-end 
      -1 exit
   then

\   d# 150	h# 3c08	breg!	\ Rx Coalescing Ticks
\   d# 150	h# 3c0c	breg!	\ Send Coalescing Ticks
   0		h# 3c08	breg!	\ Rx Coalescing Ticks#######DEBUG########
   0		h# 3c0c	breg!	\ Send Coalescing Ticks   #######DEBUG########

\   d# 10	h# 3c10	breg!	\ Rx Max Coalescing Count
\   d# 10	h# 3c14	breg!	\ Send Max Coalescing Count
   1		h# 3c10	breg!	\ Rx Max Coalescing Count#####DEBUG####
   1		h# 3c14	breg!	\ Send Max Coalescing Count#####DEBUG#####

   0		h# 3c18	breg!	\ (don't) Rx Coalescing Ticks During Interrupt
   0		h# 3c1c	breg!	\ (don't) Tx Coalescing Ticks During Interrupt
   
   0		h# 3c20	breg!	\ Rx Max Coalesced Frames During Interrupt
   0		h# 3c24	breg!	\ Send Max Coalesced Frames During Interrupt
   
   io-dma-base	>dma-status-blk h# 3c38 breg-x! \ Status Block host adr
   io-dma-base	>dma-stat-blk   h# 3c30 breg-x! \ Statisticss Block host adr

   d# 1.000.000	h# 3c28	breg!	\ Statistics Tick Counter Reg (recommended)

   h# 300	h# 3c40	breg!	\ NIC Statistics Base adr
   h# b00	h# 3c44	breg!	\ NIC Status Block Base adr reg

   2		h# 3c00	breg-bset \ enable host coalescing engine
   6		h# 3000	breg-bset \ Enable BD completion functional block
   2		h# 2000	breg-bset \ Enable Rx list placement functional block
   6		h# 3400	breg-bset \ Enable Rx list selector functional block
   h# e0.0000	mac-reg-set	  \ Enable DMA engines (Mac Mode Register)
   h# d800	mac-reg-set	  \ Enable Statistcs   (Mac Mode Register)

   h# 01009608	h# 6808	breg!	\ Misc Local Control (device specific!!!)
				\ defines gpio pins.  This value matches
				\ Solaris.

   0		hpm-im0	breg!	\ Zero interrupt mailbox 0
   2		h# 6400	breg!	\ Enable DMA Completion Functional Block
   h# 3fe	h# 4c00	breg!	\ Configure write DMA Mode Reg
   h# 3fe	h# 4800	breg!	\ Configure read DMA Mode Reg
   6		h# 2800	breg!	\ Enable Rx data completion functional block
   2		h# 3800	breg!	\ Enable Mbuf cluster free functional block
   2		h# 1000	breg!	\ Enable Send Data Completion functional block
   6		h# 1c00	breg!	\ Enable Send BD Completion functional block
   6		h# 2c00	breg!	\ Enable Rx BD Initiator functional block
   h# 12	h# 2400	breg!	\ Enable Rx Data & BD Intiator functionalblock
   2		h# c00	breg!	\ Enable Send Data Initiator functional block
   6		h# 1800	breg!	\ Enable Send BD Initiator functional block
   6		h# 1400	breg!	\ Enable Send BD Descriptor functional block

   enable-txmac			\ Enable Tx mac
   enable-rxmac			\ Enable Rx mac

   h# c.0000	h# 454	breg-bset \ Disable auto polling
    
   h# 2000000	h# 40c	breg!	\ LED Control Reg, Blink Period = 15.9 Hz

   init-mac-mode
 
   1		h# 450	breg!	\ Activate link
   #rxbufs	hpm-spr-pi breg!  \ give controller some buffers to use

   h# 1000	h# 408	breg-bset \ set event error interupt
   h# 1c00.0000	mode-ctrl-set	  \ enable dma,mac,flow attention
   2		mhcr-clear	  \ enable PCI (interrupts).  We have pci
				  \ interrupts masked off, this gets the chip
				  \ servicing interrupts internally
   false			  \ If we made it this far there were no errors
;

: set-port-mode  ( -- )	\ GMII or MII
   h# c 400 breg-bclear
   chosen-speed 1000Mbps = if  8  else  4  then  h# 400 breg-bset
;

: set-mac-duplex  ( -- )
   chosen-duplex half-duplex = if  
      2 h# 400 breg-bset 
   else
      2 h# 400 breg-bclear
   then
;

: set-mac-polarity  ( -- )
    h# 400 mac-reg-set
;

: configure-mac  ( -- )
   set-port-mode
   set-mac-duplex
   set-mac-polarity		\ 5701,3,4 boards have non-default polarity
;
