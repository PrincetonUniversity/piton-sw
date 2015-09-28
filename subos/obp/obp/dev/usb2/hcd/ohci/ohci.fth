\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ohci.fth
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
id: @(#)ohci.fth 1.1 07/01/22
purpose: Driver for OHCI USB Controller
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

hex
headers

defer end-extra				' noop to end-extra

\ Configuration space registers
my-address my-space          encode-phys
                           0 encode-int encode+ 0 encode-int encode+
\ OHCI operational registers
0 0    my-space  0200.0010 + encode-phys encode+
                           0 encode-int encode+  1000 encode-int encode+

" reg" property

1 constant potpgt			\ PowerONToPowerGoodTime

true value first-open?
0 value open-count
0 value ohci-reg

: map-regs  ( -- )
   4 my-w@  6 or  4 my-w!
   0 0 my-space h# 0200.0010 + 1000  map-in to ohci-reg
;

: unmap-regs  ( -- )
   ohci-reg  1000  map-out  0 to ohci-reg
;

: ohci-reg@  ( idx -- data )  ohci-reg + rl@  ;
: ohci-reg!  ( data idx -- )  ohci-reg + rl!  ;

: hc-cntl@  ( -- data )   4 ohci-reg@  ;
: hc-cntl!  ( data -- )   4 ohci-reg!  ;
: hc-stat@  ( -- data )   8 ohci-reg@  ;
: hc-cmd!   ( data -- )   8 ohci-reg!  ;
: hc-intr@  ( -- data )   c ohci-reg@  ;
: hc-intr!  ( data -- )   c ohci-reg!  ;
: hc-hcca@  ( -- data )  18 ohci-reg@  ;
: hc-hcca!  ( data -- )  18 ohci-reg!  ;

: hc-rh-desA@  ( -- data )  48 ohci-reg@  ;
: hc-rh-desA!  ( data -- )  48 ohci-reg!  ;
: hc-rh-desB@  ( -- data )  4c ohci-reg@  ;
: hc-rh-desB!  ( data -- )  4c ohci-reg!  ;
: hc-rh-stat@  ( -- data )  50 ohci-reg@  ;
: hc-rh-stat!  ( data -- )  50 ohci-reg!  ;

: hc-rh-psta@  ( port -- data )  4 * 54 + ohci-reg@  ;
: hc-rh-psta!  ( data port -- )  4 * 54 + ohci-reg!  ;

: hc-cntl-clr  ( bit-mask -- )  hc-cntl@ swap invert and hc-cntl!  ;
: hc-cntl-set  ( bit-mask -- )  hc-cntl@ swap or hc-cntl!  ;

: reset-usb  ( -- )
   1 hc-rh-stat!		\ power-off root hub
   1 hc-cmd!			\ reset usb host controller
   10 ms
;

: init-ohci-regs  ( -- )
   hcca-phys hc-hcca!		\ physical address of hcca

   81 hc-cntl!			\ USB operational, 2:1 ControlBulkServiceRatio
   d# 10 ms

   a668.2edf 34			\ HcFmInterval

\ Sometimes the HcFmInterval register will not hold it's value 
\ after the first write.  This was seen primarily on the ULI 1575 
\ controller, but also reported on the 1535+. 
\ Loop on the write to ensure it has completed.
   d# 10 0 do
      2dup ohci-reg!
      2dup ohci-reg@ = if
         leave
      then
      d# 10 ms
   loop
   ohci-reg@ <> if
      cmn-error[ " Unable to write to HcFmInterval Register" ]cmn-end
   then

   2580 40 ohci-reg!		\ HcPeriodicStart
;

: (process-hc-status)  ( -- )
   hc-intr@ dup hc-intr!
   h# 10 and  if  " Unrecoverable error" USB_ERR_HCHALTED set-usb-error  then
;
' (process-hc-status) to process-hc-status

: wait-for-frame  ( -- )  begin  hc-intr@ 4 and  until  ;
: next-frame      ( -- )  4 hc-intr!  wait-for-frame    ;

external
\ Kick the USB controller into operation mode.
: start-usb     ( -- )  c0 hc-cntl-clr 80 hc-cntl-set  ;
: suspend-usb   ( -- )  c0 hc-cntl-set  ;

: open  ( -- flag )
   parse-my-args
   open-count 0=  if
      map-regs
      first-open?  if
         false to first-open?
         reset-usb
         init-struct
         init-ohci-regs
      then
      alloc-dma-buf
   then
   open-count 1+ to open-count
   true
;

: close  ( -- )
   open-count 1- to open-count
   end-extra
   open-count 0=  if  free-dma-buf unmap-regs  then
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
