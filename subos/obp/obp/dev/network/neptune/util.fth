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
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved.
copyright: Use is subject to license terms.

headerless

: xrshift ( x n -- x' )
   swap xlsplit rot			( lo hi n )
   dup d# 32 >=  if			( lo hi n )
      rot drop 0 swap d# 32 -		( lo' 0 n' )
   then					( lo' hi' n' )
   2dup rshift >r			( lo' hi' n' )( R: res.hi )
   1 over lshift 1- rot and		( lo' n' bits )
   d# 32 2 pick - lshift -rot rshift or	( res.lo )
   r>					( res.lo res.hi )( R: )
   lxjoin				( x' )
;

\ 0<> tokenizes into l0<>, which doesn't pick up the 
\ bits [63:32]
: x0<> ( x -- flag ) 
   xlsplit or 0<>
;

: wait-status ( timeout check-acf --  ok? )
   swap       ( check-acf timeout )
   0          ( check-acf timeout 0 )
   ?do     
      dup     ( check-acf check-acf ) 
      execute ( check-acf ??? )  \ ??? is the return value of check-acf 
      if      ( check-acf ) 
         unloop 
         drop 
         true exit  
      then  
      1 ms 
   loop 
   drop       ( )       \ drop check-acf
   false      ( false )
;

\ The difference between this and wait-status is that this word passes 
\ one argument to check-acf. For example, we can pass a DMA channel 
\ number to a check-acf function.
\
: wait-status-with-arg ( timeout arg check-acf --  ok? )
   rot 0 ?do           ( arg check-acf )
      2dup execute if  ( arg check-acf )    
      unloop           ( arg check-acf )
         2drop         (  )
         true exit     ( ok? )
      then             ( arg check-acf )
      1 ms             ( arg check-acf )
   loop                ( arg check-acf )
   2drop               ( )
   false               ( ok? )
;

: timed-out? ( when -- flag ) get-msecs - 0< ;

: set-default-link-params
   auto-speed      to user-speed
   auto-duplex     to user-duplex
   auto-link-clock to user-link-clock
   0               to chosen-speed
   0               to chosen-duplex
;

d# 128 constant my-path-len
my-path-len buffer: my-path$

: make-path ( -- )
   my-path$ my-path-len 0 fill                \ Clear device path.
   \ Build device path.
   my-path-len 2 - my-path$ 1+                ( len' va' )
   my-self ihandle>phandle " package-to-path" ( len' va' ihandle method$ )
   " /openprom/client-services" find-package  ( ... [false | phandle true] )
   0= if 3drop 2drop exit then                ( ... ihandle method$ phandle )
   find-method                                ( ... ihandle [false | xt true] )
   0= if 3drop exit then                      ( ... ihandle xt )
   execute                                    ( len'' )
   \ Append ": " to the device-path.
   1+ dup 1+ my-path$ tuck c! +               ( [len''+1+va] )
   " : " rot swap move                        ( )
;

: path$            ( -- str,len ) my-path$ count ;

: pdump ( adr len -- )
   cr
   0 ?do
      \ Print byte with 3 character alignment
      dup i + c@ 3 u.r
      \ cr every 8 bytes
      i 1+ d# 8 mod 0= if cr then
   loop
   drop cr
;
