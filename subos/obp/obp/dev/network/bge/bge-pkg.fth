\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: bge-pkg.fth
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
id: @(#)bge-pkg.fth 1.6 06/07/14
purpose: Routines defining the interface to the driver 
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headers

0 instance value obp-tftp

: init-obp-tftp ( tftp-args$ -- okay? )
   " obp-tftp" find-package  if  
      open-package  
   else  
      ." Can't open OBP standard TFTP package"  cr
      2drop 0  
   then
   dup to obp-tftp
;

: (setup-link) ( -- link-up? )
   net-on  if
      setup-transceiver if
         configure-mac true exit
      then
   then false
;

: setup-link ( -- [ link-status ] error? ) 
   int-loopback loopback-test  if  ['] (setup-link) catch  else  true  then
;

: bringup-link ( -- ok? )
   d# 20000 get-msecs +  false
   begin
      over timed-out? 0=  over 0=  and
   while
      setup-link  if  2drop false exit  then    ( link-up? )
      if 
         drop true
      else
         " Retrying network initialization"  diag-type-cr
      then
   repeat nip
;

external

: close	 ( -- )
   obp-tftp ?dup  if  close-package  then
   breg-base  if  net-off unmap-resources  then
;

: open  ( -- flag )
   map-resources
   my-args parse-devargs
   init-obp-tftp 0= if  unmap-resources false exit  then
   bringup-link ?dup 0=  if  close false exit  then
   mac-address encode-bytes  " mac-address" property
;

headers

: bge-xmit  ( buffer length -- #sent )
   link-up? 0=  if
      " Link is down. Restarting network initialization" diag-type-cr
      restart-net if
          2drop 0 exit
      then
   then                                                  ( buffer len )
   get-tx-buffer swap                                    ( buffer txbuf len )
   2dup >r >r cmove r> r>                                ( txbuf len )
   tuck                                                  ( len txbuf len )
   d# 64  max						 ( len txbuf len' )
   transmit 0=  if  drop 0  then                         ( #sent )
;

: bge-poll  ( buffer len -- #rcvd )
   receive-ready?  0=  if  
      2drop 0 exit  
   then
   receive ?dup  if                           ( buffer len handle pkt pktlen )
      rot >r rot min >r swap r@ cmove r> r>   ( #rcvd handle ) 
   else                                       ( buffer len handle pkt )
      drop nip nip 0 swap                     ( 0 handle )
   then
   return-buffer    
;

external

: read  ( buf len -- -2 | actual-len )
   bge-poll  ?dup  0=  if  -2  then
;

: write  ( adr len -- len' )
   bge-xmit
;

: load  ( adr -- size )
   " load" obp-tftp $call-method 
;

: watch-net
   map-resources
   my-args parse-devargs 2drop         ( )
   promiscuous to mac-mode
   setup-link 0=  if                   ( link-up? )
      if  watch-test  then
   then
   net-off
   unmap-resources
;

headers

: reset  ( -- )
   breg-base  if \ #### Maybe get rid of this functionality?
      net-off unmap-resources
   else
      map-regs net-off unmap-regs
   then
;

\ On some platforms, onboard network controllers may carry their
\ own MAC address (like plugin cards). For those platforms the
\ MAC address is automatically loaded into MAC Address Hi (0x410)
\ and MAC Address Lo (0x414) registers at poweron/reset time.
\ The following code reads the MAC address from MAC Address Hi/Lo
\ registers and populates the local-mac-address property in the 
\ network node.

[ifdef] USE-MAC-ADDR-REGS

6 buffer: my-local-mac

\ Check if the hi and lo values are both 0 or both 0xffffffff
\ If either case is true, the value of hi and lo is invalid
\ MAC address is 6 bytes. When checking for hi value, we only
\ check the 2 valid bytes.
\                 31             00
\ Format of lo :  [lo0:lo1:lo2:lo3]
\ Format of hi :  [hi0:hi1:XXX:XXX]

: mac-addr=0? ( lo hi  -- flag )
   h# ffff not and or 0=
;
: mac-addr=ff? ( lo hi -- flag )
   h# ffff or and h# ffffffff =
;
: valid-mac-addr? ( lo hi -- flag )
   2dup mac-addr=0? -rot mac-addr=ff? or not
;

\ Create local-mac-address property from hi and lo values read
\ from the registers
: create-local-mac-address ( hi lo -- )
   lbsplit                 ( hi lo0 lo1 lo2 lo3 )
   my-local-mac 5 + c!
   my-local-mac 4 + c!
   my-local-mac 3 + c!
   my-local-mac 2 + c!
   lbsplit                 ( hi0 hi1 hi2 hi3 )
   my-local-mac 1 + c!
   my-local-mac 0 + c!     ( hi0 hi1 )
   2drop                   (  )
   my-local-mac 6 encode-bytes " local-mac-address" property
;

: populate-local-mac-addr  ( -- )
   map-regs                             (  )
   reset-core-clks 100 ms               (  )
   restore-pci-regs                     (  )
   h# 410 breg@ h# 414 breg@            ( hi lo )
   2dup swap valid-mac-addr? if         ( hi lo )
      create-local-mac-address          (  )
   else
      2drop                             (  )
   then
   unmap-regs
;

populate-local-mac-addr

[then]
