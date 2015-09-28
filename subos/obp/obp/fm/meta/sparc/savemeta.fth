\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: savemeta.fth
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
\ savemeta.fth 2.2 90/09/03
\ Copyright 1985-1990 Bradley Forthware

\ Symbol table:  hand-crafted for now.  Sigh.
hex
only forth labels also forth also definitions
:-h ,c"  \ string"  ( -- )
   ascii " word  count  bounds  ?do i c@ c, loop  0 c,
;-h
create symbol-table
meta
\ string-offset    flags      symbol value
\       4 l,      05000000 l,    ' save-state  >body-t l,   \ _forth_trap
\      10 l,      05000000 l,    ' enter-forth >body-t l,   \ _enter_forth
\      1d l,      05000000 l,    ' cold-code   >body-t l,   \ _init_forth
forth-h
 here symbol-table - constant /syms

create string-table
\    0 l,	\ string table length
\    ,c" _forth_trap"
\    ,c" _enter_forth"
\    ,c" _init_forth"
here string-table -  dup  string-table l!   constant /strings

\ Program header
create header   forth
\ th 01   c,    \ Tool Version
\ th 03   c,    \ Machine type
\ th 0107 w,    \ Magic Number - old impure format
th 30800008 l,  \ Branch past the header
      0 l,    \ Text size, actual value will be set later
      0 l,    \ Data size, actual value will be set later
      0 l,    \ Bss  size
      0 l,    \ Symbol Table size
      0 l,    \ Entry
      0 l,    \ Text Relocation Size
      0 l,    \ Data Relocation Size
\ End of header.
here header -  constant /header

only forth also meta also forth-h also definitions

\ Save an image of the target system in the Unix file whose name
\ is the argument on the stack.

: text-base  ( -- adr )  origin-t >hostaddr  ;
: text-size  ( -- n )  here-t origin-t -  3 + 3 invert and  ;
: user-base  ( -- adr )  userarea-t  ;
: user-size  ( -- n )  user-size-t  ;
: save-meta ( str -- )
   new-file

   \ Set the text and data sizes in the program header
   text-size             header th  4 + l!  \ Text size
   user-size             header th  8 + l!  \ Data size
   /syms                 header th 10 + l!  \ Symbol table size

   th    0               header th 14 + l!  \ Entry point

   header               /header       ofd @  fputs
   text-base            text-size     ofd @  fputs
   user-base            user-size     ofd @  fputs

   symbol-table         /syms         ofd @  fputs
   string-table         /strings      ofd @  fputs

   ofd @ fclose
;
: save-meta-exe  ( str -- )
   new-file
   text-base >hostaddr  text-size   ofd @  fputs
   ofd @ fclose
;

only forth also meta also definitions
