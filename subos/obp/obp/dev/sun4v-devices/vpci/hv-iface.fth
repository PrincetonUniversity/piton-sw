\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: hv-iface.fth
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
id: @(#)hv-iface.fth 1.3 07/01/08 
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

fload ${BP}/dev/sun4v-devices/utilities/property-access.fth

: md-getvalue ( x -- x' d )  dup x@ swap /x + swap ;

\ load the configuration data from the node description
" address-ranges" required-prop 2drop
   md-getvalue constant pci-iobase		\ IO
   md-getvalue constant pci-iosize
   md-getvalue constant pci-mem32base		\ MEM32
   md-getvalue constant pci-mem32size
   md-getvalue constant pci-mem64base		\ MEM64
   md-getvalue constant pci-mem64size
   drop

" virtual-dma" required-prop 2drop
   md-getvalue swap md-getvalue nip		( va,len )
   over encode-int 2 pick encode-int encode+ " virtual-dma" property
   over constant virtual-dma-base		( va len )
   + h# 100.0000 tuck - 			( len va' )
   constant virtual-dma-addr
   constant virtual-dma-size

" device-type"	required-prop	drop encode-string " device_type" property
" compatible" 	required-prop	ascii d =  if  1-  then 
				     encode-string " compatible" property

" pci"				name
2 encode-int			" #size-cells" property
3 encode-int			" #address-cells" property
0 0				" bus-parity-generated" property

external
0 value my-pci-bus

" bus-ranges" required-prop 2drop	( va )
   md-getvalue is my-pci-bus		( va )
   md-getvalue nip			( n )
my-pci-bus encode-int			( n xdr,len )
rot encode-int encode+ " bus-range" property
