\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bge-test.fth
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
id: @(#)bge-test.fth 1.1 02/09/06
purpose: Test Routines
copyright: Copyright 2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

hex

headers

create loopback-data
   ff c, 00 c,  \ Ones and zeroes
   01 c, 02 c,
   04 c, 08 c,
   10 c, 20 c,
   40 c, 80 c,  \ Walking ones
   fe c, fd c,
   fb c, f7 c,
   ef c, 0df c,

   0bf c, 7f c, \ Walking zeroes
   55 c, aa c,
   ff c, 00 c,  \ Ones and zeroes
   01 c, 02 c,
   04 c, 08 c,
   10 c, 20 c,
   40 c, 80 c,  \ Walking ones
   fe c, fd c,

   fb c, f7 c,
   ef c, 0df c,
   bf c, 7f c,  \ Walking zeroes
   55 c, aa c,
   01 c, 02 c,
   04 c, 08 c,
   10 c, 20 c,
   40 c, 80 c,  \ Walking ones
   da c, da c,
   da c, da c,

d# 52 constant /loopback-data
d# 64 constant /loopback-pkt

: loopback-buffer ( -- adr len )
   get-tx-buffer
   mac-address drop  over                      6 cmove  \ Set dest address
   mac-address drop  over 6 +                  6 cmove  \ Set source address
   loopback-data     over d# 12 + /loopback-data cmove  \ Set buffer contents
   /loopback-pkt
;

: pdump  ( adr -- )
   base @ >r  hex
   dup      d# 10  bounds  do  i c@  3 u.r  loop  cr
   d# 10 + dup  d# 10  bounds  do  i c@  3 u.r  loop  cr
   d# 10 + dup  d# 10  bounds  do  i c@  3 u.r  loop  cr
   d# 10 + dup  d# 10  bounds  do  i c@  3 u.r  loop  cr
   d# 10 + dup  d# 10  bounds  do  i c@  3 u.r  loop  cr
   d# 10 +  d# 2  bounds  do  i c@  3 u.r  loop  cr
   r> base !
;

: .loopback ( -- )
   mac-mode  int-loopback =  if
      ." Internal Loopback test -- "
   else
      ." Unknown mode"
   then
;

: check-len&data ( pkt len -- ok? )

   dup /loopback-pkt <>  if                            ( pkt len )
      .loopback ." Wrong packet length. Expected"     ( pkt len )
      /loopback-pkt .d                                 ( pkt len )
      ." Received" .d                                  ( pkt )
      drop false exit                                  ( false )
   then

   swap dup d# 12 + loopback-data /loopback-data comp 0<> if
      .loopback
      ." Received packet contained incorrect data. Expected: " cr
      loopback-data /loopback-data pdump
      ." Observed"  d# 12 + swap pdump
      false exit
   then 2drop

   true
;

: timed-receive ( timeout-ms -- [ buf-handle pkt len ] err? )
   0 ?do
      receive-ready? if
         receive dup if
            unloop 4 -		\ last 4 bytes = checksum 
	    false exit
         then
         2drop return-buffer
      then
      1 ms
   loop true
;

\ headers
 
: (loopback-test) ( -- success? )
   loopback-buffer transmit 0= if
      .loopback ." Cannot send loopback packet" cr
      false
   else
      d# 2000 timed-receive if       ( handle pkt len )
         .loopback ." Did not receive expected loopback packet" cr
         false
      else                           ( handle pkt len )
         check-len&data              ( handle flag )
         swap return-buffer          ( flag )
      then
   then
;

: loopback-test ( loopback-mode -- pass? )
   mac-mode >r
   to  mac-mode
   net-on  if
      configure-mac
      (loopback-test)
   else
      false
   then
   net-off
   r> to mac-mode
;

: watch-test ( -- )
   ." Looking for Ethernet Packets." cr
   ." '.' is a Good Packet.  'X' is a Bad Packet."  cr
   ." Type any key to stop."  cr
   begin
      key? 0=
   while
      receive-ready?  if
         receive  if  ." ."  else  ." X"  then
         drop return-buffer
      then
   repeat
   key drop
;
