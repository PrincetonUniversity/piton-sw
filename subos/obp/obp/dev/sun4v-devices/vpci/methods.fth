\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: methods.fth
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
id: @(#)methods.fth 1.6 07/06/22
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless

h# ff.ff00 constant pci-device-mask	\ pci device is   00000000.bbbbbbbb.dddddfff.00000000
h# fff     constant pci-reg-mask	\ pci register is 00000000.00000000.0000rrrr.rrrrrrrr

: config-@ ( phys.hi size -- data )
   dup rot dup pci-device-mask and swap		( size size pci-device phys.hi )
   phys.hi>cfg-offset pci-reg-mask and rot	( size pci-device offset size )
   pci-config-get 0<> if			( size data )
      drop					( size )
      \ 1 -> 0xff, 2 -> 0xffff, 4 -> 0xffff.ffff
      0 swap 8 * 0 do h# ff i << or 8 +loop	( data )
   else						( size data )
      nip					( data )
   then						( data )
;

: config-! ( data phys.hi size  -- ) 
   rot >r >r dup pci-device-mask and swap	( pci-device phys.hi )( R: data size )
   phys.hi>cfg-offset pci-reg-mask and r> r>	( pci-device offset size data )
   pci-config-put drop				(  )
;

external

: config-b@ ( phys.hi -- b ) 1 config-@ ;
: config-b! ( b phys.hi -- ) 1 config-! ;
: config-w@ ( phys.hi -- w ) 2 config-@ ;
: config-w! ( w phys.hi -- ) 2 config-! ;
: config-l@ ( phys.hi -- l ) 4 config-@ ;
: config-l! ( l phys.hi -- ) 4 config-! ;

: decode-unit ( adr len -- phys.lo phys.mid phys.hi )
   pci-decode-unit lwsplit drop  my-pci-bus  wljoin
;

: encode-unit  ( phys.lo phys.mid phys.hi -- adr len ) pci-encode-unit ;

: map-in ( p.low p.mid p.hi len -- vaddr ) pci-map-in ;
: map-out ( va len -- ) " map-out" $call-parent ;

variable my-memlist  my-memlist off
variable my-mem64list  my-mem64list off
variable my-io-list  my-io-list off

\ get-package-property for boolean property in
\ /options node returns value instead of adr,len 
\ as defined by IEEE.
" /options" find-package drop			( phandle )
" pci-mem64?" rot get-package-property if 
   false
then						( flag )
to mem64-support?		\ This flag needs to be set true for
				\ host-bridge that support mem64 space.

: allocate-bus# ( n mem-aln mem-sz mem64-aln mem64-sz io-aln io-sz -- . . . . . . . )
                      ( . . . . . -- mem-l mem64-l io-l dma-l mem-h mem64-h io-h dma-h bus# )
   pci-allocate-bus#
; 
: assign-int-line ( int phys.hi -- false )		2drop false  ;
: prober ( adr len -- )					pci-prober  ;

0 value current-md-node

\ 0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f,10,11,12,13,14,15,16,17,18,19,1a,1b,1c,1d,1e,1f
\ is 0x50 bytes
h# 50 constant /pci-probe-path-buffer

: get-node-dev-fcn ( nptr -- dev fcn true | false )
   dup " device-number" ascii v md-find-prop	( nptr prop | false )
   dup if					( nptr prop | false )
      md-decode-prop drop swap			( dev nptr )
      " function-number" ascii v md-find-prop	( dev prop|false )
      dup if					( dev prop| false )
         md-decode-prop drop true		( dev fcn true )
      else					( dev false )
         nip					( false )
      then					( dev fcn true | false )
   else 					( nptr false )
      nip					( false )
   then						( dev fcn true | false )
;

\ find-my-md-node is a recursive function that parses the MD starting at
\ the node pointed to by nptr2 looking for a node that matches the child 
\ device string found in '$path'. The resulting node will be returned in 
\ nptr1.
: find-my-md-node ( nptr1 $path nptr2 -- nptr1 $path )
   recursive
   >r 2dup ascii / left-parse-string 2swap 2drop	( nptr1 $path $path' )( R: nptr2 )
   ascii @ left-parse-string 2drop		( nptr1 $path $unit )
   decode-unit nip nip				( nptr1 $path phys.hi )
   dup cfg>dev# swap cfg>fcn#			( nptr1 $path dev fcn )
   r@ get-node-dev-fcn if			( nptr1 $path dev fcn [dev' fcn' | ] )
      rot = -rot = and if			( nptr1 $path )
         ascii / left-parse-string 2drop	( nptr1 $path' )
         dup if					( nptr1 $path' )
            ['] find-my-md-node r> md-applyto-fwds	( nptr1 $path'' )
         else					( nptr1 $path' )
            \ Found it!
            rot drop r> -rot			( nptr1' $path )
         then
      else					( nptr1 $path )
         \ Keep looking
         r> drop				( nptr1 $path )
      then					( nptr1 $path )
   else						( nptr1 $path dev fcn )
      \ No device/function number in the MD node
      r> 3drop					( nptr1 $path )
   then						( nptr1 $path )
;

\ If the 'node' has a 'device-number' property, pushd it on the stack 
\ and increase the #dev counter.
: find-child-dev# ( #devs node -- dev #devs+1 )
   " device-number" ascii v md-find-prop ?dup if	( #devs prop )
      md-decode-prop drop swap 1+			( dev #devs+1 )
   then							( dev #devs+1 )
;

: (make-probe-list) ( ...#devs -- $probe-list)
   <#			( ... x3 x2 x1 #devs )
   begin		( ... x3 x2 x1 #devs )
      swap u#s drop	( ... x3 x2 #devs )
      1- dup		( ... x3 x2 #devs' #devs' )
   while		( ... x3 x2 #devs' )
      ascii , hold	( ... x3 x2 #devs' )
   repeat		( ... x3 x2 #devs' )
   u#>			( $probe-list )
;

\ For each device number on the stack, add it to the probe list.
\ For example,
\ 1 1 --> One device -- > " 1"
\ 1 4 7 3 -- > Three devices --> " 1,4,7"
: make-probe-list ( ... #devs buffer -- $probe-list )
   >r (make-probe-list)			( $probe-list )( R: buffer )
   tuck r@ swap move			( len )( R: buffer )
   r> swap				( $probe-list )
;


\ Use a simple bit mask to remove duplicate device numbers.
\ Kind of like a zipper down and up the stack.
0 value dev-mask
: rm-duplicates ( ... #dev -- ... #dev' )
   -1 to dev-mask			( ... x3 x2 x1 #dev )
   0 ?do				( ... x3 x2 x1 )
      1 swap << invert dev-mask and	( ... x3 x2 mask )
      to dev-mask			( ... x3 x2 )
   loop					( ... x3 x2 )
   0 d# 32 0 do				( #dev )
      1 i << dev-mask and 0= if		( #dev )
         i swap 1+			( ... #dev' )
      then				( ... #dev' )
   loop					( ... #dev' )
;

: sun4v-pci-prober ( $probe-list -- )
   make-path$ 0= if				( $probe-list )
      cmn-error[ " Could not create device path" ]cmn-end 2drop exit
   then						( $probe-list )
   pci-path count				( $probe-list $current-path )

   \ Trim the '/pci@X,Y/' from the upper characters of the current device path
   ascii / left-parse-string 2drop		( $probe-list $current-path' )
   ascii / left-parse-string 2drop		( $probe-list $child-path )

   \ Put a zero on the stack for symmetry. This will become the child
   \ node pointer (nptr).
   0 -rot					( $probe-list nptr $child-path ) 
   ['] find-my-md-node my-node md-applyto-fwds	( $probe-list nptr $child-path )

   \ Save current node pointer for later.
   2drop current-md-node >r 			( $probe-list nptr )( R: current )

   ?dup if					( $probe-list nptr| )
      \ We found an MD node for this PCI device
      >r r@ to current-md-node			( $probe-list )( R: current nptr )
      r@ " slot-present" ascii v md-find-prop if
         \ This is a PCI slot, so there won't be any child device ndoes in the MD. 
         \ Use method argument $probe-list
         r> drop pci-prober			(  )
      else					( $probe-list )( R: current nptr )
         \ This is an onboard PCI device node, so there had better be an MD node for it.
         \ Use the fwd links to create the proper probe list.
         2drop					(  )
         0 ['] find-child-dev# r> md-applyto-fwds	( ... #dev )
         ?dup if				( ... #dev | 0 )
            \ Multi-function devices will show up twice. Remove them.
            rm-duplicates			( ... #dev' )

            /pci-probe-path-buffer alloc-mem	( ... #dev' buffer )
            dup >r make-probe-list		( $probe-list )( R: buffer )
            pci-prober				(  )
            r> /pci-probe-path-buffer free-mem	(  )
         then					(  )
      then					(  )
   else						( $probe-list )
      \ Could not find MD node; Use method argument 'probe-list'
      pci-prober				(  )
   then   					(  )
   r> to current-md-node			(  )( R: )
;

\ The 'NON-MD-IODEVICE' flag can be turned on to probe an unknown hardware
\ IO topology. The MD will not be checked, so all devices on every pci bus 
\ will be probed.
: prober-xt ( -- adr )				
[ifdef] NON-MD-IODEVICE
   ['] pci-prober
[else]
   ['] sun4v-pci-prober
[then]
;

: master-probe  ( -- )
   my-node 
   dup to current-md-node

   \ We need the hotplug slot count properties before probing since the 
   \ pci bridge code inherits this property.
   dup " level2-hotplug-slot-count" ascii v md-find-prop ?dup if
      md-decode-prop drop encode-int " level2-hotplug-slot-count" property
   then
   " level1-hotplug-slot-count" ascii v md-find-prop ?dup if
      md-decode-prop drop encode-int " level1-hotplug-slot-count" property
   then
   
   bar-struct-addr my-memlist @ my-mem64list @ my-io-list @	( reg mem mem64 io )
   set-pointers						( -- )
   setup-swapped-fcodes
   pci-master-probe
   make-available-property				( -- )
   get-pointers						( reg mem mem64 io )
   my-io-list ! my-mem64list ! my-memlist ! drop	( -- )
   restore-fcodes
;

: open true ;
: close ;

headerless
