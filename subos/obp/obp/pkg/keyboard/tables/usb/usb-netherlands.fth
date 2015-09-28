\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: usb-netherlands.fth
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
\ id: @(#)usb-netherlands.fth 1.4 06/08/17
\ purpose: 
\ copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
\

decimal

\ Keyboard country code assigned by HID doc.
18 keyboard: Dutch

\  normal  	shifted      altg      key#
\  -------      -------      -------   -----    ------------
   ascii @      section      notsign    53      allk		\ lft of 1
                             raised1    30      ak		\ 1
                ascii "      raised2    31      sak		\ 2
                             raised3    32      ak		\ 3
                             one4th     33      ak		\ 4
                             onehalf    34      ak		\ 5
                ascii &      thre4th    35      sak		\ 6
                ascii _      p-strlg    36      sak		\ 7
                ascii (      ascii {    37      sak		\ 8
                ascii )      ascii }    38      sak		\ 9
                ascii '      ascii `    39      sak		\ 0
   ascii /      ascii ?      ascii \    45      allk		\ rt of 0
   degrees      oops                    46      nsk		\ lft of bckspc
   oops         oops                    47      nsk  		\ rt of p
   ascii *      ascii |      ascii ~    48      allk  		\ lft of upRtn
                             s-doubl    22      ak		\ s
   ascii +      plusmin                 51      nsk		\ rt of L
   oops         oops                    52      nsk  
   ascii <      ascii >      ascii ^    50      allk  		\ lft of lowRtn
   ascii ]      ascii [      ascii |    100     allk		\ left of z
                             lftgull    29      ak		\ z
                             rtguill    27      ak		\ x
                             cents      6       ak		\ c
                             mu         16      ak		\ m
                ascii ;                 54      sk 		\ rt of m
                ascii :      cen-dot    55      sak 
   ascii -      ascii =                 56      nsk		\ lft of rtshft
                                                        
kend

