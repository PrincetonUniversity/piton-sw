\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: binhdr.fth
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
\ binhdr.fth 2.6 96/02/29
\ Copyright 1985-1990 Bradley Forthware

\ Header for Forth ".exe" file to be executed by the C wrapper program.
hex

only forth also hidden also
forth definitions
headerless

hidden definitions
h# 20 buffer: bin-header
: wstruct 0 ;
: wfield  \ name ( offset size -- offset' )
   create
   over w,  +
   does>     ( struct-base -- field-addr )
   w@ bin-header +
;
: long  4 wfield  ;

wstruct ( Binary header)
 long h_magic	(  0)		\ Magic Number
 long h_tlen    (  4)		\ length of text (code)
 long h_dlen	(  8)		\ length of initialized data
 long h_blen	(  c)		\ length of BSS unitialized data
 long h_slen	(  10)		\ length of symbol table
 long h_entry	(  14)		\ Entry address
 long h_trlen	(  18)		\ Text Relocation Table length
 long h_drlen	(  1c)		\ Data Relocation Table length
constant /bin-header ( 20)

: text-size  ( -- size-of-dictionary )  dictionary-size aligned  ;
headers

only forth also definitions
