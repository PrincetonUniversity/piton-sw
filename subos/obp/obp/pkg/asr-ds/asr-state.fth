\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: asr-state.fth
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
id: @(#)asr-state.fth 1.1 07/02/07
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.


\ FWARC/2006/080

headerless

\ ASR State message types
h# a	constant ASR-STATE-REQ
h# 1a   constant ASR-STATE-RES

\ ASR State Response
struct
   /l   field >state-result
   /l   field >state-length
   d# 1000   field >key-strings		\ This field is a variable field,
					\ max size is determined by DS layer
					\ for now use 1000 byte
constant /state-response

\ Wrap state data to be sent to the domain services layer
\ We only need to send command, there is no payload to go with

\ ASR state request command
: assemble-state-pkt  ( -- pkt len )
   asr-buf                              ( pkt )
   ASR-STATE-REQ over asr-cmd!          ( pkt )
   /asr-hdr                  		( pkt len )
;

: (asr-state)  ( -- $response | -1 )
   asr-buf /max-asr-response erase
   check-asr-channel-state if
      \ Assume nothing disabled
      true exit					( -1 )
   then
   assemble-state-pkt                           ( buf len )
   asr-svc-handle send-ds-data if
      cmn-warn[ " Error sending ASR data - transaction failed" ]cmn-end
      \ Assume nothing disabled
      -1 exit					( -1 )
   then
   receive-asr-response ?dup 0= if              ( buf' len' )
      \ subtract asr-hdr, state-result and state-length bytes
      /asr-hdr - 0 >key-strings -		( buf' len" )
      swap dup asr-cmd@ ASR-STATE-RES = if      ( len" buf )
	 >asr-payload 				( len" payload-buf )
	 dup >state-result l@			( len" payload-buf result ) 
         ASR-CMD-FAILED = if                    ( len" payload-buf )
            cmn-warn[ " ASR State request Failed - Command Failed" ]cmn-end
	    \ Assume nothing disabled
            2drop -1 exit 			( -1 )
         then                                   ( len" payload-buf )
         dup >key-strings swap >state-length l@ rot min ( $response ) 
      else                                      ( buf' len' )
	 \ Assume nothing disabled
         2drop -1                                ( -1 )
      then                                      ( $response | -1 )
   then                                         ( $response | -1 )
;

\ len = 0 means nothing is disabled
: asr-state  ( -- $response )
   (asr-state) dup -1 = if                      ( $response  |  )
      \ Assume nothing disabled
      drop 0 0 					( 0 0 )
   then                                         ( $response' )
;


: cstrlen ( cstr -- length )
   dup  begin  dup c@  while  ca1+  repeat  swap -
;

: cscount ( cstr -- adr len )  dup cstrlen ;

\ returns ptr to the next byte after the cstring
: cmn-cstr ( ptr -- ptr' )  cscount 2dup cmn-append + 1+ ;


\ state   [key1][0][key2][0][keyn][0]
\ len = 0 means nothing is disabled
: check-asr-state   ( -- )
   \ Get ASR State information, length of 0 means nothing disabled
   asr-state ?dup 0= if drop exit then	(  )
   cmn-error[ " The following devices are disabled:"r"n" cmn-append
   over + swap                          ( end buf )
   begin                                ( end buf )
      2dup > while                      ( end buf )
      "     " cmn-append                ( end buf' )
      cmn-cstr                          ( end buf' )
      " "r"n" cmn-append                ( end buf' )
   repeat 2drop                         ( )
   " " ]cmn-end                         ( )
;

chain: check-machine-state ( -- )  check-asr-state ;

