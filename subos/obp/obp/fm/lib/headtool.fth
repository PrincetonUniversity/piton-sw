\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: headtool.fth
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
id: @(#)headtool.fth 1.9 03/12/11 09:22:54
purpose: 
copyright: Copyright 1990-2001 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.
\ Copyright 1985-1990 Bradley Forthware

\ Tools to make headerless definitions easier to live with.
\ To reheader the headerless words, download the headers file
\ via  DL  or something like it. 

headers

\  The format of each line of the "headers" file produced by the OBP
\  make  process is:
\      h#  <Offset>  <headerless:|header:>  <name>
\
\  After reading the "headers" file through these definitions, it should
\  be possible to find a name for most definitions.

\  Re-create headers by making them an alias for the actual name.  Keep them
\  within the special re-created headers' vocabulary.  If they are leftover
\  transient words, i.e., outside the dictionary, ignore them...
: headerless:  \ name  ( offset -- )   compile-time
               \       ( ??? -- ??? )  run-time
   origin+ dup in-dictionary? parse-word rot if
	  [ also hidden ]
	  ['] re-heads
	  [ previous ] $create-word flagalias  acf-align token,
   else
	  3drop
   then
;

: header:      \ name  ( offset -- )   compile-time
               \       ( ??? -- ??? )  run-time
   drop [compile] \
;


\  Before faking-out a headerless name, scan the vocabulary of the
\  re-created headers.  Fake-out the name only if it isn't found.
: find-head  ( cfa -- nfa )
   [ also hidden ]
   ['] re-heads
   [ previous ] follow begin	( cfa )
      another?			( cfa nfa flag )
   while			( cfa nfa )
      2dup name> token@		( cfa nfa cfa cfa2 )
      = if			( cfa nfa )
	 nip exit		( nfa )
      else
	 drop			( cfa )
      then			( cfa )
   repeat			( cfa )
   fake-name			( nfa )
;


\  Plug the routine to scan the re-created headers' vocabulary in to
\  the word that looks up names.  It does no harm to have it plugged
\  in place even if the headers file has not been read, because the
\  initial link-pointer in the re-created headers' vocabulary is null.

patch find-head fake-name >name


