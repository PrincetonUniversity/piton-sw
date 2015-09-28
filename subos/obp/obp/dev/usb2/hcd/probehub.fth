\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: probehub.fth
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
id: @(#)probehub.fth 1.1 07/01/04
purpose: USB Hub Probing Code
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

hex

[ifndef] set-usb20-char
: set-usb20-char  ( port dev -- )  2drop  ;
[then]

: power-hub-port   ( port -- )      PORT_POWER  DR_PORT set-feature drop  ;
: reset-hub-port   ( dev port -- )  PORT_RESET  DR_PORT set-feature drop  d# 20 ms  ;

: probe-hub-port  ( hub-dev port -- )
   swap set-target			( port )
   dup reset-hub-port			( port )

   gen-desc-buf 4 2 pick DR_PORT get-status nip  if
      ." Failed to get port status for port " u. cr
      exit
   then					( port )

   gen-desc-buf c@ 1 and 0=  if	 drop exit  then	\ No device connected
   ok-to-add-device?     0=  if  drop exit  then	\ Can't add another device

   new-address				( port dev )
   gen-desc-buf le-w@ h# 600 and 9 >> over di-speed!
					( port dev )
   2dup set-usb20-char			( port dev )

   0 set-target				( port dev )	\ Address it as device 0
   dup set-address  if  2drop exit  then ( port dev )	\ Assign it usb addr dev
   dup set-target			( port dev )	\ Address it as device dev
   make-device-node			( )
;

external
: probe-hub  ( dev -- )
   dup set-target			( hub-dev )
   gen-desc-buf 8 0 0 HUB DR_HUB get-desc nip  if
      ." Failed to get hub descriptor" cr
      exit
   then

   gen-desc-buf dup 5 + c@ swap		( hub-dev #2ms adr )
   2 + c@ 1+				( hub-dev #2ms #ports )

   " configuration#" get-int-property set-config	( hub-dev #2ms #ports usberr )
   if  2drop  ." Failed to set config for hub at " u. cr exit  then

   tuck  1  ?do  i power-hub-port  loop  2* ms
					( hub-dev #ports )
   d# 100 ms

   ( hub-dev #ports ) 1  ?do
      dup i ['] probe-hub-port  catch  if
         2drop
         ." Failed to probe hub port " i u. cr
      then
   loop  drop
;

: probe-hub-xt  ( -- adr )  ['] probe-hub  ;

\ Sun Note - create PCI compatible property for hcd.

fload ${BP}/dev/pci/compatible.fth
fload ${BP}/dev/pci/compatible-prop.fth

make-compatible-property

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
