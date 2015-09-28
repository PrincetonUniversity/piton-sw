\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: pkg.fth
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
id: @(#)pkg.fth 1.5 07/06/22
purpose: Intel Ophir/82571 external interface
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless
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
      setup-transceiver 		( link-up? )
   else
      false				( link-up? )
   then
;

\ Needed?
: (restart-net) ( -- link-up? )  
   false to restart?
   (setup-link)
;

['] (restart-net) to restart-net

: setup-link ( -- [ link-status ] error? ) 
   ['] (setup-link) catch
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
   reg-base  if  net-off unmap-resources  then
;

: open  ( -- flag )
   map-resources
   my-args parse-devargs
   init-obp-tftp 0= if  close false exit  then
   bringup-link ?dup 0=  if  close false exit  then
   publish-properties
   mac-address encode-bytes  " mac-address" property
;

headers

depend-load SUN4V ${BP}/dev/sun4v-devices/utilities/md-parse.fth
depend-load SUN4V ${BP}/dev/pci/cfgio.fth
depend-load SUN4V ${BP}/dev/utilities/strings.fth

[ifdef] SUN4V
defer package-to-path  0 " package-to-path" do-cif is package-to-path

d# 256 buffer: path-buf

\ create a packed string that contains the current node's device-path
\ the unit address must me manually added because it's not available
\ at probe time.
: make-path ( -- )
   path-buf 0 over c!					( buf )
   d# 255 over 1+					( buf len buf' )
   my-self ihandle>phandle package-to-path		( buf len' )
   \ then add unit address
   1+ 2dup + ascii @ swap c!				( buf len'' )
   0 0 my-space " encode-unit" $call-parent		( buf len'' $unit )
   2over + 1+ swap dup >r move r> +			( buf len''' )
   swap c!						(  )
;

: $path ( -- str,len ) path-buf count ;

6 constant /lcl-mac-buf
/lcl-mac-buf buffer: lcl-mac-buf

0 value done?

\ convert the mac-address (if available) to a byte stream
: get-mac-address  ( node --  )
   " mac-addresses" ascii d md-find-prop ?dup if		( prop| )
      md-decode-prop 2drop					( mac-addr )
      lcl-mac-buf /lcl-mac-buf move true to done?		(  )
   then								(  )
;

h# 256 buffer: pci-string

: $pci ( -- str,len ) " /pci@" ;
: $network ( -- str,len ) " /network@" ;

: make-root-pci-string ( cfg-handle -- $device-path )
   $pci pci-string 0 $strcat
   rot (u.) 2swap $strcat
;

: (make-pci-string) ( device function $device-path $suffix -- $device-path' )
   2swap $strcat 2swap			( $device-path device function )
   >r (u.) 2swap $strcat		( $device-path )( R: function ) 
   r> ?dup if				( $device-path function| )
      -rot " ," 2swap $strcat		( function $device-path )
      rot (u.) 2swap $strcat		( $device-path )
   then 				( $device-path )
;

: make-pci-string ( $device-path device function -- $device-path' )
   2swap $pci (make-pci-string)
;

: make-network-string ( $device-path device function -- $device-path' )
   2swap $network (make-pci-string)
;

: $compare ( flag str1,len1 str2,len2 -- flag str1,len1 )
   2over $= -rot 2swap or -rot
;

\ Flag to determine if the input MD node is a PCI bus type device.
: pcibus? ( node -- flag )
   " device-type" ascii s md-find-prop dup if	( prop|0 )
      md-decode-prop drop			( $device-type )
      0 -rot					( flag $device-type )
      " pcie-switch-upstream" $compare		( flag $device-type )
      " pcie-switch-downstream" $compare	( flag $device-type )
      " pcie-pcix-bridge" $compare		( flag $device-type )
      " pcix-pcix-bridge" $compare		( flag $device-type )
      2drop					( flag )
   then						( flag )
;

\ Flag to determine if the input MD node is a network device.
: network-device? ( node -- flag )
   " device-type" ascii s md-find-prop dup if	( prop|0 )
      md-decode-prop drop			( $device-type )
      " pci-network" $=				( flag )
   then						( flag )
;

\ Returns the device and function number of the input MD node
: get-md-dev-fcn ( node -- dev# fcn# )
   dup " device-number" md-get-required-prop drop	( node dev# )
   swap " function-number" md-get-required-prop drop	( dev# fcn# )
;

\ (fill-mac-buf) is a recursive function that parses the MD looking for the correct 
\ node associated with this device tree node instance. Once it finds the MD node, 
\ the method extracts the 'mac-addresses' property and fills the mac buffer with the 
\ first entry (which will become the local-mac-address for this node). 
: (fill-mac-buf) ( $device-path node -- $device-path )
   recursive
   >r r@ pcibus? done? 0= and if	( $device-path )( R: node )
      2dup				( $device-path $device-path )
      r@ get-md-dev-fcn			( $device-path $device-path dev# fcn# )
      make-pci-string			( $device-path $device-path' )
      ['] (fill-mac-buf)		( $device-path $device-path' acf )
      r@ md-applyto-fwds		( $device-path $device-path' )( R: )
      2drop				( $device-path )
   then					( $device-path )
   r@ network-device? if		( $device-path )
      2dup				( $device-path $device-path )
      r@ get-md-dev-fcn			( $device-path $device-path dev# func# )
      make-network-string		( $device-path $device-path' )  
      $path				( $device-path $device-path' $device-path'' )
      $= if				( $device-path flag )
         r@ get-mac-address		( $device-path )
      then				( $device-path )
   then					( $device-path )
   r> drop				( $device-path )( R: )
;

\ 'node' should point to the phys_io node in the MD. This function will scan 
\ through all children looking for the local-mac-address to fill the mac buffer
: fill-mac-buf ( node -- )
   dup " device-type" ascii s md-find-prop ?dup if	( node prop| )
      md-decode-prop drop				( node $dev-type )
      " pciex" $= if					( node )
         dup " cfg-handle" ascii v md-find-prop	( node prop )
         md-decode-prop drop				( node cfg-handle )
         make-root-pci-string				( node $device-path )
         rot ['] (fill-mac-buf) swap md-applyto-fwds	( $device-path )
         2drop						(  )
      else						( node )
         drop 						(  )
      then						(  )
   else							( node )
      drop						(  )
   then							(  )
;

\ Returns a buffer that contains the local-mac-address for this node
: find-my-mac-addr  ( -- buf | 0 )
   make-path
   lcl-mac-buf /lcl-mac-buf erase
   0 to done?
   0 " phys_io" md-find-node ?dup if		( node|false )
      ['] fill-mac-buf swap			( acf node )
      md-applyto-fwds				(  )
   then						(  )
   done? if					(  )
      lcl-mac-buf				( buf )
   else						(  )
      false					( 0 )
   then						(  )
;

\ The following code compares the MAC address assigned by the system
\ to the MAC address programmed in the Ophir EEPROM. This step is 
\ required because Intel reloads the MAC addresses from the EEPROM 
\ when the controler is reset (going into loopback mode during SunVTS 
\ for example) so we have to make sure the EEPROM matches what we 
\ assign the device
: update-mac-address ( -- )
   find-my-mac-addr ?dup if
      map-resources			( mac-adr-ptr )
      dup w@ wbflip >r			( mac-adr-ptr )( R: mac0 )
      dup 2 + w@ wbflip >r		( mac-adr-ptr )( R: mac0 mac1 )
      4 + w@ 1 invert and wbflip r> r>	( mac2' mac1 mac0 )
      3dup false			( mac2' mac1 mac0 mac2' mac1 mac0 flg )
      swap 0 eeprom-w@ <> or		( mac2' mac1 mac0 mac'2 mac1 flag )
      swap 1 eeprom-w@ <> or		( mac2' mac1 mac0 mac2' flag )
      swap 2 eeprom-w@ <> or if		( mac2' mac1 mac0 )
	 0 eeprom-w! 1 eeprom-w!	( mac2' )
	 2 eeprom-w! checksum		( checksum )
	 h# 3f eeprom-w!		(  )
      else				( mac2' mac1 mac0 )
	 3drop				(  )
      then				(  )
      unmap-resources			(  )
   else
      cmn-warn[ " Missing network-vpd MD node " ]cmn-end
   then
;

update-mac-address

[else]
\ The following code compares the MAC address assigned by the system
\ to the MAC address programmed in the Ophir EEPROM. This step is 
\ required because Intel reloads the MAC addresses from the EEPROM 
\ when the controler is reset (going into loopback mode during SunVTS 
\ for example) so we have to make sure the EEPROM matches what we 
\ assign the device
: update-mac-address ( -- )
   map-resources			(  )
   " local-mac-address" 		( propstr,len )
   get-my-property 2drop		( mac-adr-ptr )
   dup w@ wbflip >r			( mac-adr-ptr )( R: mac0 )
   dup 2 + w@ wbflip >r			( mac-adr-ptr )( R: mac0 mac1 )
   4 + w@ 1 invert and wbflip r> r>	( mac2' mac1 mac0 )
   3dup false				( mac2' mac1 mac0 mac2' mac1 mac0 flag )
   swap 0 eeprom-w@ <> or		( mac2' mac1 mac0 mac'2 mac1 flag )
   swap 1 eeprom-w@ <> or		( mac2' mac1 mac0 mac2' flag )
   swap 2 eeprom-w@ <> or if		( mac2' mac1 mac0 )
      0 eeprom-w! 1 eeprom-w!		( mac2' )
      2 eeprom-w! checksum		( checksum )
      h# 3f eeprom-w!			(  )
   else					( mac2' mac1 mac0 )
      3drop				(  )
   then					(  )
   unmap-resources			(  )
;

update-mac-address

[then]

: xmit  ( buffer length -- #sent )
   link-up? 0=  if
      \ >>> cmn-xxx
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

: poll  ( buffer len -- #rcvd )
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
   poll  ?dup  0=  if  -2  then
;

: write  ( adr len -- len' )
   xmit
;

: load  ( adr -- size )
   " load" obp-tftp $call-method 
;

: watch-net  ( -- )
   map-resources
   my-args parse-devargs 2drop		( )
   promiscuous to mac-mode
   bringup-link				( ok? )	
   if  watch-test  then
   net-off
   unmap-resources
;

headers

: reset  ( -- )
   reg-base  if
      net-off unmap-resources
   else
      map-regs net-off unmap-regs
   then
;
