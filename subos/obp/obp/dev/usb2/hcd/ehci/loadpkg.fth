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
id: @(#)loadpkg.fth 1.1 07/01/24
purpose: Load file for the EHCI HCD files

\ Generic HCD stuff
fload ${BP}/dev/usb2/align.fth			\ DMA memory allocation
fload ${BP}/dev/usb2/pkt-data.fth		\ USB packet definitions
fload ${BP}/dev/usb2/pkt-func.fth		\ USB descriptor manipulations
fload ${BP}/dev/usb2/hcd/hcd.fth		\ Common HCD methods
fload ${BP}/dev/usb2/hcd/error.fth		\ Common HCD error manipulation
fload ${BP}/dev/usb2/hcd/dev-info.fth		\ Common internal device info

\ EHCI HCD stuff
fload ${BP}/dev/usb2/hcd/ehci/ehci.fth		\ EHCI methods
fload ${BP}/dev/usb2/hcd/ehci/qhtd.fth		\ EHCI QH & qTD manipulations
fload ${BP}/dev/usb2/hcd/ehci/control.fth	\ EHCI control pipe operations
fload ${BP}/dev/usb2/hcd/ehci/bulk.fth		\ EHCI bulk pipes operations
fload ${BP}/dev/usb2/hcd/ehci/intr.fth		\ EHCI interrupt pipes operations
fload ${BP}/dev/usb2/hcd/control.fth		\ Common control pipe API

\ EHCI usb bus probing stuff
fload ${BP}/dev/usb2/vendor.fth			\ Vendor/product table manipulation
fload ${BP}/dev/usb2/device/vendor.fth		\ Supported vendor/product tables
fload ${BP}/dev/usb2/hcd/fcode.fth		\ Load fcode driver for child
fload ${BP}/dev/usb2/hcd/device.fth		\ Make child node & its properties
fload ${BP}/dev/usb2/hcd/ehci/probe.fth		\ Probe root hub
fload ${BP}/dev/usb2/hcd/ehci/probehub.fth	\ USB 2.0 hub specific stuff
fload ${BP}/dev/usb2/hcd/probehub.fth		\ Probe usb hub


