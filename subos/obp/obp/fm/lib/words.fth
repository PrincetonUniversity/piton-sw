\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: words.fth
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
\ words.fth 2.9 02/11/26
\ Copyright 1985-1990 Bradley Forthware
\ Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
\ Copyright Use is subject to license terms.

\ Display the WORDS in the Context Vocabulary

decimal

only forth also definitions

: over-vocabulary  (s acf-of-word-to-execute voc-acf -- )
   follow  begin  another?  while   ( acf anf )
      n>link over execute           ( acf )
   repeat  ( acf )  drop
;
: +words   (s -- )
   0 lmargin !  d# 64 rmargin !  d# 14 tabstops !
   ??cr
   begin  another?  while      ( anf )
     dup name>string nip .tab  ( anf )
     .id                       ( )
     exit? if  exit  then      ( )
   repeat                      ( )
;
: follow-to  (s adr voc-acf -- error? )
   follow  begin  another?  while         ( adr anf )
      over u<  if  drop false exit  then  ( adr )
   repeat                                 ( adr )
   drop true
;
: prior-words  (s adr -- )
   context token@ follow-to  if
      ." There are no words prior to this address." cr
   else
      +words
   then
;

\ [ifdef] Daktari
\ [message] XXX (words) and voc-words for Daktari
: (words)  ( lmarg rmarg tabs -- )
   tabstops !				\ Set tab/column width
   rmargin !				\ Set right-hand margin
   lmargin !				\ Set left-hand margin
   ??cr
   0  context token@			( 0 voc-acf )
   begin another-word?  while		( alf voc-acf anf )
     dup name>string nip .tab		( alf voc-acf anf )
     .id				( alf voc-acf )
     exit? if  2drop exit  then		( alf voc-acf )
   repeat				( )
;
\ [then]

: words  (s -- )
   0 lmargin !  d# 64 rmargin !  d# 14 tabstops !  ??cr
   0  context token@             ( 0 voc-acf )
   begin another-word?  while    ( alf voc-acf anf )
     dup name>string nip .tab    ( alf voc-acf anf )
     .id                         ( alf voc-acf )
     exit? if  2drop exit  then  ( alf voc-acf )
   repeat                        ( )
;

\ [ifdef] Daktari
\ voc-words -- List all words in a specified vocabulary

: voc-words (s lmarg rmarg tabs vocabulary-xt -- )
   also execute				\ Select specified vocabulary
   (words)				\ List out the vocabulary
   previous				\ Discard specified vocabulary
;
\ [then]

only definitions forth also
: words    words ;  \ Version for 'root' vocabulary
only forth also definitions
