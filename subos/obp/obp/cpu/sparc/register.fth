\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: register.fth
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
id: @(#)register.fth 2.16 07/06/05 10:54:45
purpose: Register names for saved program state
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.
\ Copyright 1985-1990 Bradley Forthware

\ This version uses multiple-code-field defining words for the self-fetching
\ register names.

\ Display and modify the saved state of the machine.
\
\ This code is highly machine-dependent.
\
\ Version for the SPARC processor
\
\ Requires:
\
\ >state  ( offset -- addr )
\	Returns an address within the processor state array given the
\	offset into that array
\ #windows ( -- n )
\	The number of implemented register windows
\ window-registers ( -- offset )
\	The offset from CPU-STATE to the start of the area where the
\	window registers are stored
\
\ Defines:
\
\ %g0 .. %g7  %o0 .. %o7  %l0 .. %l7  %i0 .. %i7
\ %pc %npc %y %psr
\ V8, Priviliged: %wim %tbr
\ Priviliged: cwp
\ w
\ .registers .locals

needs action: objects.fth

decimal

only forth hidden also forth also definitions

3 actions
action:  @ >state @  ;
action:  @ >state !  ; ( is )
action:  @ >state    ; ( addr )
transient
: global-reg  \ name  ( offset -- offset+/n )
   create  allocate-reg ,
   use-actions
;
: global-regs  \ name name ... ( offset #regs -- offset' )
   ( offset #regs )  0  ?do  global-reg  loop  ( offset' )
;
: offset-of  \ name  ( -- offset )
   parse-word ['] forth $vfind  if
      >body @ 1
   else
      ." offset-of can't find " type  cr
      where
   then
   do-literal
; immediate
resident

headerless
variable view-window
variable previous-outs
: >outreg  ( reg# -- )  previous-outs @  +  ;
: >window  ( reg# -- )  view-window @  +  ;
headers

3 actions
action:  @ >window @  ;
action:  @ >window !  ; ( is )
action:  @ >window    ; ( addr )
transient
: local-regs  \ name name ... ( reg# #regs -- )
   bounds  ?do  create  i /n* ,  use-actions  loop
;
resident

3 actions
action:  @ >outreg @  ;
action:  @ >outreg !  ; ( is )
action:  @ >outreg    ; ( addr )

transient
: out-regs  \ name name ... ( #regs -- )
   ( #regs )  0  do  create  i /n* ,  use-actions  loop
;
resident

4 global-regs %pc  %npc  %y  %psr

[ifdef] firmware
2 global-regs  %wim %tbr
[then]

8 global-regs %g0  %g1  %g2  %g3  %g4  %g5  %g6  %g7

2 global-regs %state-valid  %restartable?
\ Following words defined here to satisfy the
\ references to these "variables" anywhere else
: state-valid   ( -- addr )  addr %state-valid   ;
: restartable?  ( -- addr )  addr %restartable?  ;

[ifdef] firmware
3 global-regs %saved-my-self  last-trap#  error-reset-trap

\ Following words defined here to satisfy the
\ references to these "variables" anywhere else
: saved-my-self ( -- addr )  addr %saved-my-self  ;
[then]

\ The set of out registers has to be defined as a single batch.
\ They can't be defined piecemeal like global registers.
\ The set of local registers must be "batched" too.

8 out-regs    %o0  %o1  %o2  %o3  %o4  %o5  %o6  %o7

0 8 local-regs %l0  %l1  %l2  %l3  %l4  %l5  %l6  %l7
8 8 local-regs %i0  %i1  %i2  %i3  %i4  %i5  %i6  %i7

alias %base %g2
alias %up   %g3
alias %tos  %g4
alias %ip   %i3
alias %rp   %i4
alias %sp   %i5


false value standalone?	\ Can be used to turn off stuff in stand.exe
headerless

0 value window#

: aligned?  ( adr -- flag )  3 and 0=  ;
defer accessible?   ( adr -- flag )
: yes-accessible  ( adr -- true )  drop true  ;
' yes-accessible is accessible?

\ Invalid, unaligned, or inaccessible call point
: pointer-bad?  ( adr -- flag )   \ True if the address is not a good pointer
   dup 0<>   over aligned? and  swap accessible? and  0=
;

headers

: 0w  ( -- )
   window-registers >state   dup previous-outs !  8 na+  view-window !
   0 is window#
;

\ cached-window? can be used in cases where the hardware register windows
\ are saved in a place other than on the stack.
defer cached-window?  ( -- [ last? ] handled? )  ' false is cached-window?

: (+w)  ( -- last? )
   cached-window?  if  exit  then

   %i6 pointer-bad?   %i6 0=  or  if
      true exit
   else
      addr %i0  previous-outs !
      %i6  view-window !
   then
   window#  1+  is window#
   false
;
: +w  ( -- )  (+w) abort" No more valid windows"  ;

: set-window  ( n -- )  0w  ( n ) 0 ?do   (+w) ?leave  loop  ;
: w  ( n -- )
   dup  set-window  window# <>  if
      ." Window number too large.  The maximum number is " window# . cr
   then
;

headerless
defer .other-regs  ' noop is .other-regs
headers
: .registers ( -- )
   ??cr
."     "
."       %g0      %g1      %g2      %g3      %g4      %g5      %g6      %g7" cr
."     " addr %g0 8 .ndump   cr
."     "
."        PC      nPC        Y"     cr
."     " %pc .nx  %npc .nx  %y .nx  cr
.other-regs
;
: .locals
."     "
."         0        1        2        3        4        5        6        7"
cr
." IN: "   addr %i0  8 .ndump  cr
." LOC:"   addr %l0  8 .ndump  cr
." OUT:"   addr %o0  8 .ndump  cr
;

: init-window  ( -- )  0w  ;

: .window  ( window# -- )  w .locals  ;

only forth also definitions
