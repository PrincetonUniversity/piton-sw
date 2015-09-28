\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: machine-init.fth
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
id: @(#)machine-init.fth 1.5 07/06/22
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless
0 1     0 0 hypercall: partition-exit
0 0	2 0 hypercall: partition-restart

defer (reset-all-hook ( -- )  ' noop is (reset-all-hook

chain: (reset-all
   (reset-all-hook
   partition-restart
;
' (reset-all is reset-all

defer power-off-hook ( -- )  ' noop is power-off-hook

headers

\ OpenBoot command to turn power off of a system is not supported
\ Direct users to use an appropriate SC command
: power-off 
  ??cr ." NOTICE: power-off command is not supported, use appropriate" cr
  ." NOTICE: command on System Controller to turn power off." cr
;

\ Set power-off CIF, we don't want to change Solaris behavior and hence
\ need to continue to support earlier behavior till we deprecate this CIF
cif: SUNW,power-off ( -- ) power-off-hook 0 partition-exit ;

headerless

: make-prop-from-md ( node name$ -- )
      -1 md-find-prop ?dup if			
         dup md-decode-prop ascii v = if
            encode-int
         else
            encode-string
         then
         rot md-prop-name property
      then 
;

: make-root-props ( -- )
   root-device
      0 " platform" md-find-node
      dup " stick-frequency" 	make-prop-from-md
      dup " clock-frequency" 	make-prop-from-md
      dup " name" 		make-prop-from-md
      dup " banner-name" 	make-prop-from-md

      " stick-frequency" ascii v md-find-prop
      md-decode-prop drop is system-tick-speed

   device-end
;

stand-init: Build root-properties
   make-root-props
;
