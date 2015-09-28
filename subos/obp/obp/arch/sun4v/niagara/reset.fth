\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: reset.fth
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
id: @(#)reset.fth 1.3 07/06/22
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

\ [define] verify-dropin-copy?
\ [define] dropin-checksum?

resident headerless

h# 4f.42.4d.44  constant  dropin-magic
h# 70           constant  soft-state-set

1               constant  core-api-group
1               constant  core-major-version 
0               constant  core-minor-version 
3               constant  guest-state-api-group 
1               constant  guest-state-major-version 
0               constant  guest-state-minor-version 
2               constant  sis-transitional 
1               constant  sis-normal

fload ${BP}/arch/sun4s/reset/common.fth
fload ${BP}/arch/sun/auto-field.fth

: save-binary
   new-file
   obj-base  obj-size ofd @  fputs
   ofd @ fclose
;

begin-obj

label reset-vector
   resident-assembler

   nop nop nop nop
   nop nop nop nop

   0 F: always brif annul nop
   nop nop nop nop nop nop

   1 F: always brif annul nop
   nop nop nop nop nop nop

   2 F: always brif annul nop
   nop nop nop nop nop nop

   3 F: always brif annul nop
   nop nop nop nop nop nop

   4 F: always brif annul nop
   nop nop nop nop nop nop

   5 F: always brif annul nop
   nop nop nop nop nop nop

end-code

label sccs-string  sccs-id cscount ", align  end-code

label boot-name$ " bootprom" bounds do i c@ c, loop 0 c, end-code
label obp-name$  " OBP" bounds do i c@ c, loop 0 c, end-code

\ these two labels need to be kept one after the other for proper
\ opperation

label guest-state-align-buffer& h# 20 .align end-code
label guest-state-init-string$ 
   " Openboot initializing" tuck bounds do i c@ c, loop 0 c, 
   h# 1f swap -
   0 do 0 c, loop
end-code

fload ${BP}/cpu/sparc/ultra4v/tlbasm.fth
fload ${BP}/arch/sun4v/niagara/tlbsetup.fth
fload ${BP}/arch/sun4v/savestate.fth
fload ${BP}/arch/sun4v/error-reset.fth
fload ${BP}/arch/sun4v/diagprint.fth
fload ${BP}/pkg/dropins/sparc/find-dropin.fth
fload ${BP}/arch/sun/reset-dropin.fth

label power-on-reset
   %i0			%g1	move		\ membase
   %i1			%g2	move		\ memsize
   %i2			%g3	move		\ pd base
   %g0  h# f			wrpil
   %g0  4			wrpstate
   %g0  0			wrtba
   %g0  7			wrcleanwin
   %g0  0			wrotherwin
   %g0  0			wrwstate
   %g0  0			wrcanrestore
   %g0  6			wrcansave
   %g0  0			wrcwp
   %g1			%i0	move		\ restore %i's
   %g2			%i1	move
   %g3			%i2	move
   %g0  0			wrtl		\ TL = 0
   %g0  0                       wrgl
  
   \ At start up, all hypervisor API calls are disabled.  Any calls
   \ we need must be enabled with appropriate calls to
   \ API_SET_VERSION.
   core-api-group       %o0     set             \ core API group
   core-major-version   %o1     set             \ current major version 
   core-minor-version   %o2     set             \ current minor version
   %g0  0               %o5     add             \ api_set_version function
   %g0  h# 7f  always           htrapif
                                nop

   \ Negotiate the guest-state API, and set the initial state.
   \ If the guest-staet API is not supported, hypervisor will
   \ return an error, but we are not checking the return code

   guest-state-api-group        %o0    set      \ guest state API group
   guest-state-major-version    %o1    set      \ current major version
   guest-state-minor-version    %o2    set      \ current minor version
   %g0  0                       %o5    add      \ api_set_version function
   %g0  h# 7f  always                  htrapif
                                       nop

   sis-transitional     %o0     set             \ transitional state
   guest-state-init-string$ obj-base -          \ 
                %o2     %o1     setx            \ location of string
   %i0  %o1             %o1     add             \ physical address
   soft-state-set       %o5     set             \ soft-state-set function
   %g0  0       always          htrapif
                                nop

   %i0			%o0	move
   setup-i/d-tlbs		call
   %i1			%o1	move

   \ DTLB: 0 -> membase + 8M
   %g0			%o0	move
   8meg			%o1	set
   %i0  %o1		%o1	add
   %g0  3		%o2	add
   setup-dtlb-entry		call
   %g0  0		%o3	add

   \ ITLB: 0 -> membase + 8M
   %g0			%o0	move
   8meg			%o1	set
   %i0  %o1		%o1	add
   %g0  3		%o2	add
   setup-itlb-entry		call
   %g0  0		%o3	add

   %g0  1		%o0	add
   %g0  h# 27		%o5	add		\ MMU_ENABLE
   %g4				rdpc
   %g4  h# 10 		%o1	add
   %g0  0  always		htrapif
				nop

   \ bclear the first 512KB of memory (@0)
   1meg 2/		%l4	set		\ 512Kb
   8meg			%l3	set
   %i0  %l3		%l3	add		\ offset
   %g0  h# 31		%o5	add		\ mem_scrub
   begin
     %l4		%o1	move		\ Len
     %l3		%o0	move		\ RA
     %g0  0		always	htrapif
     %o0  7		%g0	subcc		\ error?
     0<> if
        %g0  %g0	%g0	subcc		\ BAIL!
	%l3  %o1	%l3	add		\ dump RA
	%l4  %o1	%l4	subcc
     then
   0<= until
     %g0  h# 31		%o5	add		\ (mem scrub) delay

   obp-name$  obj-base -
		%o1	%o0	setx
   %i0  %o0		%o0	add
   %i0			%o1	move
   %g0  h# 20		%o2	add
   %g0  %g0		%o3	add
   find&copy-dropin		call
   %g0	1		%o4	add

   %o0  h# 20		%i7	add

h# 10 .align

   here obj-base - h# 20 +  scr set
   scr		%g0	%g0	jmpl
   nop		nop	nop	nop
   nop		nop	nop	nop
   nop		nop

   boot-name$ obj-base -
		%o1	%o0  setx
   %i0  %o0		%o0	add
   %i0			%o1	move
   ROMbase		%o2	set
   %i7  %g0		%o3	add
   find&copy-dropin		call
   %g0	1		%o4	add

   ROMbase		%o0	set
   %o0 h# 30		%g0	jmpl  nop

   begin again nop

h# 20 .align

0 L:				\ Power On Reset        0x20
   power-on-reset always brif annul nop
1 L:                            \ Watchdog Reset        0x40

   save-reset-state             call  nop

   %g0  2               %o1     add     \ error code
   %o1  %o0 offset-of last-trap#  %asi  stxa    \ last-trap = error-reset-trap
   %o1  %o0 offset-of error-reset-trap %asi stxa

   error-reset-recovery         call  nop

   ROMbase           %o0     set
   %o0 h# 40         %g0     jmpl  nop

   begin again nop
2 L:                            \ XIR                   0x60

   save-reset-state             call  nop

   %g0  3               %o1     add     \ error code
   %o1  %o0 offset-of last-trap#  %asi  stxa    \ last-trap = error-reset-trap
   %o1  %o0 offset-of error-reset-trap %asi stxa

   error-reset-recovery		call  nop

   ROMbase           %o0     set
   %o0 h# 60         %g0     jmpl  nop

   begin again nop
3 L:                            \ SIR                   0x80

   save-reset-state             call  nop
   %g0  4               %o1     add     \ error code
   %o1  %o0 offset-of last-trap#  %asi  stxa    \ last-trap = error-reset-trap
   %o1  %o0 offset-of error-reset-trap %asi stxa

   error-reset-recovery         call  nop

   ROMbase           %o0     set
   %o0 h# 80         %g0     jmpl  nop

   begin again nop
4 L:                            \ RED                   0xa0

   save-reset-state             call  nop
   %g0  5               %o1     add     \ error code
   %o1  %o0 offset-of last-trap#  %asi  stxa    \ last-trap = error-reset-trap
   %o1  %o0 offset-of error-reset-trap %asi stxa

   error-reset-recovery         call  nop

   ROMbase           %o0     set
   %o0 h# 80         %g0     jmpl  nop

   begin again nop
5 L:
   begin again nop
   -1 ,

end-code
end-obj

" reset-vector"		" reset" 	$export-procedure

fload ${BP}/arch/sun/reset-cleanup.fth
