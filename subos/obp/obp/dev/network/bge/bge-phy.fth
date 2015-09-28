\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bge-phy.fth
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
id: @(#)bge-phy.fth 1.9 06/08/23
purpose:
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.


headers

0 value  an-debug?

d# 5	constant #rst-retries	\ # of retries to reset phy
create pattern
   h# 5555 w, h# 0005 w, h# 2aaa w, h# 000a w, h# 3456 w, h# 0003 w,
   h# 2aaa w, h# 000a w, h# 3333 w, h# 0003 w, h# 789a w, h# 0005 w,
   h# 5a5a w, h# 0005 w, h# 2a6a w, h# 000a w, h# 1bcd w, h# 0003 w,
   h# 2a5a w, h# 000a w, h# 33c3 w, h# 0003 w, h# 2ef1 w, h# 0005 w,

: phy-macro-done? ( -- flag )
   h# 16 phy@ h# 1000 and 0=
;

: wait-phy-macro-done ( -- flag )
   d# 100 ['] phy-macro-done? wait-status
;

\ Put PHY in loopback mode temporarily to bring the link down
: force-link-down ( -- )
   phy-cr@  phycr.loopback or  phy-cr!
   d# 1000 ms
   phy-cr@  phycr.loopback invert and phy-cr!
;

: phy-reset-complete? ( -- flag )   phy-cr@ phycr.reset and 0= ;

: wait-phy-reset ( -- flag )   
   d# 700 ['] phy-reset-complete?  wait-status 
;

\ This code is taken from a recommendation by Broadcom on
\ how to reset the PHY and check for a failed reset
\ condition that can occur occasionally, if such a condition
\ is detected then retry the reset for a pre-determined
\ number of iterations

: pattern@ ( index set# -- val )
   6 * + /w * pattern + w@
;

: (reset-transceiver-once) ( -- ok? )
   \ issue a phy reset, and wait for reset to complete
   phy-cr@ phycr.reset or phy-cr!		( )
   wait-phy-reset drop				( )
   \ now go check the DFE TAPs to see if locked up, but
   \ first, we need to set up PHY so we can read DFE TAPs
   \ Disable Transmitter and Interrupt, while we play with
   \ the PHY registers, so the link partner won't see any
   \ strange data and the Driver won't see any interrupts.
   h# 10 phy@ h# 3000 or h# 10 phy!		( )
   \ Setup Full-Duplex, 1000 mbps
   h# 140 phy-cr!				( )
   \ Set to Master mode
   h# 1800 9 phy!				( )

   \ ADC and Gamma fixes only apply to Ax revisions
   \ not Bx revisions, so check that relevant part
   \ of revision id is 0
   pci-rev-id h# f00 and 0= if
      \ ADC fix
      \ Enable SM_DSP_CLOCK & 6dB
      h# c00 h# 18 phy!				( )
      \ work-arounds
      h# 201f h# 17 phy!			( )
      h# 2aaa h# 15 phy!			( )

      \ Gamma fix
      h#    a h# 17 phy!			( )
      h#  323 h# 15 phy!			( )
   then

   \ blocks the PHY control access
   h# 8005 h# 17 phy!				( )
   h# 800 h# 15 phy!				( )
   \ check TAPs for all 4 channels, as soon
   \ as we see a lockup we'll stop checking
   4 0 do					( )
      \ select channel and set TAP index to 0
      i h# 2000 * h# 200 or h# 17 phy!		( )
      \ freeze filter again just to be safe
      2 h# 16 phy!				( )
      \ write fixed pattern to the RAM, 3 TAPs for
      \ each channel, each TAP have 2 WORDs (LO/HI)
      6 0 do					( )
         i j pattern@ h# 15 phy!		( )
      loop					( )
      \ Active PHY's Macro operation to write DFE TAP from RAM,
      \ and wait for Macro to complete
      h# 202 h# 16 phy!				( )
      wait-phy-macro-done drop			( )
      \ --- done with write phase, now begin read phase ---
      \ select channel and set TAP index to 0
      i h# 2000 * h# 200 or h# 17 phy!		( )
      \ Active PHY's Macro operation to load DFE TAP to RAM,
      \ and wait for Macro to complete
      h# 82 h# 16 phy!				( )
      wait-phy-macro-done drop			( )
      \ enable "pre-fetch"
      h# 802 h# 16 phy!				( )
      wait-phy-macro-done drop			( )
      \ read back the TAP values
      \ 3 TAPs for each channel, each TAP have 2 WORDs (LO/HI)
      6 0 do					( )
         \ read Lo/Hi then wait for 'done' is faster
         \ For DFE TAP, the HI word contains 6 bits,
         \ LO word contains 15 bits
         h# 15 phy@ h# 7fff and			( dataLo )
         h# 15 phy@ h# 3f and			( dataLo dataHi )
         wait-phy-macro-done drop		( dataLo dataHi )
         \ check if what we wrote is what we read back
         i 1+ j pattern@ = swap			( hiMatch? dataLo )
         i j pattern@ =				( hiMatch? loMatch? )
         and 0= if				( )
            \ if failed, then the PHY is locked up,
            \ we need to do PHY reset again
            unloop unloop false exit		( false )
         then					( )
      2 +loop					( )
   loop						( )
   true						( true )
;

: (reset-transceiver-special) ( -- ok? )
   false
   #rst-retries 0 do
      (reset-transceiver-once) if	( false )
         drop true leave		( true )
      then				( false )
   loop					( ok? )
   \ remove block phy control
   h# 8005 h# 17 phy!			( ok? )
   0 h# 15 phy!				( ok? )
   \ unfreeze DFE TAP filter for all channels
   h# 8200 h# 17 phy!			( ok? )
   0 h# 16 phy!				( ok? )
   \ Restore PHY back to operating state
   h# 400 h# 18 phy!			( ok? )
   \ enable transmitter and interrupt
   h# 10 phy@ h# cfff and h# 10 phy!	( ok? )
;

: (reset-transceiver-generic) ( -- ok? )
   phy-cr@ phycr.reset or phy-cr!   
   wait-phy-reset
;

\ return true if BCM5704C rev < B0
: bcm5704c<revb0?  ( -- flag )
   pci-dev-id BCM-5704 =
   pci-rev-id h# f00 and 0= and
;

: (reset-transceiver) ( -- ok? )
   pci-dev-id BCM-5703 =
   pci-dev-id BCM-5703a = or
   bcm5704c<revb0? or if    		\ The 5703 and 5704 (revs less than
                                        \ B0) need a non-default method to
                                        \ reset the phy
                                        \ NB: 5702/5705 are not supported.
      (reset-transceiver-special)
   else
      (reset-transceiver-generic)
   then
;

: reset-transceiver ( -- ok? )
   d# 15000 get-msecs +  false
   begin
      over timed-out? 0=  over 0=  and
   while
      (reset-transceiver)  if  drop true  then
   repeat  nip
   dup 0=  if  ." Failed to reset transceiver!" cr  exit  then
   phy-cr@ phycr.speed-100 invert and  phycr.duplex invert and phy-cr!
;

: disable-auto-nego ( -- )
   an-debug?  if ." Disabling Autonegotiation" cr then 
   phy-cr@  phycr.an-enable invert and phy-cr!
;

: enable-auto-nego ( -- )
   an-debug?  if  ." Enabling Autonegotiation" cr  then 
   phy-cr@ phycr.an-enable phycr.an-restart or  or phy-cr!
;

: an-link-speed&mode ( -- speed duplex-mode )

   phy-sr@  physr.ext-status and  if
      phy-1000-sr@  h# c00 and d# 10 rshift
      phy-1000-cr@  h# 300 and d#  8 rshift and     ( 1000bt-common-cap )
      d# 10 lshift
      dup gsr.lp-1000fdx  and  if  drop 1000Mbps full-duplex  exit  then
          gsr.lp-1000hdx  and  if       1000Mbps half-duplex  exit  then
   then

   phy-anlpar@ phy-anar@ and           ( an-common )
   dup anlpar.100fdx and  if  drop 100Mbps full-duplex  exit  then
   dup anlpar.100hdx and  if  drop 100Mbps half-duplex  exit  then
   dup anlpar.10fdx  and  if  drop 10Mbps  full-duplex  exit  then
   dup anlpar.10hdx  and  if  drop 10Mbps  half-duplex  exit  then
;

: supported-speed&mode  ( speed mode$ -- bit-mask )
   rot case
      10Mbps   of
         " half" $= if h# 1 else h# 2 then
      endof
      100Mbps  of
         " half" $= if h# 4 else h# 8 then
      endof
      1000Mbps  of
         " half" $= if h# 10 else h# 20 then
      endof
      ( default ) 0
   endcase
;

: parse-supported-abilities ( str$ -- abilities )
   base @ >r decimal
   ascii , left-parse-string 2drop
   ascii , left-parse-string $number drop -rot  ( speed str$ )
   ascii , left-parse-string 2drop		( speed mode$ )
   supported-speed&mode				( bit-mask )
   r> base !
;

: get-supported-abilities  ( phy-abilty -- phy-abilty | abilty )
   " supported-network-types" get-my-property 0= if
      begin 
         decode-string ?dup 
      while					( phy-abilty str1$ str2$ )
         parse-supported-abilities		( phy-abilty str1$ mask )
         3 roll swap xor -rot			( mask' str1$ )
      repeat 3drop				( mask' )
      invert h# 3f and				( abilty )
   then
;

: phy-abilities ( -- abilities )
   phy-sr@ d# 11 rshift h# f and
   gmii-phy? if  phy-esr@ d# 12 rshift h# 3 and  else  0  then d# 4 lshift or
   ( phy-abilty )  get-supported-abilities	( abilities )
;

\ Construct bit-mask abilities based on speed, duplex mode settings
\       0000.0001     10Mbps, Half Duplex
\       0000.0010     10Mbps, Full Duplex
\       0000.0100    100Mbps, Half Duplex
\       0000.1000    100Mbps, Full Duplex
\       0001.0000   1000Mbps, Half Duplex
\       0010.0000   1000Mbps, Full Duplex
: construct-abilities ( speed duplex-mode -- abilities )
   phy-abilities
   swap case
      half-duplex of   h# 15  endof     \ Mask FDX abilities
      full-duplex of   h# 2a  endof     \ Mask HDX abilities
      auto-duplex of   h# 3f  endof
   endcase and
   swap case
      10Mbps      of   h# 3   endof
      100Mbps     of   h# c   endof
      1000Mbps    of   h# 30  endof
      auto-speed  of   h# 3f  endof
   endcase and
;

: publish-capabilities ( -- )

   user-speed user-duplex  construct-abilities                  ( abilities )
   dup h# f  and d# 5 lshift h# 1 or  phy-anar!                     \ anar[8:5]
   gmii-phy?  if                                                ( abilities )
      h# 30 and  d# 4 lshift                                    ( 1000-cap )
      user-link-clock auto-link-clock <>  if
         gcr.ms-cfg-enable or
         user-link-clock master-link-clock =  if
            gcr.ms-cfg-value or
         then
      then
      phy-1000-cr!
   else                                                         ( abilities )
      drop                                                      ( )
   then                                                         ( )
;

: match-capabilities ( -- ok? )
   phy-sr@  physr.ext-status and  if
      phy-1000-sr@ h# c00 and  d# 10 rshift
      phy-1000-cr@ h# 300 and  d#  8 rshift
      and 0<>
   else
      0
   then
   phy-anlpar@ phy-anar@ and 0<> or
;

\ Autonegotiation may take as much as 5 seconds with 10/100 BaseT PHYs 
: wait-autoneg-complete ( -- complete? )
   d# 5000 get-msecs +  false
   begin
      over timed-out? 0=
      over 0= and
   while
      d# 20 ms
      phy-sr@  physr.an-complete and  if
         drop true
      then
   repeat nip
;

: phy-link-up? ( -- up? )  
   phy-sr@  drop
   phy-sr@  physr.link-up and 
;

: link-up? ( -- flag )  phy-link-up? ;

: wait-link-up? ( -- up? )
   wait-phy-reset drop
   d# 2000 ['] phy-link-up? wait-status
;

: (autonegotiate) ( -- link-up? )

   \ Advertise my capabilities & start auto negotiation
   publish-capabilities
   enable-auto-nego

   \ Wait for auto negotiation to complete
   wait-autoneg-complete
   0=  if
      ." Timed out waiting for Autonegotiation to complete" cr
      false exit
   then

   \ Check if autonegotiation completed by parallel detection,
   \ and if so, whether there are any parallel detect (multiple
   \ link fault) errors
   phy-aner@  dup aner.lp-an-able and 0=  swap aner.mlf and  and if
      ." Multiple link faults seen during Autonegotiation" cr
      false exit
   then

   \ Check for common capabilities
   match-capabilities 0=  if
      ." System and network incompatible for communicating" cr
      false exit
   then

   \ Valid Link established?
   phy-link-up?  
;

: do-autonegotiation ( -- link-up? )
   (autonegotiate)  if
      an-link-speed&mode  set-chosen-speed&duplex
      true
   else
      ." Check cable and try again" cr
      false
   then
;

: check-phy-capability ( -- )
   user-speed user-duplex 2dup construct-abilities 0=  if 
      ." Not capable of " .link-speed,duplex 
      -1 throw
   else
      2drop
   then
;

\ Set/Force link speed and mode, and check link status
\ For 1Gbps, we manually configure local PHY as SLAVE
: speed&mode-possible? ( speed duplex-mode -- link-up? )
   over 1000Mbps =  if
      phy-1000-cr@ h# 1800 invert and h# 1000 or  phy-1000-cr!
   then 
   phy-cr@  b# 0010.0001.0100.0000 invert and  \ Mask speed & duplex bits
   swap  full-duplex =  if  phycr.duplex or then
   swap  case
      10Mbps    of   phycr.speed-10    endof
      100Mbps   of   phycr.speed-100   endof
      1000Mbps  of   phycr.speed-1000  endof
   endcase  or
   phy-cr!
   wait-link-up?
;


: set-speed&mode ( -- link-up? )
   disable-auto-nego
   force-link-down
   user-speed user-duplex
   2dup speed&mode-possible?  if  set-chosen-speed&duplex true exit  then
   over 1000Mbps =  if
      ." Cannot bringup link using non-autonegotation." cr
      ." Force link partner to " .link-speed,duplex ." as link-clock "
      user-link-clock master-link-clock =  if
         ." slave"
      else
         ." master"
      then  
      cr -1 throw
   then
   2drop false
;

\ Use non-autonegotiation only is both speed & duplex modes are specified
: use-autonegotiation? ( -- flag )
   user-speed auto-speed =  user-duplex auto-duplex =  or if
     true exit
   then
   user-speed 1000Mbps = if
     user-link-clock auto-link-clock =
   else
     false
   then
;

: show-link-status ( -- )
   phy-link-up?  if
      chosen-speed chosen-duplex  .link-speed,duplex  ."  Link up"
   else
      ." Link Down"
   then cr
;

: disable-link-events  ( -- )
   pci-dev-id BCM-5704 =		\ Rev a0 of the 5704 needs non-default
   pci-rev-id 0= and if			\ timing.
      h# 8d68 h# 1c phy!		\ bcm5704 PHY-MAC timing reg
      h# 8d68 h# 1c phy!		\ needs to be written twice to stick
   then
   0		h# 6844	breg!	\ Make sure we're in auto-access mode
   h# 18	h# 404	breg-bset \ Clear Link Attentions (Enet MAC Status Reg)
   h# c0000	h# 454	breg-bset \ Disable auto polling (MI Mode Reg)
   1 ms				\ wait 40 us
   2 h# 18 phy!			\ Disable Wake on Lan
   h# 1a phy@ drop		\ Read MDI Interrupt_Status Reg twice 
   h# 1a phy@ drop		\ to clear sticky bits
   h# fffd h# 1b phy!		\ mask all interrupts except Link Status Change
;


: setup-transceiver ( -- ok? )
   reset-transceiver drop
   disable-link-events		\ Should be turned off by reset but...
   check-phy-capability
   use-autonegotiation? if  do-autonegotiation  else  set-speed&mode  then
   show-link-status
;
