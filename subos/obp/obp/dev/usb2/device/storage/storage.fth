\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: storage.fth
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
id: @(#)storage.fth 1.1 07/01/04
purpose: USB Mass Storage device driver loader
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

headers
hex

" scsi-usb" device-type
0 encode-int " #size-cells"    property
2 encode-int " #address-cells" property	\ SUN Note - scsi has two address cells


external

\ SUN Note - scsi has two address cells.
: encode-unit ( l h -- adr,len )  swap <# u#s drop ascii , hold u#s u#> ;
: decode-unit  ( addr len -- unit# target# )  parse-2int  ;

\ These routines may be called by the children of this device.
\ This card has no local buffer memory for the ATAPI device, so it
\ depends on its parent to supply DMA memory.  For a device with
\ local buffer memory, these routines would probably allocate from
\ that local memory.

h#  800 constant low-speed-max
h# 2000 constant full-speed-max
h# 4000 constant high-speed-max
: my-max  ( -- n )
   " low-speed"  get-my-property 0=  if  2drop low-speed-max  exit  then
   " full-speed" get-my-property 0=  if  2drop full-speed-max exit  then
   high-speed-max
;
: max-transfer ( -- n )
   " max-transfer" ['] $call-parent catch if
      2drop my-max
   then
   my-max min
;

headers

fload ${BP}/dev/usb2/device/common.fth		\ USB device driver common routines
fload ${BP}/dev/usb2/device/storage/scsi.fth	\ High level SCSI routines
fload ${BP}/dev/usb2/device/storage/atapi.fth	\ ATAPI interface support
fload ${BP}/dev/usb2/device/storage/hacom.fth	\ Basic SCSI routines

new-device
   " disk" device-name
   fload ${BP}/dev/usb2/device/storage/scsidisk.fth
finish-device

init


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
