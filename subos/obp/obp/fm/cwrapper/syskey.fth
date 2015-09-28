\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: syskey.fth
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
\ syskey.fth 2.5 98/10/21
\ Copyright 1985-1994 Bradley Forthware

\ Console I/O using the C wrapper program

headerless
decimal

: sys-emit   ( c -- )   1 syscall drop  ;	\ Outputs a character
: sys-key    ( -- c )   0 syscall retval  ;	\ Inputs a character
: sys-(key?  ( -- f )   8 syscall retval  ;	\ Is a character waiting?
: sys-cr     ( -- )    27 syscall  #out off  1 #line +!  ;  \ Go to next line

\ Is the input stream coming from a keyboard?

: sys-interactive?  ( -- f )  12 syscall retval  0=  ;

headers
\ Reads at most "len" characters into memory starting at "adr".
\ Performs keyboard editing (erase character, erase line, etc).
\ The operation terminates when either a "return" is typed or "len"
\ characters have been read.
\ The operating system does the line editing until we load the line editor

: sys-accept  ( adr len -- actual )
   14 syscall 2drop retval   #out off  1 #line +!
;
headerless

\ Outputs "len" characters from memory starting at "adr"

: sys-type  ( adr len -- )  13 syscall  2drop  ;

\ Returns to the OS

: sys-bye  ( -- )  0 9 syscall  ;

\ Memory allocation

: sys-alloc-mem  (s #bytes -- adr )  26 syscall  drop  retval  ;
: sys-free-mem  (s adr #bytes -- )   32 syscall  2drop  ;

\ Cache flushing - needed for copyback data caches (e.g. 68040)

: sys-sync-cache  ( adr len -- )  swap 29 syscall 2drop  ;

: install-wrapper-io  ( -- )
   ['] sys-alloc-mem     is alloc-mem
   ['] sys-free-mem      is free-mem

   ['] sys-cr            is cr
   ['] sys-type          is (type
   ['] sys-emit          is (emit
   ['] sys-key           is (key
   ['] sys-(key?         is key?
   ['] sys-bye           is bye
   ['] sys-accept        is accept
   ['] sys-interactive?  is (interactive?

   ['] sys-sync-cache    is sync-cache
;
headers
