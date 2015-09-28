\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: parses1.fth
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
id: @(#)parses1.fth 2.9 07/01/22
purpose:
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.



headers
: +string  ( adr len -- adr len+1 )  1+  ;
: -string  ( adr len -- adr+1 len-1 )  swap 1+  swap 1-  ;

\ Splits a string into two halves before the first occurrence of
\ a delimiter character.
\ adra,lena is the string including and after the delimiter
\ adrb,lenb is the string before the delimiter
\ lena = 0 if there was no delimiter

: split-before  ( adr len delim -- adra lena  adrb lenb )
   split-string 2swap
;
alias $split left-parse-string

: cindex  ( adr len char -- [ index true ]  | false )
   false swap 2swap  bounds  ?do  ( false char )
      dup  i c@  =  if  nip i true rot  leave  then
   loop                           ( false char  |  index true char )
   drop
;

\ Splits a string into two halves after the last occurrence of
\ a delimiter character.
\ adra,lena is the string after the delimiter
\ adrb,lenb is the string before and including the delimiter
\ lena = 0 if there was no delimiter

\ adra,lena is the string after the delimiter
\ adrb,lenb is the string before and including the delimiter
\ lena = 0 if there was no delimiter

: split-after  ( adr len char -- adra lena  adrb lenb  )
   >r  2dup + 0                       ( adrb lenb  adra 0 )

   \ Throughout the loop, we maintain both substrings.  Each time through,
   \ we add a character to the "after" string and remove it from the "before".
   \ The loop terminates when either the "before" string is empty or the
   \ desired character is found

   begin  2 pick  while               ( adrb lenb  adra lena )
      over 1- c@  r@ =  if \ Found it ( adrb lenb  adra lena )
         r> drop 2swap  exit          ( adrb lenb  adra lena )
      then
      2swap 1-  2swap swap 1- swap 1+ ( adrb lenb  adra lena )
   repeat                             ( adrb lenb  adr1 len1 )

   \ Character not found.  lenb is 0.
   r> drop  2swap
;

\ Count # of words in the specified string
\ Example:
\    " "               --> 0
\    " ab cdef"        --> 2
\    "   ab   cdef  "  --> 2
: count-words ( adr len -- n )
   0 >r						(  ) ( r: count )
   begin					(  ) ( r: count )
      -leading bl left-parse-string nip 0>	( remain$ len>0? ) ( r: count )
   while					( remain$ ) ( r: count )
      r> 1+ >r					( remain$ ) ( r: count )
   repeat					( adr 0 ) ( r: count )
   2drop r>					( count )
;

headers

