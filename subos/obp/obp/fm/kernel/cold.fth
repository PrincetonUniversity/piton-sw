\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: cold.fth
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
\ cold.fth 2.6 94/09/11
\ Copyright 1985-1994 Bradley Forthware

\ Some hooks for multitasking
\ Main task points to the initial task.  This usage is currently not ROM-able
\ since the user area address has to be later stored in the parameter field
\ of main-task.  It could be made ROM-able by allocating the user area
\ at a fixed location and storing that address in main-task at compile time.

defer pause  \ for multitasking
' noop  is pause

defer init-io    ( -- )
defer do-init    ( -- )
defer cold-hook  ( -- )
defer init-environment  ( -- )

[ifndef] run-time
: (cold-hook  (s -- )
   [compile] [
;

' (cold-hook  is cold-hook
[then]

: cold  (s -- )
   decimal
   init-io			  \ Memory allocator and character I/O
   do-init			  \ Kernel
   ['] init-environment guarded	  \ Environmental dependencies
   ['] cold-hook        guarded	  \ Last-minute stuff

   process-command-line

   \ interactive? won't work because the fd hasn't been initialized yet
   (interactive?  if  title  then

   quit
;

[ifndef] run-time
headerless
: single  (s -- )  \ Turns off multitasking
   ['] noop ['] pause (is
;
headers
: warm   (s -- )  single  sp0 @ sp!  quit  ;
[then]
