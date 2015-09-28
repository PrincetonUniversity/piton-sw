\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: transien.fth
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
\ transien.fth 2.10 99/05/04
\ Copyright 1985-1990 Bradley Forthware

\ Transient vocabulary
\
\ transient  ( -- )		Compile following definitions into the
\				transient dictionary
\				Nested 'transient's are *not* allowed
\ resident  ( -- )		Compile following definitions into the resident
\				dictionary.

decimal
0 value transize
0 value transtart

0 value there
0 value hedge
0 value ouser
   \ Two dictionary pointers exist, for transient space and
   \ resident space.  "Here" always points to the set currently being used.
   \ "There" points to the "other" one.
   \ "limit" is top of current space, "hedge" is top of other space
   \ "ouser" is the other user area allocation pointer.
0 value transient?

hex
: set-transize  ( transient-size user-transient-size -- )
   over  0=  if                          ( 0 user-transient-size )
      transize  if                       ( 0 user-transient-size )
         transtart transize +  is limit  ( 0 user-transient-size )
      then                               ( 0 user-transient-size )
      drop  is transize                  ( )
      exit
   then

   there transtart <> abort" Cannot change transient area unless unused."

   user-size swap - is ouser

   is transize
   limit is hedge			\ Top of transient space
   hedge transize -  is transtart
   transtart   is there
   transtart   is limit
;
decimal
\   \t16 decimal 30000 set-transize
\   \t32 decimal 40000 set-transize

: exchange  ( -- )  \ switch "here" with "there"
   here   there dp !       is there
   limit  hedge is limit   is hedge

   #user @  ouser #user !  is ouser
   \ XXX need to support limit checking for user area too.
;

: in-any-dictionary?  ( adr -- flag )
   dup origin here between    ( adr flag )
   transize  if
      swap  transtart dup transize +  between  or
   else
      nip
   then
;
' in-any-dictionary?  is in-dictionary?

false value suppress-transient?
: transient  ( -- )
   suppress-transient?  if  exit  then
   transient? abort" Nested transient's not allowed"
   true is transient?
   exchange
;
: resident  ( -- )  transient?  if  false is transient?  exchange  then  ;

: headerless:  ( r-xt -- )  origin+  create 0 setalias  ;
: header:      ( r-xt -- )  drop [compile] \ ; immediate
