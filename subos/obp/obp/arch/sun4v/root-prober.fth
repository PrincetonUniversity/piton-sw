\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: root-prober.fth
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
id: @(#)root-prober.fth 1.4 07/06/22
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless

: make-root$ ( n type$ -- root$ )
   push-hex
   rot <# u#s -rot ascii - hold 1- bounds swap do i c@ hold -1 +loop u#>
   pop-base
;

: get-root-driver? ( name$ -- acf,-1|0 )
   ['] builtin-drivers-package find-method
;

0 value pdnode-handle

: make-io-node ( acf node unit -- )
   push-hex (.) pop-base		( acf node $reg )
   rot encode-int 2swap			( acf $args $reg )
   cmn-type[ " Device: " cmn-append	( acf $args $reg )
   " /" begin-package			( acf )
   catch drop				(  )
   end-package				(  )
   " " ]cmn-end				(  )
;

\ When attaching FCode drivers, look for drivers that match the
\ "compatible" property first, then "device-type"
\
: load-root-driver ( node -- )
   dup " disabled" ascii v md-find-prop dup if	( node prop )
      md-decode-prop	drop			( node status )
   then						( node status )
   0= if					( node )
      dup " cfg-handle" ascii v md-find-prop	( node prop )
      dup if md-decode-prop drop then		( node unit )
      over " compatible" -1 md-find-prop ?dup if ( node unit node'| )
         md-decode-prop drop			( node unit prop,len )
         \ Currently, we only support attaching the driver to the
         \ first compatible property. This can be extended to a loop
         \ if necessary.
         decode-string 2swap 2drop		( node unit str,len )
         get-root-driver? ?dup 0= if		( node unit [acf -1]| )
            over " device-type" -1 md-find-prop ( node unit node' )
            dup if				( node unit node'|0 )
               md-decode-prop drop		( node unit str,len )
               get-root-driver?			( node unit [acf -1]|0 )
             then				( node unit [acf -1]|0 )
         then            			( node unit [acf -1]|0 )
         if					( node unit acf| )
            -rot over >r make-io-node r>	( node )
         else					( node unit )
            drop				( node )
         then					( node )
      else					( node unit )
         drop					( node )
      then					( node )
   then						( node )
   drop						(  )
;

: probe-wart  ( node -- )
   dup md-node-name " wart" $= if
      load-root-driver
   else
      drop
   then
;

: load-wart-drivers  ( node -- )
   ['] probe-wart swap md-applyto-fwds
;

: make-io-nodes  ( -- )
   0
   begin
      " iodevice" md-find-node ?dup			( 0 | node node )
   while
      dup load-root-driver				( node )
      dup load-wart-drivers				( node )
   repeat
;

stand-init: Probe root devices
   make-io-nodes
;

