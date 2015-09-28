\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: util.fth
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
id: @(#)util.fth 1.1 07/01/23
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

\ Process integer property
: process-int-prop ( prop-str,len -- x )
   2dup get-inherited-property if			( str,len [ adr,len | ] )
      cmn-error[ " Could not find required property: %s" ]cmn-end 0
   else							( str,len adr,len )
      2swap 2drop decode-int nip nip			( x )
   then							( x )
;

: /regline ( -- /regline )
   " #address-cells" process-int-prop 	( x )
   " #size-cells" process-int-prop +	( /regline )

;

: drop-regline ( reg-addr,len -- reg-addr',len' )
   /regline 0 ?do		( reg-addr,len )
      decode-int drop		( reg-addr',len' )
   loop				( reg-addr',len' )
;

: map-in-regline ( reg-addr,len -- reg-addr',len' vaddr )
   /regline 0 ?do		( reg-addr,len )
      decode-int -rot		( ... reg-addr',len' )
   loop				( ... reg-addr',len' )
   >r >r			( phys.hi phys.lo len.hi len.lo )( R: reg-addr',len' )
   swap lxjoin -rot swap rot	( phys.lo phys.hi len )
   " map-in" $call-parent	( vaddr )
   r> r> rot			( reg-addr',len' vaddr )
;

: regline-size ( reg-addr,len -- size )
   decode-int drop decode-int drop
   decode-int >r decode-int >r
   2drop r> r> lxjoin
;

: align-size ( size alignment -- size' )
   tuck tuck /mod		( alignment alignemnt rem quo )
   rot * swap 			( alignemnt size' rem )
   if + else nip then		( size' ) 		
;

: enx+ ( xdr,len x -- xdr,len ) xlsplit swap >r en+ r> en+ ;
