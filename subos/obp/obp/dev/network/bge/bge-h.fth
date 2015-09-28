\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bge-h.fth
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
id: @(#)bge-h.fth 1.5 07/05/30
purpose: data structure definitions
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headers

0 instance value breg-base	\ Controller mem-base address
0 instance value bmem-base	\ Host mem-base address
0 instance value cpu-dma-base	\ cpu mapped dma base
0 instance value io-dma-base	\ device mapped dma base
0 instance value pci-$line-size	\ PCI Cache Line Size
0 instance value pci-dev-id	\ PCI Device ID
0 instance value pci-rev-id	\ PCI Revision ID
0 instance value pci-max-latency \ PCI Max Latency

h# 1647	constant BCM-5703	\ 5703 Device ID
h# 16a7	constant BCM-5703a	\ 5703 alternate Device ID
h# 1648	constant BCM-5704	\ 5704 Device ID
h# 1668 constant BCM-5714	\ 5714 Device ID
h# 1678 constant BCM-5715	\ 5715 Device ID
h# 1659 constant BCM-5721	\ 5721 Device ID

d# 128	constant #rxbufs	\ # of Receive Buffers for consumption
d# 2048 constant /rxbuf		\ Size of each Receicve Buffer 
1	constant #rxrings	\ # of rx rings

\
\ 5714,5715,5721 do not support /rxring=1024, 512 does not work for 5704
\
2 my-w@ dup to pci-dev-id
dup 		BCM-5721 = 
over		BCM-5715 = or
swap 		BCM-5714 = or 

if d# 512 else d# 1024 then
	instance value /rxring	\ # of rx RBDs per ring (mini's disabled)

1	constant #txbufs	\ # of Send Buffers for consumption
d# 2048 constant /txbuf		\ Size of each Send Buffer 
1	constant #txrings	\ # of tx rings
d# 512	constant /txring	\ # of tx RBDs per ring
d# 512	constant /std-ring	\ # of BDs in Standard Ring
h# 80	constant /statistics-blk \ Size of statistics block

\ Ring Control Buffer:
struct
   /x field >rcb-host-adr	\ Host-side Ring Buffer Address
   /l field >rcb-len-flags	\ length and flag fields
   /l field >rcb-nic-adr	\ Controller-side Ring Buffer Address
constant /rcb

\ Transmit Buffer Descriptor
struct
   /x field >txbd-host-adr	\ Host-side Transmit Buffer Address
   /w field >txbd-len		\ 0 = no buffer accociated
   /w field >txbd-flags		\ control flags
   /w field >txbd-rsvd		\ reserved (set to 0)
   /w field >txbd-vlan		\ vlan tag
constant /txbd

\ Receive Buffer Descriptor
struct
   /x field >rxbd-host-adr	\ Host-side Receive Buffer Address
   /w field >rxbd-index		\ host index
   /w field >rxbd-len		\ length of buffer ready to receive
   /w field >rxbd-type		\ producer rings = 0, return rings = ignore
   /w field >rxbd-flags		\ control flags (FRAME_HAS_ERROR = b10)
   /w field >rxbd-ip-cksum	\ producer ring = 0,  0 or ffff is ok
   /w field >rxbd-tcp-cksum	\ producer ring = 0
   /w field >rxbd-err-flags	\ only valid if FRAME_HAS_ERROR set
   /w field >rxbd-vlan		\ Vlan tag
   /l field >rxbd-rsvd		\ reserved (set to 0)
   /l field >rxbd-opaque	\ used to pass info from p-ring to r-ring
constant /rxbd

h# 400 constant rxbd-flags.frame-err	\ Frame has error (error field valid)
1      constant rxbd-err.bad-crc	\ packet has bad ethernet crc
2      constant rxbd-err.coll-detect	\ collision was encountered
4      constant rxbd-err.link-lost	\ link lost - packet incomplete
8      constant rxbd-err.phy-err	\ undef err, could mean bad alignment
h# 10  constant rxbd-err.odd-nibble	\ odd nibbles, packet may be corrupt
h# 20  constant rxbd-err.mac-abort	\ mac aborted during receive, ouch
h# 40  constant	rxbd-err.too-small	\ packet less than 64 bytes
h# 80  constant rxbd-err.truncated	\ not enough resources for packet
h# 100 constant rxbd-err.giant		\ packet larger than MTU Size

\ Status Block
struct
   /l field >status-word	\ Status Error Information
   /l field >status-tag		\ Different on every DMA (am-I-updated?)
   /w field >status-std-ci	\ Standard Producer Ring Consumer Index
   /w field >status-jmb-ci	\ Jumbo Producer Ring Consumer Index
   /w field >status-rsvd	\ Reserved
   /w field >status-mini-ci	\ Mini Producer Ring Consumer Index
   d# 16 /l * field >status-i-base \ Rx and Tx rings (1-16) indicies
constant /status-blk

: >status-tx-ci-n  ( base-adr n -- offset )	\ Offset of TX Ring n
   1- /l * swap >status-i-base +		\ Consumer Index
;
: >status-rx-pi-n  ( base-adr n -- )		\ Offset of Rx Ring n
   >status-tx-ci-n /w +				\ Producer Index
;

struct
   /status-blk			field >dma-status-blk	\ Status Block
   /std-ring /rxbd *		field >dma-std-ring	\ Standard Prod Ring
   #rxrings /rxring /rxbd * *	field >dma-rx-rings	\ Return Rings
   #txrings /txring /txbd * *	field >dma-tx-rings	\ Send Rings
   #rxbufs /rxbuf *		field >dma-rx-bufs	\ Receive Buffers
   #txbufs /txbuf *		field >dma-tx-bufs	\ Send Buffers
   /statistics-blk		field >dma-stat-blk	\ Statistic Block
constant /dma-blk
				\ hpm = High Priority Mailbox
h# 204 constant  hpm-im0	\ hpm Interupt Mailbox 0 
h# 274 constant	 hpm-jumbo-pi	\ hpm Jumbo Producer Ring Index
h# 27c constant	 hpm-mini-pi	\ hpm Mini Producer Ring Index
h# 284 constant  hpm-rrci0	\ hpm Return Ring 0 Consumer Index
h# 304 constant	 hpm-txpi0	\ hpm Transmit Ring 0 (host)Producer Index
h# 26c constant  hpm-spr-pi	\ hpm Standard Producer Ring Index

: status-blk  ( -- offset )  cpu-dma-base >dma-status-blk ;
: rrbd0  ( -- adr )  cpu-dma-base >dma-rx-rings ;
: txbd0  ( -- adr )  cpu-dma-base >dma-tx-rings ;
: std0  ( -- adr )  cpu-dma-base >dma-std-ring ;
: txbuf0  ( -- adr )  cpu-dma-base >dma-tx-bufs ;
: rxbuf0  ( -- adr )  cpu-dma-base >dma-rx-bufs ;

d# 1518 constant mtu-size
