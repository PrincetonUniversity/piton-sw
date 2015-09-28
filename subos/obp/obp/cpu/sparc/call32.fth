\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: call32.fth
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
id: @(#)call32.fth 1.3 07/06/05 10:54:43
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.
\ Copyright 1985-1990 Bradley Forthware

\ From Forth, call the C subroutine whose address is on the stack

code call32  ( [ arg5 .. arg0 ] adr -- [ arg5 .. arg0 ] result )
   sp		    %o5   move	\ Propagate sp to new frame
   %o6 /entry-frame %o6   save
   %o6 V9_SP_BIAS   %o6   add
   %o0                    rdpstate
   %o0    h# 10     %o0   or
   %o0    0               wrpstate

   sp 0 /n*         %o0   nget
   sp 1 /n*         %o1   nget
   sp 2 /n*         %o2   nget
   sp 3 /n*         %o3   nget
   sp 4 /n*         %o4   nget
   sp 5 /n*         %o5   nget

   do-ccall               call
   tos              %l0   move

   %o0  0           tos   srl
   %o0                    rdpstate
   %o0  h# 10       %o0   andn
   %o0  0                 wrpstate
   %o6  V9_SP_BIAS  %o6   sub
   %g0  %g0         %g0   restore
   %o5		    sp    move  \ Propagate sp to new frame
c;
