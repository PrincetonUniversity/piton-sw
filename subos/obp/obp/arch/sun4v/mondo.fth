\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: mondo.fth
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
id: @(#)mondo.fth 1.2 06/12/21
purpose:
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

\ We are at TL=1 when we execute following interrupt handler.
label cpu-mondo-interrupt
   %o0 %g1 move   %o1 %g2 move
   %o2 %g5 move   %o5 %g6 move

   %g0 h# 3c            %o0  add
   %g0 h# 15            %o5  add
   %g0 0 always              htrapif

   %o1 %g3 move   %o2 %g4 move		\ %g3 = queue RA; %g4 = nentries 
   %g1 %o0 move   %g2 %o1 move
   %g5 %o2 move   %g6 %o5 move

   prom-main-task       %g5	set
   %g4 6		%g4	sllx    \ multiple by queue size (64)	
   %g4 1	  	%g1	sub	\ mask
   %g0  h# 25			wrasi	\ %asi = QUEUE_ASI
   %g0  h# 3c0 %asi	%g5	ldxa
   %g5  /queue-entry	%g7	add
   %g7  %g1		%g6	and	\ new-offset
   %g5  %g3		%g7	add	\ Buffer Addr
   %g0  memory-asi		wrasi
   %g7  h# 08 %asi	%g1	ldxa	\ %g1 = arg1
   %g7  h# 10 %asi	%g2	ldxa	\ %g2 = arg2
   %g7  h# 18 %asi	%g3	ldxa	\ %g3 = arg3
   %g7  h# 20 %asi	%g4	ldxa	\ %g4 = arg4
   %g7	h# 28 %asi	%g5	ldxa	\ %g5 = arg5
   %g7  h# 00 %asi	%g7	ldxa	\ %g7 = xcall PC

   %g0  h# 25			wrasi	\ %asi = QUEUE_ASI
   %g6  %g0 h# 3c0 %asi		stxa

   %g7  %g0		%g0   jmpl
			      nop
end-code

h# 07c cpu-mondo-interrupt set-vector

\ This handler is used after OBP relinquished control to OS.
label devmondo-interrupt
   %g0  h# 38           %g4     add
   %g4  %g0  h# 20      %g7     ldxa            \ CPU struct PA
   0 >cpu-devmondo-ptr  %g6     set
   %g7  %g6             %g7     add             \ target PA

   %g0  h# 25                   wrasi           \ %asi = QUEUE_ASI
   %g0  h# 3d0 %asi     %g5     ldxa            \ current head
   %g0  h# 3d8 %asi     %g6     ldxa            \ get tail
   %g7  %g0 memory-asi  %g1     ldxa            \ get saved value
   %g1  %g0             %g0     subcc
   0=                           if
      %g6  %g0 h# 3d0 %asi      stxa            \ head = tail.
      \ OK, we need to preserve the current head to restore later
      %g0  1            %g1     add
      %g1  d# 63        %g1     sllx            \ bit63
      %g1  %g5          %g5     or              \ head offset | bit63
      %g5  %g7  %g0 memory-asi  stxa            \ save it
   then
                                retry
end-code

h# 07d devmondo-interrupt set-vector

label resumable-interrupt
   %g0  h# 38                %g4  add
   %g4  %g0  h# 20           %g7  ldxa        \ CPU struct PA
   0 >reserr-count           %g1  set
   %g1 %g7                   %g1  add         \ counter for res error
   %g1 %g0 memory-asi        %g2  ldxa
   %g2 1                     %g2  add
   %g2 %g0 %g1 memory-asi         stxa

   \ Get resumable queue config info from hypervisor
   %g0 h# 3e                 %o0  add
   %g0 h# 15                 %o5  add
   %g0 0 always                   htrapif     \ %o1 = queue RA; %o2 = nentries 
   %g0  h# 25                     wrasi       \ %asi = QUEUE_ASI
   %g0  h# 3e0 %asi          %g5  ldxa        \ get current qhead
   %o2  6                    %o2  sllx        \ multiple by queue size (64)
   %o2 1                     %g1  sub         \ mask
   %g5 /queue-entry          %g5  add         \ increase qhead to next
   %g5 %g1                   %g5  and         \ size mask to wrap around
   %g5 %g0  h# 3e0  %asi          stxa        \ update qhead
                                  retry
end-code

h# 07e resumable-interrupt set-vector

label nonresumable-interrupt
   %g0  h# 38                %g4  add
   %g4  %g0  h# 20           %g7  ldxa        \ CPU struct PA
   0 >nonreserr-count        %g1  set
   %g1 %g7                   %g1  add         \ counter for non-res error
   %g1 %g0 memory-asi        %g2  ldxa
   %g2 1                     %g2  add
   %g2 %g0 %g1 memory-asi         stxa

   \ Get non-resumable queue config info from hypervisor
   %g0 h# 3f                 %o0  add
   %g0 h# 15                 %o5  add
   %g0 0 always                   htrapif     \ %o1 = queue RA; %o2 = nentries 
   0 >nonreserr-shadowbuf    %g3  set
   %g3 %g7                   %g3  add         \ shadow buffer ptr
   %g0  h# 25                     wrasi       \ %asi = QUEUE_ASI
   %g0  h# 3f0 %asi          %g5  ldxa        \ get current qhead
   0 >nonreserr-bflag        %g1  set
   %g1 %g7                   %g1  add         \ shadow buffer flag ptr
   %g1 %g0 memory-asi        %g2  ldxa
   %g2 %g0                   %g0  subcc       \ check if buffer is free
   0= if nop
      \ save trap's 64 bytes from queue entry to shadow buffer
      %o1 %g5                %g4  add         \ error entry ptr
      0                      %g2  set         \ init offset to entry field
      8                      %g7  set         \ init field count
      begin
         %g4 %g2 memory-asi  %g6  ldxa        \ read error info field
         %g6 %g3 %g2 memory-asi   stxa        \ save to shadow buffer 
         %g2 8               %g2  add         \ increment to next field
         %g7 1               %g7  subcc       \ there are total of 64 bytes
                                              \ we go through the loop 8 times
                                              \ (8 * 8 = 64)
      0= until nop
      %g0 -1                 %g2  add         \ mark buffer not free
      %g2 %g0 %g1 memory-asi      stxa
   then

   %o2  6                    %o2  sllx        \ multiple by queue size (64)
   %o2  1                    %g1  sub         \ mask
   %g5  /queue-entry         %g5  add         \ increase qhead to next
   %g5  %g1                  %g5  and         \ size mask to wrap around
   %g5  %g0  h# 3f0  %asi         stxa        \ update qhead
   save-state                     always  brif
                                  nop
end-code

h# 07f nonresumable-interrupt set-vector
h# 27f nonresumable-interrupt set-vector

\ iodevice interrupts are handled using devmondo queues on sun4v. Interrupt 
\ resends involves saving the devmondo queue head on a devmondo interrupt,
\ and restoring it in (crestart) along with other CPU state.

: reset-interrupts ( -- ) ;

headers
