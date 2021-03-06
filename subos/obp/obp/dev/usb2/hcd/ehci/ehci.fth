\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ehci.fth
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
id: @(#)ehci.fth 1.1 07/01/24
purpose: Driver for EHCI USB Controller
\ See license at end of file

hex
headers

defer init-extra	' noop to init-extra
defer end-extra		' noop to end-extra

true value first-open?
0 value open-count
0 value ehci-reg
0 value op-reg-offset

h# 100 constant /regs

\ Configuration space registers
my-address my-space          encode-phys
                           0 encode-int encode+ 0 encode-int encode+
\ EHCI operational registers
0 0    my-space  0200.0010 + encode-phys encode+
                           0 encode-int encode+  /regs encode-int encode+
" reg" property

: map-regs  ( -- )
   4 my-w@  6 or  4 my-w!
   0 0 my-space h# 0200.0010 + /regs  map-in to ehci-reg
;
: unmap-regs  ( -- )
   4 my-w@  7 invert and  4 my-w!
   ehci-reg  /regs  map-out  0 to ehci-reg
;

: ehci-reg@  ( idx -- data )  ehci-reg + rl@  ;
: ehci-reg!  ( data idx -- )  ehci-reg + rl!  ;

: ll ( idx -- )  dup h# f and 0=  if  cr 2 u.r ."   "  else  drop  then  ;
: dump-ehci  ( -- )  100 0 do  i ll i ehci-reg@ 8 u.r space 4  +loop  ;

\ Host controller capability registers
: hcsparams@  ( -- data )  4 ehci-reg@  ;
: hccparams@  ( -- data )  8 ehci-reg@  ;
: (hcsp-portroute@)  ( -- d.lo,hi )  h# c ehci-reg@  h# 10 ehci-reg@  ;
: hcsp-portroute@  ( port -- data )
   (hcsp-portroute@) rot
   dup >r 7 >  if  8 - nip  else  drop  then r>
   4 * >> h# f and
;

\ Host Controller operational registers
: op-reg@    ( idx -- data )  op-reg-offset + ehci-reg@  ;
: op-reg!    ( data idx -- )  op-reg-offset + ehci-reg!  ;

: usbcmd@    ( -- data )  0 op-reg@  ;
: usbcmd!    ( data -- )  0 op-reg!  ;
: flush-reg  ( -- )       usbcmd@ drop  ;
: usbsts@    ( -- data )  4 op-reg@  ;
: usbsts!    ( data -- )  4 op-reg! flush-reg  ;
: usbintr@   ( -- data )  8 op-reg@  ;
: usbintr!   ( data -- )  8 op-reg!  ;
: frindex@   ( -- data )  h# c op-reg@  ;
: frindex!   ( data -- )  h# c op-reg!  ;
: ctrldsseg@ ( -- data )  h# 10 op-reg@  ;
: ctrldsseg! ( data -- )  h# 10 op-reg!  ;
: periodic@  ( -- data )  h# 14 op-reg@  ;
: periodic!  ( data -- )  h# 14 op-reg!  ;
: asynclist@ ( -- data )  h# 18 op-reg@  ;
: asynclist! ( data -- )  h# 18 op-reg!  ;

: cfgflag@   ( -- data )  h# 40 op-reg@  ;
: cfgflag!   ( data -- )  h# 40 op-reg! flush-reg  ;
: portsc@    ( port -- data )  4 * h# 44 + op-reg@  ;
: portsc!    ( data port -- )  4 * h# 44 + op-reg!  flush-reg  ;

: halted?    ( -- flag )  usbsts@ h# 1000 and  ;
: halt-wait  ( -- )       begin  halted?  until  ;

: process-hc-status  ( -- )  
   usbsts@ dup usbsts!		\ Clear interrupts and errors
   h# 10  and  if  " Host system error" USB_ERR_HCHALTED set-usb-error  then
;

: doorbell-wait  ( -- )
   begin  usbsts@ h# 20 and  until	\ Wait until interrupt on async advance bit is set
   h# 20 usbsts!			\ Clear status
;
: ring-doorbell  ( -- )
   usbcmd@ h# 40 or usbcmd!		\ Interrupt on async advance doorbell
   usbcmd@ drop
   doorbell-wait
;

external

: start-usb  ( -- )
   ehci-reg dup 0=  if  map-regs  then
   halted?  if  usbcmd@ 1 or usbcmd!  then
   0=  if  unmap-regs  then
;

: stop-usb   ( -- )
   ehci-reg dup 0=  if  map-regs  then
   usbcmd@ 31 invert and usbcmd!
   halt-wait
   0=  if  unmap-regs  then
;

: reset-usb  ( -- )
   ehci-reg dup 0=  if  map-regs  then
   usbcmd@ 2 or 1 invert and usbcmd!	\ HCReset
   d# 10 0  do
      usbcmd@ 2 and  0=  ?leave
      1 ms
   loop
   0=  if  unmap-regs  then
;

: test-port-begin  ( port -- )
   ehci-reg dup 0=  if  map-regs  then
   swap dup portsc@ h# 4.0000 or swap portsc!
   0=  if  unmap-regs  then
;

: test-port-end  ( port -- )
   ehci-reg dup 0=  if  map-regs  then
   swap dup portsc@ h# 7.0000 invert and swap portsc!
   0=  if  unmap-regs  then
;

headers

: init-ehci-regs  ( -- )
   0 ctrldsseg!
   0 periodic!
   0 asynclist!
   0 usbintr!
;

: reset-port  ( port -- )
   dup portsc@ h# 100 or 4 invert and over portsc!	\ Reset port
   d# 50 ms
   dup portsc@ h# 100 invert and swap portsc!
   d# 10 ms
;

: power-port   ( port -- )  dup portsc@ h# 1000 or swap portsc!  2 ms  ;

: disown-port  ( port -- )  dup portsc@ h# 2000 or swap portsc!  ;

: claim-ownership  ( -- )
   1 cfgflag!				\ Claim ownership to all ports
   1 ms

   \ Power on ports if necessary
   hcsparams@ h# 10 and  if
      hcsparams@ h# f and 0  ?do
         i power-port
      loop
   then
;

external
: open  ( -- flag )
   parse-my-args
   open-count 0=  if
      map-regs
      first-open?  if
         false to first-open?
         0 ehci-reg@  h# ff and to op-reg-offset
         reset-usb
         init-ehci-regs
         start-usb
         claim-ownership
         init-struct
         init-extra
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
