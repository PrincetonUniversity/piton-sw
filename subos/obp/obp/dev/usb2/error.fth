\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: error.fth
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
id: @(#)error.fth 1.1 07/01/24
purpose: USB error codes for use by USB device drivers
\ See license at end of file

headers
hex

\ Common error codes so that device drivers are EHCI/OHCI/UHCI independent
0000.0000 constant USB_ERR_NONE
0000.0001 constant USB_ERR_CRC
0000.0002 constant USB_ERR_BITSTUFFING
0000.0004 constant USB_ERR_DATATOGGLEMISMATCH
0000.0008 constant USB_ERR_STALL
0000.0010 constant USB_ERR_DEVICENOTRESPONDING
0000.0020 constant USB_ERR_PIDCHECKFAILURE
0000.0040 constant USB_ERR_UNEXPECTEDPIC
0000.0080 constant USB_ERR_DATAOVERRUN
0000.0100 constant USB_ERR_DATAUNDERRUN
0000.0200 constant USB_ERR_BUFFEROVERRUN
0000.0400 constant USB_ERR_BUFFERUNDERRUN
0000.0800 constant USB_ERR_NOTACCESSED
0000.1000 constant USB_ERR_HCHALTED
0000.2000 constant USB_ERR_DBUFERR
0000.4000 constant USB_ERR_BABBLE
0000.8000 constant USB_ERR_NAK
0001.0000 constant USB_ERR_MICRO_FRAME
0002.0000 constant USB_ERR_SPLIT
0004.0000 constant USB_ERR_HCERROR
0008.0000 constant USB_ERR_HOSTERROR
1000.0000 constant USB_ERR_TIMEOUT
2000.0000 constant USB_ERR_INV_OP
4000.0000 constant USB_ERR_BAD_PARAM
8000.0000 constant USB_ERR_UNKNOWN


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
