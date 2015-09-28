\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: common.fth
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
id: @(#)common.fth 1.1 07/01/24
purpose: USB device driver common routines
\ See license at end of file

headers
hex

fload ${BP}/dev/usb2/error.fth			\ USB error definitions
fload ${BP}/dev/usb2/pkt-data.fth		\ Packet data definitions
fload ${BP}/dev/usb2/hcd/hcd-call.fth		\ HCD interface

0 value device
0 value configuration

0 value bulk-in-pipe
0 value bulk-out-pipe
0 value /bulk-in-pipe
0 value /bulk-out-pipe

0 value intr-in-pipe
0 value intr-out-pipe
0 value intr-in-interval
0 value intr-out-interval
0 value /intr-in-pipe
0 value /intr-out-pipe

0 value iso-in-pipe
0 value iso-out-pipe
0 value /iso-in-pipe
0 value /iso-out-pipe

false instance value debug?

: debug-on  ( -- )  true to debug?  ;

: get-int-property  ( name$ -- n )
  get-my-property  if  0  else  decode-int nip nip  then
;

: init  ( -- )
   " assigned-address"  get-int-property  to device
   " configuration#"    get-int-property  to configuration
   " bulk-in-pipe"      get-int-property  to bulk-in-pipe
   " bulk-out-pipe"     get-int-property  to bulk-out-pipe
   " bulk-in-size"      get-int-property  to /bulk-in-pipe
   " bulk-out-size"     get-int-property  to /bulk-out-pipe
   " iso-in-pipe"       get-int-property  to iso-in-pipe
   " iso-out-pipe"      get-int-property  to iso-out-pipe
   " iso-in-size"       get-int-property  to /iso-in-pipe
   " iso-out-size"      get-int-property  to /iso-out-pipe
   " intr-in-pipe"      get-int-property  to intr-in-pipe
   " intr-out-pipe"     get-int-property  to intr-out-pipe
   " intr-in-size"      get-int-property  to /intr-in-pipe
   " intr-out-size"     get-int-property  to /intr-out-pipe
   " intr-in-interval"  get-int-property  to intr-in-interval
   " intr-out-interval" get-int-property  to intr-out-interval
;

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
