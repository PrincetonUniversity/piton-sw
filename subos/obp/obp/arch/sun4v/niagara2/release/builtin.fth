\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: builtin.fth
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
\
\ Warning this is a machine generated file
\ Changes made here will go away
\

caps off
" /packages/SUNW,builtin-drivers" find-device
   headerless
   : load-driver ( str$ -- )
      find-drop-in  if		( adr,len )
         >r dup >r  1 byte-load	(  )
	 r> r> free-drop-in	(  )
      then			(  )
   ;
   headers
   : interrupt-property ( n -- )  " interrupts" integer-property  ;
   : get-fcode  ( adr1 len1 adr2 len2 -- true | false )
      find-drop-in  if
         2dup >r >r
         rot min  rot swap  move
         r> r> free-drop-in
         true
      else  2drop false
      then
   ;
   headers


   : onboard-devices ( -- )
      diagnostic-mode? if
         ." Loading onboard drivers: "
      then
      0 0 " 100" " /" begin-package
         " SUNW,vnexus" load-driver
      end-package
   ;


   : disk ( -- )	" legion-disk" load-driver ;


   : nvram ( -- )  " legion-nvram" load-driver ;


   : flashprom ( -- )	" sun4v-flashprom" load-driver ;


   :  SUNW,sun4v-console ( -- )	" sun4v-console" load-driver  ;


   : SUNW,sun4v-channel-devices  ( -- )  " sun4v-chan-dev" load-driver ;


   : SUNW,sun4v-network  ( -- )   " sun4v-vnet" load-driver  ;


   : SUNW,sun4v-disk  ( -- )  " sun4v-vdisk" load-driver  ;


   : SUNW,sun4v-tod ( -- )	" sun4v-tod" load-driver ;


   : pciex ( -- )
       " sun4v-vpci" load-driver   
   ;


   : SUNW,n2piu-pr ( -- )
      " sun4v-perf-cnt" load-driver
   ;


   : SUNW,niumx ( -- )
      " niu-nexus" load-driver
   ;


   : SUNW,niusl ( -- )
      " niu-network" load-driver
   ;


device-end
caps on

