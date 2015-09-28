\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: global.fth
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
id: @(#)global.fth 1.1 07/01/23
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless
 
\ Register offset definitions
0 value pio
0 value fzc-pio
0 value fzc-mac
0 value xmac0
0 value xpcs
0 value xpcs0
0 value pcs0
0 value xmac1
0 value xpcs1
0 value pcs1
0 value bmac2  
0 value pcs2
0 value bmac3
0 value pcs3
0 value esr
0 value mif
0 value fzc-ipp
0 value fflp
0 value fzc-fflp
0 value pio-vaddr
0 value zcp
0 value fzc-zcp
0 value dmc
0 value fzc-dmc
0 value txc
0 value fzc-txc
0 value pio-ldsv
0 value pio-ldgim
0 value pio-imask0
0 value pio-imask1
0 value fzc-prom
0 value fzc-pim 


0 value  mactype
0 value  portmode
0 value  port
0 value  chan#

\ 2 different MAC types
0 constant xmac
1 constant bmac

\ Driver specific MAC modes
0  constant  normal 
3  constant  xmac-loopback
4  constant  xpcs-loopback
5  constant  serdes-ewrap-loopback
6  constant  serdes-pad-loopback
7  constant  xcvr-loopback
8  constant  2xgf-ext-loopback  \ Neptune 2XGF external loopback
9  constant  qgc-ext-loopback   \ Neptune QGC  external loopback

\ Many of the registers inside NIU are not accessable to the guest.
\ They are written to by Hypervisor using a set of APIs as a proxy.
\ We need to key off this when initialzing Neptune vs. NIU
0 value  niu?

0 constant  1g-copper
1 constant  1g-fiber
2 constant  10gig
3 constant  10g-fiber
4 constant  10g-copper

false value link-is-up?

\ Ethernet standard requires minimun 46B payload, so the minimun
\ size of the an Ethernet frame is 60B= 6B dest mac + 6B (src mac)
\ + 2B (ether-type) + 46B
d# 60 constant /min-ether-len

d# 18 constant full-header
d# 18 constant /rx-header

: .bad-mode     ( -- ) cmn-warn[ " Bad speed mode" ]cmn-end ;
: .bad-mactype  ( -- ) cmn-warn[ " Bad MAC type" ]cmn-end ;

\ Neptune is a little endian device. The 'rl@' FCode tokenizes into 'x@',
\ which is a big endian access. We pre-swap the data here so that we read and
\ write the correct values.
: swapped-rx@ ( vadr -- x )  rx@  xbflip  ;
: swapped-rl@ ( vadr -- l )  rl@  lbflip  ;
: swapped-rw@ ( vadr -- w )  rw@  wbflip  ;
: swapped-rx! ( x vadr -- )  >r xbflip r> rx!  ;
: swapped-rl! ( l vadr -- )  >r lbflip r> rl!  ;
: swapped-rw! ( l vadr -- )  >r wbflip r> rw!  ;

\ Must swap for real hardware. 
alias rx@ swapped-rx@
alias rl@ swapped-rl@
alias rw@ swapped-rw@
alias rx! swapped-rx!
alias rl! swapped-rl!
alias rw! swapped-rw!

1 d# 8 lshift constant mpr \ Used by both XMAC and BMAC

: unsupported-port ( -- )
   cmn-fatal[ " Unsupported port number" ]cmn-end abort
;

\ Offsets for the two XMACs
: xmac-offset ( -- offset )
   port case
      0 of h#    0 endof
      1 of h# 6000 endof
      unsupported-port
   endcase
;

\ Offsets for the two XPCSs
: xpcs-offset ( -- offset )
   port case
      0 of h#    0 endof
      1 of h# 6000 endof
      unsupported-port
   endcase
;

\ Offsets for the two BMACs
: bmac-offset ( -- offset )
   port case
      2 of h#    0 endof
      3 of h# 4000 endof
      unsupported-port
   endcase
;

\ Offsets for the four PCSs
: pcs-offset ( -- offset )
   port case
      0 of h#    0 endof
      1 of h# 6000 endof
      2 of h# a000 endof
      3 of h# e000 endof
   endcase
;

\ RX Message Descriptor Format
\ Neptune rmd entry only holds the high32 bits of the 44bits address
4 constant /rmd   
8 constant /rcd              \ Rx Completion descriptor is 8 bytes 

d# 64  constant  #rmds       \ Number of Rx Message Descriptors
                             \ Do not use a too small number because
                             \ WRED requires some room for defending 
                             \ the interface from attack

\ #rcds/#rmds = (block buff size)/(smallest partition size in the buff)
\             = 8K/2K = 4,  so #rcds = 4 x #rmds
#rmds 4 * constant  #rcds    \ Number of Rx Completion Descriptors
#rmds 4 - constant  #rbufs   \ #rmds - 4 

d# 8192    constant  /rbuf   \ Size of each RX buffer

\ TX Message Descriptor Format

d#   64 constant  #tmds      \ # of TX descriptor ring
d#    8 constant  /tmd       \ Size of TX descriptor ring entry
d#    1 constant  #tbufs     \ Only 1 TX buffer
d# 2048 constant  /tbuf      \ Size of TX buffer

\ --- IPP ---
\ Because the offsets of Neptune's port0 and port1 IPP must be the same
\ as the N2-NIU's offsets, the four IPP' offsets are as follows,
\
: ipp-step   ( port -- ipp-offset )
   case
      0 of       0 endof
      1 of h# 8000 endof
      2 of h# 4000 endof
      3 of h# c000 endof
   endcase
;

\ --- MIF ---
h# 2.0000      constant ta=10        \ TA field of Clause 45 frame = 10
1 d# 28 lshift constant op=write
3 d# 28 lshift constant op=read45    \ Clause45 Read is b11
2 d# 28 lshift constant op=read22    \ Clause22 Read is b10
1 d# 30 lshift constant st=cls22

\ --- Rx Errors ---
0 value rx-dma-err-status      \ Rx DMA Rrror status bits
0 value rdmc-pre-err-status    \ Rx DMA Prefetch Error Status bits
0 value rdmc-sha-err-status    \ Rx DMA Shadow Error Status bits
0 value rx-ctl-dat-fifo-status
0 value ipp-int-err-status     \ IPP Interrupt status
0 value rx-xmac-err-status     \ Rx XMAC
0 value rx-bmac-err-status     \ Rx BMAC

\ --- Tx Errors ---
0 value tx-dma-err-status
0 value tx-xmac-err-status
0 value tx-bmac-err-status

\ --- Do external loopback or not ---
false value do-ext-loopback? 
