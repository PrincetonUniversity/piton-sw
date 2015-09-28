\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: loadpkg.fth
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
id: @(#)loadpkg.fth 1.6 05/02/14
purpose:
copyright: Copyright 1994 Firmworks  All Rights Reserved
copyright: Copyright 2005 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

fload ${BP}/dev/deblock.fth             \ Block-to-byte conversion package
fload ${BP}/pkg/boot/sunlabel.fth       \ Sun Disk Label package
fload ${BP}/pkg/termemu/loadfb.fth	\ Frame buffer & terminal emulator 
fload ${BP}/pkg/boot/bootparm.fth       \ S boot command parser
fload ${BP}/os/bootprom/callback.fth    \ Client callbacks
fload ${BP}/pkg/console/instcons.fth    \ install-console
fload ${BP}/arch/sun4u/go.fth           \ Initial program state
fload ${BP}/os/bootprom/dlbin.fth       \ Serial line loading
fload ${BP}/pkg/dhcp/macaddr.fth
fload ${BP}/os/bootprom/dload.fth       \ Diagnostic loading
fload ${BP}/pkg/sunlogo/logo.fth
fload ${BP}/pkg/console/sysconfig.fth   \ System configuration information 
fload ${BP}/pkg/console/banner.fth      \ Banner with logo
[ifndef] Littleneck?
fload ${BP}/arch/sun4u/help.fth         \ Help package
[else]
[message] XXX FIXME! HELP PKG REMOVED XXX
[then]
