\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: loadmach.fth
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
id: @(#)loadmach.fth 1.13 03/07/17
copyright: Copyright 1991-1994 Firmworks  All Rights Reserved
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

[ifndef] assembler?  transient  [then]
fload ${BP}/cpu/sparc/assem.fth
fload ${BP}/cpu/sparc/asmmacro.fth
fload ${BP}/cpu/sparc/code.fth
fload ${BP}/fm/lib/loclabel.fth
[ifndef] assembler?  resident  [then]

warning on

fload ${BP}/cpu/sparc/disforw.fth	\ Exports (dis , pc , dis1 , +dis

fload ${BP}/fm/lib/instdis.fth

fload ${BP}/fm/lib/sparc/decompm.fth

fload ${BP}/os/stand/sparc/notmeta.fth

fload ${BP}/fm/lib/sparc/bitops.fth	\ Used by allocpmeg.fth

\  : be-l!  ( l adr -- )  >r lbsplit r@ c! r@ 1+ c!  r@ 2+ c! r> 3 + c!  ;
\  : be-l,  ( l -- )  here set-swap-bit  here  4 allot  be-l!  ;
\  : be-l@  ( adr -- n )  >r r@ 3 + c@ r@ 2+ c@ r@ 1+ c@ r> c@ bljoin  ;
\  : be-w@  ( adr -- w )  dup 1+ c@  swap c@  bwjoin  ;

fload ${BP}/os/sun/nlist.fth	\ Not transient; Used by symdebug.fth

fload ${BP}/os/sun/elf.fth

[ifdef] save-as-aout
transient fload ${BP}/os/sun/symtab.fth  resident
transient fload ${BP}/os/sun/sparc/aout.fth  resident
[else]
transient fload ${BP}/os/sun/sparc/elf.fth  resident
transient fload ${BP}/os/sun/elfsym.fth  resident
[then]

transient fload ${BP}/os/sun/sparc/reloc.fth  resident
fload ${BP}/fm/lib/sparc/external.fth  \ Uses does>; not transient
transient fload ${BP}/os/sun/exports.fth 	resident

transient fload ${BP}/fm/cwrapper/binhdr.fth		resident
transient fload ${BP}/fm/cwrapper/sparc/savefort.fth	resident

warning @ warning off  alias save-forth save-forth  warning !

fload ${BP}/cpu/sparc/doccall.fth		\ Common code
transient fload ${BP}/cpu/sparc/ccall.fth		resident
transient fload ${BP}/cpu/sparc/acall.fth		resident

\t16 fload ${BP}/fm/lib/sparc/debugm16.fth	\ Forth debugger support
\t32 fload ${BP}/fm/lib/sparc/debugm.fth	\ Forth debugger support
fload ${BP}/fm/lib/debug.fth			\ Forth debugger

32\ fload ${BP}/cpu/sparc/traps.fth
64\ fload ${BP}/cpu/sparc/traps9.fth

fload ${BP}/fm/lib/sparc/objsup.fth
fload ${BP}/fm/lib/objects.fth
fload ${BP}/fm/lib/action-primitives.fth

fload ${BP}/cpu/sparc/cpustate.fth

32\ fload ${BP}/cpu/sparc/register.fth
32\ fload ${BP}/cpu/sparc/regv8.fth

64\ fload ${BP}/cpu/sparc/register9.fth

fload ${BP}/fm/lib/savedstk.fth
fload ${BP}/fm/lib/rstrace.fth
fload ${BP}/fm/lib/sparc/ftrace.fth
32\ fload ${BP}/fm/lib/sparc/ctrace.fth
64\ fload ${BP}/fm/lib/sparc/ctrace9.fth

32\ fload ${BP}/cpu/sparc/asi.fth
64\ fload ${BP}/cpu/sparc/asi9.fth

start-module			\ Breakpointing
fload ${BP}/fm/lib/sparc/cpubpsup.fth	\ Breakpoint support
fload ${BP}/fm/lib/breakpt.fth
end-module

[ifdef] unix-signals
headerless
window-registers
alias lretval retval
fload ${BP}/os/sun/sparc/signal.fth
32\ fload ${BP}/os/sun/sparc/catchexc.fth
fload ${BP}/os/unix/sparc/arcbpsup.fth
to window-registers
headers
[then] \ unix-signals

fload ${BP}/cpu/sparc/memtest.fth

fload ${BP}/os/sun/aout.fth

32\ fload ${BP}/cpu/sparc/fentry.fth
32\ transient fload ${BP}/os/sun/sparc/makecent.fth	resident

64\ fload ${BP}/cpu/sparc/fentry9.fth
64\ transient fload ${BP}/os/sun/sparc/makecent9.fth	resident

fload ${BP}/cpu/sparc/call.fth
64\ fload ${BP}/cpu/sparc/call32.fth

transient fload ${BP}/cpu/sparc/ccalls.fth  resident

fload ${BP}/fm/lib/sparc/dfill.fth	\ Memory fill words
fload ${BP}/fm/lib/sparc/lmove.fth
