\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: multipath-boot.fth
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
id: @(#)multipath-boot.fth 1.1 07/01/22
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless

false value ok-prompt?
defer cmn-end-mpb-recovery

fload ${BP}/arch/sun4ju/columbus2/multipath-boot.fth

defer old-boot-read-fail-hook ( -- )
' boot-read-fail-hook behavior is old-boot-read-fail-hook

: 4v-boot-read-fail-hook ( -- )
   old-boot-read-fail-hook
   cmn-error[ " boot-read fail" ]cmn-end
   mpb-recovery-with-reboot		(  )	\ Check multipath boot failure.
						\ if the faulure occured, the 
						\ system will get rebooted
;
' 4v-boot-read-fail-hook is boot-read-fail-hook


defer old-default-device-hook ( -- )
' default-device-hook behavior is old-default-device-hook

: 4v-default-device-hook ( -- )
   old-default-device-hook
   4v-boot-read-fail-hook
;
' 4v-default-device-hook is default-device-hook


defer old-4v-$boot-load-hook ( -- )
' $boot-load-hook behavior is old-4v-$boot-load-hook

: 4v-$boot-load-hook ( -- )
   old-4v-$boot-load-hook
   false to ok-prompt?
;
' 4v-$boot-load-hook is $boot-load-hook


defer old-reset-page ( -- )
' reset-page behavior is old-reset-page

: 4v-reset-page   ( -- )
   old-reset-page
   true to ok-prompt?
;

' noop is cmn-end-mpb-recovery

chain: stand-init-io
   ['] 4v-reset-page is reset-page
;
