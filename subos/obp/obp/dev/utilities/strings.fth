\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: strings.fth
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
id: @(#)strings.fth 1.4 03/09/18
purpose:
copyright: Copyright 2001-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

: upper  ( adr len -- )  bounds  ?do i dup c@ upc swap c!  loop  ;
: lower  ( adr len -- )  bounds  ?do i dup c@ lcc swap c!  loop  ;

: printable? ( n -- flag )
   dup bl h# 7f within swap h# 80 h# ff between or 
; 

: white-space? ( n -- flag ) \ true is n is non-printable? or a blank
   dup printable? 0=  swap  bl =  or
;

: -leading  ( adr len -- adr' len' )
   begin  dup  while   ( adr' len' )
      over c@  white-space? 0=  if  exit  then
      swap 1+ swap 1-
   repeat
;

: -trailing  (s adr len -- adr len' )
   dup  0  ?do   2dup + 1- c@   white-space? 0=  ?leave  1-    loop
;

: $=  ( adr1 len1 adr2 len2 -- same? )
   rot tuck  <>  if  3drop false exit  then   ( adr1 adr2 len1 )
   comp 0=
;

: cstrlen ( c-string -- length )
   dup  begin  dup c@  while  ca1+  repeat  swap -
;

\ Split (non-destructive) a string after the last occurrence of the delimiter
\ adra,lena is the string after the delimiter
\ adrb,lenb is the string before and including the delimiter
\ lenb = 0 if there was no delimiter

: split-after ( adr len delimiter -- adra lena adrb lenb )
   >r 2dup + 0                          ( adrb lenb adra 0 )

   begin  2 pick  while                 ( adrb lenb adra lena )
      over 1- c@  r@ =  if  \ Found it  ( adrb lenb adra lena )
         r> drop 2swap exit             ( adra lena adrb lenb )
      then
      2swap 1-  2swap swap 1- swap 1+   ( adrb lenb adra lena )
   repeat                               ( adrb lenb adra lena )

   \ Character not found
   r> drop 2swap                        ( adra lena adrb lenb )
;

\ Split (non-destructive) a string before first occurence of the delimiter
\ adra,lena is the string including and after the delimiter
\ adrb,lenb is the string before the delimiter
\ lena = 0 if there was no delimiter

: split-before ( adr len delimiter -- adra lena adrb lenb )
   >r  over 0 2swap                     ( adrb lenb adra lena )
   begin  dup  while                    ( adrb lenb adra lena )
     over c@ r@ =  if                   ( adrb lenb adra lena )
       r> drop 2swap exit               ( adra lena adrb lenb )
     then
     1- swap 1+ swap  2swap 1+ 2swap    ( adrb lenb adra lena )
   repeat                               ( adrb lenb adra lena )

   \ Character not found. lena is 0
   r> drop 2swap                        ( adra lena adrb lenb )
;

\ Concatenate 2 forth strings
: $strcat ( src$ dest$ -- dest+src$ )
   rot                  ( src dest dlen slen )
   2dup + >r            ( src dest dlen slen )  ( r: tlen )
   -rot                 ( src slen dest dlen )  ( r: tlen )
   over >r              ( src slen dest dlen )  ( r: tlen dest )
   ca+                  ( src slen dest+dlen )  ( r: tlen dest )
   swap cmove           (  )                    ( r: tlen dest )
   r> r>                ( dest tlen )
   2dup ca+ 0 swap c!   ( dest+src$ )
;

\ Concatenate a string with a packed string 
: $cat  ( adr len  pstr -- ) 
   >r r@ count nip   ( addr len len' )   ( r: pstr )
   d# 255 swap - min ( addr len' )       ( r: pstr ) 
   r@ count +        ( adr len end-adr ) ( r: pstr )
   swap dup >r       ( adr endadr len )  ( r: pstr len )
   cmove r> r>       ( len pstr )
   dup c@ rot + swap c!
;
