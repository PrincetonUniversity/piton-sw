\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: mdload.fth
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
id: @(#)mdload.fth 1.4 07/06/22
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless

0 value reset-reason

: power-on-reset? ( -- flag )  reset-reason 0=  ;

2 2 h# 01 0 hypercall: hv-get-md ( len buf -- len status )

stand-init: Get machine description and initialize values
   \ Hcall will fail, and return the actual length
   0 0 hv-get-md drop					( n )
   dup h# 1f + alloc-mem				( n va )
   h# 20 round-up dup is guest-md is md-data		( n )
   md-data >physical drop  hv-get-md  if		( len )
      cmn-fatal[ " Failed to read machine description" ]cmn-end
   then  drop						( )

   md-root-node " reset-reason"  md-get-required-prop 	( val type )
   drop is reset-reason

   power-on-reset? if
      \ On 'power-on' ie guest first init memory is always clean
      memory-clean? on
   then

   0 " platform" md-find-node
   " max-cpus" md-get-required-prop
   drop is max-#cpus

   md-root-node " cpu" md-find-node
   " mmu-max-#tsbs" md-get-required-prop drop is max-#tsb-entries
;

