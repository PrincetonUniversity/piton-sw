\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: multipath-boot.fth
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
id: @(#)multipath-boot.fth 1.5 07/02/27
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Copyright 2007 Fujitsu Limited.  All Rights Reserved.
copyright: Use is subject to license terms.

\ Multipath boot controlling methods
\ 
\ Boot failure cases:
\
\  OS --+---> cif: boot  --> $reboot-hook : mpb-$reboot-hook
\       |                    Increment boot-device-index when called due to
\       |                    unsuccessful boot. Abort rebooting if all devices
\       |                    have failed in boot-device configuration.
\       |
\       +---> cif: exit  --> client-fail-exited-chain : mpb-fail-exited-chain
\       |                    Increment boot-device-index when called due to
\       |                    unsuccessful boot. Reboot if alternative available
\       |                    devices are left in boot-device configuration.
\       |
\       +---> XIR        --> (arch/sun4ju/error-reset.fth)
\       |
\       +---> error trap --> Degrade and reset
\       |
\       +---> FATAL      --> Clear Reset. SCF might degrade the fault unit.
\       |
\       +---> POFF/PON   --> Clear Reset
\       |
\       +---> hangup     --> SCF might issue XIR
\             +---> XIR        --> (arch/sun4ju/error-reset.fth)


headerless
false value boot-path-specified?

\ Create multipath-boot property in chosen node.
\ This property is created at run time by obp to indicate that 
\ boot device was picked up from "boot-device" config variable 
\ and "multipath-boot?" configuration-variable is currently 
\ set to TRUE.   
: make-multipath-boot-property ( -- )
   " /chosen" find-device
      0 0 encode-bytes " multipath-boot" property
   device-end
;

: no-available-device-error ( -- )
   cmn-error[ " All device paths in boot-device have failed." ]cmn-end
;

: all-devices-failed? ( -- flag )
   boot-device				( adr len )
   count-words boot-device-index <	( flag )
;

\ Indicate if multipath-boot (mpb) is enabled or not.
: mpb-enable? ( -- enable? )
   multipath-boot?			( enable? )
   diagnostic-mode? 0= and		( enable?' )
   boot-path-specified? 0= and		( enabled? )
;

: increment-boot-device-index  ( -- )
   boot-device-index 1+ to boot-device-index
;

: multipath-default-device  ( -- $devname )
   false to boot-path-specified?	(  )
   mpb-enable?				( enable? )
   0= if				(  )
      (default-device)			( devname$ )
      exit				( devname$ )
   then

   boot-device				( devnames$ )
   boot-device-index 0			( devnames$ index 0 )
   ?do					( devnames$ )
      -leading bl left-parse-string	( right$ left$ )
[ifdef] multipath-debug
      ??cr ." skip boot device '" 2dup type ." '" cr
[then]
      2drop				( right$ )
   loop					( devnames$' )

   begin				( devnames$ )
      strip-blanks dup			( devnames$ len )
   while				( devnames$ )
      bl left-parse-string		( right$ left$ )
[ifdef] multipath-debug
      ??cr ." current boot index : " boot-device-index .d
      ."   current boot device '" 2dup type ." '" cr
[then]
      2dup locate-device 0= if		( right$ left$ phandle )
         device-status-ok? if		( right$ left$ )
            2dup open-dev ?dup  if	( right$ left$ ihandle )
               close-dev 2swap 2drop	( left$ )
               \ Create multipath-boot property
               make-multipath-boot-property
               exit			( left$ )
            else
               default-device-hook	( right$ left$ )
            then			( right$ left$ )
         then				( right$ left$ )
      then				( right$ left$ )
      2drop				( right$ )
      increment-boot-device-index	( right$ )
   repeat				( adr 0 )
   2drop				(  )
   no-available-device-error		(  )
   abort
;
' multipath-default-device to default-device

\ Check and detect the multipath boot failure. 
\ Called at: 
\ - rebooting, 
\ - cif "exit", 
\ - error-reset-recovery, and 
\ - the failure case of opening boot-device, and
\ - and case where OBP detects some error but could not identify the
\ faulty device
\ 
\ The multipath boot failure is determined if 
\ - OBP has not relinquished its trap handling to the client program 
\ although we are in process of those methods 
\ AND 
\ if multipath-boot feature is enabled. 
\ 
\ Case caused by command line operation is excluded. 
: multipath-boot-failed? ( -- failed? )
   mpb-enable?				( enable? )
   already-go? and			( failed? )	\ open-dev succeed?
   obp-control-relinquished? 0= and	( failed?' )	\ boot-failed or shutdowned
							\             or not-booted?
   ok-prompt? 0= and			( failed?'')	\ not commandline operation?
;

\ Hook $boot
\   Set boot-path-specified? to default value.
defer old-mpb-$boot-load-hook
' $boot-load-hook behavior is old-mpb-$boot-load-hook 
: mpb-$boot-load-hook ( -- )
   true to boot-path-specified?		\ default setting  
   old-mpb-$boot-load-hook 
;
' mpb-$boot-load-hook is $boot-load-hook

\ Reboot for multipath-boot feature. Ignore path-buf to continue autoboot.
: multipath-force-reboot
   args-buf cscount " " " boot" $restart	(  )
;

\ Common code to detect and recover the multipath boot failure.
\ This code is supposed to be called in 
\ - rebooting via "$reboot", CIF "exit"
\ - error-reset-recovery
\ - the case where load of boot-device fail in "boot-read" or "$boot"
\ - the case where OBP detects some error but could not identify
\   the faulty device.
\ 
\ This code checks if those methods are called due to multipath boot failure.
\ If so, increment boot-device-index. Then, if any other alternative
\ boot-device is present, take the specified action: force the system to
\ reboot so that we can try the next possible boot-device, or to do nothing
\ but exit. If all boot-devices fail, abort to drop at OBP prompt with an
\ error message.
\
: boot-failure-recovery ( force-reboot? -- )
   multipath-boot-failed? 0= if
      drop exit					(  )
   then						(  )
   increment-boot-device-index			( reboot? )
   all-devices-failed? if			( reboot? )
      \ Drop at OBP prompt if all boot-devices fail.
      drop					(  )
      no-available-device-error			(  )
      abort					(  )
   else						( reboot? )
      \ Force reboot if specified.
      \ path-buf will be ignored to continue autoboot.
      if					(  )
         multipath-force-reboot
      then					(  )
   then
;

\ Hook "$reboot", which is called by CIF "boot' and "$load", to check
\ and recover the multipath-boot failure. Even if OBP detects a boot
\ failure and can select alternate device from "boot-device"
\ configuration, this method does nothing but exit. Subsequent
\ "$reboot" code is expected to reboot the system.
defer old-mpb-$reboot-hook
' $reboot-hook behavior is old-mpb-$reboot-hook
: mpb-$reboot-hook
   old-mpb-$reboot-hook
   false boot-failure-recovery
;
' mpb-$reboot-hook is $reboot-hook

\ Called to hook the methods except "$reboot". If OBP detects
\ multipath boot failure and can select alternate device from
\ "boot-device" configuration, force to reboot the system.
: mpb-recovery-with-reboot ( -- )
   true boot-failure-recovery
;
' mpb-recovery-with-reboot is cmn-end-mpb-recovery


\ Hook CIF "exit" to check and recover the multipath-boot failure
\ 
defer old-mpb-fail-exited-chain
: mpb-fail-exited-chain ( -- )
   old-mpb-fail-exited-chain
   mpb-recovery-with-reboot
;

\ Hook CIF "SUNW,set-trap-table" to initialize boot-device-index
\ on a successful boot.
defer old-mpb-starting-chain
: mpb-starting-chain ( -- )
   old-mpb-starting-chain

   \ reset the index value at SUNW,set-trap-table only if it is non-zero
   boot-device-index if
      0 to boot-device-index
   then
;

\ Following hooks must be installed at stand-init, because
\ these chains are initialized to noop at cleanup on make.
stand-init: Install multipath boot hooks
   ['] client-fail-exited-chain behavior is old-mpb-fail-exited-chain
   ['] mpb-fail-exited-chain is client-fail-exited-chain

   ['] client-starting-chain behavior is old-mpb-starting-chain
   ['] mpb-starting-chain is client-starting-chain
;
