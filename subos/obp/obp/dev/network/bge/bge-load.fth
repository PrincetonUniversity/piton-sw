\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bge-load.fth
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
id: @(#)bge-load.fth 1.5 06/06/23
purpose: Loadfile for Onboard bge 
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

fload ${BP}/dev/pci/config-access.fth
fload ${BP}/dev/pci/compatible.fth
fload ${BP}/dev/network/bge/bge-h.fth

: encode-reg ( addr space size -- adr len )
   >r encode-phys 0 encode-int encode+ r> encode-int encode+
;

: reg-property-value ( -- adr len )
   my-address my-space                          0 encode-reg
   my-address my-space h# 300.0010 or  h# 20.0000 encode-reg  encode+


\ The 5704, 5714, and 5715 implement another 64bit bar that is unused by
\ OBP but should be made available to Solaris.

   pci-dev-id dup BCM-5704 = 
   over		  BCM-5714 = or
   swap 	  BCM-5715 = or if
      my-address my-space h# 300.0018 or  h#  1.0000 encode-reg  encode+
   then
;

headers


fload ${BP}/dev/network/bge/bge-map.fth

fload ${BP}/dev/network/bge/bgeutil.fth
fload ${BP}/dev/network/bge/mif.fth

fload ${BP}/dev/network/common/mif/mii-h.fth
fload ${BP}/dev/network/common/mif/gmii-h.fth

fload ${BP}/dev/network/common/link-params.fth
fload ${BP}/dev/network/common/devargs.fth

\ BGE Includes

depend-load ipmifw-support ${BP}/dev/network/bge/bge-ipmifw.fth
fload ${BP}/dev/network/bge/bge-mac.fth
fload ${BP}/dev/network/bge/bge-phy.fth
fload ${BP}/dev/network/bge/bge-core.fth
fload ${BP}/dev/network/bge/bge-test.fth
fload ${BP}/dev/network/bge/bge-pkg.fth

headers
