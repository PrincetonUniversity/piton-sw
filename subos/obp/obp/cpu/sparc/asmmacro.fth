\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: asmmacro.fth
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
id: @(#)asmmacro.fth 2.13 07/06/05 10:54:41
purpose: Assembly language macros related to the Forth implementation
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.
\ Copyright 1985-1990 Bradley Forthware

\ These words are specific to the virtual machine implementation
: assembler  ( -- )  srassembler  ;

only forth also assembler also definitions

\ Forth Virtual Machine registers

\ Note that the Forth Stack Pointer (r1) is NOT the same register that
\ C uses for the stack pointer (r14).  The hardware does all sorts of
\ funny things with the C stack pointer when you do save and restore
\ instructions, and when the register windows overflow.

: base %g2  ;  : up  %g3  ;  : tos  %g4  ;
: ip   %i3  ;  : rp  %i4  ;  : sp   %i5  ;

: scr %l0  ;  : sc1  %l1 ;  : sc2  %l2 ;  : sc3 %l3  ;
: sc4 %l4  ;  : sc5  %l5 ;  : sc6  %l6 ;  : sc7 %l7  ;

\ C stack pointer is %o6
: spc %o7  ;	\ Saved Program Counter - set by the CALL instruction

\ Macros:

32\ : slln  ( rs1 rs2 rd -- ) sll  ;
32\ : srln  ( rs1 rs2 rd -- ) srl  ;
32\ : sran  ( rs1 rs2 rd -- ) sra  ;
32\ : nget  ( ptr off  dst -- )  ld  ;
32\ : nput  ( src off  ptr -- )  st  ;

64\ : slln  ( rs1 rs2 rd -- ) sllx  ;
64\ : srln  ( rs1 rs2 rd -- ) srlx  ;
64\ : sran  ( rs1 rs2 rd -- ) srax  ;
64\ : nput  ( src off  ptr -- )  stx  ;
64\ : nget  ( ptr off  dst -- )  ldx  ;

: put  ( src ptr -- )  0  swap  nput ;
: get  ( ptr dst -- )  0  swap  nget ;

: lget   ( ptr dst -- )  0 swap ld  ;
: lput   ( src ptr -- )  0 swap st  ;

: move  ( src dst -- )  %g0 -rot add    ;
: ainc  ( ptr -- )      dup /n swap add  ;
: adec  ( ptr -- )      dup /n swap sub  ;
: push  ( src ptr -- )  dup adec  put   ;
: pop   ( ptr dst -- )  over -rot get  ainc  ;
: test  ( src -- )      %g0 %g0 addcc   ;
: cmp   ( s1 s2 -- )    %g0     subcc   ;
: %hi   ( n -- n.hi )   h# 03ff invert land  ;
: %lo   ( n -- n.lo )   h# 03ff land  ;
: rtget ( srca srcb dst -- )
\t16  dup >r lduh r> ( dst )  tshift over sll
\t32  ld
;

\ Put a bubble in the pipeline to patch the load interlock bug
: bubble  ( nop )  ;

\ The next few words are already in the forth vocabulary;
\ we want them in the assembler vocabulary too
alias next  next
: exitcode  ( -- )
   previous
;
' exitcode is do-exitcode

alias end-code  end-code
alias c;  c;

: 'user  \ name  ( -- user-addressing-mode )
   up       ( reg# )
   '        ( acf-of-user-variable )
   >user#   ( reg# offset )
   dup h# 1000 [ also forth ] >= [ previous ] abort" user number too big"
;
: 'body  \ name  ( -- variable-apf-offset )
   '  ( acf-of-user-variable )  >body  origin-
;
: 'acf  \ name  ( -- variable-acf-offset )
   '  ( acf-of-user-variable )  origin-
;

\  If  'user  kicks you out -- or if you think it might -- use this:
\  It uses a  temp-register  to allow for a large user-offset.
\  If the user-offset is small enough, it acts like  'user
\
\  Oh!  And another nice thing about this:  If this is going to be part
\  of a "load" instruction (e.g., LD , LDX, NGET, etc.), the destination
\  register of that instruction can be used as the  temp-register ...
\
: 'userx  ( temp-reg -- user-addressing-mode ) \ <Name>
   dup up ' >user#			( temp-reg temp-reg user-reg# offset )
   dup h# 1000 [ also forth ] < if
      2swap 2drop exit					 (  user-reg# offset )
   then  [ previous ]			( temp-reg temp-reg user-reg# offset )
   \  Generate instruction(s) to load
   \  the offset into  temp-register .
   rot					( temp-reg user-reg# offset temp-reg )
   set					( temp-reg user-reg# )
;

: apf  ( -- reg offset )
\t16  sc1 2       \ code field is a 16-bit token
\t32  spc 8       \ code field is 2 instructions
;

: nops ( n -- )  0  ?do  nop  loop ;
: .align ( n -- )  here swap round-up here - 2 rshift nops  ;

: entercode  ( -- )  !csp align also assembler  ;
' entercode is do-entercode

only forth also definitions
