\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: usb-japanese.fth
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
\ id: @(#)usb-japanese.fth 1.2 06/12/12
\ purpose: 
\ copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
\

decimal

\ Keyboard country code assigned by HID doc # N86A-8811-0150-E.
15 keyboard: Japanese

\  normal  	shifted      altg      key#     key change
\  -------      -------      -------   -----    ----------
   yen          ascii |      ascii _    137     allk	\ lft of 1, type-6 kb
                                        53      nk  	\ lft of 1, type-7 kb
                ascii "                 31      sk	\ 2
                ascii &                 35      sk      \ 6
                ascii '                 36      sk	\ 7
                ascii (                 37      sk	\ 8
                ascii )                 38      sk  	\ 9
                                        39      sk	\ 0
                ascii =                 45      sk	\ rt of 0
   ascii ^      ascii ~                 46      nsk	\ rt of -
   ascii @      ascii `      ascii "    47      allk	\ rt of p
   ascii [      ascii {      degrees    48      allk	\ rt of @
                ascii +                 51      sk	\ rt of l
   ascii :      ascii *                 52      nsk	\ rt of ;
   ascii ]      ascii }                 50      nsk	\ rt of :
   ascii \      ascii _                 135     nsk	\ lft of rtshft

kend

