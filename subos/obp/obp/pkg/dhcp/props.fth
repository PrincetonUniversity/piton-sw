\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: props.fth
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
id: @(#)props.fth 1.4 03/05/08
purpose: Export bootreply packet and dhcp-clientid in /chosen node 
copyright: Copyright 1995-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

0  instance value  selected-bootreply
0  instance value  selected-reply-size

: root-name$  ( -- adr len )
   " /" find-package drop
   " name" rot  get-package-property drop
   decode-string 2swap 2drop
;

: dhcp-clientid-prop  ( -- adr len false | true)
   " /" find-package drop
   " client-id" rot  get-package-property
;

: package(  ( ihandle -- )  r> my-self >r >r  is my-self  ;
: )package  ( -- )  r> r> is my-self >r  ;

: publish-bootp-response  ( -- )
   " /chosen" find-package  if				( phandle )
      selected-bootreply selected-reply-size rot	( adr,len phandle )
      0 package(					( adr,len phandle )
         push-package					( adr,len )
         encode-bytes " bootp-response" property	( )
         pop-package					( )
      )package						( )
   then
;

: publish-dhcp-clientid  ( adr len-- )
   " /chosen" find-package  if				( adr,len phandle )
      0 package(					( adr,len phandle )
         push-package					( adr,len )
         encode-bytes " client-id" property		( )
	 pop-package					( )
      )package						( )
   then
;

headers
