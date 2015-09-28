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
id: @(#)methods.fth 1.5 07/04/10
purpose: Virtual Disk driver methods
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

external

d# 512		constant block-size

: dma-alloc   ( size -- vaddr )			pagesize swap 0 claim  ;
: dma-free    ( vaddr size -- )			swap  release  ;
: dma-sync    ( virt-addr dev-addr size -- )	3drop  ;
: dma-map-out ( vaddr devaddr n -- )            3drop  ;
: dma-map-in  ( vaddr size cache? -- devaddr )
   2drop
;

headerless

/vdisk-attr-msg /vdsk-descr-msg max value /vdsk-descr-buf \ Size of the descr
					\ buffer is max of attr and descr
					\ structures.
h# 8000 value /max-transfer		\ Maximum transfer size is 32k bytes

fload ${BP}/dev/sun4v-devices/ldc/methods.fth

\ If the vDisk client does not use the VTOC service, it must specify a value
\ of 0xff for the slice field for read and write transactions so that the
\ server knows that the offset specified is the absolute offset relative to
\ the start of a disk.  See VIO specification for details.

h# ff constant use-absolute-disk-offset

vdev-disk-client to current-vio-dev
0 	value 	debug-vdisk?	\ Debug message enabler
vd-disk-type-unk value	vd-disk-type \ Stores type of virtual disk, unknown, disk or slice
1 	value 	use-block-read?

8 	value 	vdsk-sid	\ Variable to hold sequence ID
d# 200 value 	vd-retries	\ Variable to hold # of retries
0 	value 	vdsk-descr-buf	\ Variable to hold vdisk descriptor buffer

0 	value 	offset-low	\ Low Offset to start of partition
0 	value 	offset-high	\ High Offset to start of partition
0	value 	label-package	\ Stores ihandle for label package
0 	value 	deblocker	\ Stores ihandle for deblocker package
0 	value 	ldc-up?		\ flag, Set if LDC is up
0 	value 	vdsk-seq	\ Sequence# for the next request
0 	value 	cur-vdsk-seq	\ Sequence# of the current request

: init-deblocker  ( -- okay? )
   " "  " deblocker"  $open-package  to deblocker
   deblocker if
      true
   else
      cmn-error[ " Can't open deblocker package"  ]cmn-end  false
   then
;

: init-label-package  ( -- okay? )
   0 to offset-high  0 to offset-low
   my-args  " disk-label"  $open-package dup to label-package
   if
      0 0  " offset" label-package $call-method to offset-high to offset-low
      true
   else
      cmn-error[ " Can't open disk label package"  ]cmn-end  false
   then
;

\ The service domain may be down or rebooting...  Keep retrying for 5 minutes
: open-vdisk-ldc (  -- error?  )
   get-msecs d# 300.000 + 		\ 5 minutes later
   begin					( finish-time )
      get-msecs over <				( finish-time keep-trying? )
   while					( finish-time )
      vd-ldcid ldc-mode-unreliable ldc-open if	( finish-time )
         true to ldc-up?			( finish-time )
         drop false exit			( false )
      then					( finish-time )
      cmn-warn[ 
         " Timeout connecting to virtual disk server... retrying" 
      ]cmn-end
      d# 5000 ms				( finish-time )
   repeat
   cmn-warn[ " Unable to connect to virtual disk server" ]cmn-end
   drop true					( true )
;

: close-vdisk-ldc  ( -- )
   ldc-close 0 to ldc-up?
;

\ Retry a few times if EWOULDBLOCK, print out warning message if didn't get EOK.
\ Only update seqid upon successful return because Solaris counter part
\ doesn't like new seqid if OBP higher level SW do retries
: send-to-ldc  ( buf len -- #bytes )
   0 vd-retries 0 do				( buf len status )
      drop 2dup					( buf len buf len )
       ldc-write				( buf len #bytes status )
      dup HV-EOK <>  if				( buf len #bytes status )
         dup HV-EWOULDBLOCK <>  if		( buf len #bytes status )
	    dup LDC-NOTUP = if			( buf len #bytes status )
		cmn-warn[ " Sending packet to LDC but LDC is Not Up!" ]cmn-end
		2drop 2drop 0 unloop exit	( 0 )
	    then
            cmn-warn[ " Sending packet to LDC, status: %d" ]cmn-end
            3drop 0 unloop exit			( 0 )
         then
      else					( buf len #bytes status )
         cur-vdsk-seq 1+ to vdsk-seq
         drop nip nip unloop exit		( #bytes )
      then
      nip  					( buf len status )
      \ Every 20 loops, roughly 20 seconds (ldc-write can take @ 1s),
      \ print a retrying message
      i 1+ d# 20 mod 0= if
         cmn-warn[ 
            " Timeout sending package to LDC ... retrying" 
         ]cmn-end
      then
   loop						( buf len status )
   3drop 0
   cmn-warn[ " Sending packet to LDC timed out!" ]cmn-end
;


: receive-from-ldc  ( buf len -- #bytes )
   0 vd-retries 0 do				( buf len status )
      drop 2dup ldc-read			( buf len #bytes status )
      dup HV-EOK <>  if				( buf len #bytes status )
         dup HV-EWOULDBLOCK <> if 		( buf len #bytes status )
	    dup LDC-NOTUP = if			( buf len #bytes status )
		cmn-warn[ 
		   " Receiving packet from LDC but LDC is Not Up!"
		]cmn-end
		2drop 2drop 0 unloop exit 	( 0 )
	    then
            cmn-warn[ " Receiving packet from LDC, status: %d" ]cmn-end
            3drop 0 unloop exit			( 0 )
         then
      else					( buf len #bytes status )
	   \ Treat EOK with length = 0 same as EWOULDBLOCK at LDC layer
	   \ in which case just retry
	   over if				(  buf len #bytes status ) 
	     drop nip nip unloop exit		( #bytes )
	   then
      then					( buf len #bytes status )
      nip 					( buf len status )
      \ Every 20 loops, roughly 20 seconds (ldc-read can take @ 1s),
      \ print a retrying message
      i 1+ d# 20 mod 0= if
         cmn-warn[ 
            " Timeout receiving packet from LDC ... retrying" 
         ]cmn-end
      then
   loop						( buf len status )
   3drop 0
   cmn-warn[ " Receiving packet from LDC timed out!" ]cmn-end
;

' receive-from-ldc is retrieve-packet

\ Set up vio-msg-tag, sid and seq
: set-descr-req-header  ( -- )
   vdsk-descr-buf /vdsk-descr-msg erase			( )

   vio-msg-type-data vio-subtype-info vio-desc-data	( type stype env )
   vdsk-descr-buf set-vio-msg-tag			( )
   vdsk-sid vdsk-descr-buf tuck  >vio-sid l!		( buf )

   vd-disk-type over >vdsk-slice c!			( buf )
   vdsk-seq swap 2dup >vdsk-seq x!			( seq buf )
   >vdsk-reqid x!					( )
   vdsk-seq to cur-vdsk-seq
;

: send-descr-req  ( -- ok? )
   vdsk-descr-buf /vdsk-descr-msg send-to-ldc	( len )
   /vdsk-descr-msg =				( ok? )
;

\ Send VDS in-band descriptor ring request
: send-descr-read-req  ( size offset cadr ck# -- ok? )
   set-descr-req-header				( size offset cadr ck# )
   2swap over swap				( cadr ck# size size offset )
   block-size /					( cadr ck# size size boffset )
   vdsk-descr-buf tuck >vdsk-addr x!		( cadr ck# size size buf )
   tuck >vdsk-nbytes x!				( cadr ck# size buf )
   vdsi-bread over >vdsk-operation c!		( cadr ck# size buf )
   vdsk-#cookies over >vdsk-#cookies l!		( cadr ck# size buf )
   >vdsk-cookie fill-in-vio-cookie		( )
   send-descr-req
;

: vdsk-ack-msg?  ( -- yes? )
   vdsk-descr-buf get-vio-msg-tag 			( env stype type )
   vio-desc-data vio-subtype-ack vio-msg-type-data 	( desc subtype msg-type )
   vio-tag-match?  0= if				(  )
      false exit 					( false )
   then

   vdsk-descr-buf >vdsk-seq x@				( seq )

   cur-vdsk-seq  = if					(  )
      \ Status follows the definition in /usr/include/sys/errno.h
      vdsk-descr-buf >vdsk-status l@ 0=			( yes? )
   else
      cmn-warn[ " vdisk response packet out of sequence" ]cmn-end
      false 						( false )
   then
;

\ Get an ACK for our request
\ The receive-from-ldc times out in @ 3 minute. Try one additional
\ time in case do not get descr-ack the first time around.
: get-descr-ack?  ( -- yes? )
   2 0 do						( )
     vdsk-descr-buf /vdsk-descr-msg receive-from-ldc	( rlen )
     /vdsk-descr-msg = if				( )
        vdsk-ack-msg? if				( )
           true unloop exit				( true ) 
        then
     then   
  loop false						( false )
;

: disk-read  ( size addr offset  -- #bytes )
   debug-vdisk? if 3dup ." disk-read: offset addr size: " u. u. u. cr then
   >r >r dup dup r> swap r> -rot 	( size size offset addr size)
   ldc-add-map-table-entries		( size size offset cadr ck# )
   debug-vdisk? if 2dup ." #cookie cookie-addr  " u. u. cr then
					( size size offset cadr ck# )   
   send-descr-read-req if		( #bytes )
      get-descr-ack? 0= if		( #bytes )
         drop 0 			( 0 )
      then
   else					( #bytes )
      cmn-warn[ " Can't send vdisk read request!" ]cmn-end
      drop 0 				( 0 )
   then 				( #bytes|0 )
;

\ Fill in version negotiation pkt content and send out
: send-vdsk-ver-msg  ( -- ok? )
   vdsk-descr-buf /vio-ver-msg erase	(  )

   \ vdsk session id is only updated once during version negotiation
   vdsk-sid 1+ dup to vdsk-sid 		( sid )
   vdsk-descr-buf  >vio-sid l!		(  )

   vio-msg-type-ctrl vio-subtype-info vio-ver-info	( msg-type sub-type ver )
   vdsk-descr-buf set-vio-msg-tag	(  )
 
   vdev-disk-client vdisk-minor vdisk-major 	( dev-type minor major )
   vdsk-descr-buf set-vio-msg-ver	(  )

   vdsk-descr-buf  /vio-ver-msg		( buf len )
   send-to-ldc				( #bytes )

   /vio-ver-msg =			( ok? )
;

' send-vdsk-ver-msg is send-vio-ver-msg

\ The ack parameter may be ack or nack
: send-vdsk-ack-msg  ( buf ack -- ok? )
   over >vio-subtype c!				( buf )
   vdsk-sid over  >vio-sid l!			( buf )
   /vio-ver-msg send-to-ldc 			( len )
   /vio-ver-msg =
;

' send-vdsk-ack-msg is send-vio-ack-msg

: vdsk-compatible-ver?  ( buf -- yes? )
   dup >vio-ver-major w@ vdisk-major =		( buf flag1 )
   swap >vio-ver-minor w@ vdisk-minor =		( flag1 flag2 )
   and 						( yes? )
;

' vdsk-compatible-ver? is vio-compatible-ver?

\ Send our attributes 
: send-vdsk-attr  ( -- ok? )
   vdsk-descr-buf /vdisk-attr-msg erase		(  )
   vio-msg-type-ctrl vio-subtype-info vio-attr-info	( msf-type subtype attr )
   vdsk-descr-buf set-vio-msg-tag		(  )
   vdsk-sid vdsk-descr-buf  >vio-sid l!		(  )

   vdsk-descr-buf /max-transfer block-size / over >vdisk-mtu x!	( buf )
   block-size over >vdisk-bsize l!				( buf )
   vio-desc-mode swap >vdisk-xfer-mode c!	(  ) 

   vdsk-descr-buf /vdisk-attr-msg send-to-ldc	( #bytes )
   /vdisk-attr-msg =				( ok? )
;
' send-vdsk-attr is send-vio-attr

: send-vdsk-rdx  ( buf -- ok? )
  dup /vdisk-attr-msg erase			( buf )
  >r vio-msg-type-ctrl vio-subtype-info vio-rdx	( msg-type subtype rdx ) ( r: buf )
  r@ set-vio-msg-tag				(  ) ( r: buf )
  vdsk-sid r@ >vio-sid l!			(  )
  r> /vdisk-attr-msg send-to-ldc		( #bytes )
  /vdisk-attr-msg = 				( ok? )
;

' send-vdsk-rdx is send-vio-rdx

\ Inspect VDS attributes, if vdisk-type is type-disk then set slice to use 
\ an absolute disk offset 
: (update-vd-disk-type  ( buf -- )
   >vdisk-type c@  vd-disk-type-disk = if	( )
      use-absolute-disk-offset to vd-disk-type	( )
   then
;

' (update-vd-disk-type is update-vd-disk-type

\ Stages:
\ Version negotiation -> Vdisk Attr info -> Dring info -> RDX
: init-vdsk-conn  ( -- ok? )
   vdsk-descr-buf version-negotiation if			(  )
      vdsk-descr-buf /vdisk-attr-msg  vio-exchange-attr if	(  )
        true exit						( true )
      then
   then
   cmn-warn[ " Communication error with Virtual Disk Server!" ]cmn-end
   false							( false )
;

\ The disk writes are not supported, just return 0 bytes written
: disk-write ( size raddr offset -- #bytes )
   3drop 0 
;

headerless
: r/w-blocks ( addr block# #blocks read? -- #read/#written )
   >r block-size * -rot	( size addr block# )  ( r: read? )
   block-size * 	( size addr offset )  ( r: read? )
   r>  if		( size addr offset )
      disk-read		( #bytes )
   else			( size addr offset )
      disk-write	( #bytes )
   then  		( #bytes )
   block-size /		( #read|#written )
;

\ Allocate vdisk descriptor buffer
: allocate-vdsk-descr-buf
   8 /vdsk-descr-buf 0 claim to vdsk-descr-buf	(  )
;

\ Release and reset vdisk descriptor buffer
: deallocate-vdsk-descr-buf
   /vdsk-descr-buf vdsk-descr-buf release	(  )
   0 to vdsk-descr-buf
;

external
\ These three methods are called by the deblocker.

: max-transfer  ( -- #bytes )  /max-transfer ;
: read-blocks   ( addr block# #blocks -- #read )     true  r/w-blocks  ;
: write-blocks  ( addr block# #blocks -- #written )  false r/w-blocks  ;

: #blocks  ( -- true | n false )  true  ;

: open ( -- flag )
   open-vdisk-ldc if
      false exit				( false )
   then

   allocate-vdsk-descr-buf			(  )

   init-deblocker  0=  if  
      deallocate-vdsk-descr-buf			(  )
      close-vdisk-ldc				(  )
      false exit  				( false )
   then
   debug-vdisk? if ." deblocker opened." cr then (  )

   init-vdsk-conn 0= if				(  )
      deallocate-vdsk-descr-buf			(  )
      deblocker close-package 			(  )
      close-vdisk-ldc				(  )
      false exit 				( false )
   then

   init-label-package  0=  if			(  )
      deallocate-vdsk-descr-buf			(  )
      deblocker close-package 			(  )
      close-vdisk-ldc				(  )
      false exit 				( false )
   then
   true						( true )
   debug-vdisk? if ." label pkg opened." cr then ( true )
;

: close  ( -- )
   deallocate-vdsk-descr-buf			(  )

   label-package ?dup if			(  )
      close-package 				(  )
   then
   deblocker ?dup if				(  )
      close-package				(  )
   then
   ldc-up?  if					(  )
      close-vdisk-ldc
   then
;

: seek  ( offset.low offset.high -- okay? )
   offset-low offset-high d+  " seek"   deblocker $call-method	( okay? )
;

: read  ( addr len -- actual-len )  
   " read"  deblocker $call-method  	( actual-len )
;

: write ( addr len -- actual-len )  
   " write" deblocker $call-method  	( actual-len )
;

: load  ( addr -- size )    
   " load"  label-package $call-method	( size )  
;

: size  ( -- d.size )  
   " size" label-package $call-method 	( d.size ) 
;

headerless
