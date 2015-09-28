\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: catchexc.fth
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
id: @(#)catchexc.fth 2.10 07/06/05 
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.
\ Copyright 1985-1990 Bradley Forthware

\ Solaris 2.x version

\ Save the SPARC processor state after a signal.

\ This code is entered as a result of a Unix signal.
\ It saves the processor state and the register windows, then
\ enters Forth so that the state may be examined, and possibly
\ re-established later.

\ Because our dictionary is independent of the ELF binary
\ that loads it we can concievably end up with a 32-bit
\ dictionary running in a 32-bit process environment, a 64-bit
\ dictionary running in a 64-bit process environment, a 64-bit
\ dictionary running in a 32-bit process environment, or
\ concievably a 32-bit dictionary running in a 64-bit environment,
\ (Note: the last one will only work if the dictionary is located
\ entirely within the 32-bit address space, and our forth binary
\ currently does not ensure that.)
\
\ So we really should determine the size of the sigcontext structure
\ dynamically based on the stack bias.  However, to fully support
\ this we need to always allocate space for 64-bit registers in
\ our user save area and change the code to always save all 64-bits
\ of registers even on a 32-bit dictionarey.  But that's a project
\ for the future.  Right now I'll continue to use nget and nput.

decimal

only forth also hidden also  forth definitions

3 global-regs %signal#  %signal-code  %fault-addr
3 global-regs %psr %asi %fprs
0 value unix-cpu-state
hidden definitions

\ ?insane prevents endless occurrences of the same exception.
\ The variable "insane" is cleared after "expect" returns,
\ which is indicative of a human being somewhat in control.
: ?insane  ( -- )  insane @  if  bye  then  insane on  ;

: enterforth  ( -- )  init-window  ?insane  handle-breakpoint  ;

\ Offset from the %o6 stack pointer of saved %g2.
\ This depends in detail on the code in sigtramp.s

\ Here is what is on the stack below the globals:

\ word#   0      16         17     23        24    56     57    58
\ windowregs  struct-ret   args  align     fpregs  fsr    y   (total)
  16             1 +        6 +   even       32 +  1 +   1 +      /l*

constant %g2-offset  ( -- offset )

: exception  ( -- adr )  addr %signal#  ;

\ This is the second level save routine.  The first level is called
\ from the signal handler, saving the globals and processor state registers.
\ This second level is called after the handler returns, to save the
\ window registers and the stacks.

\ Align the start of window registers ( %o's %l's and %i's ) to 16 bytes
window-registers h# 10 round-up is window-registers

label finish-save

   spc  ( %o7 )       %g1   move   \ save a copy of %o7

   \ Set the base register
   here 8 +                 call   \ address of next instruction in spc
   nop
   here 8 - origin -  base  set	   \ relative address of current instruction
   spc base           base  sub	   \ subtract them to find the base address

   \ Find the user area
   32\ \t32   'body main-task    up    set
   32\ \t32   base up            up    ld     \ Address of main task's user area

   64\ \t32   'body main-task    up    set
   64\ \t32   base up            scr   add
   64\ \t32   scr  4             up    ld
   64\ \t32   scr  0             scr   ld
   64\ \t32   scr  th 20         scr   sllx
   64\ \t32   up   scr           up    add

   32\ \t16   'body main-task    up    set
   32\ \t16   base up            tos   add
   32\ \t16   tos  2             up    lduh
   32\ \t16   tos  0             tos   lduh
   32\ \t16   tos  th 10         tos   sll
   32\ \t16   up   tos           up    add

   64\ \t16   'body main-task    up    set
   64\ \t16   base up            tos   add
   64\ \t16   tos  6             up    lduh
   64\ \t16   tos  4             tos   lduh
   64\ \t16   tos  th 10         tos   sll
   64\ \t16   up   tos           up    add

   %g1                spc   move   \ restore %o7

   'user unix-cpu-state    %g4   nget     \ Base address of save area

   %g0 3            always  trapif \ Flush window registers to memory

   \ Save the ins, outs, locals

   window-registers  ( offset )

   0  +  %o0   %g4  2 pick    nput	\ %o0
   /n +  %o1   %g4  2 pick    nput	\ %o1
   /n +  %o2   %g4  2 pick    nput	\ %o2
   /n +  %o3   %g4  2 pick    nput	\ %o3
   /n +  %o4   %g4  2 pick    nput	\ %o4
   /n +  %o5   %g4  2 pick    nput	\ %o5
   /n +  %o6   %g4  2 pick    nput	\ %o6
   /n +  %o7   %g4  2 pick    nput	\ %o7

   /n +  %l0   %g4  2 pick    nput	\ %l0
   /n +  %l1   %g4  2 pick    nput	\ %l1
   /n +  %l2   %g4  2 pick    nput	\ %l2
   /n +  %l3   %g4  2 pick    nput	\ %l3
   /n +  %l4   %g4  2 pick    nput	\ %l4
   /n +  %l5   %g4  2 pick    nput	\ %l5
   /n +  %l6   %g4  2 pick    nput	\ %l6
   /n +  %l7   %g4  2 pick    nput	\ %l7

   /n +  %i0   %g4  2 pick    nput	\ %i0
   /n +  %i1   %g4  2 pick    nput	\ %i1
   /n +  %i2   %g4  2 pick    nput	\ %i2
   /n +  %i3   %g4  2 pick    nput	\ %i3
   /n +  %i4   %g4  2 pick    nput	\ %i4
   /n +  %i5   %g4  2 pick    nput	\ %i5
   /n +  %i6   %g4  2 pick    nput	\ %i6
   /n +  %i7   %g4  2 pick    nput	\ %i7

   drop

   \ Establish the Data and Return stacks
   'user .rp0         rp    nget
   'user .sp0         sp    nget

   \ Validate the saved state
   true               %l0   move
   %l0   %g4 offset-of %state-valid   nput
   %l0   %g4 offset-of %restartable?  nput

   \ Copy the entire Forth Data and Return stacks areas to a save area.

   \ Data Stack
   'user pssave       scr   nget    \ Address of data stack save area

   sp  ps-size        sc1   sub    \ Bottom of data stack area

   ps-size            sc2   move   \ Size of data stack area in sc2

   begin
      sc2 /n       sc2  subcc
      sc1 sc2      sc3  nget
   0= until
      sc3      scr sc2  nput		\ Delay slot

   \ Return Stack
   'user rssave       scr   nget     \ Address of return stack save area

   rp  rs-size        sc1   sub    \ Bottom of return stack area

   rs-size            sc2   move   \ Size of return stack area in sc2

   begin
      sc2 /n       sc2  subcc
      sc1 sc2      sc3  nget
   0= until
      sc3      scr sc2  nput		\ Delay slot

   \ Adjust the stack pointer to account for the top of stack register
   sp /n           sp   add

   \ Restart the Forth interpreter.

   \ Execute enterforth

   \itc   'acf enterforth  sc1   set
   \itc   sc1 base         sc1   add
   \itc   sc1 0            scr   rtget

   \dtc 'acf enterforth       scr   set

   base  scr          %g0   jmpl
   nop
end-code

\ getexc is executed in the signal handler context.  It is called
\ from _sigtramp with a bunch of machine state on the %o6 stack.
\ %o2 points to the sigcontext structure.

\ If this is entered as a result of a breakpoint, there are two case:
\ a) The breakpoint was unimplemented instruction = 0
\        This is a breakpoint that was placed in the code.
\        We save the state and return to Forth.
\ b) The breakpoint was unimplemented instruction = 1
\        This occurs at the end of the (restart routine.
\        (restart has restored all the state except for PC and nPC
\        We have to
label getexc

   \ We have a fresh set of local registers as a result of the
   \ sigtramp code

   spc   %l4   move		\ Save the return address

   \ Set the base register
   here 8 +                 call   \ address of next instruction in spc
   nop
   here 8 - origin -  base  set	   \ relative address of current instruction
   spc base           base  sub	   \ subtract them to find the base address

   \ Find the user area
   32\ \t32   'body main-task    up    set
   32\ \t32   base up            up    ld  \ Address of main task's user area

   64\ \t32   'body main-task    up    set
   64\ \t32   base up            scr   add
   64\ \t32   scr  4             up    ld
   64\ \t32   scr  0             scr   ld
   64\ \t32   scr  th 20         scr   sllx
   64\ \t32   up   scr           up    add

   32\ \t16   'body main-task    up    set
   32\ \t16   base up            tos   add
   32\ \t16   tos  2             up    lduh
   32\ \t16   tos  0             tos   lduh
   32\ \t16   tos  th 10         tos   sll
   32\ \t16   up   tos           up    add

   64\ \t16   'body main-task    up    set
   64\ \t16   base up            tos   add
   64\ \t16   tos  6             up    lduh
   64\ \t16   tos  4             tos   lduh
   64\ \t16   tos  th 10         tos   sll
   64\ \t16   up   tos           up    add

   'user unix-cpu-state    %l3   nget     \ Base address of save area

   \ Now we need to properly handle the sigcontext structure.
   \ We don't know what size of structure we're looking at
   \ since the size of the Forth dictionary is independent of
   \ the ABI of the ELF executable that loaded it.  We need to
   \ make that decision based on the stack bias.

   \ One thing that is probably still incorrect is that we should
   \ not be using nget and nput to save and restore register values
   \ from the user area, we should always try to save all 64-bits
   \ if possible.  That's a bit of a problem until I make sure we
   \ allocate enough space in the user structure to store the regs
   \ and add code to DTRT on both V8 and V9 instruction set machines.
   
   %o6	1   %g0 andcc
   0=  if  nop
      \ 32-bit aligned stack frame indicates a 32-bit context
      
      %o2 11 /l*   %l0  ld	\ Get the PC of the breakpoint instruction
      %l0  0   %l0  ld		\ Get the instruction
      %l0  1   %g0  subcc	\ Was it unimp=1 ?
      0=  if			\ If so, we fix PC and nPC
	 %l3 offset-of %pc   %l0     nget	\ PC from Forth save area
	 %l0          %o2 11 /l*     st		\ fix PC  in sigcontext
	 %l3 offset-of %npc  %l0     nget	\ nPC from Forth save area
	 %l0          %o2 12 /l*     st		\ fix nPC in sigcontext
	 %l4 8  %g0     jmpl	\ Return
	 nop
      then
      
      \ Save the State Registers
      
      %o0   %l3 offset-of %signal#       nput	\ Signo
      %o1   %l3 offset-of %signal-code   nput	\ Sigcode
      %o3   %l3 offset-of %fault-addr    nput	\ Fault address

      %o2  11 /l*  %l0 ld   %l0  %l3 offset-of %pc  nput	\ PC
      %o2  12 /l*  %l0 ld   %l0  %l3 offset-of %npc nput	\ nPC
		   %l0 rdy  %l0  %l3 offset-of %y   nput	\ Y
      %o2  10 /l*  %l0 ld   %l0  %l3 offset-of %psr nput	\ PSR

      \ Save the Globals (sigtramp put them on the C stack)

                           %g0  %l3 offset-of %g0  nput \ g0 is immutable
      %o2  14 /l* %l0 ld   %l0  %l3 offset-of %g1  nput \ g1 is in sigcontext

      %g2-offset
      
      drop 15 /l*	\ Note: we don't use %g2-offset, rather a constant
      
      ( offset-to-saved-%g2 )
          %o2 over  %l0 ld   %l0  %l3 offset-of %g2  nput	\ g2
      4 + %o2 over  %l0 ld   %l0  %l3 offset-of %g3  nput	\ g3
      4 + %o2 over  %l0 ld   %l0  %l3 offset-of %g4  nput	\ g4
      4 + %o2 over  %l0 ld   %l0  %l3 offset-of %g5  nput	\ g5
      4 + %o2 over  %l0 ld   %l0  %l3 offset-of %g6  nput	\ g6
      4 + %o2 swap  %l0 ld   %l0  %l3 offset-of %g7  nput	\ g7

      \ Now we set the saved PC to point to the rest of the state save
      \ routine, the return to the signal dispatcher, which will clean
      \ up its stack frame and execute the Unix signal cleanup call.
      \ sigcleanup will restore the process to the context that existed
      \ at the time of the signal, except that the PC will be set to the
      \ finish-code routine.
      \ We have to do it this way to prevent nesting of the signal handler.

      finish-save origin- %l0   set
      base %l0            %l0   add
      %l0         %o2 11 /l*    st		\ Change saved PC
      %l0 4               %l0   add
      %l0         %o2 12 /l*    st		\ Change saved nPC
      
   else nop
      \ Unaligned stack, so read out a 64-bit context
      
      %o2 h# 48    %l0  ldx
      %l0  0   %l0  ld		\ Get the instruction
      %l0  1   %g0  subcc	\ Was it unimp=1 ?
      0=  if			\ If so, we fix PC and nPC
	 %l3 offset-of %pc   %l0     nget	\ PC from Forth save area
	 %l0	       %o2 h# 48     stx	\ fix PC  in sigcontext
	 %l3 offset-of %npc  %l0     nget	\ nPC from Forth save area
	 %l0           %o2 h# 50     stx	\ fix nPC in sigcontext
	 %l4 8  %g0     jmpl	\ Return
	 nop
      then
      
      %o0   %l3 offset-of %signal#       nput	\ Signo
      %o1   %l3 offset-of %signal-code   nput	\ Sigcode
      %o3   %l3 offset-of %fault-addr    nput	\ Fault address
      
      %o2  h# 48   %l0 ldx  %l0  %l3 offset-of %pc  nput	\ PC
      %o2  h# 50   %l0 ldx  %l0  %l3 offset-of %npc nput	\ nPC
                   %l0 rdy  %l0  %l3 offset-of %y   nput	\ Y
      %o2  h# 40   %l0 ldx  %l0  %l3 offset-of %psr nput	\ CCR
      %o2  h# d8   %l0 ldx  %l0  %l3 offset-of %asi nput	\ ASI
      %o2  h# e0   %l0 ldx  %l0  %l3 offset-of %fprs nput	\ FPRS
      
      \ Save the Globals (sigtramp put them on the C stack)

                        %g0  %l3 offset-of %g0  nput \ g0 is immutable
      %o2  h# 60  %l0 ldx  %l0  %l3 offset-of %g1  nput \ g1 is in sigcontext

      %g2-offset
      
      drop h# 68	\ Note: we don't use %g2-offset, rather a constant
      
      ( offset-to-saved-%g2 )
          %o2 over  %l0 ldx   %l0  %l3 offset-of %g2  nput	\ g2
      8 + %o2 over  %l0 ldx   %l0  %l3 offset-of %g3  nput	\ g3
      8 + %o2 over  %l0 ldx   %l0  %l3 offset-of %g4  nput	\ g4
      8 + %o2 over  %l0 ldx   %l0  %l3 offset-of %g5  nput	\ g5
      8 + %o2 over  %l0 ldx   %l0  %l3 offset-of %g6  nput	\ g6
      8 + %o2 swap  %l0 ldx   %l0  %l3 offset-of %g7  nput	\ g7
      
      \ Now we set the saved PC to point to the rest of the state save
      \ routine, the return to the signal dispatcher, which will clean
      \ up its stack frame and execute the Unix signal cleanup call.
      \ sigcleanup will restore the process to the context that existed
      \ at the time of the signal, except that the PC will be set to the
      \ finish-code routine.
      \ We have to do it this way to prevent nesting of the signal handler.

      finish-save origin- %l0   set
      base %l0            %l0   add
      %l0         %o2 h# 48     stx		\ Change saved PC
      %l0 4               %l0   add
      %l0         %o2 h# 50     stx		\ Change saved nPC

   then
   
   %l4 8               %g0   jmpl	\ Return
   nop
end-code

code (restart-unix  ( -- )
   \ Restore the Forth stacks.

   \ Establish the Data and Return stack pointers
   'user .rp0         rp    nget
   'user .sp0         sp    nget

   \ Data Stack
   'user pssave       scr   nget     \ Address of data stack save area

   sp  ps-size        sc1   sub    \ Bottom of data stack area

   ps-size            sc2   move   \ Size of data stack area in sc2

   begin
      sc2 /n       sc2  subcc
      scr sc2      sc3  nget
   0= until
      sc3      sc1 sc2  nput		\ Delay slot

   \ Return Stack
   'user rssave       scr   nget   \ Address of return stack save area

   rp  rs-size        sc1   sub    \ Bottom of return stack area

   rs-size            sc2   move   \ Size of return stack area in sc2

   begin
      sc2 /n       sc2  subcc
      scr sc2      sc3  nget
   0= until
      sc3      sc1 sc2  nput		\ Delay slot

   \ Restore the Window Registers.

   'user unix-cpu-state          %g1  nget

   window-registers   ( offset )

   0  +  %g1 over  %o0   nget		\ %o0
   /n +  %g1 over  %o1   nget		\ %o1
   /n +  %g1 over  %o2   nget		\ %o2
   /n +  %g1 over  %o3   nget		\ %o3
   /n +  %g1 over  %o4   nget		\ %o4
   /n +  %g1 over  %o5   nget		\ %o5
   /n +  %g1 over  %o6   nget		\ %o6
   /n +  %g1 over  %o7   nget		\ %o7

   /n +  %g1 over  %l0   nget		\ %l0
   /n +  %g1 over  %l1   nget		\ %l1
   /n +  %g1 over  %l2   nget		\ %l2
   /n +  %g1 over  %l3   nget		\ %l3
   /n +  %g1 over  %l4   nget		\ %l4
   /n +  %g1 over  %l5   nget		\ %l5
   /n +  %g1 over  %l6   nget		\ %l6
   /n +  %g1 over  %l7   nget		\ %l7

   /n +  %g1 over  %i0   nget		\ %i0
   /n +  %g1 over  %i1   nget		\ %i1
   /n +  %g1 over  %i2   nget		\ %i2
   /n +  %g1 over  %i3   nget		\ %i3
   /n +  %g1 over  %i4   nget		\ %i4
   /n +  %g1 over  %i5   nget		\ %i5
   /n +  %g1 over  %i6   nget		\ %i6
   /n +  %g1 over  %i7   nget		\ %i7
   drop

   \ Restore the State Registers.

   'user unix-cpu-state     %g7  nget

   %g7 offset-of %y   %g4  nget  %g4 0  wry	\ Y
   nop nop nop

   32\ %g7 offset-of %psr   %g1  nget		\ PSR
   32\ %g1  8   %g1  sll    %g1 28  %g1  srl	\ Extract icc bits
   64\ %g7 offset-of %psr   %g1  nget		\ CCR
   64\ %g1 h# f %g1  and    %g1 d# 20 %g1 srl	\ Extract icc bits
   %g0 d# 33  always trapif			\ Set icc

   64\ %g7 offset-of %asi   %g1  nget		\ ASI
   64\ %g1 0 wrasi
   64\ %g7 offset-of %fprs  %g1  nget		\ FPRS
   64\ %g1 0 wrfprs

   \ Restore the Globals.

   %g7 offset-of %g0   %g0  nget
   %g7 offset-of %g1   %g1  nget
   %g7 offset-of %g2   %g2  nget
   %g7 offset-of %g3   %g3  nget
   %g7 offset-of %g4   %g4  nget
   %g7 offset-of %g5   %g5  nget
   %g7 offset-of %g6   %g6  nget
   %g7 offset-of %g7   %g7  nget

   \ Take another trap, so we can fix up the PC's in the signal handler
   1 ,

\   %l1 %g0   %g0   jmpl
\   %g0 %g0   %g0   restore	\ Do we need to do something with nPC ?
end-code

' (restart-unix is restart

: .signal ( -- )
   [ also signals ]
   exception @
   case
   SIGINT   of ." Interrupt"            endof
   SIGILL   of ." Illegal Instruction"  endof
   SIGTRAP  of ." Trace Trap"           endof
   SIGIOT   of ." IO Trap"              endof
   SIGEMT   of ." Emulator Trap"        endof
   SIGSEGV  of ." Segmentation Violation" endof
   SIGBUS   of ." Bus Error"            endof
   SIGFPE   of ." Numeric Exception"    endof
     ." Signal # " dup 3 u.r
   endcase
   [ previous ]
   space
;

hidden definitions

: print-breakpoint
   .exception  \ norm
   interactive? 0=  if bye then	\ Restart only if a human is at the controls
   ??cr quit
;
' print-breakpoint is handle-breakpoint

: unix-catch-exceptions  ( -- )
   ['] print-breakpoint is handle-breakpoint
   ['] (restart-unix is restart
   ps-size alloc-mem to pssave
   rs-size alloc-mem to rssave
   h# 400 alloc-mem is unix-cpu-state
   ['] unix-cpu-state is cpu-state
   [ window-registers literal ] to window-registers
   ['] yes-accessible is accessible?

   [ also signals ]
   getexc SIGILL  signal  drop
   getexc SIGINT  signal  drop
   getexc SIGBUS  signal  drop
   getexc SIGSEGV signal  drop
   getexc SIGTRAP signal  drop
   getexc SIGIOT  signal  drop
   getexc SIGEMT  signal  drop
   getexc SIGFPE  signal  drop
   [ previous ]
   ['] .signal is .exception
;
unix-catch-exceptions

forth definitions
headers
: unix-init  ( -- )  unix-init unix-catch-exceptions  ;

only forth also definitions
