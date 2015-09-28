\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: decompm.fth
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
\ decompm.fth 2.9 94/06/11
\ Copyright 1985-1990 Bradley Forthware

\ Machine/implementation-dependent definitions
decimal
headerless

only forth also hidden also  definitions
: dictionary-base  ( -- adr )  origin  ;

\  forth definitions
\  defer hi-segment-base   ' here   is hi-segment-base
\  defer hi-segment-limit  ' here   is hi-segment-limit
\  defer lo-segment-base   ' origin is lo-segment-base
\  defer lo-segment-limit  ' here   is lo-segment-limit
\  hidden definitions

: ram/rom-in-dictionary?  ( adr -- flag )
   dup  #talign 1-  and  0=  if
      dup  lo-segment-base lo-segment-limit  within
      swap hi-segment-base hi-segment-limit  within  or
   else
      drop false
   then
;

' ram/rom-in-dictionary? is in-dictionary?

\ True if adr is a reasonable value for the interpreter pointer
: reasonable-ip?  ( adr -- flag )
   dup  in-dictionary?  if  ( ip )
      #talign 1- and 0=  \ must be token-aligned
   else
      drop false
   then
;

\ variable isvar  \ already defined
\ create iscreate \ already defined

headerless0
only forth also definitions
headers
