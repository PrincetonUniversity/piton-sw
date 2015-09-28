\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: md-iodevice-props.fth
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
id: @(#)md-iodevice-props.fth  1.1  07/06/22
purpose: Apply local mac address properties using devaliases
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless

fload ${BP}/dev/pci/cfgio.fth

d# 256 buffer: pci-string

\ The root pci string's unit address is only the cfg-handle, so return
\ " pci@<cfg-handle>"
: make-root-pci-string ( cfg-handle -- $device-path )
   $pci pci-string 0 $strcat		( cfg-handle $device-path )
   rot (u.) 2swap $strcat		( $device-path' )
;

\ Concatinate the input device string with
\ " pci@<device>,<function" 
: make-pci-string ( $device-path device function -- $device-path' )
   2swap $pci 2swap $strcat 2swap	( $device-path device function )
   >r (u.) 2swap $strcat		( $device-path )( R: function )
   r> ?dup if				( $device-path function| )
      -rot " ," 2swap $strcat		( function $device-path )
      rot (u.) 2swap $strcat		( $device-path )
   then 				( $device-path )
;

\ Compare str2 with str1, and update the flag accordingly
: $compare ( flag str1,len1 str2,len2 -- flag str1,len1 )
   2over $= -rot 2swap or -rot			( flag str1,len1 )
;

\ Compare the 'device-type' property of the input node with the allowable
\ pci bus types and return a flag.
: pcibus? ( node -- flag )
   " device-type" MD_PROP_STR md-find-prop dup if ( prop|0 )
      md-decode-prop drop			( str,len )
      0 -rot					( flag str,len )
      " pcie-switch-upstream" $compare		( flag str,len )
      " pcie-switch-downstream" $compare	( flag str,len )
      " pcie-pcix-bridge" $compare		( flag str,len )
      " pcix-pcix-bridge" $compare		( flag str,len )
      2drop					( flag )
   then						( flag )
;

\ Check to see if the input node is a network device
: network-device? ( node -- flag )
   " device-type" MD_PROP_STR md-find-prop dup if ( prop|0 )
      md-decode-prop drop			( str,len )
      " pci-network" $=				( flag )
   then						( flag )
;

\ All interrupt-map nodes must have a parrent-interrupt property
: interrupt-mapping? ( node -- flag )
   " parent-interrupt" -1 md-find-prop 0<> ( flag )
;

\ All slot-name nodes must have a slot-name property
: slot-name? ( node -- flag )
   " slot-names" MD_PROP_STR md-find-prop 0<>	( flag )
;

\ Extract the device and function numbers from the MD node
: get-md-dev-fcn ( node -- dev# fcn# )
   dup " device-number" md-get-required-prop drop	( node dev# )
   swap " function-number" md-get-required-prop drop	( dev# fcn# )
;

\ Input:
\ phandle - Package handle of parent device tree node
\ dev# - target child device number
\ fcn# - target child function number
\ Oputput:
\ phandle' - Package handle of child device
: find-child-device ( dev# fcn# phandle -- phandle' )
   child dup if						( dev fcn phandle )
      begin						( dev fcn phandle )
         dup if						( dev fcn phandle )
            dup " reg" rot get-package-property drop	( dev fcn phandle reg,len )
            decode-int nip nip				( dev fcn phandle phys.hi )
            2over rot					( dev fcn phandle dev fcn phys.hi )
            tuck cfg>fcn# = -rot cfg>dev# = and 0=	( dev fcn phandle flag )
         else						( dev fcn phandle )
            false					( dev fcn phandle flag )
         then						( dev fcn phandle )
      while						( dev fcn phandle )
         peer						( dev fcn phandle )
      repeat						( dev fcn phandle )
   then							( dev fcn phandle )
   nip nip						( phandle )
;

\ 'prop' is a property to create, 'name' is the name of the property, and 
\ 'phandle' is the device to create the property in.
: set-device-property ( prop,len name,len phandle -- )
   current-device >r	( prop,len name,len phandle )( R: phandle )
   my-self >r		( prop,len name,len phandle )( R: phandle my-self )
   0 to my-self		( prop,len name,len phandle )( R: phandle my-self )
   push-device property (  )
   r> to my-self	(  )( R: phandle )
   r> push-device	(  )( R:  )
;

\ Integers in MD are stored in arrays of 64 bits, encode-int wants 32 bits.
: encode-md-prop-data ( data,len -- prop,len )
   0 0 encode-bytes rot 0 ?do		( data prop,len )
      2 pick i + x@ encode-int encode+	( data prop,len' )
   /x +loop				( data prop,len' )
   rot drop				( prop,len' )
;

\ Creates a property in the package pointed to by phandle if it exists in the 
\ MD node pointed to by node.
: create-optional-property ( phandle node name,len -- )
   2dup >r >r					( phandle node name,len )( R: len name )
   -1 md-find-prop ?dup if			( phandle prop| )
      md-decode-prop case			( phandle [$data | val] )
         MD_PROP_VAL of encode-int endof	( phandle prop,len )
         MD_PROP_STR of encode-string endof	( phandle prop,len )
         MD_PROP_DATA of encode-md-prop-data endof	( phandle prop,len )
         cmn-error[ " Invalid MD property type" ]cmn-end
      endcase					( phandle prop,len )
      rot r> r> rot				( prop,len name,len phandle )( R:  )
      set-device-property			(  )
   else						( phandle )
      r> r> 3drop				(  )( R: )
   then						(  )
;

\ These pci bus node properties are not required, but OpenBoot should create 
\ them if they are present in the MD.
: create-optional-pci-properties ( phandle node -- )
   2dup " interrupts" create-optional-property			( phandle node -- )
   2dup " #interrupt-cells" create-optional-property		( phandle node -- )
   2dup " level2-hotplug-slot-count" create-optional-property	( phandle node -- )
   2dup " level1-hotplug-slot-count" create-optional-property	( phandle node -- )
   " interrupt-map-mask" create-optional-property		(  )
;

\ 'node' will point to an interrupt mapping node as specified by FWARC 2007/070. $path is the 
\ device tree path to create the interrupt mapping properties in.
: create-interrupt-mapping ( $path node -- )
   >r find-package if					( phandle| )( R: node )
      \ If the node already has an interrupt-map property, extend it.
      \ Otherwise, start a new one.
      dup " interrupt-map" rot get-package-property if	( phandle [prop,len| ] )
         0 0 encode-bytes				( phandle prop,len )
      else						( phandle prop,len )
         encode-bytes					( phandle prop,len )
      then						( phandle prop,len )
      r@ " child-unit-address" md-get-required-prop drop ( phandle prop,len prop',len' )
      encode-md-prop-data encode+			( phandle prop,len )
      r@ " child-interrupt" md-get-required-prop	( phandle prop,len [val type] | [buf len type] )
      MD_PROP_VAL = if					( phandle prop,len [val | buf len ] )
         encode-int					( phandle prop,len prop'',len )
      else						( phandle prop,len buf len )
         encode-md-prop-data				( phandle prop,len prop'',len )
      then						( phandle prop,len prop'',len )
      encode+						( phandle prop,len )
      r@ " parent-device-path" md-get-required-prop drop ( phandle prop,len path,len )
      find-package if					( phandle prop,len pphandle| )
         encode-int encode+				( phandle prop,len )
      else						( phandle prop,len )
         cmn-error[ " Interrupt parent device missing" ]cmn-end
      then						( phandle prop,len )
      r@ " parent-interrupt" md-get-required-prop	( phandle prop,len [val type] | [buf len type] )
      MD_PROP_VAL = if					( phandle prop,len [val | buf len ] )
         encode-int					( phandle prop,len prop'',len )
      else						( phandle prop,len buf len )
         encode-md-prop-data				( phandle prop,len prop'',len )
      then						( phandle prop,len prop'',len )
      encode+						( phandle prop,len )
      rot " interrupt-map" rot set-device-property	(  )
   then							(  )
   r> drop						(  )( R: )
;

\ 'node' points to a slot-name MD node, and '$path' points to the device tree path 
\ to create the slot name property in.
: create-slot-name ( $path node -- )
   >r find-package if					( phandle| )( R: node )
      r@ " slot-number" md-get-required-prop drop	( phandle slot-number )
      encode-int					( phandle prop,len )
      r@ " slot-names" md-get-required-prop drop	( phandle prop,len name,len )
      encode-string encode+				( phandle prop,len )
      rot " slot-names" rot set-device-property		(  )
   then							(  )
   r> drop						(  )( R: )
;

\ (apply-md-pci-props) is a recursive function that scans the IO devices in the MD and 
\ populates the OpenBoot device tree nodes with any necessary properties.
defer (apply-md-pci-props)

: ((apply-md-pci-props)) ( $device-path node -- $device-path )
   >r r@ pcibus? if					( $device-path )( R: node )
      2dup						( $device-path $device-path )
      r@ get-md-dev-fcn					( $device-path $device-path dev# fcn# )
      make-pci-string					( $device-path $device-path' )
      2dup find-package if				( $device-path $device-path' phandle )
         r@ create-optional-pci-properties		( $device-path $device-path )
         ['] (apply-md-pci-props)			( $device-path $device-path' acf )
         r@ md-applyto-fwds				( $device-path $device-path' )
      then						( $device-path $device-path )
      2drop						( $device-path )
   then							( $device-path )
   r@ network-device? if				( $device-path )
      2dup find-package if				( $device-path phandle| )
         r@ get-md-dev-fcn				( $device-path phandle dev fcn )
         rot find-child-device ?dup 0= if		( $device-path phandle| )
            r> drop exit				( $device-pah )
         then						( $device-path phandle )
         dup r@ " phy-type" create-optional-property	( $device-path phandle )
         r@ " mac-addresses" MD_PROP_DATA md-find-prop ?dup if ( $device-path phandle prop| )
            over >r md-decode-prop drop	 		( $device-path phandle prop,len )
            2dup encode-bytes " mac-addresses"		( $device-path phandle prop,len prop,len name,len )
            r@ set-device-property			( $device-path phandle prop,len )
            drop 6 encode-bytes " local-mac-address"	( $device-path phandle prop,len name,len )
            r> set-device-property			( $device-path phandle )
         then						( $device-path phandle )
         drop						( $device-path )
      then						( $device-path )
   then							( $device-path )
   r@ interrupt-mapping? if				( $device-path )
      2dup r@ create-interrupt-mapping			( $device-path )
   then							( $device-path )
   r@ slot-name? if					( $device-path )
      2dup r@ create-slot-name				( $device-path )
   then							( $device-path )
   r> drop						( $device-path )( R: )
;

' ((apply-md-pci-props)) is (apply-md-pci-props)

\ Traverse through the root nexus pci devices (the ones that have 
\ direct fwd links off of the phys_io node). These differ from normal pci 
\ device MD nodes since they are unique based on cfg-handle and not on 
\ device,function numbers.
: apply-md-pci-props ( node -- )
   dup " device-type" MD_PROP_STR md-find-prop ?dup if	( node prop| )
      md-decode-prop drop				( node $dev-type )
      " pciex" $= if					( node )
         dup " cfg-handle" md-get-required-prop drop	( node cfg-handle )
         make-root-pci-string				( node $device-path )
         2dup find-package if				( node $device-path phandle| )
            3 pick create-optional-pci-properties	( node $device-path )
            rot ['] (apply-md-pci-props) swap md-applyto-fwds ( $device-path )
         then						( node $device-path )
         2drop						(  )
      else						( node )
         drop 						(  )
      then						(  )
   else							( node )
      drop						(  )
   then							(  )
;

stand-init: Set MD device properties
   0 " phys_io" md-find-node ?dup if		( node|false )
      ['] apply-md-pci-props swap		( acf node )
      md-applyto-fwds				(  )
   then						(  )
;
