\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ccall.fth
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
\ ccall.fth 2.6 94/09/06
\ Copyright 1985-1990 Bradley Forthware

\ Usage:
\ Subroutine calls:
\
\    " external-procedure-name" $ccall
\ or
\    " external-procedure-name" $ccall: name  { args -- results }

\ NOTE: sc1 through sc6  (%l1 through %l6) are destroyed
\
\ Data references:
\
\    " external-name" <register-name> $set-external

\ Assembler macro to assemble code to call a named C subroutine.
\ This is an implementation word used by "ccall:".
\ The code to transfer the arguments from the stack must be generated
\ before executing this macro.  Afterwards, the code to transfer the
\ results back onto the stack must be generated.  "ccall" generates:
\
\     sethi  %hi(c_entry_point), %l0
\     call   do-ccall
\     or     %l0, %lo(c_entry_point), %l0
\
\ do-ccall is a shared procedure that saves and restores the Forth
\ virtual machine state before calling the C procedure.

: $ccall   ( procedure-name-adr,len -- )
   [ also assembler ]
   ?$add-symbol                                   ( sym# )

   \ To optimize the generated code, we move the "or" half of the
   \ "set" instruction into the delay slot of the call, generating
   \ relocation table entries accordingly.

   dictionary-size   over  0 sparc-hi22 make-relocation  ( sym# )
   0  %l0  sethi                                         ( sym# )

   do-ccall call			                 ( sym# )

   dictionary-size   swap  0 sparc-lo10 make-relocation  ( )
   %l0 0  %l0  or
   [ previous ]
;
: $ccall:  \ name  ( procedure-name$ -- procedure-name$ 'subroutine-call )
   ['] $ccall code   current token@ context token!
;
also assembler definitions
: $set-external  ( name$ register -- )
   dictionary-size  2swap  $set-reference   ( register )
   0 over sethi                             ( register )
   0 over or
;
previous definitions
