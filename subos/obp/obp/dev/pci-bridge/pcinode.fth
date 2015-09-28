\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: pcinode.fth
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
id: @(#)pcinode.fth 1.8 06/10/18
purpose: PCI bridge probe code
copyright: Copyright 1994 Firmworks  All Rights Reserved
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.


hex
headerless

" pci"						device-name
pci-express?  if  " pciex"  else  " pci"  then	device-type

2 encode-int " #size-cells" property
3 encode-int " #address-cells" property

0 value my-bus#

defer parent-decode-unit

external
: allocate-bus# ( n m-aln m-sz m64-aln m64-sz io-aln io-sz --
                       mem-l mem64-l io-l dma-l mem-h mem64-h io-h dma-h bus# )
   " allocate-bus#" $call-parent
;
: decode-unit  ( adr len -- phys.lo..hi )
   parent-decode-unit lwsplit drop  my-bus# wljoin
;
defer encode-unit  ( phys.lo..hi -- adr len )

\
\ This routine allows allocation of resources from the current IO/MEM lists.
\
: resource-alloc ( physhi align size -- addr|0 )
   " resource-alloc" $call-parent
;

\ This routine returns a range to the relevant list.
\ Be CAREFUL no checking is done to verify that an allocation from one
\ pool is not returned to the other, nor that you are freeing more than
\ you alloc'd.
: resource-free ( physhi addr len -- )
   " resource-free" $call-parent
;

\ decode-unit and encode-unit must be static methods, so they can't use
\ $call-parent at run-time

" decode-unit" my-parent ihandle>phandle find-method drop  ( xt )
to parent-decode-unit

" encode-unit" my-parent ihandle>phandle find-method drop  ( xt )
to encode-unit

: prober-xt    ( -- xt )                         " prober-xt"   $call-parent  ;

: assign-int-line  ( phys.hi.func int-pin -- false | irq true )
   nip my-space swap " assign-int-line"   $call-parent
;

: dma-alloc    ( size -- vaddr )                 " dma-alloc"   $call-parent  ;
: dma-free     ( vaddr size -- )                 " dma-free"    $call-parent  ;
: dma-map-in   ( vaddr size cache? -- devaddr )  " dma-map-in"  $call-parent  ;
: dma-map-out  ( vaddr devaddr size -- )         " dma-map-out" $call-parent  ;
: dma-sync     ( virt-addr dev-addr size -- )    " dma-sync" 	$call-parent  ;

: open  ( -- okay? )  true  ;
: close  ( -- )  ;

headerless
