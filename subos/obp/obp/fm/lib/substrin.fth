\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: substrin.fth
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
\ substrin.fth 2.6 94/09/06
\ Copyright 1985-1990 Bradley Forthware

\ High level versions of string utilities needed for sifting

only forth also hidden also definitions
decimal
forth definitions
\ True if str1 is a substring of str2
: substring?   ( adr1 len1  adr2 len2 -- flag )
   rot tuck     ( adr1 adr2 len1  len2 len1 )
   <  if  drop 2drop false  else  tuck $=  then
;

headerless
: unpack-name ( anf where -- where) \ Strip funny chars from a name field
   swap name>string rot pack
;
hidden definitions
: 4drop  ( n1 n2 n3 n4 -- )  2drop 2drop  ;
: 4dup   ( n1 n2 n3 n4 -- n1 n2 n3 n4 n1 n2 n3 n4 )  2over 2over  ;

headers
forth definitions
: sindex  ( adr1 len1 adr2 len2 -- n )
   0 >r
   begin  ( adr1 len1 adr2' len2' )
      \ If string 1 is longer than string 2, it is not a substring
      2 pick over  >  if  4drop  r> drop  -1 exit   then
      4dup substring?  if  4drop r> exit  then
      \ Not found, so remove the first character from string 2 and try again
      swap 1+ swap 1-
      r> 1+ >r
   again
;
only forth also definitions
