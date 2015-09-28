\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: th.fth
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
\ id: @(#)th.fth 2.6 96/06/04
\ Copyright 1985-1990 Bradley Forthware
\ Modified by  M.Milendorf
\ and again by Tayfun.
\ Copied over by Dave Redman from Tayfun's tree.
\
\ Temporary hex, and temporary decimal.  "h#" interprets the next word
\ as though the base were hex, regardless of what the base happens to be.
\ "d#" interprets the next word as though the base were decimal.
\ "o#" interprets the next word as though the base were octal.
\ "b#" interprets the next word as though the base were binary.

\  Also, words to stash and set, and retrieve, the base during execution
\     of a word in which they're used.  The words of the form  push-<base>
\     (where <base> is hex, decimal, etcetera) does the equivalent of
\     base @ >r <base>     The word  pop-base  recovers the old base...

decimal
: #:  \ name  ( base -- )  \ Define a temporary-numeric-mode word
   create c, immediate
   does>
      base @ >r  c@ base !
      parse-word
      2dup 2>r  $handle-literal?  0=  if
	 2r@  $compile
      then
      2r> 2drop
      r> base !
;

\ The old names; use h# and d# instead
10 #: td
16 #: th

: push-base:  \ name   ( base -- )  \  Define a base stash-and-set word
   create c,
   does>  r> base @ >r >r c@ base !
;

\ Stash the old base on the return stack and set the base to ...
10 push-base:  push-decimal
16 push-base:  push-hex

 2 push-base:  push-binary
 8 push-base:  push-octal

\ Retrieve the old base from the return stack
: pop-base ( -- )  r> r> base ! >r ;

headers

 2 #: b#	\ Binary number
 8 #: o#	\ Octal number
10 #: d#	\ Decimal number
16 #: h#	\ Hex number

headers
