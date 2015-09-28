\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: vio-struct.fth
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
id: @(#)vio-struct.fth 1.1 06/10/11
purpose: This file contains data structures shared by VIO devices
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

\ ----------- Common to both vdisk and vnet ----------------

h# 2000		constant	pagesize	

\ First 64 bits are common among all message
\ types. 
struct
   /c	field	>vio-msgtype
   /c	field	>vio-subtype
   /w	field	>vio-subtype-env
   /l	field	>vio-sid
constant	/vio-msg-tag

\  Message types 
1   constant 	vio-msg-type-ctrl
2   constant 	vio-msg-type-data
4   constant	vio-msg-type-err

\  Message sub-types 
1   constant	vio-subtype-info
2   constant	vio-subtype-ack
4   constant	vio-subtype-nack

\  Message sub-type envelopes
1   constant	vio-ver-info
2   constant	vio-attr-info
5   constant	vio-rdx
h# 40	constant	vio-pkt-data
h# 41 	constant	vio-desc-data

\  dev_type 
1   constant	vdev-net-client
3   constant	vdev-disk-client

struct
   /x	field	>ldc-mem-caddr
   /x	field	>ldc-mem-csize
constant	/ldc-mem-cookie

\  xfer_mode 
1   constant	vio-pkt-mode
2   constant	vio-desc-mode

\ VIO version negotation message.
\ tag == CTRL/INFO/VIO_VER_INFO
struct
   /vio-msg-tag	field	>vio-msg-tag
   /w		field	>vio-ver-major
   /w		field	>vio-ver-minor
   /c		field	>vio-dev-type
   d# 43        field   >vio-ver-res1   \ Total size = 56 bytes, 8 byte LDC header is
                                        \ added on top of the structure ==> 64 bytes
constant	/vio-ver-msg

\ ---------------- vdisk specific ----------------------
\ Definitions of the various ways vds can export disk support to vdc.
0   constant        vd-disk-type-unk
1   constant        vd-disk-type-slice
2   constant        vd-disk-type-disk

\ Supported versions
1   constant	vdisk-major
0   constant	vdisk-minor

\ Currently, max xfer size is 0x8000, page size is 0x2000
\ Each cookie size is 1 page, so we need 4 cookies
4  constant	vdsk-#cookies

\ vdisk attribute msg format CTRL/INFO/ATTR_INFO
struct
   /vio-msg-tag	field	>vdisk-vio-tag
   /c		field	>vdisk-xfer-mode
   /c		field	>vdisk-type
   /w 		field	>vdisk-res1
   /l		field	>vdisk-bsize
   /x		field	>vdisk-op
   /x		field	>vdisk-size
   /x		field	>vdisk-mtu
   d# 16 		field	>vdisk-res
constant   /vdisk-attr-msg

struct
   /vio-msg-tag				field	>vdsk-tag
   /x					field 	>vdsk-seq
   /x					field	>vdsk-desc-hdl
   /x					field	>vdsk-reqid
   /c					field	>vdsk-operation
   /c					field	>vdsk-slice
   /w					field	>vdsk-resv
   /l					field	>vdsk-status
   /x					field	>vdsk-addr 	
   /x					field	>vdsk-nbytes
   /l					field	>vdsk-#cookies
   /l					field	>vdsk-resv1
   /ldc-mem-cookie vdsk-#cookies  *	field	>vdsk-cookie
constant   /vdsk-descr-msg

\ Operation definition
\ There are other operations defined but we are not using them in Openboot
1   constant        vdsi-bread
2   constant        vdsi-write

\ ------------- vnet specific ---------------------

\ Supported versions
1   constant 	vnet-major
0   constant	vnet-minor

\ Ethernet frame size is 1514, each cookie is 0x2000(1 page) in size
\ So we need 2 cookies at most
2   constant	vnet-#cookies

\ Vnet/Vswitch device attributes information message.
\ tag == CTRL/INFO/ATTR_INFO
\
struct
   /vio-msg-tag	field	>vnet-vio-tag
   /c		field	>vnet-xfer-mode
   /c		field	>vnet-addr-type
   /w		field	>vnet-ack-freq
   /l		field	>vnet-resv1
   /x		field	>vnet-attr-addr
   /x		field	>vnet-attr-mtu
   d# 24		field	>vnet-ldc-pkt-pad
constant   /vnet-attr-msg

\ addr_type 
1   constant	addr-type-mac

\ Vswitch in-band descriptor data message
\ tag == DATA/{INFO|ACK|NACK}/DESC_DATA
struct
   /vio-msg-tag		field	>vnet-tag
   /x			field	>vnet-seq
   /x			field	>vnet-desc-hdl
   /l			field	>vnet-ctrl-nbytes
   /l			field	>vnet-ctrl-#cookies
dup    constant /vnet-descr-short
   /ldc-mem-cookie vnet-#cookies *	field	>vnet-cookie
constant   /vnet-descr-msg

