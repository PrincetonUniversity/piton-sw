\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: k64t32.headless.fth
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
h# 0080f0 headerless: (lit) 
h# 008118 headerless: (wlit) 
h# 008134 headerless: (llit) 
h# 008154 headerless: branch 
h# 00816c headerless: ?branch 
h# 00818c headerless: (loop) 
h# 0081b0 headerless: (+loop) 
h# 0081dc headerless: (do) 
h# 008224 headerless: (?do) 
h# 0082a4 headerless: (leave) 
h# 0082c4 headerless: (?leave) 
h# 0082fc headerless: (of) 
h# 008340 headerless: (endof) 
h# 008358 headerless: (endcase) 
h# 008610 headerless: first-code-word 
h# 009254 headerless: (is-user) 
h# 009278 headerless: (is-defer) 
h# 009f10 headerless: dec-sp-instr 
h# 009f20 headerless: dec-rp-instr 
h# 009f30 headerless: pfa>scr-instr 
h# 009f40 headerless: param>scr-instr 
h# 009f50 headerless: >offset-30 
h# 009f74 headerless: put-call 
h# 009fa0 headerless: put-branch 
h# 009fdc headerless: set-delay-slot 
h# 009ff8 headerless: place-call 
h# 00a028 headerless: place-cf 
h# 00a038 headerless: code-cf 
h# 00a048 headerless: >code 
h# 00a054 headerless: code? 
h# 00a108 headerless: create-cf 
h# 00a124 headerless: place-does 
h# 00a140 headerless: place-;code 
h# 00a14c headerless: does-ip? 
h# 00a19c headerless: put-cf 
h# 00a1c0 headerless: used 
h# 00a1d4 headerless: does-clause? 
h# 00a220 headerless: does-cf? 
h# 00a298 headerless: colon-cf? 
h# 00a2d8 headerless: user-cf 
h# 00a2f4 headerless: value-cf 
h# 00a310 headerless: constant-cf 
h# 00a32c headerless: defer-cf 
h# 00a350 headerless: defer? 
h# 00a390 headerless: 2constant-cf 
h# 00a3ac headerless: /branch 
h# 00a3bc headerless: branch, 
h# 00a3cc headerless: branch! 
h# 00a3dc headerless: branch@ 
h# 00a3ec headerless: >target 
h# 00a8b4 headerless: clear-relocation-bits 
h# 00ab78 headerless: init 
h# 00ae60 headerless: hash 
h# 00b1bc headerless: /t* 
h# 00b450 headerless: ?2off 
h# 00b46c headerless: d(pre-compare) 
h# 00c434 headerless: #-buf 
h# 00c440 headerless: init 
h# 00c88c headerless: (ul.) 
h# 00c8c8 headerless: ul.r 
h# 00c8f0 headerless: (l.) 
h# 00c96c headerless: l.r 
h# 00caf0 headerless: stringbuf 
h# 00cafc headerless: "select 
h# 00cb08 headerless: '"temp 
h# 00cb14 headerless: /stringbuf 
h# 00cb24 headerless: init 
h# 00cccc headerless: add-char 
h# 00ccfc headerless: nextchar 
h# 00cd58 headerless: nexthex 
h# 00cdb8 headerless: get-hex-bytes 
h# 00ce4c headerless: get-char 
h# 00dd50 headerless: (compile-time-error) 
h# 00dd78 headerless: (compile-time-warning) 
h# 00e5dc headerless: saved-dp 
h# 00e5e8 headerless: saved-limit 
h# 00e5f4 headerless: level 
h# 00e600 headerless: /compile-buffer 
h# 00e610 headerless: 'compile-buffer 
h# 00e61c headerless: compile-buffer 
h# 00e630 headerless: init 
h# 00e658 headerless: reset-dp 
h# 00e7e4 headerless: +>mark 
h# 00e804 headerless: +<mark 
h# 00e818 headerless: ->resolve 
h# 00e83c headerless: -<resolve 
h# 00f038 headerless: interpret-do-defined 
h# 00f04c headerless: compile-do-defined 
h# 00f0a8 headerless: $interpret-do-undefined 
h# 00f0d0 headerless: $compile-do-undefined 
h# 00f0fc headerless: ([) 
h# 00f144 headerless: (]) 
h# 00f9ac headerless: buffer-link 
h# 00f9b8 headerless: make-buffer 
h# 00f9f0 headerless: /buffer 
h# 00fa08 headerless: init-buffer 
h# 00fa38 headerless: do-buffer 
h# 00fa74 headerless: (buffer:) 
h# 00fab8 headerless: >buffer-link 
h# 00fad4 headerless: clear-buffer:s 
h# 00fb0c headerless: init 
h# 00fd6c headerless: $make-header 
h# 00fe78 headerless: >ptr 
h# 00fea4 headerless: next-word 
h# 00fed4 headerless: insert-word 
h# 010168 headerless: voc-link, 
h# 01018c headerless: fake-name-buf 
h# 0103cc headerless: duplicate-notification 
h# 010408 headerless: init 
h# 010658 headerless: tbuf 
h# 010740 headerless: trim 
h# 010914 headerless: init 
h# 0109cc headerless: shuffle-down 
h# 010a68 headerless: compact-search-order 
h# 011038 headerless: init 
h# 011094 headerless: is-error 
h# 0110dc headerless: >bu 
h# 0110f0 headerless: word-types 
h# 01110c headerless: data-locs 
h# 011124 headerless: is-user 
h# 011138 headerless: is-defer 
h# 01114c headerless: is-const 
h# 011160 headerless: !data-ops 
h# 011178 headerless: (is-const) 
h# 01119c headerless: (!data-ops) 
h# 0111b4 headerless: associate 
h# 011218 headerless: +token@ 
h# 011230 headerless: +execute 
h# 011244 headerless: kerntype? 
h# 0114fc headerless: single 
h# 01162c headerless: /check-stack 
h# 01163c headerless: /check-frame 
h# 01164c headerless: >check-prev 
h# 011668 headerless: >check-myself 
h# 011684 headerless: >check-age 
h# 0116b8 headerless: init-checkpt 
h# 011744 headerless: alloc-checkpt 
h# 01192c headerless: save-checkpt 
h# 011984 headerless: restore-checkpt 
h# 0119dc headerless: free-oldest-frames 
h# 011ab8 headerless: alloc-frame 
h# 011c24 headerless: free-frame 
h# 011c5c headerless: (free-checkpt) 
h# 011dfc headerless: init 
h# 011f7c headerless: cstrbuf 
h# 011f88 headerless: init 
h# 012090 headerless: ln+ 
h# 0120a8 headerless: @c@++ 
h# 0120c8 headerless: @c!++ 
h# 0120f4 headerless: split-string 
h# 012200 headerless: bftop 
h# 01220c headerless: bfend 
h# 012218 headerless: bfcurrent 
h# 012224 headerless: bfdirty 
h# 012230 headerless: fmode 
h# 01223c headerless: fstart 
h# 012248 headerless: fid 
h# 012254 headerless: seekop 
h# 012260 headerless: readop 
h# 01226c headerless: writeop 
h# 012278 headerless: closeop 
h# 012284 headerless: alignop 
h# 012290 headerless: sizeop 
h# 01229c headerless: (file-line) 
h# 0122a8 headerless: line-delimiter 
h# 0122b4 headerless: pre-delimiter 
h# 0122c0 headerless: (file-name) 
h# 01244c headerless: not-open 
h# 012478 headerless: write 
h# 0124a4 headerless: read-write 
h# 01256c headerless: fakeread 
h# 012634 headerless: fdavail? 
h# 012670 headerless: bfsync 
h# 0126a8 headerless: ?flushbuf 
h# 012754 headerless: fillbuf 
h# 0127e4 headerless: >bufaddr 
h# 01280c headerless: shortseek 
h# 012874 headerless: ?fillbuf 
h# 012938 headerless: #fds 
h# 012948 headerless: /fds 
h# 012958 headerless: fds 
h# 012964 headerless: init 
h# 0129c0 headerless: (get-fd 
h# 012a10 headerless: string-sizeop 
h# 012a38 headerless: open-buffer 
h# 012b3c headerless: (.error#) 
h# 012bb4 headerless: /fbuf 
h# 012bc4 headerless: get-fd 
h# 012c84 headerless: fflush 
h# 012d90 headerless: (feof? 
h# 012eb0 headerless: copyin 
h# 012f14 headerless: copyout 
h# 0132d8 headerless: opened-filename 
h# 013a84 headerless: _fclose 
h# 013ab8 headerless: _fwrite 
h# 013af4 headerless: _fread 
h# 013b34 headerless: _lseek 
h# 013b64 headerless: _fseek 
h# 013b94 headerless: _dfseek 
h# 013bc8 headerless: _ftell 
h# 013bf8 headerless: _dftell 
h# 013c0c headerless: _fsize 
h# 013c54 headerless: _dfsize 
h# 013c68 headerless: file-protection 
h# 013c74 headerless: sys_fopen 
h# 013db0 headerless: sys_newline 
h# 013dd0 headerless: install-disk-io 
h# 013dfc headerless: lf-pstr 
h# 013e08 headerless: cr-pstr 
h# 013e14 headerless: crlf-pstr 
h# 013e20 headerless: _falign 
h# 013e44 headerless: _dfalign 
h# 013e70 headerless: unix-init-io 
h# 013e80 headerless: sys-emit 
h# 013e98 headerless: sys-key 
h# 013eb0 headerless: sys-(key? 
h# 013ec8 headerless: sys-cr 
h# 013ef8 headerless: sys-interactive? 
h# 013f64 headerless: sys-type 
h# 013f84 headerless: sys-bye 
h# 013fa4 headerless: sys-alloc-mem 
h# 013fc8 headerless: sys-free-mem 
h# 013fe8 headerless: sys-sync-cache 
h# 01400c headerless: install-wrapper-io 
h# 0140e4 headerless: sysretval 
h# 014244 headerless: error? 
h# 014280 headerless: cstr 
h# 014290 headerless: unix-init-io 
h# 0142b8 headerless: unix-init 
h# 014900 headerless: skipwhite 
h# 014948 headerless: scantowhite 
h# 0149ac headerless: skipchar 
h# 014a08 headerless: scantochar 
h# 015024 headerless: (file-read-line) 
h# 0150a0 headerless: interpret-lines 
h# 0150c4 headerless: include-file 
h# 01513c headerless: $open-error 
h# 01518c headerless: include-buffer 
h# 0151c0 headerless: $abort-include 
h# 01521c headerless: including 
h# 015230 headerless: fl 
h# 015240 headerless: error-file 
h# 01524c headerless: error-line# 
h# 015258 headerless: error-source-id 
h# 015264 headerless: error-source-adr 
h# 015270 headerless: error-#source 
h# 01527c headerless: init 
h# 0152c0 headerless: (eol-mark?) 
h# 01530c headerless: (mark-error) 
h# 015444 headerless: (show-error) 
h# 0155fc headerless: memtop 
h# 015638 headerless: cold-code 
