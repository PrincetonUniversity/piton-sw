\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ethernet.fth
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
id: @(#)ethernet.fth 2.10 02/08/22
purpose: Definitions related to Ethernet headers and addresses
copyright: Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

hex

headerless
6 instance buffer: my-en-addr
6 instance buffer: his-en-addr
create broadcast-en-addr  ff c, ff c, ff c, ff c, ff c, ff c,

decimal

instance variable active-struct

: active-struct@ ( -- adr )  active-struct @ ;

\ Access to composite data in Internet byte order (big-endian)

: be-l!  ( l adr -- )  >r lbsplit r@ c! r@ ca1+ c! r@ 2 ca+ c! r> 3 ca+ c!  ;
: be-l@  ( adr -- l )  dup 3 ca+ c@  swap dup 2 ca+ c@  swap dup ca1+ c@  swap c@ bljoin  ;
: be-w@  ( adr -- w )  dup 1+ c@ swap c@ bwjoin  ;
: be-w!  ( w adr -- )  >r wbsplit  r@ c!  r> 1+ c!  ;

struct ( ether-header )
   6 field >en-dest-addr
   6 field >en-source-addr
   2 field >en-type
constant /ether-header

: en-dest-addr   ( -- adr )  active-struct@ >en-dest-addr ;
: en-source-addr ( -- adr )  active-struct@ >en-source-addr ;
: en-type        ( -- adr )  active-struct@ >en-type ;

: broadcast-en-addr?  ( adr-buf -- flag )
   broadcast-en-addr 6  comp  0=
;

headers

\ Display Ethernet address
: u..  ( n -- )  (u.) type  ;
: .enaddr  ( addr-buff -- )
   base @ >r  hex
   5 0 do  dup c@ u.. 1+  ." :"  loop  c@ u..
   r> base !
;
