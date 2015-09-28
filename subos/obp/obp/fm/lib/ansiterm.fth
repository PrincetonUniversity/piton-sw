\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ansiterm.fth
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
id: @(#)ansiterm.fth 1.1 94/09/01
purpose: Terminal control for ANSI terminals
copyright: Copyright 1994 FirmWorks  All Rights Reserved.

headerless
: .esc[        ( -- )     control [ (emit  [char] [ (emit  ;
: .esc[x       ( c -- )   .esc[ (emit  ;
headers

: left         ( -- )     [char] D .esc[x  -1 #out  +!  ;
: right        ( -- )     [char] C .esc[x   1 #out  +!  ;
: up           ( -- )     [char] A .esc[x  -1 #line +!  ;
: down         ( -- )     [char] B .esc[x   1 #line +!  ;
: insert-char  ( c -- )   [char] @ .esc[x  (emit ;
: delete-char  ( -- )     [char] P .esc[x  ;
: kill-line    ( -- )     [char] K .esc[x  ;
: kill-screen  ( -- )     [char] J .esc[x  ;
: insert-line  ( -- )     [char] L .esc[x  ;
: delete-line  ( -- )     [char] M .esc[x  ;
: dark         ( -- )     [char] 7 .esc[x  [char] m (emit  ;
: light        ( -- )     [char] m .esc[x  ;

: at-xy  ( col row -- )
    2dup #line !  #out !
    base @ >r decimal
    .esc[   1+ (.) (type  [char] ; (emit  1+ (.) (type  [char] H (emit
    r> base !
;
: page         ( -- )  0 0 at-xy  kill-screen  ;

false [if] 
headerless
: color:  ( adr len "name" -- )
   create ",  does> .esc[  count (type  [char] m (emit
;
headers

" 0"    color: default-colors
" 1"    color: bright
" 2"    color: dim
" 30"   color: black-letters
" 31"   color: red-letters
" 32"   color: green-letters
" 33"   color: yellow-letters
" 34"   color: blue-letters
" 35"   color: magenta-letters
" 36"   color: cyanletters
" 37"   color: white-letters
" 40"   color: black-screen
" 41"   color: red-screen
" 42"   color: green-screen
" 43"   color: yellow-screen
" 44"   color: blue-screen
" 45"   color: magenta-screen
" 46"   color: cyan-screen
" 47"   color: white-screen
[then]
