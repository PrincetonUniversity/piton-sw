\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: slavecpu.fth
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
id: @(#)slavecpu.fth 1.1 07/04/27
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.


code slave-enterforth ( -- )
   sc3 sc4 sc5 sc6	mutex-enter prom-lock	\ Wait for prom-lock

   up	sc1	scr     get-cpu-struct  \ scr has cpu-struct-ptr
   0 >cpu-status	sc1	set	\ sc1 has offset for cpu-status

   scr	sc1	sc2	ldx		\ Read current cpu-state
   CPU-IDLING	sc3	set		\ sc3 has CPU-IDLING constant
   sc2 	sc3	%g0	subcc		\ Is it CPU-IDLING?
   0=			if 		\ If it is CPU-IDLING
      CPU-OBP-COLD	sc2	move	\ then mark is COLD
   else nop	
      CPU-OBP-WARM	sc2	move	\ Or else mark it WARM
   then
   sc2	scr	sc1	stx		\ Update cpu-state, COLD or WARM

   'body  enterforth ip	set		\ Set ip to address of enterforth
   ip   base      	 ip	add
c;					\ Done, c; includes "next"


\ Cross Call handler to jump to slave-enterforth
label	xcall-slave-enterforth
   \ Set the base register
   base                    rdpc		\ Read current PC
   here 4 - origin - sc3   set		\ sc3 has offset of previous inst
   base  sc3         base  sub		\ Sub offset from PC to establish as base
   'acf  slave-enterforth sc3    set	\ sc3 has acf of slave-enterforth
   sc3   base       sc3    add		\ Add base add to it
   sc3	0		wrtpc		\ Set tPC to jump address
   sc3	4	 sc3	add		\ Add 4 to the address
   sc3	0		wrtnpc		\ Set tNPC to jump addr + 4
   retry				\ Return from xcall to jump addr
end-code

code slave-idle-loop
   \ base = origin
   \ up   = User Area Pointer
   \ The User Area is now initialized
   scr		        rdpstate	\ We should not be spinning in 	
   #sync		membar		\ this loop with IE = 0
   scr  2	scr	or		\ set IE = 1
   scr  0		wrpstate	\ Write to pstate reg.
   #sync		membar
   up   sc1 scr     	get-cpu-struct	\ scr has cpu-struct-ptr
   scr		rp	get-rp0		\ Setup RP

   0 >cpu-status sc1	set		\ sc1 has offset to cpu-status
   CPU-IDLING	sc2	move		\ sc2 has CPU-IDLING constant
   sc2	scr	sc1	stx		\ Mark as Idle

   sc3  sc4  sc5 mutex-exit  prom-lock	\ Let go prom-lock

   \ Wait here until we are started OR the master CPU advances us
   \ into the wait for lockfree phase
   begin
      h# 12	%o5	move		\ cpu_yield, FN # 0x12
      %g0 fast-trap#	always	htrapif \ Trap into HV and stay there
      nop				\ until interrupted
   again nop				\ Loop forever while in slave idle loop
c;

headerless
defer slave-idle-loop-hook  ( -- )  ' noop is slave-idle-loop-hook
: (slave-idle-loop)
   flush-temporary-mappings		\ Flush all temp mappings
   slave-idle-loop-hook
   enable-cpu-errors			\ Enable errors
   mid@ enable-reentry			\ Enable reentry for the slave CPU
   slave-idle-loop			\ Enter slave-idle-loop
;

\
\ Setup the per cpu rp0, sp0 pointers just the once.
\ Don't make this a : definition because we don't
\ have stacks yet!!
\
label slave-init
   up  sc1 scr		get-cpu-struct	\ scr has pointer to cpu-struct
   CPU-INIT sc1 sc2 scr	mark-cpu-state	\ Mark cpu-state to CPU-INIT
   scr  sc1 sc2		set-rp0		\ Set RP0
   scr  sc1 sc2		set-sp0		\ Set SP0

   scr		sp	get-sp0		\ Establish SP
   scr		rp	get-rp0		\ Establish RP
   sp	/n	sp	add		\ account for TOS

   'body (slave-idle-loop) ip set		\ Set jump address of
   ip  base		ip add		\ (slave-idle-loop)
   next					\ Jump to the address
end-code

headers

