\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: lmove.fth
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
\ lmove.fth 2.4 94/05/30
\ Copyright 1985-1990 Bradley Forthware

code lmove  (s from-addr to-addr cnt -- )
   sp 1 /n*  scr   nget       \ Src into scr
   sp 0 /n*  sc1   nget       \ Dst into sc1

   scr tos  scr  add    \ Src = src+cnt (optimize for low-to-high copy)
   sc1 tos  sc1  add    \ Dst = dst+cnt
   sc1 4    sc1  sub    \ Account for the position of the addcc instruction
   %g0 tos  tos  subcc  \ Negate cnt

   <> if
      nop
      begin
         scr tos   sc2  ld         \ (delay) Load byte
         tos 4     tos  addcc      \ (delay) Increment cnt
      >= until
         sc2   sc1 tos  st         \ Store byte
   then   

   sp 2 /n*  tos    nget      \ Delete 3 stack items
   sp 3 /n*  sp     add     \   "
c;
code wmove  (s from-adr to-adr #bytes -- )
   sp 1 /n*   scr   nget       \ Src into scr
   sp 0 /n*   sc1   nget       \ Dst into sc1

   scr tos  scr  add    \ Src = src+cnt (optimize for low-to-high copy)
   sc1 tos  sc1  add    \ Dst = dst+cnt
   sc1 2    sc1  sub    \ Account for the position of the addcc instruction
   %g0 tos  tos  subcc  \ Negate cnt

   <> if
      nop
      begin
         scr tos   sc2  lduh       \ (delay) Load byte
         tos 2     tos  addcc      \ (delay) Increment cnt
      >= until
         sc2   sc1 tos  sth        \ Store byte
   then   

   sp 2 /n*  tos    nget    \ Delete 3 stack items
   sp 3 /n*  sp     add     \   "
c;
