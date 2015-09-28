\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: probe.fth
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
id: @(#)probe.fth 1.6 07/05/01
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

fload ${BP}/dev/utilities/cif.fth	\ for phandle>devname

h# 100 dup constant MAX-PATH-LEN buffer: path-buf

defer package-to-path  ( len buf phandle -- len' )
0 " package-to-path" do-cif is package-to-path

: phandle>devname  ( phandle -- $path )
   path-buf tuck MAX-PATH-LEN swap rot package-to-path
;

: $=  ( $str1 $str2 -- =? )
   rot tuck =  if  comp 0=  else  3drop false  then
;

0 value builtin-phandle

: init-builtin-drivers  ( -- )
   " /packages/SUNW,builtin-drivers" find-package 0= if
	cmn-error[ " "tCan't find builtin-drivers package" ]cmn-end
        abort
  then
  to builtin-phandle
;

: md-next-fwd  ( node fwd|0 -- entry|0 )
   begin
      over swap md-next-prop dup	( node next )
   while
      dup md-prop-type ascii a = if	( node next )
         dup md-prop-name " fwd" $= if	( node next )
            nip exit			( entry )
         then				( node next )
      then				( node next )
   repeat
   nip					( 0 )
;

: md-applyto-fwds  ( ??? acf node -- ??? )
   0 				        ( ?? acf node 0 )
   begin
      2dup md-next-fwd nip dup		( ?? acf node next-fwd|0 next-fwd|0 )
   while
      dup md-decode-prop drop		( ?? acf node next-fwd fwd-node ) 
      -rot >r >r swap >r r@		( ?? fwd-node acf )
      catch ?dup if   
         r> r> r> 3drop throw
      then
      r> r> r>				( acf node next-fwd )
   repeat   
   3drop				(  )
;

: required-prop  ( node $name type -- val,type | buf,len,type )
   >r 3dup r>				( node $name node $name type )
   md-find-prop ?dup 0= if
      rot md-node-name			( prop-name$ node-name$ )
      cmn-error[ " Missing ""%s"" property in ""%s"" node of " cmn-append 
              " the Machine Description " 
      ]cmn-end				( )
      abort 				( )
   else
      nip nip nip md-decode-prop
   then
;

\ peel the extra 0 off the MD_PROP_DATA version of compatible
: get-compatible-prop ( node -- $compatible | 0 )
   " compatible" -1 md-find-prop dup if 	( entry | 0 ) 
      md-decode-prop ascii d = if  
         1- 
      then
   then
;

: get-cfg-handle  ( node -- cfg-handle )
   " cfg-handle" ascii v required-prop drop
;

\ Cycle through the compatible property looking for a matching driver
: find-fcode-driver  ( node -- acf true | false )
   dup get-compatible-prop ?dup if
      begin 				( node $comp )
         decode-string ?dup		( node $comp' $entry )
      while
         builtin-phandle find-method if	( node $comp acf )
            nip nip nip true exit	( acf true )
         then				( node $comp )
      repeat				( node $comp )
      3drop				( node )
   then

   \ fall back to name property
   " name" -1 md-find-prop dup if
      md-decode-prop drop 		( $name )
      builtin-phandle find-method	( acf,true | false )
   then
;

: load-fcode-driver  ( acf -- )
   catch ?dup if
      cmn-fatal[ " Unable to load FCODE driver" ]cmn-end
   then
;

\ Service channel nodes have a corresponding platform_service node in the MD
: find-platform-service  ( 0 node -- svc-node|0 )
   dup md-node-name " platform_service" $= if
      nip
   else
      drop
   then
;

: svc-channel?  ( md-node -- svc-node|0 )
   0 ['] find-platform-service rot md-applyto-fwds
;

\ Create standard MD based properties for virtual devices with no FCODE driver
: create-standard-props  ( md-node -- )
   dup " name" -1 required-prop drop 	encode-string " name"       property
   dup get-cfg-handle 		 	encode-int    " reg"        property

   get-compatible-prop ?dup if 	 	
	encode-string " compatible" property
   then

;

\ Create service channel specific properties
: create-svc-channel-props  ( svc-node -- )
   dup " flags" ascii v required-prop drop encode-int " flags" 	  property
   dup " mtu"	ascii v required-prop drop encode-int " mtu" 	  property
       " sid"	ascii v required-prop drop encode-int " channel#" property

\ append glvc to the compatible property
   " compatible" get-my-property 0= if
      1- encode-string
   else
      0 0 encode-bytes
   then	
   " glvc" encode-string encode+ " compatible" property
;


\ retrieve the ino property from the node or it's associated service channel
: get-ino-prop  ( node -- prop|0 )
   dup " ino" -1 md-find-prop ?dup 0= if	( node )
      svc-channel? dup if			( node )
         " ino" -1 md-find-prop			( prop|0 )
      then					( prop|0 )
   else						( node prop )
      nip					( prop )
   then						( prop|0 )
;

\ for PROP_VAL  interrupts = 1
\ for PROP_DATA interrupts = vector containing 1-n for each entry in PROP_DATA 
: create-interrupts-prop  ( md-node -- ) 
   get-ino-prop ?dup if 				( prop )
      md-decode-prop ascii v = if	\ PROP_VAL	( val )
         drop 1 encode-int				( str,len )
      else				\ PROP_DATA	( buf,len )
         nip 0 0 encode-bytes				( str',len' )
         rot  /x / 0 ?do
            i 1+ encode-int encode+			( str,len'' )
         loop
      then
      " interrupts" property				(  )
   then
;

\ Create a devalias based on $path,$name.
\ If a devalias '$name' is already present don't create a new one.
: $devalias  ( $path $name -- )
   " /aliases" find-package  if		( $path $name alias-phandle )
      3dup get-package-property if	( $path $name al-ph )
	 my-self >r 0 to my-self	( $path $name al-h )	( r: my-s )
	 push-package			( $path $name )		( r: my-s )
	    property			(  )			( r: my-s )
	 pop-package			(  )			( r: my-s )
	 r> to my-self			(  )
      else				( $path $name al-ph $prop )
	 3drop 3drop drop		(  )
      then				(  )
   else					( $path $name )
      2drop 2drop			(  )
   then					(  )
;

\ If the virtual device node contains a devalias prop, create
\ a devalias pointing to this device with that as the name
\
\ Note: phandle>devname (rather than ihandle>devname) is used so that the
\       devalias doesn't include device arguments.  This is important because
\       MD pointers are passed in as dev-args during probe time.
: create-devalias  ( node -- )
   " devalias" ascii s md-find-prop ?dup if	( prop )
      my-self ihandle>phandle phandle>devname 	( prop $path )
      encode-string rot				( $path prop )
      md-decode-prop drop			( $path $name )
      $devalias					(  )
   then						(  )
;


\ Create virtual device based on an MD node
: create-device-node ( md-node --  )
   dup get-cfg-handle					( node cfg-h )
   over encode-int rot encode-unit			( node $args $reg )
   new-device set-args					( node )
      dup create-interrupts-prop			( node )
      dup find-fcode-driver if				( node )
         dup load-fcode-driver drop			( node )
      else						( node )
         dup create-standard-props			( node )
         dup svc-channel? ?dup if			( node svc-node )
            create-svc-channel-props			( node )
         then						( node )
      then						( node )
      create-devalias					(  )
   finish-device
;

\ Add an entry into nexus's interrupt-map property based on child's MD node.
\ Interrupt map is an array with entries of type:
\ [<child-unit-address> <child-ispec> <iparent.phandle> <iparent.ispec>]
\ 
\ <iparent.ispec> is an integer -> type PROP_VAL  (ino[0]) 
\          or array of integers -> type PROP_DATA (ino[x]) 
\
\               <child-unit-address>      = cfg-handle
\               <child-ispec>             = x + 1
\               <iparent.phandle>         = vnexus phandle
\               <iparent.ispec>           = ino[x]
\

0 value tmp-cfg

: add-interrupt-map-entry ( xdr,len node -- xdr,len' )
   dup get-cfg-handle to tmp-cfg
   get-ino-prop ?dup if
      md-decode-prop ascii v = if \ PROP VAL
         -rot					( ino xdr,len )
         tmp-cfg en+				( ino xdr'len' )
         1 en+					( ino xdr'len' )
         my-interrupt-parent en+		( ino xdr'len' )
         rot en+				( xdr'len' )
      else		\ PROP DATA		( xdr,len data,len )
         0 ?do					( xdr,len data )
            -rot				( data xdr,len )
            tmp-cfg en+				( data xdr',len' )
            i /x / 1+ en+			( data xdr',len' )
            my-interrupt-parent en+		( data xdr',len' )
            2 pick i + x@ en+			( data xdr',len' )
            rot					( xdr',len' data )
         /x +loop				( xdr',len' data )
         drop					( xdr',len' )
      then
   then
;

headers

\ Create children of virtual-devices nexus
: create-virtual-devices ( -- )
   init-builtin-drivers   
   0 " virtual-devices" md-find-node 			( node|0 )
   ?dup if
      ['] create-device-node swap md-applyto-fwds	(  )
   then
;

\ Create children of virtual-devices nexus
: create-channel-devices ( -- )
   init-builtin-drivers   
   0 " channel-devices" md-find-node 			( node|0 )
   ?dup if
      ['] create-device-node swap md-applyto-fwds	(  )
   then
;

\ Create interrupt-map for virtual-devices nexus
: create-interrupt-map  ( -- )
   0 " virtual-devices" md-find-node
   ?dup if
      0 0 encode-bytes rot				( xdr,len node )
      ['] add-interrupt-map-entry swap md-applyto-fwds	( xdr',len' )
      " interrupt-map" property				(  )
   then
;
