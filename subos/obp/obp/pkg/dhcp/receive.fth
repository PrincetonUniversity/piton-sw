\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: receive.fth
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
id: @(#)receive.fth 2.10 02/08/22
purpose: Interface between IP protocol layer and network driver
copyright: Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ Interface between IP protocol layer and network driver

headerless

0 instance value ethernet-max
instance variable *buffer
0 *buffer !
instance variable buffer-use-cnt    \ Number of modules using *buffer

: bufadr,len  ( -- adr len )  *buffer @  ethernet-max   ;

: reserve-buffer ( -- )
   *buffer @ 0=  if
      " max-frame-size" get-inherited-property 0=  if
         decode-int nip nip
      else
         d# 1518	\ 6 srcadr + 6 dstadr + 2 type + 1500 data + 4 crc	
      then  to ethernet-max
      ethernet-max alloc-mem *buffer !
   then
   1 buffer-use-cnt +!
;

: release-buffer  ( -- )
   -1 buffer-use-cnt +!
   buffer-use-cnt @ 0=  if
      bufadr,len  free-mem
      0 *buffer !
   then
;

\ non-zero if something good came in, <= ethernet-max
: receive  ( -- len )
   bufadr,len  " read" $call-parent  ( -2 | actual-len )
   0 max
;

\ len' is number of bytes sent
: transmit  ( len -- len' )  *buffer @  swap  " write" $call-parent  ;

headers
