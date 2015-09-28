\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: cpu.fth
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
id: @(#)cpu.fth 1.2 06/07/13
purpose: 
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

: cpu-root ( -- str,len ) " /" ;

variable cpu-error?

: en+ encode-int encode+ ;

: make-cpu-props ( node -- )
   " cpu"	encode-string			" name"		property
   my-space	encode-int my-address en+ 0 en+ 0 en+	" reg"	property
   " cpu"	encode-string			" device_type"	property

   \ get compatible property from the MD
   dup " compatible" -1 md-find-prop		( node entry )
   md-decode-prop drop encode-bytes		( node $prop )
   " compatible" property			( node )

   \ get clock freq from the MD
   " clock-frequency" ascii v md-find-prop	( entry )
   md-decode-prop drop				( freq )
   " clock-frequency" integer-property
;

: make-cpu-nodes ( -- )
   cpu-error? off				( )
   0						( md-start )
   begin					( 0 )
      " cpu" md-find-node 			( cpunode | 0 ) 
   ?dup while					( cpunode )
      dup " id" ascii v md-find-prop		( cpunode entry|0 )
      ?dup if					( cpunode pdentry )
         md-decode-prop drop			( cpudnode id )
         dup mid-present?  if			( cpunode id )
            0 0 rot push-hex (.) pop-base	( cpunode arg$ reg$ )
            " /" begin-package			( cpunode )
            dup make-cpu-props			( cpunode ) 
            end-package				( cpunode )
         else					( cpunode id )
            drop 1 cpu-error? +!		( cpunode )
         then					( cpunode )
[ifndef] RELEASE
      else					( cpunode )
         cmn-fatal[ " missing 'ID' property in cpu description" ]cmn-end
[then]
      then					( cpunode )
   repeat 					( )
   cpu-error? @ ?dup if				( badcpus )
      cmn-error[ " %d CPUs in MD did not start" ]cmn-end 
   then
;

stand-init: Making cpu nodes
   make-cpu-nodes
;
