\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: cstrings.fth
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
\ cstrings.fth 2.8 01/04/06
\ Copyright 1985-1994 Bradley Forthware
\ Copyright 1994-2001 Sun Microsystems, Inc.  All Rights Reserved

\ Conversion between Forth-style strings and C-style null-terminated strings.
\ cstrlen and cscount are defined in cmdline.fth

decimal

headerless
0 value cstrbuf		\ Initialized in
chain: init  ( -- )  d# 258 alloc-mem is cstrbuf  ;

headers
\ Convert an unpacked string to a C string
: $cstr  ( adr len -- c-string-adr )
   \ If, as is usually the case, there is already a null byte at the end,
   \ we can avoid the copy.
   2dup +  c@  0=  if  drop exit  then
   >r   cstrbuf r@  cmove  0 cstrbuf r> + c!  cstrbuf
;

\ Convert a packed string to a C string
: cstr  ( forth-pstring -- c-string-adr )  count $cstr  ;

\ Find the length of a C string, not counting the null byte
: cstrlen  ( c-string -- length )
   dup  begin  dup c@  while  ca1+  repeat  swap -
;
\ Convert a null-terminated C string to an unpacked string
: cscount  ( cstr -- adr len )  dup cstrlen  ;

headers
