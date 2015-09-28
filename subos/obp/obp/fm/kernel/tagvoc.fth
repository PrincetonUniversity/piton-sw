\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: tagvoc.fth
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
id: @(#)tagvoc.fth 3.9 04/03/19 17:00:34
purpose: 
copyright: Copyright 1994-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.
\ Copyright 1985-1994 Bradley Forthware

\ Implementation of vocabularies.  Vocabularies are lists of word names.
\ The following operations may be performed on vocabularies:
\    find-word  - Search for a given word
\    "header    - Create a new word in the "current" vocabulary
\    trim       - Remove all words in a vocabulary created after an address
\    another?   - Enumerate all the the words
\
\ Each word name in a vocabulary has a byte with the following attributes:
\    name flag bit      (7) - Identifies the byte as, indeed, belonging to a name 
\    immediate flag bit (6) - Controls compilation of that word
\    alias flag bit     (5) - Identifies the word as an alias
\    name-length bits (0-4) - Length of the name

headers

\ Find a potential name field address
: find-name  ( acf -- anf )  >link l>name  ;

\ The test for a valid header searches backward to the position that
\ is expected to contain a name length byte.  That byte is first checked
\ for the presence of the 'name-tag' (80) bit.  Then the length is checked
\ to confirm that it is non-zero.  Finally, the characters in the name
\ are checked to make sure that they are all non-blank and printable.

: >name?  ( acf -- anf good-name? )
   find-name				( anf )

   \ Check for the name-flag bit
   dup c@ h# 80 and dup if  drop	( anf )

      \ Check for zero-length name.
      true over name>string		( anf true adr len )
      ?dup 0= if 2drop false exit then

      \ Check for bogus (blank or non-printable) characters.
      bounds ?do			( anf true )
	 i c@ bl 1+ h# 7e between  0=
	 if  0= leave  then
      loop				( anf good-name? )
   then
;

\ Address conversion operators
: n>link   ( anf -- alf )  1+  ;
: l>name   ( alf -- anf )  1- ;
: n>flags  ( anf -- aff )  ;
: name>    ( anf -- acf )  n>link link>  ;
: link>    ( alf -- acf )  /link +  ;
: >link    ( acf -- alf )  /link -  ;
: >flags   ( acf -- aff )  >name n>flags  ;
: name>string  ( anf -- adr len )  dup c@ h# 1f and  tuck - swap  ;
: l>beginning  ( alf -- adr )  l>name name>string drop  ;
: >threads  ( acf -- ath )  >body >user  ;

nuser last

headerless

: $make-header  ( adr len voc-acf -- )
   -rot 					( voc-acf adr,len )
   dup 1+ /link +				( voc-acf adr,len hdr-len )

   here +					( voc-acf adr,len  addr' )
   dup acf-aligned swap - allot 		( voc-acf adr,len )
   tuck here over 1+  note-string  allot	( voc-acf len adr,len anf )
   place-cstr					( voc-acf len anf )
   over + c!					( voc-acf )
   here 1- last !				( voc-acf )
   >threads					( threads-adr )
   /link allot here				( threads-adr acf )

   swap 2dup link@				( acf threads-adr acf succ-acf )
   swap >link link! link!			(  )

   last @ c@  h# 80 or  last @ c!
;

headers
: >first  ( voc-acf -- first-alf )  >threads  ;

[ifndef] XREF
: $find-word  ( adr len voc-acf -- adr len [ false | xt,+-1 ] )
   >first  $find-next  find-fixup
;
[else]
\
\ Watchout the lose is patched with the acf of keys-forth later!!
\
: $find-word ( adr len voc-acf -- adr len [ false | xt,+-1 ] )
   >r 2dup r@ >first $find-next find-fixup    ( adr len [ adr,len,0 | xt,+-1 ] )
   dup if				      ( adr len xt,+-1 )
      2swap				      ( xt,+-1 adr len )
      r> ['] lose <>			      ( xt,+-1 adr len xref? )
      if  xref-find-hook  then		      ( xt,+-1 adr len )
      2drop				      ( xt,-+1 )
   else					      ( adr len adr,len,0 )
      r> drop  >r 2swap 2drop r>	      ( adr,len,0 )
   then					      ( adr len [ false | xt,+-1 ] )
;
[then]

headerless
: >ptr  ( alf voc-acf -- ptr )
   over  if  drop  else  nip >threads  then
;
: next-word  ( alf voc-acf -- false  |  alf' true )
   >ptr another-link?  if  >link  true  else  false  then
;
: insert-word  ( new-alf old-alf voc-ptr -- )
   >ptr              ( new-alf alf )
   swap link> swap   ( new-acf alf )
   2dup link@        ( new-acf alf  new-acf next-acf )
   swap >link link! link!
;

headers
\
\ WARNING, the '>threads' in remove-word is patched by fm/kernel/hashcach.fth
\
: remove-word  ( new-alf voc-acf -- )
   >threads                                   ( new-alf prev-link )
   swap link> swap link>                      ( new-acf prev-link )
   begin                                      ( acf prev-link )
      >link
      2dup link@ =  if                        ( acf prev-link )
         swap >link link@ swap link!  exit    (  )
      then                                    ( acf prev-link )
      another-link? 0=                  ( acf [ next-link ] end? )
   until
   drop
;

\ Makes a sealed vocabulary with the top-of-voc pointer in user area
\ parameter field of vocabularies contains:
\ user-#-of-voc-pointer ,  voc-link ,

\ For navigating inside a vocabulary's data structure.
\ A vocabulary's parameter field contains:
\   user#  link
\ The threads are stored in the user area.
\ The link-field points to the preceding vocabulary.
\
\  Historically, the pointer was the address of the link-field;
\  but in our current implementation, the pointer is the ACF.

: voc>      ( voc-link-adr -- acf )
\  \  Comment-out the code to go from link-field to ACF,
\  \  in case we ever resurrect the old way.
\   /user# -  body>
;

: >voc-link ( voc-acf -- voc-link-adr )  >body /user# +  ;

: (wordlist)  ( -- )
   create-cf
   /link user#,  !null-link   ( )
   voc-link,
   0 ,				\ Space for additional information
   does> body> context token!
; resolves <vocabulary>
headers
