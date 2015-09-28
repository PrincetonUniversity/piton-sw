\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: usbprobe.fth
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
id: @(#)usbprobe.fth 1.2 07/06/22
purpose: Create secondary USB nodes after main probe
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserve
copyright: Use is subject to license terms.

\ Based on probe-scsi code.

headerless


\ co-routine to identify usb controllers and probe them

: usb-children  ( -- )
   \ Ignore nodes which are not class code c0300
   " class-code" get-property  if  exit  then	( enc$ )
   drop l@ h# ff not and			\ class code without version
   h# 000c0300 = if				\ Is class-code a USB node?
      " probe-usb" method-name 2!  call-method?
   then
;

\ co-routine to identify usb controllers and power-up the ports

: power-usb-children ( -- )
   \ Ignore nodes which are not class code c0300
   " class-code" get-property  if  exit  then	( enc$ )
   drop l@ h# ff not and			\ class code without version
   h# 000c0300 = if				\ Is class-code a USB node?
      " power-usb-ports" method-name 2!  call-method?
   then
;

headers

: probe-usb-all ( -- )
      " /" ['] power-usb-children scan-subtree
      d# 1000 ms	\ Wait for USB devices to settle down before probing.
      " /" ['] usb-children  scan-subtree
;
