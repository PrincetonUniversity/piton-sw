\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: map.fth
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
id: @(#)map.fth 1.2 07/03/13
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless

: map-in  ( phys.lo phys.hi size -- vaddr )   " map-in" $call-parent ;

: map-out ( vaddr size -- )  " map-out" $call-parent ;

: make-power-of-2 ( x -- x' ) 1 d# 63 << begin 1 xrshift 2dup and until 1 << nip ;

\ The Hypervisor NIU APIs are defined in FWARC case 2006/524
h# 142 constant n2niu-rx-lp-set
h# 144 constant n2niu-tx-lp-set

: log-page-set ( vaddr size -- )
   swap >physical drop swap 	( raddr size )
   0 0 2swap			( channel register raddr size )
   2over 2over 4 1 n2niu-rx-lp-set h# 80 htrap ?dup if
      cmn-fatal[ " RX Logical page setting failed!" ]cmn-end
   then
   4 1 n2niu-tx-lp-set h# 80 htrap ?dup if
      cmn-fatal[ " TX Logical page setting failed!" ]cmn-end
   then
;

: dma-alloc ( size -- vaddr )  " dma-alloc" $call-parent  ;
: dma-free  ( vaddr size -- )  " dma-free"  $call-parent  ;

: dma-map-in  ( vaddr n cache? -- devaddr )  
   >r 2dup log-page-set
   r> " dma-map-in"  $call-parent  
;

: dma-map-out ( vaddr devaddr n -- ) " dma-map-out" $call-parent  ;

: dma-sync ( virt-adr dev-adr size -- )
   " dma-sync" ['] $call-parent  catch  if
      3drop 2drop
   then
;

0 value      cpu-dma-base
0 value      io-dma-base

\ Conversion between cpu dma address and io dma address.
: cpu>io-adr  ( cpu-adr -- io-adr )  cpu-dma-base - io-dma-base +  ;
: io>cpu-adr  ( io-adr -- cpu-adr )  io-dma-base - cpu-dma-base +  ;

#rcds /rcd * h# 2000 align-size
constant /rcd-ring 	\ RX completion ring, 8KB aligned

#rmds /rmd * h# 2000 align-size
constant /rmd-ring 	\ RX descriptor ring, 8KB aligned

#rbufs /rbuf * constant /rbufs	\ RX data buffers, 8KB aligned

#tmds /tmd * h# 800 align-size
constant /tmd-ring	\ TX descriptor ring, 2KB aligned

/tbuf h# 1000 align-size
constant /tbufs		\ TX data buffer(s), 4KB aligned

d# 64 constant /tmbox 		\ TX Mailbox
d# 64 constant /rmbox 		\ RX Mailbox

struct
   /rcd-ring	field >rcd-ring
   /rmd-ring	field >rmd-ring
   /rbufs	field >rbufs
   /tmd-ring	field >tmd-ring
   /tbufs	field >tbufs
   /tmbox       field >tmbox
   /rmbox       field >rmbox
make-power-of-2 constant /dma-region

: rcd0  ( -- addr ) cpu-dma-base >rcd-ring ;
: rmd0  ( -- addr ) cpu-dma-base >rmd-ring ;
: rbuf0 ( -- addr ) cpu-dma-base >rbufs ;
: tmd0  ( -- addr ) cpu-dma-base >tmd-ring ;
: tbuf0 ( -- addr ) cpu-dma-base >tbufs ;
: rmbox ( -- addr ) cpu-dma-base >rmbox ;
: tmbox ( -- addr ) cpu-dma-base >tmbox ;

: io-rcd0  ( -- addr ) io-dma-base >rcd-ring ;
: io-rmd0  ( -- addr ) io-dma-base >rmd-ring ;
: io-rbuf0 ( -- addr ) io-dma-base >rbufs ;
: io-tmd0  ( -- addr ) io-dma-base >tmd-ring ;
: io-tbuf0 ( -- addr ) io-dma-base >tbufs ;
: io-rmbox ( -- addr ) io-dma-base >rmbox ;
: io-tmbox ( -- addr ) io-dma-base >tmbox ;

: map-buffers ( -- )
   /dma-region dup dma-alloc dup to cpu-dma-base
   swap false dma-map-in to io-dma-base
;

: unmap-buffers ( -- )
    cpu-dma-base io-dma-base /dma-region dma-map-out
    cpu-dma-base /dma-region dma-free
    0 to cpu-dma-base 0 to io-dma-base
;

: map-regs ( -- )
   " reg" get-my-property drop	( reg-addr,len )
   drop-regline
   map-in-regline		( reg-addr',len' vaddr )
   nip nip			( vaddr )
   dup 		   to pio
   dup h#  80000 + to fzc-pio
   dup h# 180000 + to xmac0
   dup h# 182000 + to xpcs0   
   dup h# 184000 + to pcs0   
   dup h# 196000 + to mif   
   dup h# 280000 + to fzc-ipp
   dup h# 380000 + to fzc-fflp
   dup h# 580000 + to fzc-zcp 
   dup h# 600000 + to dmc
   dup h# 680000 + to fzc-dmc
   dup h# 780000 + to fzc-txc
   h# 800000 + to pio-ldsv
;

: unmap-regs ( -- )
   " reg" get-my-property drop		( reg-addr,len )
   drop-regline				( reg-addr',len' )
   regline-size pio swap map-out	(  )
   0 to pio       0 to fzc-pio    0 to xmac0    0 to xpcs0     
   0 to mif       0 to fzc-ipp    0 to fzc-fflp 0 to fzc-zcp 
   0 to dmc       0 to fzc-dmc    0 to fzc-txc  0 to pio-ldsv 
;

: map-resources ( -- )
   pio 0= if
      map-regs map-buffers
      10g-fiber to portmode
      my-space to port
   then
;

: unmap-resources ( -- )
   pio if  
      unmap-buffers unmap-regs  
   then
;

headerless
