\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: memstack.fth
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
id: @(#)memstack.fth 1.4 06/10/18
purpose: 
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

struct
   /n field >stack.next
   /n field >stack.mem-list
   /n field >stack.mem64-list
   /n field >stack.io-list
   /n field >stack.bar-info
constant /stacknode

variable stack-base stack-base off
variable pci-mem64list pci-mem64list off

: get-pointers ( -- reg mem mem64 io )
   bar-struct-addr pci-memlist @  pci-mem64list @ pci-io-list @
;
: set-pointers ( reg mem mem64 io -- )
   pci-io-list !  pci-mem64list ! pci-memlist ! to bar-struct-addr
;

: push-stack ( reg new-mem new-mem64 new-io -- )
   /stacknode alloc-mem >r		( reg new-mem new-mem64 new-io )( R: node )
   get-pointers				( reg new-mem new-mem64 new-io reg mem mem64 io )
   r@ >stack.io-list !			( reg new-mem new-mem64 new-io reg mem mem64 )
   r@ >stack.mem64-list !		( reg new-mem new-mem64 new-io reg mem )
   r@ >stack.mem-list !			( reg new-mem new-mem64 new-io reg )
   r@ >stack.bar-info !			( reg new-mem new-mem64 new-io )
   stack-base @ r@ >stack.next !	( reg new-mem new-mem64 new-io )
   set-pointers				(  )
   r> stack-base !			(  )( R: )
;

: pop-stack ( -- reg prev-mem prev-mem64 prev-io )
   get-pointers				( reg prev-mem prev-mem64 prev-io )
   stack-base @ >r			( reg prev-mem prev-mem64 prev-io )( R: base )
   r@ >stack.next @ stack-base !	( reg prev-mem prev-mem64 prev-io )
   r@ >stack.bar-info @			( reg prev-mem prev-mem64 prev-io reg )
   r@ >stack.mem-list @		( reg prev-mem prev-mem64 prev-io reg mem )
   r@ >stack.mem64-list @		( reg prev-mem prev-mem64 prev-io reg mem mem64 )
   r@ >stack.io-list @			( reg prev-mem prev-mem64 prev-io reg mem mem64 io )
   set-pointers				( reg prev-mem prev-mem64 prev-io )
   r> /stacknode free-mem		( reg prev-mem prev-mem64 prev-io )( R: )
;
