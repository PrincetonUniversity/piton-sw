\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: kernel-xref.headless.fth
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
h# 0000dc headerless: (lit) 
h# 0000f8 headerless: (wlit) 
h# 000114 headerless: (llit) 
h# 000130 headerless: branch 
h# 000144 headerless: ?branch 
h# 000164 headerless: (loop) 
h# 000188 headerless: (+loop) 
h# 0001b4 headerless: (do) 
h# 0001f8 headerless: (?do) 
h# 000274 headerless: (leave) 
h# 000290 headerless: (?leave) 
h# 0002c8 headerless: (of) 
h# 000308 headerless: (endof) 
h# 00031c headerless: (endcase) 
h# 0005d4 headerless: first-code-word 
h# 001194 headerless: (is-user) 
h# 0011b8 headerless: (is-defer) 
h# 001cd0 headerless: dec-sp-instr 
h# 001cdc headerless: dec-rp-instr 
h# 001ce8 headerless: pfa>scr-instr 
h# 001cf4 headerless: param>scr-instr 
h# 001d00 headerless: >offset-30 
h# 001d1c headerless: put-call 
h# 001d44 headerless: put-branch 
h# 001d78 headerless: set-delay-slot 
h# 001d94 headerless: place-call 
h# 001dc4 headerless: place-cf 
h# 001dd4 headerless: code-cf 
h# 001de4 headerless: >code 
h# 001df0 headerless: code? 
h# 001e8c headerless: create-cf 
h# 001ea4 headerless: place-does 
h# 001ebc headerless: place-;code 
h# 001ec8 headerless: does-ip? 
h# 001f18 headerless: put-cf 
h# 001f3c headerless: used 
h# 001f50 headerless: does-clause? 
h# 001f98 headerless: does-cf? 
h# 00200c headerless: colon-cf? 
h# 002048 headerless: user-cf 
h# 002060 headerless: value-cf 
h# 002078 headerless: constant-cf 
h# 002090 headerless: defer-cf 
h# 0020b0 headerless: defer? 
h# 0020ec headerless: 2constant-cf 
h# 002104 headerless: /branch 
h# 002110 headerless: branch, 
h# 002120 headerless: branch! 
h# 002130 headerless: branch@ 
h# 002140 headerless: >target 
h# 0025f0 headerless: clear-relocation-bits 
h# 002b10 headerless: init 
h# 0032c8 headerless: (xref-on) 
h# 003388 headerless: (xref-off) 
h# 003420 headerless: perform 
h# 003430 headerless: hash 
h# 003780 headerless: /t* 
h# 0039d8 headerless: ?2off 
h# 0039f4 headerless: d(pre-compare) 
h# 0047c8 headerless: #-buf 
h# 0047d4 headerless: init 
h# 004c00 headerless: (ul.) 
h# 004c3c headerless: ul.r 
h# 004c64 headerless: (l.) 
h# 004cdc headerless: l.r 
h# 004e58 headerless: stringbuf 
h# 004e64 headerless: "select 
h# 004e70 headerless: '"temp 
h# 004e7c headerless: /stringbuf 
h# 004e88 headerless: init 
h# 005014 headerless: add-char 
h# 005044 headerless: nextchar 
h# 00509c headerless: nexthex 
h# 0050f8 headerless: get-hex-bytes 
h# 005184 headerless: get-char 
h# 005fbc headerless: (compile-time-error) 
h# 005fdc headerless: (compile-time-warning) 
h# 0067c4 headerless: saved-dp 
h# 0067d0 headerless: saved-limit 
h# 0067dc headerless: level 
h# 0067e8 headerless: /compile-buffer 
h# 0067f4 headerless: 'compile-buffer 
h# 006800 headerless: compile-buffer 
h# 006814 headerless: init 
h# 00683c headerless: reset-dp 
h# 0069c4 headerless: +>mark 
h# 0069e4 headerless: +<mark 
h# 0069f8 headerless: ->resolve 
h# 006a1c headerless: -<resolve 
h# 007208 headerless: interpret-do-defined 
h# 00721c headerless: compile-do-defined 
h# 007278 headerless: $interpret-do-undefined 
h# 00729c headerless: $compile-do-undefined 
h# 0072c8 headerless: ([) 
h# 007310 headerless: (]) 
h# 007b74 headerless: buffer-link 
h# 007b80 headerless: make-buffer 
h# 007bb8 headerless: /buffer 
h# 007bd0 headerless: init-buffer 
h# 007c00 headerless: do-buffer 
h# 007c3c headerless: (buffer:) 
h# 007c80 headerless: >buffer-link 
h# 007c9c headerless: clear-buffer:s 
h# 007cd4 headerless: init 
h# 007f28 headerless: $make-header 
h# 00808c headerless: >ptr 
h# 0080b8 headerless: next-word 
h# 0080e8 headerless: insert-word 
h# 008398 headerless: voc-link, 
h# 0083bc headerless: fake-name-buf 
h# 0085e4 headerless: duplicate-notification 
h# 008620 headerless: init 
h# 00885c headerless: tbuf 
h# 008944 headerless: trim 
h# 008b18 headerless: init 
h# 008bc8 headerless: shuffle-down 
h# 008c64 headerless: compact-search-order 
h# 00922c headerless: init 
h# 009288 headerless: is-error 
h# 0092d0 headerless: >bu 
h# 0092e4 headerless: word-types 
h# 009300 headerless: data-locs 
h# 009318 headerless: is-user 
h# 00932c headerless: is-defer 
h# 009340 headerless: is-const 
h# 009354 headerless: !data-ops 
h# 00936c headerless: (is-const) 
h# 009390 headerless: (!data-ops) 
h# 0093a8 headerless: associate 
h# 00940c headerless: +token@ 
h# 009424 headerless: +execute 
h# 009438 headerless: kerntype? 
h# 0096f0 headerless: single 
h# 009818 headerless: /check-stack 
h# 009824 headerless: /check-frame 
h# 009830 headerless: >check-prev 
h# 009848 headerless: >check-myself 
h# 009860 headerless: >check-age 
h# 009890 headerless: init-checkpt 
h# 00991c headerless: alloc-checkpt 
h# 009b04 headerless: save-checkpt 
h# 009b5c headerless: restore-checkpt 
h# 009bb4 headerless: free-oldest-frames 
h# 009c8c headerless: alloc-frame 
h# 009df0 headerless: free-frame 
h# 009e28 headerless: (free-checkpt) 
h# 009fc8 headerless: init 
h# 00a13c headerless: cstrbuf 
h# 00a148 headerless: init 
h# 00a24c headerless: ln+ 
h# 00a264 headerless: @c@++ 
h# 00a284 headerless: @c!++ 
h# 00a2b0 headerless: split-string 
h# 00a3ac headerless: bftop 
h# 00a3b8 headerless: bfend 
h# 00a3c4 headerless: bfcurrent 
h# 00a3d0 headerless: bfdirty 
h# 00a3dc headerless: fmode 
h# 00a3e8 headerless: fstart 
h# 00a3f4 headerless: fid 
h# 00a400 headerless: seekop 
h# 00a40c headerless: readop 
h# 00a418 headerless: writeop 
h# 00a424 headerless: closeop 
h# 00a430 headerless: alignop 
h# 00a43c headerless: sizeop 
h# 00a448 headerless: (file-line) 
h# 00a454 headerless: line-delimiter 
h# 00a460 headerless: pre-delimiter 
h# 00a46c headerless: (file-name) 
h# 00a5ec headerless: not-open 
h# 00a610 headerless: write 
h# 00a634 headerless: read-write 
h# 00a6f8 headerless: fakeread 
h# 00a7c0 headerless: fdavail? 
h# 00a7fc headerless: bfsync 
h# 00a834 headerless: ?flushbuf 
h# 00a8e0 headerless: fillbuf 
h# 00a970 headerless: >bufaddr 
h# 00a998 headerless: shortseek 
h# 00aa00 headerless: ?fillbuf 
h# 00aac4 headerless: #fds 
h# 00aad0 headerless: /fds 
h# 00aadc headerless: fds 
h# 00aae8 headerless: init 
h# 00ab44 headerless: (get-fd 
h# 00ab94 headerless: string-sizeop 
h# 00abbc headerless: open-buffer 
h# 00acbc headerless: (.error#) 
h# 00ad30 headerless: /fbuf 
h# 00ad3c headerless: get-fd 
h# 00adfc headerless: fflush 
h# 00af08 headerless: (feof? 
h# 00b028 headerless: copyin 
h# 00b08c headerless: copyout 
h# 00b43c headerless: opened-filename 
h# 00bbe0 headerless: _fclose 
h# 00bc14 headerless: _fwrite 
h# 00bc50 headerless: _fread 
h# 00bc90 headerless: _lseek 
h# 00bcbc headerless: _fseek 
h# 00bcec headerless: _dfseek 
h# 00bd20 headerless: _ftell 
h# 00bd50 headerless: _dftell 
h# 00bd64 headerless: _fsize 
h# 00bdac headerless: _dfsize 
h# 00bdc0 headerless: file-protection 
h# 00bdcc headerless: sys_fopen 
h# 00bf04 headerless: sys_newline 
h# 00bf20 headerless: install-disk-io 
h# 00bf4c headerless: lf-pstr 
h# 00bf58 headerless: cr-pstr 
h# 00bf64 headerless: crlf-pstr 
h# 00bf70 headerless: _falign 
h# 00bf90 headerless: _dfalign 
h# 00bfb8 headerless: unix-init-io 
h# 00bfc8 headerless: sys-emit 
h# 00bfe0 headerless: sys-key 
h# 00bff8 headerless: sys-(key? 
h# 00c010 headerless: sys-cr 
h# 00c03c headerless: sys-interactive? 
h# 00c0a0 headerless: sys-type 
h# 00c0bc headerless: sys-bye 
h# 00c0d8 headerless: sys-alloc-mem 
h# 00c0f8 headerless: sys-free-mem 
h# 00c114 headerless: sys-sync-cache 
h# 00c134 headerless: install-wrapper-io 
h# 00c20c headerless: sysretval 
h# 00c36c headerless: error? 
h# 00c3a4 headerless: cstr 
h# 00c3b4 headerless: unix-init-io 
h# 00c3dc headerless: unix-init 
h# 00ca18 headerless: skipwhite 
h# 00ca60 headerless: scantowhite 
h# 00cac4 headerless: skipchar 
h# 00cb20 headerless: scantochar 
h# 00d12c headerless: (file-read-line) 
h# 00d1a8 headerless: interpret-lines 
h# 00d1cc headerless: include-file 
h# 00d244 headerless: $open-error 
h# 00d250 headerless: include-buffer 
h# 00d284 headerless: $abort-include 
h# 00d2e0 headerless: including 
h# 00d2f4 headerless: fl 
h# 00d304 headerless: error-file 
h# 00d310 headerless: error-line# 
h# 00d31c headerless: error-source-id 
h# 00d328 headerless: error-source-adr 
h# 00d334 headerless: error-#source 
h# 00d340 headerless: init 
h# 00d380 headerless: (eol-mark?) 
h# 00d3c4 headerless: (mark-error) 
h# 00d4f8 headerless: (show-error) 
h# 00d6a4 headerless: memtop 
h# 00d6e0 headerless: cold-code 
