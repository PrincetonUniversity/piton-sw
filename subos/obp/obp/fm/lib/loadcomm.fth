\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: loadcomm.fth
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
id: @(#)loadcomm.fth 1.13 03/12/11 09:22:50
purpose: 
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 1994 FirmWorks  All Rights Reserved
copyright: Use is subject to license terms.

transient fload ${BP}/fm/lib/xref.fth resident
fload ${BP}/fm/lib/th.fth

transient fload ${BP}/fm/lib/filetool.fth resident
			\ needed for dispose, savefort.fth
transient fload ${BP}/fm/lib/dispose.fth resident

transient fload ${BP}/fm/lib/showspac.fth resident

\

fload ${BP}/fm/lib/chains.fth

fload ${BP}/fm/lib/patch.fth
\ fload ${BP}/fm/kernel/hashcach.fth

headers transient   alias  headerless0  headers   resident

fload ${BP}/fm/lib/ansiterm.fth

fload ${BP}/fm/lib/strings.fth

fload ${BP}/fm/lib/fastspac.fth

fload ${BP}/fm/lib/cirstack.fth		\ Circular stack
fload ${BP}/fm/lib/pseudors.fth		\ Interpretable >r and r>

fload ${BP}/fm/lib/headtool.fth

transient  fload ${BP}/fm/lib/needs.fth  resident

fload ${BP}/fm/lib/suspend.fth

fload ${BP}/fm/lib/util.fth
fload ${BP}/fm/lib/format.fth

fload ${BP}/fm/lib/stringar.fth

fload ${BP}/fm/lib/parses1.fth	\ String parsing

fload ${BP}/fm/lib/split.fth

fload ${BP}/fm/lib/dump.fth
fload ${BP}/fm/lib/words.fth
fload ${BP}/fm/lib/decomp.fth

\ Uses  over-vocabulary  from words.fth
transient fload ${BP}/fm/lib/dumphead.fth  resident

fload ${BP}/fm/lib/seechain.fth

fload ${BP}/fm/lib/loadedit.fth		\ Command line editor module

fload ${BP}/fm/lib/caller.fth

fload ${BP}/fm/lib/callfind.fth
fload ${BP}/fm/lib/substrin.fth
fload ${BP}/fm/lib/sift.fth

fload ${BP}/fm/lib/array.fth

fload ${BP}/fm/lib/linklist.fth		\ Linked list routines

fload ${BP}/fm/lib/initsave.fth		\ Common code for save-forth et al
