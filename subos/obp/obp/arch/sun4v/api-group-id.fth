\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: api-group-id.fth
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
id: @(#)api-group-id.fth 1.4 07/06/22
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

\ Hypervisor API Group ids
\ Any additional APIs must also add an entry into the case statement below
     0 constant sun4v-id
     1 constant core-id
     2 constant intr-id
     3 constant soft-state-id
h# 100 constant vpci-id
h# 101 constant	ldc-id
h# 102 constant service-id
h# 103 constant niagara-crypto-service-id
h# 200 constant niagara-id
h# 204 constant niagara2-niu-id
h# 300 constant diagnostic-id

: id>$group ( api-id -- $group )
   case
      sun4v-id 			of " sun4v" endof
      core-id 			of " core" endof
      intr-id 			of " interrupt" endof
      soft-state-id 		of " soft state" endof
      vpci-id 			of " vpci" endof
      ldc-id 			of " ldc" endof
      service-id 		of " service" endof
      niagara-crypto-service-id	of " niagara crypto service" endof
      niagara-id 		of " niagara" endof
      niagara2-niu-id 		of " niagara2 niu" endof
      diagnostic-id 		of " diagnostic" endof
      cmn-fatal[ " Invalid hypervisor group id: %x" ]cmn-end
   endcase
;
