\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: hub.fth
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
id: @(#)hub.fth 1.1 07/01/04
purpose: USB Hub Driver
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

\ Utilities (Sun)
fload ${BP}/dev/utilities/misc.fth

hex

" usb_hub" encode-string  " device_type"     property
1          encode-int     " #address-cells"  property	\ SUN note - 1 cell
0          encode-int     " #size-cells"     property

external

\ A usb device node defines an address space of the form
\ "port,interface".  port and interface are both integers.
\ parse-2int converts a text string (e.g. "3,1") into a pair of
\ binary integers.

\ : decode-unit  ( addr len -- interface port )  parse-2int  ;
\ : encode-unit  ( interface port -- adr len )
\    >r  <# u#s drop ascii , hold r> u#s u#>	\ " port,interface"
\ ;

\ SUN Note - single-cell unit address
: decode-unit  ( addr len -- lun )  push-hex  $number  if  0  then  pop-base  ;
: encode-unit  ( lun -- adr len )   push-hex (u.) pop-base  ;

: open   ( -- flag )  true  ;
: close  ( -- )  ;

headers

: is-hub20?  ( -- flag )
   " high-speed" get-my-property 0=  if  2drop true  else  false  then
;
: hub-id  ( -- dev )
   " assigned-address" get-my-property  if
      ." Property: assigned-address not found."  abort
   then
   decode-int nip nip
;
: probe-hub  ( -- )
   ['] hub-id catch 0=  if
      is-hub20?  if
         dup encode-int " hub20-dev" property
      then
      probe-hub-xt execute
   then
;

probe-hub

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
