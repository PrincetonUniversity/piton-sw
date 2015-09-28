\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: 64bit-ops.fth
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
id: @(#)64bit-ops.fth 1.1 06/10/30
purpose: 
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

: xxlsplit ( x1 x2 -- x2.lo x1.lo x1.hi x2.hi ) 
   xlsplit rot xlsplit rot
;

: x= ( x1 x2 -- eq? ) xxlsplit = >r = r> and ;

: x< ( x1 x2 -- lt? )
   xxlsplit 2dup < if 	( x2.lo x1.lo x1.hi x2.hi )
      2drop 2drop true	( true )
   else 		( x2.lo x1.lo x1.hi x2.hi )
      > if		( x2.lo x1.lo )
	 2drop false	( false )
      else		( x2.lo x1.lo )
	 swap u<			( flag )
      then
   then 
;

: x> ( x1 x2 -- gt? )
   xxlsplit 2dup > if 	( x2.lo x1.lo x1.hi x2.hi )
      2drop 2drop true	( true )
   else 		( x2.lo x1.lo x1.hi x2.hi )
      < if		( x2.lo x1.lo )
	 2drop false	( false )
      else		( x2.lo x1.lo )
	 swap u>	( flag )
      then
   then 
;

: x<> ( x1 x2 -- ne? ) xxlsplit <> -rot <> or ;

: x<= ( x1 x2 -- lte? )
   xxlsplit 2dup < if 	( x2.lo x1.lo x1.hi x2.hi )
      2drop 2drop true	( true )
   else			( x2.lo x1.lo x1.hi x2.hi ) 
      > if		( x2.lo x1.lo )
	 2drop false	( false )
      else		( x2.lo x1.lo )
	 swap u<=	( flag )
      then
   then 
;

: x>= ( x1 x2 -- gte? )
   xxlsplit 2dup > if 	( x2.lo x1.lo x1.hi x2.hi )
      2drop 2drop true	( true )
   else			( x2.lo x1.lo x1.hi x2.hi ) 
      < if		( x2.lo x1.lo )
	 2drop false	( false )
      else		( x2.lo x1.lo )
	 swap u>=	( flag )
      then
   then 
;

: xwithin ( n min max -- min<=n<max? )
   >r over r> x< -rot swap x<= and     
;

: x0= ( x -- 0? ) 0 x= ;

: x0<> ( x -- 0<>? ) 0 x<> ;

: +x! ( n addr -- ) dup x@ rot + swap x!	;

\ Tokenizer sign extends bit[31] all the way to bit[63].
\ To weed out numbers which have been sign extended from 
\ the real 64 bit number, we should check if the upper 32
\ bits are all 1's and in that case discard them.

h# ff h# ff h# ff h# ff bljoin constant mask32
: unsigned-x ( x -- unsigned-x )
   dup xlsplit mask32 = 	( x x.lo x.hi-ones? )
   if				( x x.lo )
      nip			( x.lo )
   else
      drop			( x )
   then
;
