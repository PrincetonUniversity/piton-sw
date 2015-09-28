\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: catchsel.fth
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
id: @(#)catchsel.fth 2.5 03/12/08 13:21:57
purpose: 
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Use is subject to license terms.

\ Special version of catch and throw for Open Boot PROMs.  This version
\ saves and restores the "my-self" current package instance variable.

0 value my-self

nuser handler   \ Most recent exception handler

\ This was nasty, but we no longer need to arrange things so that my-self
\ can be defined later.
\ The new kernel 'is' is now about 30% faster than even an  avalue , so
\ moving my-self into devtree.fth  is no longer a performance win.

\  : get-my-self ( -- n ) 0 ;
\  : set-my-self ( n -- ) drop  ;

: catch  ( execution-token -- error# | 0 )
                        ( token )  \ Return address is already on the stack
   sp@ >r               ( token )  \ Save data stack pointer
   my-self >r           ( token )  \ Save current package instance handle
   handler @ >r         ( token )  \ Previous handler
   rp@ handler !        ( token )  \ Set current handler to this one
   execute              ( )        \ Execute the word passed in on the stack
   r> handler ! ( )                \ Restore previous handler
   r> drop              ( )        \ Discard saved package instance handle
   r> drop              ( )        \ Discard saved stack pointer
   0                    ( 0 )      \ Signify normal completion
;

: throw  ( ??? [ error# | 0 ] -- ???' [ error# ] )  \ Returns to saved context
   ?dup if                             \ Don't throw 0
      handler @ rp!     ( err# )       \ Return to saved return stack context
      r> handler !      ( err# )       \ Restore previous handler
      r> is my-self     ( err# )       \ Restore package instance handle
                        ( err# )       \ Remember error# on return stack
                        ( err# )       \ before changing data stack pointer
      r> swap >r        ( saved-sp )   \ err# is on return stack
      sp! drop r>       ( err# )       \ Change stack pointer
      \ This return will return to the caller of catch, because the return
      \ stack has been restored to the state that existed when CATCH began
      \ execution .
   then
;
