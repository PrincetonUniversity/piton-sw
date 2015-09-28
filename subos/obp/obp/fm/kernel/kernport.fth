\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: kernport.fth
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
\  @(#)kernport.fth 2.9 03/07/17
\ Copyright 1985-1990 Bradley Forthware
\ Copyright 1993-1994 Sun Microsystems, Inc.  All Rights Reserved
\ Copyright 2003 Sun Microsystems, Inc.  All Rights Reserved
\ Use is subject to license terms.

\ Some 32-bit compatibility words

\ These are for links that are just the same as addresses
/a constant /link
: link@  (s addr -- link )  a@  ;
: link!  (s link addr -- )  a!  ;
: link,  (s link -- )       a,  ;

headers

[ifndef] run-time

\itc : \itc ; immediate
\itc : \dtc  [compile] \ ; immediate
\itc : \ttc  [compile] \ ; immediate
\dtc : \itc  [compile] \ ; immediate
\dtc : \dtc ; immediate
\dtc : \ttc  [compile] \ ; immediate
\ttc : \itc  [compile] \ ; immediate
\ttc : \dtc  [compile] \ ; immediate
\ttc : \ttc ; immediate
\t8  : \t8  ; immediate
\t8  : \t16  [compile] \ ; immediate
\t8  : \t32  [compile] \ ; immediate
\t16 : \t8   [compile] \ ; immediate
\t16 : \t16 ; immediate
\t16 : \t32  [compile] \ ; immediate
\t32 : \t8   [compile] \ ; immediate
\t32 : \t16  [compile] \ ; immediate
\t32 : \t32 ; immediate
16\ : 16\  ; immediate
16\ : 32\  [compile] \  ; immediate
16\ : 64\  [compile] \  ; immediate
32\ : 16\  [compile] \  ; immediate
32\ : 32\  ; immediate
32\ : 64\  [compile] \  ; immediate
64\ : 16\  [compile] \  ; immediate
64\ : 32\  [compile] \  ; immediate
64\ : 64\  ; immediate
[then]
