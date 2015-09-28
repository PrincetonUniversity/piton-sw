\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: uservars.fth
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
id: @(#)uservars.fth 2.14 03/12/08 13:22:17
purpose: 
copyright: Copyright 1999-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 1985-1994 Bradley Forthware
copyright: Use is subject to license terms.

decimal

\ Initial user number

[ifexist] #user-init
#user-init
[else]
0
[then]

[ifndef] run-time
\ First 5 user variables are used for multitasking
     dup user link		\ link to next task
/n + dup user entry		\ entry address for this task
 /n + dup user saved-rp	\ this is not MP safe
 /n + dup user saved-sp	\ this is not MP safe
[then]

\ next 2 user variables are used for booting
/n + dup user up0     \ initial up
/n + dup user #user   \ next available user location
/n +     #user-t !

/n constant #ualign
: ualigned  ( n -- n' )  #ualign round-up  ;

: (check-user-size) ( #bytes -- #bytes )
   dup #user @ + user-size >= abort" ERROR: User area used up!"   ( #bytes )
;

\  These will be altered later to enable user space to grow on demand:
user-size-t value user-size
defer check-user-size  ' (check-user-size) is check-user-size

: ualloc  ( #bytes -- new-user-number )  \ allocates user space
   check-user-size
   \ If we are allocating fewer bytes than the alignment granularity,
   \ it is safe to assume that strict alignment is not required.
   \ For example, a 2-byte token doesn't have to be aligned on a 4-byte
   \ boundary.
							   ( #bytes )
   #user @						   ( #bytes user# )
   over #ualign >=  if  ualigned dup #user !  then	   ( #bytes user#' )

   swap #user +!
;

[ifndef] run-time
: nuser  \ name  ( -- )  \ like user but automatically allocates space
   /n ualloc user
;
: tuser  \ name  ( -- )  \ like user but automatically allocates space
   /token ualloc user
;
: auser  \ name  ( -- )  \ like user but automatically allocates space
   /a ualloc user
;
[then]

nuser .sp0			\ initial parameter stack
nuser .rp0			\ initial return stack

defer sp0	' .sp0 is sp0	\ MPsafe versions
defer rp0	' .rp0 is rp0	\ MPsafe versions

headerless
\ This is the beginning of the initialization chain
chain: init ( -- )  up@ link !  ;	\ Initially, only one task is active
headers
