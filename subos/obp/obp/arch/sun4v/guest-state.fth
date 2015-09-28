\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: guest-state.fth
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
id: @(#)guest-state.fth 1.1 07/06/22
purpose: Functions that support guest state implementation.
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless

1 constant sis-normal
2 constant sis-transitional

\ max-state-string-len is the length of the C-string that contains the
\ software state description (NULL terminated)
d# 32 constant max-state-string-len
\ stored-host-string-len is the length of the FORTH-string that contains the
\ software state description (non-NULL terminated)
d# 31 constant stored-host-string-len

h# 70 constant soft-state-set
h# 71 constant soft-state-get
h# 80 constant fast-trap-num

0 value guest-state-output-buffer-ptr
0 value guest-state-input-buffer-ptr

0 value phy-guest-state-output-buffer
0 value phy-guest-state-input-buffer

0 value stored-host-state-string-ptr
sis-transitional value stored-host-state

false value host-state-stored?
false value is-reset-reboot?
false value host-supports-guest-state

variable stand-init-status false stand-init-status !


: stand-init-completed?  ( -- completed? )  stand-init-status @  ;
: stand-init-completed  ( -- )  true stand-init-status !  ;


\ This function sets the guest state value
: set-guest-state ( state addr len -- error? )
   2dup stored-host-string-len <= swap 0>= and if			( state addr len )
      guest-state-output-buffer-ptr max-state-string-len 0 fill	        ( state addr len )
      1+ guest-state-output-buffer-ptr swap move			( state )
      phy-guest-state-output-buffer  					( state a-addr )
      2 1 soft-state-set fast-trap-num htrap				( error? )
   else
      -1								( error )
   then

;

\ this function gets the current value of guest state
: get-guest-state ( -- a-addr state error? )
   guest-state-input-buffer-ptr
   phy-guest-state-input-buffer		 		         	( a-addr phy )
   1 2 soft-state-get fast-trap-num htrap				( a-addr state error? )
;

headers

\ This function will print out the current guest state to the console
: .guest-state ( -- )
   get-guest-state drop					( a-addr state )
   max-state-string-len swap				( str,len state )

   case 
      sis-normal 	of " SIS_NORMAL " 	 endof	( str,len [state | str,len] )
      sis-transitional 	of " SIS_TRANSITIONAL "  endof	( str,len [state | str,len] )
      cmn-fatal[ " Invalid host state %x" ]cmn-end
   endcase						( str,len str',len' )
   cmn-type[ " Current guest state: %s %s" ]cmn-end
;

\ Client Interface Function that allows the os to tell OBP that it supports
\ the guest state feature.

cif: SUNW,soft-state-supported ( -- )
   true to host-supports-guest-state				( )
;

\ OBP2 - Set guest state to SIS_TRANSITIONAL/Openboot Running
\ The startup hook is called in the startup command.
defer old-sc-startup-hook ' startup-hook behavior is old-sc-startup-hook
: guest-state-startup-hook ( -- )
   old-sc-startup-hook						( )
   stand-init-completed						( )
   sis-transitional " Openboot Running" set-guest-state drop    ( )
;
' guest-state-startup-hook is startup-hook

\ OBP3 - Set guest state to SIS_TRANSITIONAL/Openboot Primary Boot Loader
\ The boot load hook is called when obp is loading the file to be booted
defer old-sc-$boot-load-hook ' $boot-load-hook behavior is old-sc-$boot-load-hook
: guest-state-$boot-load-hook  ( -- )
   old-sc-$boot-load-hook						 ( )
   sis-transitional " Openboot Primary Boot Loader" set-guest-state drop ( )
;
' guest-state-$boot-load-hook is $boot-load-hook

\ OBP4 - Set guest state to SIS_TRANSITIONAL/Openboot Running UFS Boot
\ The boot hook is called while openboot is booting.
defer old-$boot-hook ' $boot-hook behavior is old-$boot-hook
: guest-state-$boot-hook  ( -- )
   old-$boot-hook				        		( )
   sis-transitional " Openboot Running UFS Boot" set-guest-state drop	( )
;
' guest-state-$boot-hook is $boot-hook


\ OS - Set guest state to SIS_NORMAL/OS Started. No State Support.
\ The boot hook is called when the host os takes over the trap table. If
\ the host has not already indicated to OBP that it supports guest state
\ then the guest state is set to a generic host running state that provides
\ no information about the hosts state.
defer old-guest-state-boot-hook ' guest-state-boot-hook behavior is old-guest-state-boot-hook 
: guest-state-boot ( -- )
   old-guest-state-boot-hook						( )
   host-supports-guest-state 0= if					( )
      sis-normal to stored-host-state					( )
      " OS Started. No state support." 					( addr len )
      stored-host-state-string-ptr swap move				( )
   then
; 
' guest-state-boot is guest-state-boot-hook


\ OBP5 - Set guest state to SIS_TRANSITIONAL/Openboot Running Host Halted 
\ The client exited hook is called when the obp client exited command is
\ called.
defer old-sc-client-exited ' client-exited behavior is old-sc-client-exited
: guest-state-client-exited-hook
   old-sc-client-exited						         ( )	
   sis-transitional " Openboot Running Host Halted" set-guest-state drop ( )
;
' guest-state-client-exited-hook is client-exited


\ OBP6 - Set guest state to SIS_TRANSITIONAL/Openboot Reset Reboot
\ The guest-state-restart-hook is called when OBP does a reset command.
defer old-restart-hook ' restart-hook behavior is old-restart-hook
: guest-state-restart-hook ( -- )
   old-restart-hook							( )
   sis-transitional " Openboot Reset Reboot" set-guest-state drop	( )
   true to is-reset-reboot?						( )
;
' guest-state-restart-hook is restart-hook


\ OBP7 - Set guest state to SIS_TRANSITIONAL/Openboot Exited
\ This hook sets the guest state to OBP exited state when the reset-all
\ command is exicuted unless the reset-all command was executed by the $reset
\ command (the guest state should be reset reboot)
defer old-(reset-all-hook ' (reset-all-hook behavior is old-(reset-all-hook
: guest-state-(reset-all-hook  ( -- )
   old-(reset-all-hook							( )
   is-reset-reboot? 0= if 						( )
      sis-transitional " Openboot Exited" set-guest-state drop		( )
   then
;
' guest-state-(reset-all-hook is (reset-all-hook


\ OBP7 - Set guest state to SIS_TRANSITIONAL/Openboot Exited
\ This hook is called when the poweron command is executed.
defer old-power-off-hook ' power-off-hook behavior is old-power-off-hook
: guest-state-power-off-hook ( -- )
   old-power-off-hook							( )
   sis-transitional " Openboot Exited" set-guest-state drop		( )
;
' guest-state-power-off-hook is power-off-hook


\ OBP9 - Set guest state to SIS_TRANSITIONAL/Openboot Host Broken
\ The reenter hook is called when the host has been broken and control
\ drops back down to OBP. The state is changed to host broken. The 
\ old os state does not need to be saved because the enter cif function
\ already saved the state.
defer old-sc-reenter-hook ' reenter-hook behavior is old-sc-reenter-hook
: guest-state-reenter-hook ( -- )
   old-sc-reenter-hook
   sis-transitional " Openboot Host Received Break" set-guest-state drop 	( )
;
' guest-state-reenter-hook is reenter-hook


\ OBP8 - Set guest state to  SIS_TRANSITIONAL/Openboot Callback
defer old-sc-cif-enter-hook ' cif-enter-hook behavior is old-sc-cif-enter-hook
: guest-state-cif-enter-hook  ( -- )
   old-sc-cif-enter-hook				        ( )
   true to host-state-stored?					( )
   get-guest-state drop to stored-host-state	      		( a-addr )
   stored-host-state-string-ptr max-state-string-len move	( )
   sis-transitional " Openboot Callback" set-guest-state drop	( )
;
' guest-state-cif-enter-hook is cif-enter-hook


\ OBP8 - Set guest state back to saved host guest state
\ The cif exit hook is called while the cif gives control back to the host
defer old-sc-cif-exit-hook ' cif-exit-hook behavior is old-sc-cif-exit-hook
: guest-state-cif-exit-hook  ( -- )
   old-sc-cif-exit-hook						( )
   stored-host-state			        		( state )
   stored-host-state-string-ptr stored-host-string-len		( state a-addr len )
   set-guest-state drop						( )
   false to host-state-stored?					( )
;	
' guest-state-cif-exit-hook is cif-exit-hook


\ OBP9 - Set guest state to saved host guest state
\ When the go command is called the guest state needs to be restored to the
\ value that it was before the host called back into OBP.
chain: go-chain ( -- )
   host-state-stored? if
      stored-host-state				        	( state )
      stored-host-state-string-ptr stored-host-string-len    	( state a-addr len )
      set-guest-state drop					( )
      false to host-state-stored?				( )
   then
;


\ OBP10 - Set guest state to SIS_TRANSITIONAL/Openboot Failed 
\	 or SIS_TRANSITIONAL/Openboot Running
\	 or SIS_TRANSITIONAL/Openboot Running Host Halted
\ When enterforth function is called either a trap has occured
\ First if openboot took a trap before it was initialized then mark as OBP failed
\ Second check to see if OBP was broken. If it was set the guest state to OBP
\ running. If the host had already started booting when a user requested a break in
\ obp then the guest state is set to running host halted.
chain: enterforth-chain  ( -- )
   stand-init-completed? 0= if				       	 	( )
      sis-transitional " Openboot Failed" set-guest-state drop 	 	( )
      exit
   then
   aborted? @ if						  	( )
      already-go? if							( )
         sis-transitional " Openboot Running Host Halted"  		( state addr len )
      else 
         sis-transitional " Openboot Running" 				( state addr len )
      then
      set-guest-state drop						( )
   then
;


\ The standard initialization for the guest state feature includes
\ initializing status variables, allocating space to temporarily save a
\ guest state location, and creating an 32 bit alligned buffer for the
\ guest state h-calls.
stand-init: Guest State Initialization

   max-state-string-len alloc-mem to stored-host-state-string-ptr	( )

   max-state-string-len 2* alloc-mem					( addr )
   max-state-string-len round-up to guest-state-output-buffer-ptr	( )
   guest-state-output-buffer-ptr max-state-string-len erase		( )
   guest-state-output-buffer-ptr >physical drop				( phy )
   to phy-guest-state-output-buffer					( )
   
   max-state-string-len 2* alloc-mem					( addr )
   max-state-string-len round-up to guest-state-input-buffer-ptr	( )
   guest-state-input-buffer-ptr max-state-string-len erase		( )
   guest-state-input-buffer-ptr >physical drop				( phy )
   to phy-guest-state-input-buffer					( )

;

headers
