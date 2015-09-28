\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: switchcpu.fth
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
id: @(#)switchcpu.fth 1.3 07/06/14
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

\ Compare cpu state to given state
: cpu-status?	( cpu status -- flag )
   over mid-ok? if			( cpu status )
      swap >cpu-struct >cpu-status @ =	( flag )
   else					( cpu status )
      2drop false			( false )
   then					( flag )
;

: cpu-started? ( cpu# -- flag )  CPU-STARTED cpu-status?  ;
: cpu-idled?   ( cpu# -- flag )  CPU-PARKED  cpu-status?  ;
: idle-cpu ( cpu# -- )
   dup cpu-started?  over mid@ <>  and if	( cpu# )
      xcall-idle-cpu				( fail? )
   then  drop					( )
;
: resume-cpu ( cpu# -- )
   dup cpu-idled?  over mid@ <>  and if		( cpu# )
      xcall-resume-cpu				( fail? )
   then  drop					( )
;

: idle-other-cpus ( -- )	['] idle-cpu  do-foreach-cpu  ;
: resume-other-cpus ( -- )	['] resume-cpu  do-foreach-cpu ;

code do-release-prom ( who? acf -- )
   tos     ip              move		\ Move acf to ip
   sp      tos             pop		\ Pop stack
   tos     sc2             move		\ sc2 has who?
   sp      tos             pop		\ Pop stack
   sc2     sc3  mutex-set  prom-lock	\ Set prom-lock for who?
   ip      %g0  %g0     jmpl    nop	\ Jump to acf address
   \ Not Reached
c;

: master-release-prom ( n -- )
   dup >cpu-struct >cpu-status @ if                	( n )
      \ Set PIL level to 0xF before switching and before entering slave loop
      \ this will disable ALARM interrupt and hence break may not work
      cmn-warn[	
         " Sending a break while in OpenBoot might fail to get to OK prompt!" 
      ]cmn-end
      h# f pil!						( n )
      dup >r 0 0 xcall-slave-enterforth r> xcall-cpu drop ( n )
      cpu-state >cpu-status @                           ( n status )
      CPU-OBP-WARM =  if                                ( n )
         ['] slave-bp-loop                              ( n )
      else                                              ( n )
         ['] slave-idle-loop                            ( n acf )
      then                                              ( n acf )
      do-release-prom                                   ( )
   else                                                 ( n )
      cmn-warn[ " CPU %x is not ready" ]cmn-end	(  )
   then
;

headers

: switch-cpu ( cpu# -- )
   \ Simply return if cpu# is the currently running CPU
   dup mid@ =  if  drop exit  then		(  )
   dup mid-ok? if				( cpu# )
      dup xcall-get-pc  0= if			( cpu# pc )
         drop					( cpu# )
         dup idle-cpu				( cpu# )
         dup >cpu-struct >cpu-status @		( cpu# status )
         CPU-IDLING <>  if			( cpu# )
            d# 5 0 do dup cpu-idled? ?leave d# 100 ms loop
            dup cpu-idled?			( cpu# switch? )
         else					( cpu# )
            true				( cpu# true )
         then					( cpu# switch? )
         if  master-release-prom else drop then	( )
      then					( )
   else						( cpu# )
      cmn-warn[ " CPU %x is not present or is not responding" ]cmn-end
   then						( cpu# )
;

chain: enterforth-chain
   idle-other-cpus
;

chain: go-chain
   resume-other-cpus
;

