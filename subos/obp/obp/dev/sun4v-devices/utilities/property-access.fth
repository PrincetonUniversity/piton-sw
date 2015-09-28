\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: property-access.fth
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
id: %Z%%M% %I% %E%
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

my-args decode-int nip nip value my-node

\ Look in the machine description node for a property with the input 
\ name and if it is there return the value and type.
: required-prop ( name$ -- val,type | $data,type | 0 )
   2dup my-node -rot -1 md-find-prop
   ?dup if 
      nip nip md-decode-prop
   else
      cmn-note[ " Missing MD property: %s " ]cmn-end 0
   then
;

\ Look in the machine description node for a property with the input 
\ name. If it is there make a property in the device node with the 
\ same name and value.
: make-prop ( name$ -- ok? )
   2dup required-prop ?dup 0= if		( name$ property type | name$ )
      false					( false )
      cmn-type[ " %s property doesn't exist" ]cmn-end
   else
      case					( name$ property type )
         ascii s of encode-string endof 	
         ascii v of encode-int endof	
      endcase					( name$ enc-property )
      2swap property true              		( true ) 
   then
;
