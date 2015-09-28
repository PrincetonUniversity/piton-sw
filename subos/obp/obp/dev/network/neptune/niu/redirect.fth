\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: redirect.fth
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
id: @(#)redirect.fth 1.1 07/01/23
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ The intention of this file is to allow the Neptune PCI device and the 
\ NIU device to share as much code as possible. For example, the shared 
\ code might call 'reset-transceiver', but the method of doing this might 
\ differ between the two devices, so this file will redirect that method 
\ to the appropriate routine.

headerless

: reset-transceiver ( -- ok? ) reset-xpcs ;
: setup-transceiver ( -- ok? ) setup-bcm8704-xcvr ;

: link-up?    ( -- flag ) 
   10g-fiber-link-up?
   dup to link-is-up?    \ Record linkup status
;

: init-xif  ( -- ) init-xmac-xif ;
: init-pcs  ( -- ok? ) init-xpcs ;

: reset-mac  ( -- ok? ) reset-xmac ;
: init-mac  ( -- ok ) init-xmac ;
: init-hostinfo  ( -- ) xmac-init-hostinfo ;
: enable-mac  ( -- ) enable-xmac ;
: enable-pcs  ( -- ) enable-xpcs ;
: check-user-inputs ( -- ok? ) check-10g-user-inputs ;
: update-mac-tx-err-stat ( -- ) update-xmac-tx-err-stat ;
: update-mac-rx-err-stat ( -- ) update-xmac-rx-err-stat ;
: .mac-tx-err  ( -- ) .xmac-tx-err ;
: .mac-rx-err  ( -- ) .xmac-rx-err ;
: clear-mac-tx-err ( -- ) clear-xmac-tx-err ;
: clear-mac-rx-err ( -- ) clear-xmac-rx-err ;
: disable-mac-intr ( -- ) disable-xmac-intr ;

true to niu?

headerless
