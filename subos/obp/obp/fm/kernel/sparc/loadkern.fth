\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: loadkern.fth
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
\ id: @(#)loadkern.fth 2.34 07/06/05 10:54:48
\ purpose: 
\ copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
\ copyright: Use is subject to license terms.
\ Copyright 1985-1994 Bradley Forthware

\ Don't accept ',' as numeric punctuation because doing so makes
\ the forward referencing mechanism think that "c," is a number!
ascii . ascii , npatch numdelim?

warning off	\ Turn OFF the warning messages

64\  8  constant  /n
\needs lconstant alias lconstant constant

[ifnexist] [message]
fload ${BP}/fm/lib/message.fth
[then]

fload ${BP}/fm/meta/meta1.fth
alias xref-on meta-xref-on
alias xref-off meta-xref-off
fload ${BP}/fm/lib/xref.fth

only forth also meta also definitions
fload ${BP}/cpu/sparc/assem.fth

only forth also meta assembler also meta definitions
: assembler  ( -- )  srassembler  ;

only forth also meta also assembler definitions

fload ${BP}/fm/lib/loclabel.fth

fload ${BP}/fm/meta/nswapmap.fth
fload ${BP}/fm/meta/sparc/target.fth
fload ${BP}/fm/meta/forward.fth
fload ${BP}/fm/meta/sparc/fixvoc.fth
fload ${BP}/fm/meta/compilin.fth

only forth also definitions

[ifdef] XREF
xref-init
\ Init the first reference file
" ${BP}/fm/kernel/sparc/loadkern.fth" xref-push-file 2drop
\ The include-exit hook in metainit will pop this file
" ${BP}/fm/kernel/sparc/metainit.fth" xref-push-file 2drop
[then]

fload ${BP}/fm/kernel/sparc/metainit.fth

\ always-headers    \ Keep all the headers
\ sometimes-headers \ Keep some instead

sometimes-headers

\ Comment out the following line(s) when debugging
-1  threshold  !	\ Turn OFF ALL debugging messages
warning-t  off  	\ Turn OFF target warning messages

\ Uncomment the following line(s) for more debug output
\ show? on  1 granularity !  1 threshold !
warning-t on

fload ${BP}/fm/kernel/sparc/kerncode.fth
32\ fload ${BP}/fm/kernel/sparc/divrem.fth
64\ fload ${BP}/fm/kernel/sparc/divrem9.fth

fload ${BP}/fm/kernel/uservars.fth	\ I init task link.
32\ fload ${BP}/fm/kernel/sparc/multiply.fth
64\ fload ${BP}/fm/kernel/sparc/mulv9.fth

\t32-t fload ${BP}/fm/kernel/sparc/move.fth
\t16-t fload ${BP}/fm/kernel/sparc/moveslow.fth \ Longword optimized
					\ but not doubleword optimized
[ifdef] XREF
headers
defer xref-on			' noop is xref-on
defer xref-off			' noop is xref-off
defer xref-header-hook		' noop is xref-header-hook
defer xref-find-hook		' noop is xref-find-hook
defer xref-hide-hook		' noop is xref-hide-hook
defer xref-reveal-hook		' noop is xref-reveal-hook
defer xref-string-hook		' noop is xref-string-hook
[then]

fload ${BP}/fm/lib/xref.fth
fload ${BP}/fm/kernel/sparc/extra.fth

fload ${BP}/fm/kernel/sparc/double.fth
fload ${BP}/fm/kernel/double.fth

fload ${BP}/fm/kernel/dmuldiv.fth
64\ fload ${BP}/fm/kernel/dmul.fth
defer title ' noop is title		\ Set later in loadutil.fth

fload ${BP}/fm/kernel/io.fth		\ I init #-buf

fload ${BP}/fm/kernel/stresc.fth	\ I init stringbuf
fload ${BP}/fm/kernel/comment.fth
fload ${BP}/fm/kernel/kernel2.fth
fload ${BP}/fm/kernel/compiler.fth	\ I init 'compile-buffer
fload ${BP}/fm/kernel/interp.fth
fload ${BP}/fm/kernel/kernport.fth

fload ${BP}/fm/kernel/definers.fth \ I clear buffers
fload ${BP}/fm/kernel/tagvoc.fth
fload ${BP}/fm/kernel/voccom.fth	\ I init canonical-words and
					\   prev-canonical-word

fload ${BP}/fm/kernel/order.fth		\ I init search order
fload ${BP}/fm/kernel/is.fth
fload ${BP}/fm/kernel/sparc/field.fth

fload ${BP}/fm/kernel/cold.fth

fload ${BP}/fm/kernel/sparc/checkpt.fth

fload ${BP}/fm/kernel/guarded.fth

fload ${BP}/fm/lib/cstrings.fth		\ I init cstrbuf

\ Bootstrapping onto a minikernel does not work yet so we need these.
[undef] miniforth?

[ifndef] miniforth?
fload ${BP}/fm/kernel/sparc/filecode.fth
fload ${BP}/fm/kernel/filecomm.fth	 \ I init 'word and fds
fload ${BP}/fm/kernel/disk.fth
fload ${BP}/fm/kernel/readline.fth
fload ${BP}/fm/cwrapper/sysdisk.fth
[then]

fload ${BP}/fm/cwrapper/syskey.fth
fload ${BP}/os/unix/sparc/sys.fth

fload ${BP}/fm/lib/alias.fth

fload ${BP}/fm/kernel/cmdline.fth

fload ${BP}/fm/kernel/nswapmap.fth

fload ${BP}/fm/kernel/ansio.fth		\ I init error-file
fload ${BP}/fm/kernel/sparc/parseline.fth

[ifndef] miniforth?
fload ${BP}/fm/kernel/fileio.fth
[then]

\ fload ${BP}/fm/lib/transien.fth
\ fload ${BP}/fm/lib/headless.fth

fload ${BP}/fm/cwrapper/sparc/boot.fth
fload ${BP}/fm/kernel/init.fth
fload ${BP}/fm/kernel/sparc/finish.fth

fload ${BP}/fm/meta/sparc/savemeta.fth

warning on	\ Turn ON the warning messages

hex

metaoff

[ifndef] dic-file-name
true abort" ERROR: dic-file-name undefined, can't save image"
[then]
[defined] dic-file-name dup 1+ alloc-mem pack save-meta

\ In order to get the headers/headerless info save the dictionary
[ifdef] nheads-dic-name
[defined] nheads-dic-name "temp pack
[else]
"" nheads.dic
[then] save-forth
