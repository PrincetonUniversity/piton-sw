\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: meta1.fth
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
id: @(#)meta1.fth 2.9 03/12/08 13:22:34
purpose: 
copyright: Copyright 1990-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Use is subject to license terms.

\ Meta compiler.  Host system: F83  Target system: 68K F83

\ Variables and store don't work very well.  Use "is" instead.
create meta.f ," meta1.fth 2.9 03/12/08"

only forth also definitions
\
\ These are OK to leave permenantly installed because the meta compiler
\ never gets saved into an image
\
headers
defer meta-xref-on		' noop is meta-xref-on
defer meta-xref-off		' noop is meta-xref-off
[ifnexist] xref-header-hook
\ Bootstrapping..
defer xref-header-hook	' noop is xref-header-hook
defer xref-find-hook	' noop is xref-find-hook
[then]
[ifnexist] xref-hide-hook
\ Bootstrapping..
defer xref-hide-hook	' noop is xref-hide-hook
defer xref-reveal-hook	' noop is xref-reveal-hook
[then]
[ifnexist] xref-string-hook
\ Bootstrapping
defer xref-string-hook	' noop is xref-string-hook
[then]

vocabulary meta
vocabulary symbols
vocabulary labels

\ This will be set later
0 constant compilation-base

0 constant origin-t
variable dp-t
variable current-t
variable context-t

\ Return the host address where the given target address is being compiled
: >hostaddr  ( target-address -- host-address )
   origin-t -   compilation-base +
;
: hostaddr>  ( host-address -- target-address )
   compilation-base -  origin-t +
;

: allot-t  ( #bytes -- )  dp-t +!  ;

: here-t  ( -- target-adr )  dp-t @  ; 

: target-image  ( l.adr -- )  is compilation-base  ;
: org  ( adr -- )  dup dp-t !  is origin-t  ;

\ voc-ptr is the address of the first thread

: $sfind  ( adr len -- acf [ -1 | 1 ] | adr len false )
   $canonical ['] symbols $vfind
;

\ Version that allows target variables and constants to be interpreted
\ : xconstant ( n -- )
\    current link@ >r  context link@ >r [compile] labels definitions
\       lastword canonical "create ,
\    r> context link! r> current link!
\    does> @
\ ;
\
\ Version that doesn't
: xconstant ( n -- ) drop ;

\ This is a version of create that creates a word in a specific vocabulary.
\ The vocabulary is passed as an explicit argument. This would be somewhat
\ easier if the search-order stuff were implemented in a less "hard-wired"
\ manner.

: $vcreate  ( adr len voc-cfa -- )
   context link@ >r   current link@ >r   warning @ >r
   context link!  definitions
   warning off
   $create
   r> warning !   r> current link!   r> context link!
;
\ : vcreate  ( str voc-cfa -- )  count $vcreate  ;
