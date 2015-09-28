\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: xcall.fth
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
id: @(#)xcall.fth 1.2 07/04/27
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headers

3 h# 40 * buffer: xcall-buffer
0 value xcall-cpulist
0 value xcall-cpuargs
0 value xcall-cpulist-pa
0 value xcall-cpuargs-pa
d# 1000 value cpu-mondo-timeout		\ in msecs, 1 sec by default

\ htrap function number
h# 42 constant api-cpu-mondo-send

\ Get cpu-mondo-timeout value from MD.  If it is  not available in MD then use
\ the default value.  See FWARC/2006/545 for the MD node prop description
stand-init: setup 4v xcall buffer
   0 " platform" md-find-node ?dup if 		( node |  )
      " inter-cpu-latency" ascii v md-find-prop ?dup if  ( prop |  )
         md-decode-prop drop 			( data )
         d# 1000000 / is cpu-mondo-timeout	(  ) \ Convert from nano-secs 
      then					     \ to milli-secs, and set
   then						     \ time-out variable
   xcall-buffer					( va )
   h# 40 round-up				( va' )
   dup is xcall-cpulist				( va' )
   dup >physical drop is xcall-cpulist-pa	( va' )
   h# 40 +					( va'' )
   dup is xcall-cpuargs				( va'' )
   >physical drop is xcall-cpuargs-pa		( )
;

\ Hypervisor call
1 3 api-cpu-mondo-send fast-trap#
    hypercall: api-send-mondo  ( cpu-args cpu-list-pa n -- status )


: xcall-cpus ( n -- failed? )
   get-msecs cpu-mondo-timeout + >r		( n ) ( r: msecs )
   begin					( n ) ( r: msecs )
      dup xcall-cpuargs-pa xcall-cpulist-pa rot	( n cpu-args cpu-list-pa n )
      api-send-mondo				( n status ) ( r: msecs )
      dup HV-EOK = if				( n status ) ( r: msecs )
        r> 3drop false exit			( false )
      then
      HV-EWOULDBLOCK <> if			( n ) ( r: msecs )
         r> 2drop true exit			( true )
      then
      get-msecs r@ >				( n true|false ) ( r: msecs )
   until					( n ) ( r: msecs )
   r> 2drop true				( true )
;

: xcall-cpu ( arg1 arg0 pc mid -- failed? )
   >r r@ xcall-cpulist w!	( arg1 arg0 pc )  ( r: mid )
   xcall-cpuargs		( arg1 arg0 pc va )
   tuck x! /x +			( arg1 arg0 n' )
   tuck x! /x +			( arg1 n' )
   x!				( )
   1 xcall-cpus dup if		( failed? )
      r> cmn-warn[ " Failed to send Mondo to CPU# %x" ]cmn-end
   else
      r> drop
   then
;

headerless
hidden also definitions

label bounce
   \ TL = 1
   \ %g1 = function @ TL=0
   \ %g2 = arg0
   \ %g7 + 8 = Return address

   %g1  %g3  move
   %g2  %o0  move

   \ %o0 = Arg0
   \ %g3 = PC @ TL=0

   %o1   rdtpc
   %o2   rdtnpc

   %g3 0 wrtpc
   %g3 4 %g3 add
   %g3 0 wrtnpc

   \ TPC =   PC        of Function @ TL=0
   \ TnPC = nPC        of Function @ TL=0
   \ %o0 = Arg0        of Function @ TL=0
   \ %o1 = Return PC   of Function @ TL=0
   \ %o2 = Return nPC  of Function @ TL=0
   \ %g7 + 8 = Return address
   retry
end-code

label start-cpu ( -- )
   \ %TL = 1
   \ %g1 = PC
   \ %g2 = Arg0
   \ %g7 + 8 = Return address

   \ Setup %tpc and %tnpc
   %g1 0       wrtpc
   %g1 4  %g1  add
   %g1 0       wrtnpc

   \ %g2 = Arg0
   \ %g7 + 8 = Return address
   \ Setup the arguments
   %g2    %o0  move  %g0    %o1  move
   %g0    %o2  move  %g0    %o3  move
   %g0    %o4  move  %g0    %o5  move


   \ %g7 + 8 = Return address
   \ Set the base register
   base                    rdpc
   here 4 - origin - %g4   set
   base  %g4         base  sub

   \ %g7 + 8 = Return address
   \ Setup cpu-state variables
   prom-main-task  %g4  up    setx      \ Set User Area Pointer
   up  %g4  %g6  get-cpu-struct
   CPU-STARTED  %g4  %g1  %g6	mark-cpu-state

   \ %g7 + 8 = Return address
   %g0  1               %g1   sub
   %g1  %g6 offset-of %restartable?  nput	\ Set restartable?
   %g0  %g6 offset-of last-trap#     nput	\ Clear last-trap#
   %g0  %g6 offset-of %state-valid   nput	\ Unlock Per CPU state

   retry
end-code

label goto-cpu ( -- )
   \ %TL = 1
   \ %g1 = PC
   \ %g2 = Arg0
   \ %g7 + 8 = Return address

   \ Setup %tpc and %tnpc
   %g1 0       wrtpc
   %g1 4  %g1  add
   %g1 0       wrtnpc

   \ %g7 + 8 = Return address
   \ Setup the arguments
   %g2    %o0  move  %g0    %o1  move
   %g0    %o2  move  %g0    %o3  move
   %g0    %o4  move  %g0    %o5  move

   \ %g7 + 8 = Return address
   retry
end-code

0 value idle-pc

label get-pc ( -- )
   \ %TL = 1
   \ %g7 + 8= return address

   \ Set User Area Pointer
   prom-main-task  %g4  up    setx

   \ up   = user area
   'user# idle-pc  %g4  set
   %g5                  rdtpc
   %g5          up %g4  nput

   retry
end-code

label exec-cpu ( -- )
   \ %o0 = acf

   \ Set the up register
   prom-main-task  %g4  up    setx	\ Set User Area Pointer

   \ Set the base register
   base                    rdpc
   here 4 - origin - tos   set
   base  tos         base  sub

   \ Establish the Data and Return stacks
   up  rp  ip			get-cpu-struct	\ ip = cpu-struct base
   0 >stack-fence?	tos	set
   ip  tos		tos	ldx		\ stacks-fenced?
   tos  %g0		%g0	subcc
   0= if  nop
      0 >cpu-rp0	tos	set
      0 >cpu-sp0	sp	set
   else nop
      0 >cpu-rp0-fence	tos	set
      0 >cpu-sp0-fence	sp	set
   then
   ip  tos		rp	ldx		\ Get RP
   ip  sp		sp	ldx		\ Get SP
   sp  /n		sp	add		\ Account for TOS.

\dtc %o0  ip			move
\dtc ip	 %g0		%g0	jmpl	nop
\itc %o0  sc1			move
\itc sc1  %g0		scr	rtget
\itc scr  base		%g0	jmpl	nop
c;

also forth definitions

headers

: xcall-get-pc ( cpu# -- true | pc false )
   true to idle-pc
   >r  0 0 get-pc  r>  xcall-cpu  if
      true
   else
      d# 10000 0 do  idle-pc true  <>  if  leave  then loop
      idle-pc false
   then
;

: xcall-start-cpu ( arg0 pc mid -- failed? )
   start-cpu  swap  xcall-cpu
;
: xcall-execute ( acf cpu# -- failed? )
   exec-cpu goto-cpu rot  xcall-cpu	( fail? )
;
headerless
: xcall-idle-cpu ( cpu# -- failed? )
   >r 0 0 slave-save-state r>  xcall-cpu
;
: xcall-resume-cpu ( cpu# -- failed? )
   ['] restart-slave  ( cpu# xt )
   swap xcall-execute
;
headers
