\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: hcd-call.fth
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
id: @(#)hcd-call.fth 1.1 07/01/04
purpose: Functional interface to HCD driver provided for all usb children
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

\ All hub drivers must forward all the following methods for their children.
\ A device driver may include only a subset of the methods it needs.

hex
external

: dma-alloc    ( size -- virt )              " dma-alloc" $call-parent    ;
: dma-free     ( virt size -- )              " dma-free" $call-parent     ;
: dma-sync     ( virt phys size -- )         " dma-sync" $call-parent     ;
: dma-map-in   ( virt size cache? -- phys )  " dma-map-in" $call-parent   ;
: dma-map-out  ( virt phys size -- )         " dma-map-out" $call-parent  ;

: set-target  ( device -- )  " set-target" $call-parent  ;
: probe-hub-xt  ( -- adr )   " probe-hub-xt" $call-parent  ;
: set-pipe-maxpayload  ( size len -- ) " set-pipe-maxpayload" $call-parent  ;

\ Control pipe operations
: control-get  ( adr len idx value rtype req -- actual usberr )
   " control-get" $call-parent  
;
: control-set  ( adr len idx value rtype req -- usberr )
   " control-set" $call-parent
;
: control-set-nostat  ( adr len idx value rtype req -- usberr )
   " control-set-nostat" $call-parent
;
: get-desc  ( adr len lang didx dtype rtype -- actual usberr )
   " get-desc" $call-parent
;
: get-status  ( adr len intf/endp rtype -- actual usberr )
   " get-status" $call-parent
;
: set-config  ( cfg -- usberr )
   " set-config" $call-parent
;
: set-interface  ( alt intf -- usberr )
   " set-interface" $call-parent
;
: clear-feature  ( intf/endp feature rtype -- usberr )
   " clear-feature" $call-parent
;
: set-feature  ( intf/endp feature rtype -- usberr )
   " set-feature" $call-parent
;
: unstall-pipe  ( pipe -- )  " unstall-pipe" $call-parent  ;

\ Bulk pipe operations
: bulk-in  ( buf len pipe -- actual usberr )
   " bulk-in" $call-parent
;
: bulk-out  ( buf len pipe -- usberr )
   " bulk-out" $call-parent
;
: begin-bulk-in  ( buf len pipe -- )
   " begin-bulk-in" $call-parent
;
: bulk-in?  ( -- actual usberr )
   " bulk-in?" $call-parent
;
: restart-bulk-in  ( -- )
   " restart-bulk-in" $call-parent
;
: end-bulk-in  ( -- )
   " end-bulk-in" $call-parent
;
: set-bulk-in-timeout  ( t -- )
   " set-bulk-in-timeout" $call-parent
;

\ Interrupt pipe operations
: begin-intr-in  ( buf len pipe interval -- )
   " begin-intr-in" $call-parent
;
: intr-in?  ( -- actual usberr )
   " intr-in?" $call-parent
;
: restart-intr-in  ( -- )
   " restart-intr-in" $call-parent
;
: end-intr-in  ( -- )
   " end-intr-in" $call-parent
;

headers

\ LICENSE_BEGIN
\ Copyright (c) 2006 FirmWorks
\ 
\ Permission is hereby granted, free of charge, to any person obtaining
\ a copy of this software and associated documentation files (the
\ "Software"), to deal in the Software without restriction, including
\ without limitation the rights to use, copy, modify, merge, publish,
\ distribute, sublicense, and/or sell copies of the Software, and to
\ permit persons to whom the Software is furnished to do so, subject to
\ the following conditions:
\ 
\ The above copyright notice and this permission notice shall be
\ included in all copies or substantial portions of the Software.
\ 
\ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
\ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
\ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
\ NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
\ LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
\ OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
\ WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
\
\ LICENSE_END
