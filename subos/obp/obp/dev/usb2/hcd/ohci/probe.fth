\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: probe.fth
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
id: @(#)probe.fth 1.1 07/01/04
purpose: OHCI USB Controller probe
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

hex
headers

: enable-root-hub-port  ( port -- )
   >r
   h# 1.0002 r@ hc-rh-psta!		\ enable port
   10 r@ hc-rh-psta!			\ reset port
   r@ d# 10 0  do
      d# 10 ms
      dup hc-rh-psta@ 10.0000 and  ?leave
   loop  drop
   r@ hc-rh-psta@ 10.0000 and 0=  if  abort  then
   h# 1f.0000 r> hc-rh-psta!		\ clear status change bits
   100 ms
;

: probe-root-hub-port  ( port -- )
   dup hc-rh-psta@ 1 and 0=  if  drop exit  then	\ No device connected
   ok-to-add-device? 0=  if  drop exit  then		\ Can't add another device

   dup enable-root-hub-port		( port )
   new-address				( port dev )
   over hc-rh-psta@ 200 and  if  speed-low  else  speed-full  then over di-speed!

   0 set-target				( port dev )	\ Address it as device 0
   dup set-address  if  2drop exit  then ( port dev )	\ Assign it usb addr dev
   dup set-target			( port dev )	\ Address it as device dev
   swap 1+ swap					\ port numbers are 1-based
   make-device-node			( )
;

false value ports-powered?

external
: power-usb-ports  ( -- )
   hc-rh-desa@  dup h# 200  and  0=  if
      \ ports are power switched
      hc-rh-stat@ h# 1.0000 or hc-rh-stat!	\ power all ports
      hc-rh-desb@ d# 17 >> over h# ff and 0  ?do
         dup 1 i << and  if
            i hc-rh-psta@  h# 100 or i hc-rh-psta!	\ power port
         then
      loop  drop
   then  drop
   potpgt 2* ms			\ Wait until powergood
   true to ports-powered?
;

: probe-usb  ( -- )
   \ Power on ports
   ports-powered? not  if  power-usb-ports  then

   \ Setup PowerOnToPowerGoodTime and OverCurrentProtectionMode
   hc-rh-desA@  dup h# 00ff.ffff and
   h# 800 or potpgt d# 24 << or  hc-rh-desA!	\ per-port over-current status

   \ Probe each port
   alloc-pkt-buf
   h# ff and 0 do
      i ['] probe-root-hub-port catch  if
         drop ." Failed to probe root port " i u. cr
      then
   loop
   free-pkt-buf
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
