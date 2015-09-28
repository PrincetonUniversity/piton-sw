\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: patch.fth
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
\ patch.fth 2.11 01/04/06
\ Copyright 1985-1994 Bradley Forthware
\ copyright: Copyright 1995-2001 Sun Microsystems, Inc.  All Rights Reserved

\  Patch utility.  Allows you to make patches to already-defined words.
\   Usage:
\     PATCH new old word-to-patch
\         In the definition of "word-to-patch", replaces the first
\         occurence of "old" with "new".  "new" may be either a word
\         or a number.  "old" may be either a word or a number.
\
\     n-new  n-old  NPATCH  word-to-patch
\         In the definition of "word-to-patch", replaces the first
\         compiled instance of the number "n-old" with the number
\         "n-new".
\
\     n-new  n-old  start-adr  end-adr  (NPATCH
\         replaces the first occurrence of "n-old" in the word "acf"
\         with "n-new"
\
\     acf-new  acf-old  acf  (PATCH
\         replaces the first occurrence of "acf-old" in the word "acf"
\         with "acf-new"
\
\     new new-type   old old-type  acf  (PATCH)
\         replaces the first occurrence of "old" in the word "acf" with "new".
\         If "new-type" is true, "new" is a number, otherwise "new" is an acf.
\         If "old-type" is true, "old" is a number, otherwise "old" is an acf.
\
\     n  start-adr end-adr   SEARCH
\         searches for an occurrence of "n" between start-adr and
\         end-adr.  Leaves the adress where found and a success flag.
\
\     c  start-adr end-adr   CSEARCH
\         searches for a byte between start-adr and end-adr
\
\     w  start-adr end-adr   WSEARCH
\         searches for a 16-bit word between start-adr and end-adr
\
\     acf  start-adr end-adr TSEARCH
\         searches for a compiled adress between start-adr and end-adr
\
\

decimal

: csearch ( c start end -- loc true | false )
   false -rot swap  ?do			( c false )
      over i c@ = if
	 drop i swap true leave
      then
   /c +loop  nip
;
: wsearch  ( w start end -- loc true | false )
   rot n->w		\ strip off any high bits
   false 2swap  swap  ?do		( w false )
      over i w@ = if
	 drop i swap true leave
      then
   /w +loop  nip
;
: tsearch  ( adr start end -- loc true | false )
   false -rot  swap  ?do			( targ false )
      over i token@ = if
	 drop i swap true leave
      then
      \ Can't use /token because tokens could be 32-bits, aligned on 16-bit
      \ boundaries, with 16-bit branch offsets realigning the token list.
   #talign +loop  nip
;
: search  ( n start end -- loc true | false )
   false -rot  swap  ?do		( n false )
      over i @ = if
	 drop i swap true leave
      then
   #talign +loop  nip
;

headerless

: get-next-token  ( adr -- adr token )
   dup token@                 ( n adr token )
   dup ['] unnest =  abort" Can't find word to replace"   ( n adr token )
;

: find-lit  ( n acf -- adr )
   >body
   begin
      get-next-token             ( n adr token )
\t16  dup  ['] (wlit)  =  if     ( n adr token )
\t16     drop                    ( n adr )
\t16     2dup ta1+ w@ 1-  =  if  ( n adr )
\t16        nip exit             ( adr )
\t16     else                    ( n adr )
\t16        ta1+ wa1+            ( n adr' )
\t16     then                    ( n adr )
\t16  else                       ( n adr token )
       dup  ['] (lit) =  if      ( n adr token )
	  drop                   ( n adr )
	  2dup ta1+ @  =  if     ( n adr )
	     nip exit            ( adr )
	  else                   ( n adr )
	     ta1+ na1+           ( n adr' )
	  then                   ( n adr )
       else                      ( n adr token )
	  ['] (llit) =  if       ( n adr )
	     2dup ta1+ l@ 1-  =  if  ( n adr )
		nip exit             ( adr )
	     else                    ( n adr )
		ta1+ la1+            ( n adr' )
	     then                    ( n adr' )
	  else                       ( n adr )
	     ta1+                    ( n adr' )
	  then                       ( n adr' )
       then                          ( n adr' )
\t16 then
   again
;

: find-token  ( n acf -- adr )
   >body
   begin
      get-next-token                ( n adr token )
      2 pick =  if  nip exit  then  ( n adr )
      ta1+                          ( n adr' )
   again
;

: make-name  ( n digit -- adr len )
   >r  <# u#s ascii # hold  r> hold u#>   ( adr len )
;

: put-constant  ( n adr -- )
   over
   base @  d# 16 =  if
      ascii h make-name
   else
      push-decimal
      ascii d make-name
      pop-base
   then                           ( n adr name-adr name-len )

   \ We don't use  "create .. does> @  because we want this word
   \ to decompile as 'constant'

   warning @ >r  warning off
   $header       ( n adr )
   constant-cf swap ,             ( adr )
   r> warning !

   lastacf swap token!
;

: put-noop  ( adr -- )  ta1+  ['] noop swap token!  ;

\t16 : short-number?  ( n -- flag )  -1  h# fffe  between  ;
\t32 : long-number?  ( n -- flag )  -1  h# ffff.fffe n->l between  ;

headers
: (patch)  ( new number?  old number?  word -- )
   swap  if                         ( new number? old acf )  \ Dest. is num
      find-lit                      ( new number? adr )

\t16  dup token@ ['] (wlit) =  if   ( new number? old )  \ Dest. slot is wlit
\t16     swap  if                   ( new adr )   \ replacement is a number
\t16        over short-number?  if  ( new adr )   \ replacement is short num
\t16           ta1+ swap 1+ swap w! ( )
\t16           exit
\t16        then                    ( new adr )   \ Replacement is long num
\t16        tuck put-constant       ( adr )
\t16        put-noop                ( )
\t16        exit
\t16     then                       ( new adr )  \ replacement is a word
\t16     tuck token!  put-noop      ( )
\t16     exit
\t16  then                          ( new number? adr )  \ Dest. slot is lit

\t32  dup token@ ['] (llit) =  if   ( new number? old )  \ Dest. slot is wlit
\t32     swap  if                   ( new adr )   \ replacement is a number
\t32        over long-number?  if   ( new adr )   \ replacement is short num
64\ \t32       ta1+ swap 1+ swap l! ( )
32\ \t32       ta1+ l!              ( )
\t32           exit
\t32        then                    ( new adr )   \ Replacement is long num
\t32        tuck put-constant       ( adr )
\t32        put-noop                ( )
\t32        exit
\t32     then                       ( new adr )  \ replacement is a word
\t32     tuck token!  put-noop      ( )
\t32     exit
\t32  then                          ( new number? adr )  \ Dest. slot is lit

      swap  if  ta1+ !  exit  then  ( new adr )  \ replacement is a word

      tuck token!                   ( adr )
32\ \t16  dup put-noop  ta1+               ( )
64\ \t16  dup put-noop  ta1+ dup put-noop  dup put-noop  ta1+  ( )
64\ \t32  dup put-noop  ta1+
      put-noop                             ( )
      exit
   then                             ( new number? old acf )  \ Dest. is token

   find-token                       ( new number? adr )
   swap if  put-constant exit  then ( new adr )  \ replacement is a number
   token!
;

headerless
: get-word-type  \ word  ( -- val number? )
   parse-word  $find  if  false exit  then  ( adr len )
   $dnumber?  1 <> abort" ?"  true
;

headers
: (npatch  ( newn oldn acf -- )  >r true tuck  r>  (patch)  ;

: (patch  ( new-acf old-acf acf -- )  >r false tuck r>  (patch)  ;

\ substitute new for first occurrence of old in word "name"
: npatch  \ name  ( new old -- )
   true tuck  '  ( new true old true acf )  (patch)
;

: patch  \ new old word  ( -- )
   get-word-type   get-word-type  '  (patch)
;

