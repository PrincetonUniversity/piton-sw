\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: savefort.fth
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
\ savefort.fth 2.5 94/09/01
\ Copyright 1985-1990 Bradley Forthware

\ save-forth  ( filename -- )
\	Saves the Forth dictionary to a file so it may be later used under Unix
\
\ save-image  ( header-adr header-len init-routine-name filename -- )
\	Primitive save routine.  Saves the dictionary image to a file.
\	The header is placed at the start of the file.  The latest definition
\	whose name is the same as the "init-routine-name" argument is
\	installed as the init-io routine.

only forth also hidden also  forth definitions


headerless
: save-image  ( header header-len init-routine-name filename -- )
   new-file   ( header header-len init-routine-name )

   init-save  ( header header-len )

   ( header header-len )  ofd @  fputs		\ Write header
   origin   text-size     ofd @  fputs		\ Write dictionary
   up@      user-size     ofd @  fputs		\ Write user area
   ofd @ fclose
;
headers

0 value growth-size

\ Save an image of the target system in a file.
: save-forth  ( str -- )
   >r

   30800008    h_magic l!	\ This is a   ba,a .+0x20   instruction
   text-size   h_tlen  l!       \ Set the text size in program header
   user-size   h_dlen  l!       \ Set the data size in program header
   growth-size h_blen  l!       \ Set the bss size in program header
   0           h_slen  l!       \ Set the symbol size in program header
   origin      h_entry l!       \ Set the current starting address
   0           h_trlen l!       \ Set the relocation size
   0           h_drlen l!       \ Set the data relocation size

   " unix-init-io"  $find-name is init-io
   bin-header  /bin-header  " unix-init" r>  save-image
;

only forth also definitions
