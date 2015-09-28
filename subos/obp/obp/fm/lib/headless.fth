\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: headless.fth
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
\ @(#)headless.fth 2.10 02/05/02
\ Copyright 1985-1990 Bradley Forthware
\ Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
\ Copyright Use is subject to license terms.

\ Creates headerless dictionary entries, by putting the headers as
\ aliases in the transient space.
\
\ XXX For SPARC only!!  68000 kernel has flag byte in a different
\ place!!!

\ Created structure:
\ Transient - link token (2 or 4 bytes, aligned)
\             name field
\             flag byte (=20 for alias, or 60 if immediate)
\             padding bytes (0,1,2 or 3), value 0
\             pointer token (points to acf in resident space)
\
\ Resident -  acf (2 or 4 bytes, aligned)
\             apf ...
\
\ Use as follows (within a given source file):
\   headerless
\ (these words are now headerless)
\ : blah  ... ;
\   headerless0
\ (these words are now headerless, too.  Used for extra Sun Forth words.)
\ (This can be changed to mean *include* headers, if desired)
\ : blah  ... ;
\   headers
\ (these words are now with heads)
\ : blah  ... ;
\
\ Use as follows (file-level control):
\   fload extensions/transien.fth
\   transient fload extensions/dispose.fth resident (file will be discarded)
\   fload extensions/alias.fth  ( if needed )
\   transient fload extensions/headless.fth resident (file will be discarded)
\ fload blah.fth ... (desired heads will be discarded later)
\ transient fload blah2.fth resident  (entire file will be discarded later)
\   true is suppress-headerless?
\ fload blahblah.fth ... (all heads are preserved)
\   false is suppress-headerless?
\ fload blah.fth ... (desired heads will be discarded later)
\ ...
\   dispose  (all transient heads and files are discarded)
\   (or .dispose to print statistics messages as well)
\
\ If it is desired to perform more than one dispose cycle, then dispose.fth and
\ headless.fth should be fload'ed normally, *not* into transient!

\ needs transient transien.fth

decimal

\ New version of ($header), puts name in transient
: ($headerless)  ( adr len -- )
   acf-align
   transient  ($header)  acf-align  there token,  resident
   flagalias
   acf-align	\ To set lastacf again
;

false value headerless?

: make-headerless  ( -- )  ['] ($headerless)  is  $header  ;
: make-headerfull  ( -- )  ['] ($header)      is  $header ;

false value suppress-headerless?
: headerless  ( -- )
   transient? 0=  suppress-headerless? 0=  and
   if  make-headerless  1 is headerless?  then
;

: headers  ( -- )
   transient? 0=  if  make-headerfull  false is headerless?  then
;
alias external headers

: -headers  ( -- )
   headerless?  if  headerless? 1+ is headerless?  else  headerless  then
;

: +headers  ( -- )
   headerless? 1 <=  if  headers  else  headerless? 1- is headerless?  then
;

: alias  \ new-name old-name  ( -- )
   headerless?  if
      parse-word
      transient? 0= dup >r if  transient  then  ($header)
      hide $defined $?missing reveal   ( old-acf n )
      \ We have to create a code field, because setalias is expecting
      \ there to be one (which it may subsequently remove!)
      colon-cf setalias
      r> if  resident  then
   else
      alias
   then
;

: transient  ( -- )
   headerless? if  make-headerfull  then  transient
;

: resident ( -- )
   headerless? if  make-headerless  then resident
;

\ How to handle (marginal utility) headerless0 words
: headerless0  ( -- )  headerless  ;
