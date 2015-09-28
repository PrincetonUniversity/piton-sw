\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: compatible.fth
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
id: @(#)compatible.fth 1.6 06/05/03
purpose: 
copyright: Copyright 1994 Firmworks  All Rights Reserved
copyright: Copyright 2006 Sun Microsystems, Inc. All Rights Reserved
copyright: Use is subject to license terms.

headerless

: $hold  ( adr len -- )
   dup  if  bounds swap 1-  ?do  i c@ hold  -1 +loop  else  2drop  then
;

: vid,did ( -- ven-id dev-id )  0 my-l@ lwsplit ;

: class-code  ( -- n )  8 my-l@ 8 rshift  ;

: subsystem-base ( -- n )
   h# 0e my-b@ h# 7f and 2 = if  h# 40  else  h# 2c  then
;

: svid,ssid ( -- subven-id subsys-id ) 
   class-code h# 60400 = if
      \ Bridges dont implement subvendor ID and Subsystem ID
      0 0
   else
      subsystem-base my-l@ lwsplit
   then
;

: rev-id ( -- rev-id )  h# 8 my-b@ ;

h# ffff      constant invalid-std-cap
h# ffff.ffff constant invalid-ext-cap

: find-std-capability  ( id -- pointer | 0 )
   h# 34 my-b@                                  ( id pointer )
   begin  dup  while                            ( id pointer )
      2dup my-w@ dup invalid-std-cap <> if      ( id pointer id w-value )
         wbsplit -rot =  if             ( id pointer next )
            drop nip exit               ( pointer )
         else
            nip                         ( id next )
         then
      else
         cmn-warn[ " Standard Capability Config access failed" ]cmn-end
         abort
      then
   repeat
   nip
;

: find-extd-capability  ( id -- pointer | 0 )
   h# 100
   begin  dup  while                            ( id pointer )
      2dup my-l@ dup invalid-ext-cap <> if      ( id poinetr id l-value )
         lwsplit 4 >> -rot =  if        ( id pointer next )
            drop nip exit               ( pointer )
         else
            nip                         ( id next )
         then
      else
         cmn-warn[ " Extended Capability Config access failed" ]cmn-end
         abort
      then
   repeat
   nip
;

: pcie-capability-regs ( -- pointer | 0 )  h# 10 find-std-capability ;
: aer-capability-regs  ( -- pointer | 0 )  1 find-extd-capability ;
: shpc-capability-regs ( -- pointer | 0 )  h# 0c find-std-capability ;

: get-port-type  ( -- port-type )
   pcie-capability-regs 2 +  my-w@  4 >>  h# f and
;

pcie-capability-regs 0<>  value  pci-express?

fload ${BP}/dev/pci/compatible-prop.fth
