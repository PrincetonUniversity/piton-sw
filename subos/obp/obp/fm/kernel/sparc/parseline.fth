\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: parseline.fth
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
\ parseline.fth 1.1 02/05/02
\ Copyright 1985-1990 Bradley Forthware
\ Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
\ Copyright Use is subject to license terms.
\ 
\ Splits a buffer into two parts around the first line delimiter
\ sequence.  A line delimiter sequence is either CR, LF, CR followed by LF,
\ or LF followed by CR.
\ adr1 len2 is the initial substring before, but not including,
\ the first line delimiter sequence.
\ adr2 len3 is the trailing substring after, but not including,
\ the first line delimiter sequence.

code parse-line  ( adr1 len1 -- adr1 len2  adr1+len2 len1-len2 )
   tos       sc1  move	\ len1
   sp 0 /n*  scr  nget	\ adr1
   sp 2 /n*  sp   sub	\ Make room for extra return values

   h# 0a     tos  move	\ Delimiter 1
   h# 0d     sc4  move	\ Delimiter 2

   scr sc1   scr  add	\ Point to end
   %g0 sc1   sc3  sub	\ Index counts up from -len1
   sc3 1     sc3  sub	\ Account for pre-increment

   ahead
      sc3 1  sc3  addcc		\ Delay: Increment and test counter
   begin

      tos sc2 cmp  = if annul  sc4 sc2 cmp  then  \ Compare to delimiters

      = if annul		\ Exit if delimiter found
         sc3 1  sc3  addcc	\ Delay: Increment and test counter

         sc1 sc3    sc1  add	\ Compute len2
	 sc1   sp 1 /n*  nput	\ .. and store on stack

         sc3 1      sc3  addcc	\ Consume first delimiter
         \ Check next character too, unless we're at the end of the buffer
         0<>  if  nop
	    scr sc3  sc5  ldub	\ Get the next character

            \ Compare next character to other delimiter
            tos sc2 cmp  =  if  tos sc5 cmp   sc4 sc5 cmp  then

	    <>  if annul	\ If next character is the other delimiter
	       sc3 1   sc3  add	\ ... consume it
            then
         then
	 scr sc3    scr  add	\ Compute adr1+len2
	 scr   sp 0 /n*  nput	\ .. and store on stack

         %g0 sc3    tos  sub	\ Return len1-len2
	 next
      then

   but then
   0= until annul
   scr sc3  sc2  ldub	\ Delay: Get the next character

   \ There is no line delimiter in the input string

   scr   sp 0 /n*   nput	\ Store adr1+len2 on stack
   %g0   tos        move	\ Return rem-len=0
c;
