\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: request.fth
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
id: @(#)request.fth 1.1 07/01/24
purpose: USB HID requests
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

hex
headers

\ >dr-request constants specific to HID
h# 01 constant GET_REPORT
h# 02 constant GET_IDLE
h# 03 constant GET_PROTOCOL
h# 09 constant SET_REPORT
h# 0a constant SET_IDLE
h# 0b constant SET_PROTOCOL

\ >dr-value constants specific to HID
h# 0100 constant REPORT_IN
h# 0200 constant REPORT_OUT
h# 0300 constant REPORT_FEATURE

\ Keyboard report and LED buffers
8 constant /kbd-buf
1 constant /led-buf
0 value kbd-buf
0 value led-buf

: init-kbd-buf  ( -- )
   kbd-buf 0=  if
      /kbd-buf /led-buf + dma-alloc
      dup to kbd-buf /kbd-buf + to led-buf
   then
;
: free-kbd-buf  ( -- )
   kbd-buf  if
      kbd-buf /kbd-buf /led-buf + dma-free
      0 to kbd-buf 0 to led-buf
   then
;

: set-boot-protocol  ( -- error? )
   0 0 my-address ( interface ) 0 DR_HIDD DR_OUT or SET_PROTOCOL
   control-set-nostat
;

: set-idle  ( ms -- error? )
   >r 0 0 my-address ( interface ) r> 4 / 8 << ( 4ms ) DR_HIDD DR_OUT or SET_IDLE 
   control-set-nostat
;

\ Key modifiers

0 value    led-state
1 constant led-mask-num-lock
2 constant led-mask-caps-lock
4 constant led-mask-scroll-lock

: numlk?        ( -- flag )  led-state led-mask-num-lock    and  0<>  ;
: caps-lock?    ( -- flag )  led-state led-mask-caps-lock   and  0<>  ;
: scroll-lock?  ( -- flag )  led-state led-mask-scroll-lock and  0<>  ;


\ Keyboard LEDs

: (set-leds)  ( led -- )
   led-buf c!
   led-buf /led-buf my-address ( interface ) REPORT_OUT DR_HIDD DR_OUT or SET_REPORT
   control-set-nostat  drop
;
: set-leds     ( led-mask -- )  dup to led-state (set-leds)  ;
: toggle-leds  ( led-mask -- )  led-state xor    set-leds    ;


\ Retrieve usb keyboard report data.

: begin-scan  ( -- )
   kbd-buf /kbd-buf intr-in-pipe intr-in-interval  begin-intr-in
;
: end-scan  ( -- )  end-intr-in  ;

: get-data?  ( adr len -- actual )
   intr-in?  if  nip nip restart-intr-in exit  then	\ USB error; restart
   ?dup  if				( adr len actual )
      min tuck kbd-buf -rot move	( actual )
      restart-intr-in			( actual )
   else
      2drop 0				( actual )
   then
;

\ Sun adds ability to detect keyboard country from HID descriptor
\ for Sun type 6 and type 7 keyboards. This capability will be lost
\ in type 7c keyboards (which no longer have a country code), but
\ we still have to support existing hardware.
\
\ We read the HID descriptor from the interface. See HID device
\ class specification, from:
\     http://www.usb.org/developers/devclass_docs/HID1_11.pdf
\ Section 6.2.1 HID Descriptor defines this structure. Offset
\ 4 (listed as 4/1, offset 4, one byte long) is the bCountryCode
\ which this routine returns.
\ 
\ This method gets called infrequently, so we do our own alloc/free
\ rather than doing a top-level alloc/free like kbd-buf.

h# 10 constant /HID_DESC

: get-kbd-cntry-id ( -- country-code )
   /HID_DESC dma-alloc dup /HID_DESC 	( addr addr len )

   0 0 DR_HIDD DR_INTERFACE get-desc 2drop ( addr )
   dup 4 + c@ swap			( country-code addr )
   /HID_DESC dma-free			( country-code )
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
