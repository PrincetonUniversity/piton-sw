\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: pkt-func.fth
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
id: @(#)pkt-func.fth 1.1 07/01/24
purpose: USB Data Packet Manipulation
\ See license at end of file

hex
headers

\ XXX This code assumes the device and configuration descriptors are ok.

false value class-in-dev?

: find-desc  ( adr type -- adr' )
   swap  begin  ?dup  while		( type adr )
      dup 1+ c@ 2 pick =  if  0  else  dup c@ +  then
					( type adr' )
   repeat  nip				( adr )
;

: find-intf-desc  ( adr intfidx -- adr )
   swap  begin				( intfidx adr )
      INTERFACE find-desc		( intfidx adr' )
   swap ?dup  while			( adr intfidx )
      1- swap				( intfidx' adr )
      dup c@ +				( intfidx adr' )
   repeat
;

: get-class  ( dev-adr cfg-adr intfidx -- protocol subclass class )
   rot dup 4 + c@ ?dup 0=  if		( cfg-adr intfidx dev-adr )
      false to class-in-dev?		\ Class is not in device descriptor
      drop find-intf-desc		( intf-adr )
      dup 5 + c@ swap dup 6 + c@ swap 7 + c@
   else					\ Class is in device-descriptor
      true to class-in-dev?		( cfg-adr intfidx dev-adr class )
      2swap 2drop			( dev-adr class )
      swap dup 5 + c@ swap 6 + c@
   then
;

: get-vid  ( adr -- vendor product rev )
   dup 8 + le-w@ swap dup d# 10 + le-w@ swap c + le-w@
;

: unicode$>ascii$  ( adr -- actual )
   dup c@ 2 - 2/ swap 2 + over 0  ?do	( actual adr' )
      dup i 2* 1+ + c@ 0=  if		\ ASCII
         dup i 2* + c@			( actual adr c )
      else				\ Non-ascii
         ascii ?			( actual adr c )
      then
      over 2 - i + c!			( actual adr )
   loop  drop
;

\ XXX In the future, maybe we can decode more languages.
: encoded$>ascii$  ( adr lang -- actual )
   drop unicode$>ascii$
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
