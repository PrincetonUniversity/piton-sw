\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: sift.fth
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
\ sift.fth 2.11 99/05/04
\ Copyright 1985-1990 Bradley Forthware

also hidden
only forth also hidden also definitions
decimal
headerless

variable sift-vocabulary

\ Leave a "hook" for showing the name of the vocabulary
\ only once, the first time a matching name is found.
\ Showing the name of a device can be plugged in here also...
defer .voc     ['] noop is .voc

: .in  ( -- )  ??cr tabstops @ spaces  ." In "  ;
: .vocab  ( -- )
   .in ['] vocabulary .name space
   sift-vocabulary @ .name cr
   ['] noop is .voc
;

\ Show the "sifted" name, preceded by its  cfa  in parentheses.
\ Show the name of the vocabulary only the first time.
\ Control the display with  exit?
: .sift?  ( nfa -- exit? )
   .voc
   exit? tuck  if  drop exit  then  		( exit? nfa )
   dup  name>				 	( exit? nfa cfa )
   over n>flags c@  h# 20 and  if  token@  then	  \ Handle aliases
   fake-name			 		( nfa fstr )
   over name>string nip
   over name>string nip + 3 + .tab
  .id .id 2 spaces
;

\ Sift through the given vocabulary, using the sift-string given.
\ Control the display with  exit?
: vsift?  ( adr,len voc-acf -- exit? )
   dup sift-vocabulary !
   -rot 2>r 0 swap                      ( alf voc-acf )      ( r: adr,len )
   begin  another-word?  while	        ( alf' voc-acf nfa ) ( r: adr,len )
      dup 2r@  rot  name>string sindex	( alf' voc-acf nfa indx|-1 ) ( r: adr,len )
      1+  if  .sift?  if                ( alf' voc-acf ) ( r: adr,len )
	 2drop  2r>  2drop true  exit
	 then                           ( alf' voc-acf ) ( r: adr,len )
      else                              ( alf' voc-acf nfa ) ( r: adr,len )
	 drop                           ( alf' voc-acf ) ( r: adr,len )
      then                              ( alf' voc-acf ) ( r: adr,len )
   repeat  2r>  2drop  false            ( false )
;

headers
forth definitions

\ Sift through all the vocabularies for the string given
\ on the stack as  addr,len
: $sift ( adr,len -- )
   voc-link  begin  another-link?  while	( adr,len v-link )
      ['] .vocab is .voc                        ( adr,len v-link )
      voc> >r                                   ( adr,len ) ( r: voc-acf )
      2dup r@ vsift?  if  r> 3drop  exit  then  ( adr,len ) ( r: voc-acf )
      r> >voc-link                              ( adr,len v-link' )
   repeat  2drop                                (  )
;

\  Same thing, only the string is given on the stack in packed format
: sift  ( str -- )  count $sift  ;

\  Same thing, only the string is given in the input stream.
: sifting  \ name  ( -- )
   safe-parse-word $sift
;

only forth also definitions
