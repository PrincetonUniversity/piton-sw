\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: probe.fth
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
\ @(#)probe.fth 2.10 04/10/06
\ Copyright 1985-1994 Bradley Forthware
\ Copyright 1994-2002,2004 Sun Microsystems, Inc.  All Rights Reserved
\ Copyright Use is subject to license terms.

\ Test locations for accessability.
\   X is c , w , or l for 8, 16, or 32-bit access.
\
\   Xprobe  ( adr -- flag )
\	Read location, return false if bus error, otherwise return true.
\   Xpeek   ( adr -- false | value true )
\	Read location, return false if bus error, otherwise return data
\	and true.
\   Xpoke   ( value adr -- flag )
\	Write location, return false if bus error, otherwise return true.

headers

\ tos = operation
\ 0 = c@
\ 1 = w@
\ 2 = l@
\ 3 = x@
\ 4 = c!
\ 5 = w!
\ 6 = l!
\ 7 = x!

code safe-touch
   %g0	tos	scr		add		\ get operation
   scr	3	scr		sllx		\ shift left for offset
   sp	tos			pop
   never if					\ never1
      sc2			rdpc		\ delay
      scr	h# 8	%g0	jmpl		\ just before never2 
      tos	0	tos	ldub		\ c@
      scr	h# 8	%g0	jmpl		\ just before never2 
      tos	0	tos	lduh		\ w@
      scr	h# 8	%g0	jmpl		\ just before never2 
      tos	0	tos	ld		\ l@
      scr	h# 8	%g0	jmpl		\ just before never2 
      tos	0	tos	ldx		\ x@
      scr	h# 10	%g0	jmpl		\ just after never2 
      sc3	tos	0	stb		\ c!
      scr	h# 10	%g0	jmpl		\ just after never2 
      sc3	tos	0	sth		\ w!
      scr	h# 10	%g0	jmpl		\ just after never2 
      sc3	tos	0	st		\ l!
      scr	h# 10	%g0	jmpl		\ just after never2 
      sc3	tos	0	stx		\ x!
   then
   sc2	h# 4	sc2		add		\ after the rdpc
   sc2	scr	scr		jmpl		\ jump into never1
   sp	0	sc3		ldx		\ for the !s
   never if					\ never2
      #sync membar				\ (delay) sync on read too
      sp    1 /n*	tos     ldx             \ complete then get rid of 
      sp    2 /n*	sp      add             \ the two stack items
   then
c;

only forth also hidden also
hidden definitions
headerless
: peeker  ( adr acf -- value true | false)
   guarded-execute  dup 0=  if  nip nip then
;
: prober  ( adr acf -- flag )  guarded-execute nip dup 0= if nip then ;
: poker  ( value adr acf -- flag )	\ Flag is true if success
  guarded-execute  dup 0=  if  nip nip nip then
;


headers
forth definitions
: cpeek  ( adr -- false | value true )  0 ['] safe-touch peeker   ;
: wpeek  ( adr -- false | value true )  1 ['] safe-touch peeker  ;
: lpeek  ( adr -- false | value true )  2 ['] safe-touch peeker  ;
64\ : xpeek   ( adr -- false | value true )  3 ['] safe-touch peeker  ;
 
\ : peek   ( adr -- false | value true )  [']  @ peeker  ;
 
: cprobe  ( adr -- present-flag )  0 ['] safe-touch prober  ;
: wprobe  ( adr -- present-flag )  1 ['] safe-touch prober  ;
: lprobe  ( adr -- present-flag )  2 ['] safe-touch prober  ;
64\ : xprobe  ( adr -- present-flag )        3 ['] safe-touch prober  ;
 
\ : probe   ( adr -- present-flag )   peek probe-fix  ;
 
: cpoke   ( value adr -- flag )  4 ['] safe-touch poker  ;
: wpoke   ( value adr -- flag )  5 ['] safe-touch poker  ;
: lpoke   ( value adr -- flag )  6 ['] safe-touch poker  ;
64\ : xpoke   ( value adr -- flag )          7 ['] safe-touch poker  ;       
only forth also definitions
