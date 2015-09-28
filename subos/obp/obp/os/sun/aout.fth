\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: aout.fth
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
\ aout.fth 2.4 97/01/23
\ Copyright 1985-1990 Bradley Forthware

\ Support for reading "a.out" (linker) files
\ This is system-dependent; this version is correct for Sun Microsystems'
\ implementation of 4.2 BSD.  Other systems may be more or less different
\ For instance, Masscomp splits the a_magic field into 2 16-bit words.
\ System V uses a "common object file format" which is much different.

decimal
headerless
struct  \ "a.out-header" structure - a.out header
  0  field a_magicword	    \ Alias for the next 4 bytes as a whole
  /c field a_toolversion
  /c field a_machtype
  /w field a_magic
  /l field a_text
  /l field a_data
  /l field a_bss
  /l field a_syms
  /l field a_entry
  /l field a_trsize
  /l field a_drsize
constant /a.out-header
/a.out-header buffer: a.out-header

\ Words which return the size in bytes of various components of the a.out file

: /text  ( -- size-of-text-segment )   a.out-header a_text l@ ;
: /data  ( -- size-of-data-segment )   a.out-header a_data l@ ;
: /bss   ( -- size-of-bss-segment )    a.out-header a_bss  l@ ;
: /syms  ( -- size-of-symbol-table )   a.out-header a_syms l@ ;
: /reloc ( -- size-of-relocation )     a.out-header a_trsize l@  
                                       a.out-header a_drsize l@  + ;
: entry-adr  ( -- load-address )       a.out-header a_entry l@ ;

\ Words which return the offset from the start of the a.out file of various
\ components of the a.out file

: text0  ( -- file-address-of-text ) /a.out-header ;
: data0  ( -- file-address-of-data ) text0 /text + ; 
: reloc0 ( -- file-address-of-relocation ) data0 /data + ; 
: syms0  ( -- file-address-of-symbols ) reloc0 /reloc + ; 
: string0 ( -- file-address-of-strings ) syms0 /syms + ; 

: ?magic  ( -- )
   a.out-header a_magic w@  h# 107 <>
   abort" Magic number is not (octal) 407"
;
: read-header  ( -- )
   a.out-header 4  ifd @  fgets  4 <> abort" Can't read the magic number"
   ?magic
   a.out-header 4 +  /a.out-header 4 -  ifd @ fgets
   /a.out-header 4 - <> abort" Can't read header"
;
headers
