\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bulk.fth
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
id: @(#)bulk.fth 1.3 07/06/22
purpose: EHCI USB Controller bulk pipes transaction processing
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

hex
headers

d# 500 instance value bulk-in-timeout
d# 6000 constant bulk-out-timeout

0 instance value bulk-in-pipe
0 instance value bulk-out-pipe

0 instance value bulk-in-qh
0 instance value bulk-in-qtd

: bulk-in-data@         ( -- n )  bulk-in-pipe  target di-in-data@   di-data>td-data  ;
: bulk-out-data@        ( -- n )  bulk-out-pipe target di-out-data@  di-data>td-data  ;
: bulk-in-data!         ( n -- )  td-data>di-data bulk-in-pipe  target di-in-data!   ;
: bulk-out-data!        ( n -- )  td-data>di-data bulk-out-pipe target di-out-data!  ;
: toggle-bulk-in-data   ( -- )    bulk-in-pipe  target di-in-data-toggle   ;
: toggle-bulk-out-data  ( -- )    bulk-out-pipe target di-out-data-toggle  ;
: fixup-bulk-in-data    ( qh -- data )
   usb-error USB_ERR_STALL and  if
      drop bulk-in-pipe h# 80 or unstall-pipe 
      TD_TOGGLE_DATA0
   else
      >hcqh-overlay >hcqtd-token le-l@
   then
   bulk-in-data!
;
: fixup-bulk-out-data   ( qh -- data )
   usb-error USB_ERR_STALL and  if
      drop bulk-out-pipe unstall-pipe
      TD_TOGGLE_DATA0
   else
      >hcqh-overlay >hcqtd-token le-l@
   then
   bulk-out-data!
;

: process-bulk-args  ( buf len pipe timeout -- )
   to timeout
   clear-usb-error
   set-my-dev
   set-my-char
   2dup hcd-map-in  to my-buf-phys to /my-buf to my-buf
;

: alloc-bulk-qhqtds  ( -- qh qtd )
   my-buf-phys /my-buf cal-#qtd dup to my-#qtds
   alloc-qhqtds
;

: fill-bulk-io-qtds  ( dir qtd -- )
   my-#qtds 0  do				( dir qtd )
      my-buf my-buf-phys /my-buf 3 pick fill-qtd-bptrs
						( dir qtd /bptr )
      2 pick over d# 16 << or			( dir qtd /bptr token )
      TD_C_ERR3 or TD_STAT_ACTIVE or		( dir qtd /bptr token' )
      3 pick TD_PID_IN =  if			( dir qtd /bptr token' )
         bulk-in-data@  toggle-bulk-in-data
      else
         bulk-out-data@ toggle-bulk-out-data
      then  or					( dir qtd /bptr token' )
      2 pick >hcqtd-token le-l!			( dir qtd /bptr )
      my-buf++					( dir qtd )
      dup fixup-last-qtd			( dir qtd )
      >qtd-next l@				( dir qtd' )
   loop  2drop					( )
;

external

: set-bulk-in-timeout  ( t -- )  ?dup  if  to bulk-in-timeout  then  ;

: begin-bulk-in  ( buf len pipe -- )
   debug?  if  ." begin-bulk-in" cr  then
   bulk-in-qh  if  3drop exit  then		\ Already started

   dup to bulk-in-pipe
   bulk-in-timeout process-bulk-args
   alloc-bulk-qhqtds  to bulk-in-qtd  to bulk-in-qh

   \ IN qTDs
   TD_PID_IN bulk-in-qtd fill-bulk-io-qtds

   \ Start bulk in transaction
   bulk-in-qh pt-bulk fill-qh
   bulk-in-qh insert-qh
;

: bulk-in?  ( -- actual usberr )
   bulk-in-qh 0=  if  0 USB_ERR_INV_OP exit  then
   clear-usb-error
   bulk-in-qh dup sync-qhqtds
   qh-done?  if
      bulk-in-qh error?  if
         0
      else
         bulk-in-qtd dup bulk-in-qh >qh-#qtds l@ get-actual
         over >qtd-buf rot >qtd-pbuf l@ 2 pick dma-sync
      then
      usb-error
      bulk-in-qh fixup-bulk-in-data
\ XXX Ethernet does not like process-hc-status!
\      process-hc-status
   else
      0 usb-error
   then
;

headers
: restart-bulk-in-qtd  ( qtd -- )
   begin  ?dup  while
      dup >hcqtd-bptr0 dup le-l@ h# ffff.f000 and swap le-l!
      dup >qtd-/buf l@ d# 16 <<
      TD_STAT_ACTIVE or TD_C_ERR3 or TD_PID_IN or
      bulk-in-data@ or  toggle-bulk-in-data
      over >hcqtd-token le-l!
      >qtd-next l@
   repeat
;

external
: restart-bulk-in  ( -- )
   debug?  if  ." restart-bulk-in" cr  then
   bulk-in-qh 0=  if  exit  then

   \ Setup qTD again
   bulk-in-qtd restart-bulk-in-qtd

   \ Setup QH again
   bulk-in-qh >hcqh-endp-char dup le-l@ QH_TD_TOGGLE invert and swap le-l!
   bulk-in-qtd >qtd-phys l@ bulk-in-qh >hcqh-overlay >hcqtd-next le-l!
   bulk-in-qh sync-qhqtds
;

: end-bulk-in  ( -- )
   debug?  if  ." end-bulk-in" cr  then
   bulk-in-qh 0=  if  exit  then
   bulk-in-qtd map-out-bptrs
   bulk-in-qh dup fixup-bulk-in-data
   dup remove-qh  free-qhqtds
   0 to bulk-in-qh  0 to bulk-in-qtd
;

: bulk-in  ( buf len pipe -- actual usberr )
   debug?  if  ." bulk-in" cr  then
   dup to bulk-in-pipe
   bulk-in-timeout process-bulk-args
   alloc-bulk-qhqtds  to my-qtd  to  my-qh

   \ IN qTDs
   TD_PID_IN my-qtd fill-bulk-io-qtds

   \ Start bulk in transaction
   my-qh pt-bulk fill-qh
   my-qh insert-qh

   \ Process results
   my-qh done?  if
      0						( actual )	\ System error, timeout
   else
      my-qh error?  if
         0					( actual )	\ USB error
      else
         my-qtd dup my-#qtds get-actual				( qtd actual )
         over >qtd-buf l@ rot >qtd-pbuf l@ 2 pick dma-sync	( actual )
      then
   then

   usb-error					( actual usberr )
   my-qtd map-out-bptrs
   my-qh dup fixup-bulk-in-data
   dup remove-qh  free-qhqtds
;

: bulk-out  ( buf len pipe  -- usberr )
   debug?  if  ." bulk-out" cr  then
   dup to bulk-out-pipe
   bulk-out-timeout process-bulk-args
   alloc-bulk-qhqtds  to my-qtd  to my-qh

   \ OUT qTDs
   TD_PID_OUT my-qtd fill-bulk-io-qtds

   \ Start bulk out transaction
   my-qh pt-bulk fill-qh
   my-qh insert-qh

   \ Process results
   my-qh done? 0=  if  my-qh error? drop  then

   usb-error					( actual usberr )
   my-qtd map-out-bptrs
   my-qh dup fixup-bulk-out-data
   dup remove-qh  free-qhqtds
;

headers

: (end-extra)  ( -- )  end-bulk-in  ;


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
