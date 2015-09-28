\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: objects.fth
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
\ objects.fth 2.16 01/05/18
\ Copyright 1985-1990 Bradley Forthware
\ Copyright 1990-2001 Sun Microsystems, Inc.  All Rights Reserved

\ Action definition for multiple-code-field words.
\ Data structures:
\   nth-action-does-clause   acfs  unnest
\   n-1th-action-does-clause acfs  unnest
\   ...
\   1th-action-does-clause acfs  unnest
\   nth-adr
\   n-1th-adr
\   ...
\   1th-adr
\   n
\   0th-action-does-clause acfs  unnest
\   object-header  build-acfs
\   (') 0th-adr uses

needs doaction objsup.fth	\ Machine-dependent support routines

decimal
headerless

0 value action#
0 value #actions
0 value action-adr
headers
: actions  ( #actions -- )
   is #actions
   #actions 1- /token * na1+ allot    ( #actions )   \ Make the jump table
   \ The default action is a code field, which must be aligned
   align acf-align  here is action-adr
   0 is action#
   #actions  action-adr /n -  !
;
headerless
\ Sets the address entry in the action table
: set-action  ( -- )
   action#  #actions  > abort" Too many actions defined"
   lastacf  action-adr  action# /token * -  /n -  token!
;
headers
: action:  ( -- )
   action# if   \ Not the default action
      doaction set-action
   else \ The default action, like does>
      place-does
   then

   action# 1+ is action#
   !csp
   ]
;
: action-code  ( -- )
   action#  if   \ Not the default action
      acf-align start-code set-action
   else          \ The default action, like ;code
      start-;code
   then

   \ For the default action, the apf of the child word is found in
   \ the same way as with ;code words.

   action# 1+ is action#
   do-entercode
;
: use-actions  ( -- )
   state @  if
      compile (')  action-adr  token,  compile used
   else
      action-adr  used
   then
; immediate

headerless
: .object-error
   ( object-acf action-adr false  |  acf action# #actions true -- ... )
   ( ... -- object-acf action-adr )
   if
      ." Unimplemented action # " swap .d  ." on object " swap .name
      ." , whose maximum action # is " 1- .d cr
      abort
   then
;

headers

\ Executes the numbered action of the indicated object
\ It might be worthwhile to implement perform-action entirely in code.
: perform-action  ( object-acf action# -- )
   dup if
      >action-adr .object-error  ( object-apf action-adr )
      execute
   else
      drop execute
   then
;


1 action-name to
2 action-name addr

\ Add these words to the decompiler case tables so that the
\ debugger will display their arguments and so that the decompiler
\ will not show the action name and its argument on separate lines
\ if it happens to be near the end of a line.

: .action  ( ip -- ip' )  dup token@ .name ta1+ dup token@ .name ta1+  ;
also hidden also
' to   ' .action  ' skip-(')  install-decomp
' addr ' .action  ' skip-(')  install-decomp
previous previous

: ?has-action  ( object-acf action-acf -- object-acf action-acf )
   2dup >body >action# >action-adr .object-error  2drop
;
: action-compiler:  \ name  ( -- )
   parse-word  2dup $find  $?missing drop  \ adr len xt
   warning @ >r warning off
   -rot $create  token,  immediate
   r> warning !
   does>             ( apf )
      ' swap token@  ( object-acf action-acf )
      ?has-action    ( object-acf action-acf )
      +level         ( apf )	\ Enter temporary compile state if necessary
      compile,		\ Compile run-time action-name word
      compile,		\ Compile object acf
      -level		\ Exit temporary compile state, perhaps run word
;
\ action-compiler: to
action-compiler: addr


\ Makes "is" and "to" synonymous.  "is" first checks to see if the
\ object is of one of the kernel object types (which don't have multiple
\ code fields), and if so, compiles or executes the "(is) <token>" form.
\ If the object is not of one of the kernel object types, "is" calls
\ "to-hook" to handle the object as a multiple-code field type object.

: (to)  ( [data] acf -- )  +level  compile to  compile, -level  ;
' (to) is to-hook
warning @ warning off
alias to is
warning !

\ 3 actions
\ action:  @  ;
\ action:  !  ; ( is )
\ action:     ; ( addr )
\ : value  \ name  ( initial-value -- )
\    create ,
\    use-actions
\ ;

3 actions
action: >user 2@ ;
action: >user 2! ;
action: >user    ;
: 2value  ( n1 n2 "name" -- )  create  2 /n* user#,  2!  use-actions  ;
