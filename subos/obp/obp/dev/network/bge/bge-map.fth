\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bge-map.fth
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
id: @(#)bge-map.fth 1.1 02/09/06
purpose: Map routines
copyright: Copyright 2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headers

: map-in  ( phys.lo .. phys.hi size -- vaddr )   " map-in" $call-parent ;

: map-out ( vaddr size -- )  " map-out" $call-parent ;

: dma-alloc ( size -- vaddr )  " dma-alloc" $call-parent  ;
: dma-free  ( vaddr size -- )  " dma-free"  $call-parent  ;

: dma-map-in  ( vaddr n cache? -- devaddr )  " dma-map-in"  $call-parent  ;
: dma-map-out ( vaddr devaddr n -- )         " dma-map-out" $call-parent  ;

: dma-sync ( virt-adr dev-adr size -- )
   " dma-sync" ['] $call-parent  catch  if
      3drop 2drop
   then
;

\ The BGE is essentially a Big Endian PCI device.  Depending on the value of
\ PCI configuration register h# 68, it may try to make itself look like a
\ Little Endian Device.  There are some quirks though.  When fetching/storing
\ SOME registers via 32 bit access it gives unexpected data.  Ex.  If you try 
\ to access the mailbox register at address 200 it will give you the data from 
\ address 204.  If you access 204 it will give you the data from address 200.
\ However, this is not the case with all registers.  As far as I can tell, all
\ 32 bit registers give you the correct data.  The mailbox registers are
\ special because they used to be 64 bit registers on the 5701, but as of the
\ 5703 they are 32 bit.
\ Rather than worry about doing xor arithmetic on register address, we will
\ use the same solution as Solaris.  Namely, let the device be its native Big
\ Endian, and update the local r() words appropriately.

: my-rl@  ( adr -- l )	 rl@ lbflip ;
: my-rl!  ( l adr -- )  >r lbflip r> rl! ;

\ FCODE rx operators are broken, so use rl instead
: my-rx@  ( adr -- x )  dup 4 + my-rl@ swap my-rl@ lxjoin ; 
: my-rx!  ( x adr -- )  >r xlsplit r@ my-rl! r> 4 + my-rl! ;

: local-w!  ( data offset -- )  w! ;
: local-w@  ( offset -- data )  w@ ;
: local!    ( data offset -- )  l! ;
: local@    ( offset -- data )  l@ ;
: local-x!  ( data offset -- )  x! ;
: local-x@  ( offset -- data )  x@ ;

: my-bset  ( bits offset -- )  tuck my-b@ or swap my-b! ;
: my-bclear   ( bits offset -- )  dup my-b@ rot invert and swap my-b! ;
: my-wset  ( bits offset -- )  tuck my-w@ or swap my-w! ;
: my-wclear  ( bits offset -- )  dup my-w@ rot invert and swap my-w! ;
: my-lset  ( bits offset -- )  tuck my-l@ or swap my-l! ;
: my-lclear  ( bits offset -- )  dup my-l@ rot invert and swap my-l! ;

: breg@  ( offset -- data )  breg-base + my-rl@ ;
: breg!  ( data offset -- )  breg-base + my-rl! ;

: breg-x!  ( data offset -- )  breg-base + my-rx! ;
: breg-x@  ( offset -- data )  breg-base + my-rx@ ;

: breg-bset  ( data offset -- )  dup breg@ rot or swap breg! ;
: breg-bclear  ( data offset -- )  dup breg@ rot invert and swap breg! ;

: set-nic-reg  ( adr -- adr' )	\ Nic memory is divided up into 32K chunks
   h# 8000 /mod h# 8000 * h# 7c my-l! 
;

: nicmem!  ( data offset -- )	set-nic-reg bmem-base + my-rl! ;
: nicmem@  ( offset -- data )	set-nic-reg bmem-base + my-rl@ ;

: nicmem-x!  ( data offset -- )	set-nic-reg bmem-base + my-rx! ;
: nicmem-x@  ( data -- offset )	set-nic-reg bmem-base + my-rx@ ;

\ Conversion between cpu dma address and io dma address.
: cpu>io-adr  ( cpu-adr -- io-adr )  cpu-dma-base - io-dma-base +  ;
: io>cpu-adr  ( io-adr -- cpu-adr )  io-dma-base - cpu-dma-base +  ;

: map-buffers  ( -- )
   /dma-blk dma-alloc to cpu-dma-base
   cpu-dma-base /dma-blk false dma-map-in to io-dma-base
;

: unmap-buffers  ( -- )
   cpu-dma-base io-dma-base /dma-blk dma-map-out
   cpu-dma-base /dma-blk dma-free
   0 to cpu-dma-base 0 to io-dma-base 
;

: map-regs  ( -- )
   my-address my-space h# 300.0010 or h# 10.000 map-in
   dup to breg-base
   h# 8000 + to bmem-base
;

: unmap-regs  ( -- )
   breg-base h# 10000 map-out
   0 to breg-base 0 to bmem-base
;

: map-resources  ( -- )
   breg-base 0= if  map-regs map-buffers  then
;

: unmap-resources  ( -- )
   breg-base if  unmap-buffers unmap-regs  then
;

