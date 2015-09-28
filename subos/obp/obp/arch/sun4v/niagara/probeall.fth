\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: probeall.fth
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
id: @(#)probeall.fth 1.3 07/06/22
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

fload ${BP}/dev/usb2/usbprobe.fth		\ probe-usb-all

headerless

: $pci ( -- str,len ) " /pci@" ;

: (do-probe) ( slot$ dev$ fn$ -- )
   execute-device-method 0= if  2drop  then
;

: pci-probe ( slot$ dev$ -- ) " master-probe" (do-probe) ;

5 constant /probe-prefix     \ /pci@ = 5 characters
8 constant /probe-cfg-handle \ Maximum cfg-handle = 8 characters (hex)

struct
   /probe-prefix     field >probe-prefix     
   /probe-cfg-handle field >probe-cfg-handle 
constant /probe-path

/probe-path buffer: probe-path

: (probe-io) ( node -- )
   >r r@ " device-type" -1 md-find-prop	 		( prop )( R: node )
   ?dup if md-decode-prop drop				( str,len )( R: node )
      " pciex" $= if					(  )
         \ If the node is a PCI Express MD node, we need to create the 
         \ root device path with the node's cfg-handle. For example, if
         \ the 'cfg-handle' is 0x200, we need to creat the device path:
         \ /pci@200
         $pci probe-path >probe-prefix swap move	(  )
         r@ " cfg-handle" md-get-required-prop drop 	( cfg-handle )
         (u.) tuck 					( len str,len )
         probe-path >probe-cfg-handle swap move		( len )
         probe-path swap /probe-prefix +		( str,len )
         r> " probe-list" md-get-required-prop drop	( str,len list,len )
         2swap pci-probe				(  )
      else						(  )
         r> drop					(  )( R: )
      then						(  )
   else
      r> drop						(  )( R: )
   then
;

headers

: probe-io ( -- )
   0 " phys_io" md-find-node ?dup if			( node )
      ['] (probe-io) swap md-applyto-fwds		(  )
   then							(  )
;

: probe-all ( -- )  
   ['] diagnostic-mode? behavior 			( xt )
   max+mode? if  ['] true to diagnostic-mode?  then	( xt )
   probe-io						( xt )
   to diagnostic-mode?					( )
   probe-usb-all                        \ Probe USB devices after PCI probe
;

headerless
