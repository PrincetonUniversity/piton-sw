\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: timedrec.fth
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
id: @(#)timedrec.fth 2.7 99/09/16
purpose: Network receive that will timeout after awhile
copyright: Copyright 1990-1997 Sun Microsystems, Inc.  All Rights Reserved

\ Implements a network receive that will timeout after a certain interval.

headerless

instance variable alarmtime

: set-timeout  ( interval -- )  get-msecs  +  alarmtime !  ;

: timeout?  ( -- flag )  get-msecs  alarmtime @ >=  ;

instance defer handle-broadcast-packet  ( pkt-addr pkt-len -- )    \ Fwd reference
' 2drop to handle-broadcast-packet

: multicast? ( -- flag)  *buffer @ c@ h# 01 and ;

: receive-ethernet-packet ( type -- [ pkt-adr pkt-len ] flag )
   begin
      receive dup 0>  if                                ( type len )
         *buffer @  active-struct !                     ( type len )
         over en-type be-w@ =  if                       ( type len )
            nip active-struct @ swap true exit
         else                                           ( type len )
            multicast?  if
               *buffer @ over handle-broadcast-packet
            then                                        ( type len )
         then                                           ( type len )
      then                                              ( type len )
      drop                                              ( type )
      timeout?                                          ( type flag )
   until                                                ( type )
   drop false                                           ( false )
;

headers
