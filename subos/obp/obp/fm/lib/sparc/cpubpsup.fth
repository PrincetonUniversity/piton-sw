\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: cpubpsup.fth
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
\ cpubpsup.fth 2.10 97/07/17
\ Copyright 1985-1990 Bradley Forthware
\ SPARC-specific breakpoint support routines.

\ Processor-dependent definitions for breakpoints on the SPARC

headerless
0 value breakpoint-opcode
defer breakpoint-trap?

headers
defer op!
defer op@

: .instruction  ( -- )  %pc  [ disassembler ] pc! dis1  ;

headerless
: bp-address-valid?  ( adr -- flag )  3 and  0=  ;
: at-breakpoint?  ( adr -- flag )  op@  breakpoint-opcode =  ;
: put-breakpoint  ( adr -- )  breakpoint-opcode swap op!  ;

\ Find the places to set the next breakpoint for single stepping.
\ Usually the right place is at nPC .  However, for annulled branch
\ instructions, we have to cope with the possibility that the delay
\ instruction, which is where nPC points, won't be executed.  Annulled
\ unconditional branches never execute the delay instruction, so we have
\ to put the breakpoint at the branch target.  Annulled conditional
\ branches will either execute the delay instruction or the one right
\ after it.

: disp16 ( opcode -- disp16 )
   dup h# 3fff and  swap 3 d# 20 lshift and  6 rshift  or
   dup h# 8000 and  if  h# ffff.0000 or  then
;
: disp19 ( opcode -- disp19 )
   h# 07.ffff and
   dup h# 04.0000 and  if  h# fff8.0000 or  then
;
: disp22 ( opcode -- disp22 )
   h# 003f.ffff and
   dup h# 20.0000 and  if  h# ffc0.0000 or  then
;

: next-instruction  ( stepping? -- next-adr branch-target|0 )
   0= if  %pc la1+  0  exit  then   \ May not work for annulled branches
   %pc op@                                     ( opcode )
   \ not format 2 (op=0)
   dup  h# c000.0000 and                       ( opcode flag1 )
   \ sethi
   over h# 01c0.0000 and h# 0100.0000 =  or    ( opcode flag2 )
   \ non an annulled branch
   over h# 2000.0000 and 0=  or  if            ( opcode )
      drop %npc 0  exit
   then                                        ( opcode )

   dup  h# 1e00.0000 and  h# 1000.0000 <>  if  ( opcode )
      \ It's a conditional branch
      drop  %npc  %npc 4 + exit
   then                                        ( opcode )

   \ Unconditional branch. Need branch offset  ( opcode )
   dup h# 01c0.0000 and d# 22 rshift  case     ( opcode op2 )
      b# 011  of  disp16  endof
      b# 101  of  disp19  endof
      b# 001  of  disp19  endof
      \ default
      ( opcode op2 )
      swap disp22 swap                         ( disp22 op2 )
   endcase                                     ( dispXX )
   2 lshift l->n  %pc +  0                     ( branch-target 0 )
;
headers
: bumppc  ( -- )  %pc la1+ to %pc  %pc la1+ to %npc  ;
alias rpc %pc

code goto  ( adr -- )
   tos       scr  move
   sp        tos  get
   scr %g0   %g0  jmpl
   sp /n     sp   add
end-code

headerless
: return-adr  ( -- adr )  0 w %i7 8 +  ;
: leaf-return-adr  ( -- adr )  0 w  %o7 8 +  ;
: backward-branch?  ( adr -- flag )  \ True if adr points to a backward branch
   l@                               ( instruction )
   dup   h# c000.0000 and  0=       ( instruction flag )  \ Must be format 0
   over  h# 01c0.0000 and  case				  \ Must be a branch
         h# 0080.0000 of  true  endof   \ bcc
         h# 0180.0000 of  true  endof   \ bfcc
         h# 01c0.0000 of  true  endof   \ bccc
        ( else )          false swap
   endcase  and                     ( instruction flag )
   swap  h# 0020.0000 and 0<>  and  ( flag )		  \ Offset must be < 0
;
: loop-exit-adr  ( -- adr )
   \ Start at PC-4 in case we're sitting on a delay instruction at the loop end
   %pc 4 -  begin  dup backward-branch? 0=  while  4 +  repeat  8 +
;

headers
: set-pc  ( adr -- )  dup to %pc  4 + to %npc  ;
