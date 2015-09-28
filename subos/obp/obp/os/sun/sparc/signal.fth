\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: signal.fth
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
\ signal.fth 2.3 98/10/21
\ Copyright 1985-1990 Bradley Forthware

decimal
only forth also definitions
vocabulary signals
signals also definitions

32 constant NSIG

1 constant SIGHUP	 \ hangup 
2 constant SIGINT	 \ interrupt 
3 constant SIGQUIT	 \ quit 
4 constant SIGILL	 \ illegal instruction not reset when caught 
5 constant SIGTRAP	 \ trace trap not reset when caught 
6 constant SIGIOT	 \ IOT instruction 
7 constant SIGEMT	 \ EMT instruction 
8 constant SIGFPE	 \ floating point exception 
9 constant SIGKILL	 \ kill cannot be caught or ignored 
10 constant SIGBUS	 \ bus error 
11 constant SIGSEGV	 \ segmentation violation 
12 constant SIGSYS	 \ bad argument to system call 
13 constant SIGPIPE	 \ write on a pipe with no one to read it 
14 constant SIGALRM	 \ alarm clock 
15 constant SIGTERM	 \ software termination signal from kill 
16 constant SIGURG	 \ urgent condition on IO channel 
17 constant SIGSTOP	 \ sendable stop signal not from tty 
18 constant SIGTSTP	 \ stop signal from tty 
19 constant SIGCONT	 \ continue a stopped process 
20 constant SIGCHLD	 \ to parent on child stop or exit 
21 constant SIGTTIN	 \ to readers pgrp upon background tty read 
22 constant SIGTTOU	 \ like TTIN for output if tp->t_local&LTOSTOP 
23 constant SIGIO	 \ input/output possible signal 
24 constant SIGXCPU	 \ exceeded CPU time limit 
25 constant SIGXFSZ	 \ exceeded file size limit 
26 constant SIGVTALRM	 \ virtual time alarm 
27 constant SIGPROF	 \ profiling time alarm 
28 constant SIGWINCH	 \ window changed 

-1 constant BADSIG
0  constant SIG_DFL
1  constant SIG_IGN

: signal ( handler signal# -- oldhandler )
  td 23 syscall lretval l>r 2drop lr>
;
only forth also definitions
