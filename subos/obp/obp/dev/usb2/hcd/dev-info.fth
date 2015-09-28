\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: dev-info.fth
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
id: @(#)dev-info.fth 1.1 07/01/24
purpose: Data structures and manuipulation routines for all USB Controllers
\ See license at end of file

hex
headers

\ ---------------------------------------------------------------------------
\ device-info (DI): data structure internal to the OHCI driver.
\ It keeps track of assigned USB addresses.  For each USB device, its speed.
\ And for each endpoint in a device, its max packet size and data toggle bit.
\
\ This data structure, once created, stays around at all time.
\ ---------------------------------------------------------------------------

struct
   2 field >di-ep-maxpayload		\ Max packet size for the endpoint
   1 field >di-ep-in-toggle		\ Data toggle state
   1 field >di-ep-out-toggle		\ Data toggle state
constant /di-ep-struct

struct
   1 field >di-speed			\ Device speed
   1 field >di-hub			\ Hub address (EHCI only)
   1 field >di-port			\ Port number (EHCI only)
   1+					\ Padding for word alignment
   /di-ep-struct #max-endpoint * field >di-ep
					\ Endpoint structure
dup constant /di-entry

#max-dev * constant /di
0 value di				\ device-info

0 value cur-dev				\ Value of the last assigned usb address

: 'di     ( idx -- adr )       /di-entry * di +  ;
: 'di-ep  ( pipe idx -- adr )  'di >di-ep swap /di-ep-struct * +  ;

: di-speed!  ( speed idx -- )  'di >di-speed c!  ;
: di-speed@  ( idx -- speed )  'di >di-speed c@  ;
: di-hub!    ( hub idx -- )    'di >di-hub   c!  ;
: di-hub@    ( idx -- hub )    'di >di-hub   c@  ;
: di-port!   ( port idx -- )   'di >di-port  c!  ;
: di-port@   ( idx -- port )   'di >di-port  c@  ;

: 'di-maxpayload  ( pipe idx -- adr )  'di-ep >di-ep-maxpayload  ;
: di-maxpayload!  ( len pipe idx -- )  'di-maxpayload w!  ;
: di-maxpayload@  ( pipe idx -- len )  'di-maxpayload w@  ;

: di-in-data!   ( n pipe id -- )       'di-ep >di-ep-in-toggle  c!  ;
: di-in-data@   ( pipe id -- n )       'di-ep >di-ep-in-toggle  c@  ;
: di-out-data!  ( n pipe id -- )       'di-ep >di-ep-out-toggle c!  ;
: di-out-data@  ( pipe id -- n )       'di-ep >di-ep-out-toggle c@  ;
: di-in-data-toggle   ( pipe idx -- )  2dup di-in-data@  1 xor -rot di-in-data!   ;
: di-out-data-toggle  ( pipe idx -- )  2dup di-out-data@ 1 xor -rot di-out-data!  ;

: ok-to-add-device?  ( -- flag )  cur-dev 1+ #max-dev <  ;
: new-address  ( -- dev )
   cur-dev 1+ dup to cur-dev  
   /pipe0 0 cur-dev di-maxpayload!
;

: init-di  ( -- )
   \ allocate and initialize the device descriptors
   /di alloc-mem to di
   di /di erase
   /pipe0 0 0 di-maxpayload!		\ Default max payload
;

: init-struct  ( -- )
   init-di
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
