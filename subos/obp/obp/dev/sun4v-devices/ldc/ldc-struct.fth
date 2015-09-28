\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ldc-struct.fth
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
id: @(#)ldc-struct.fth 1.4 07/04/10
purpose: Implements logical Domain Communication
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ Hypervisor APIs
h# e0 constant tt-ldc-tx-qconf 
h# e1 constant tt-ldc-tx-qinfo 
h# e2 constant tt-ldc-tx-get-state 
h# e3 constant tt-ldc-tx-set-qtail 
h# e4 constant tt-ldc-rx-qconf 
h# e5 constant tt-ldc-rx-qinfo 
h# e6 constant tt-ldc-rx-get-state 
h# e7 constant tt-ldc-rx-set-qhead 
h# ea constant tt-ldc-set-map-table
h# eb constant tt-ldc-get-map-table
h# ec constant tt-ldc-copy
h# ed constant tt-ldc-mapin
h# ee constant tt-ldc-unmap
h# ef constant tt-ldc-revoke

d# 48 constant max-ldc-payload-reli
d# 56 constant max-ldc-payload-unreli
d# 64 constant /ldc-msg-pkt

defer max-ldc-payload   ' max-ldc-payload-unreli is max-ldc-payload

d# 2000 constant max-ldc-chan-ids

\ Reliable Datagram Packet: 
\           6 			   3 3 	 2 2   1 1 
\           3 			   2 1 	 4 3   6 5    8 7    0 
\          +------------------------+-----+-----+------+------+
\  word 0: | 		msgid       | env | ctrl| stype| type | 
\          +------------------------+-----+-----+------+------+ 
\  word 1: | 		ackid       |   version/reserved      | 
\          +--------------------------------------------------+ 
\ word 2-7 | 			data payload 		      | 
\          +--------------------------------------------------+

struct
   /c	field		>ldc-type
   /c	field		>ldc-stype
   /c	field		>ldc-ctrl
   /c	field		>ldc-env
   /l	field		>ldc-msgid
constant /ldc-header-common

struct
   /ldc-header-common		field	>ldc-hd-common
dup constant /ldc-data-unreli 
\ By default assume unreliable transport, the offset will be set appropriately
\ later on
    value   ldc-data-off

struct
   /ldc-header-common	field	>ldc-hd-common1
   /l			field	>ldc-reserved
   /l			field	>ldc-ackid
constant /ldc-data-reli 

\ The reserved field actually holds version information in the first couple
\ packets exchanged....  For data transfers the field is reserved.
alias	>ldc-version	>ldc-reserved


6 constant ldc-msg-pkt-shift

\ LDC Base_raddr must be aligned exactly to match the queue size,
\ 4k entries X 64 bytes/pkt = 256K queue size
h# 1000  constant ldc-queue-entries
/ldc-msg-pkt ldc-queue-entries * constant ldc-queue-size

\ Define LDC Message Types, for the >ldc-type field
1 	constant ldc-ctrl-type
2 	constant ldc-data-type
h# 10	constant ldc-err-type

\ LDC Message Subtypes
1	constant ldc-info
2	constant ldc-ack
4	constant ldc-nack

\ Define LDC Ctrl messages, for the >ldc-ctrl field
1 	constant ldc-ver	\ Version message 
2 	constant ldc-rts 	\ request to send
3 	constant ldc-rtr	\ ready to receive
4 	constant ldc-rdx	\ Ready for Data eXchange

\ LDC error messages
h# 10	constant ldc-inv-session
h# 20	constant ldc-inv-ver
h# 30	constant ldc-inv-pkt

\ LDC States
0	constant ldc-down
1	constant ldc-up
2	constant ldc-reset

\ LDC Error code
h# ffff	constant LDC-NOTUP

\ Protocol type
0	constant	ldc-mode-raw	
1	constant	ldc-mode-unreliable
\ 2 			(reserved)
3	constant	ldc-mode-reliable

\ Packet Envelope: For data bearing LDC packets, indicate the number of 
\ 		   bytes of data in the current packet.
\ 'start/stop' field indicates whether the data is a fragment 
\              in a multi-packet transfer.
\ The last packet in a multi-packet transfer is indicated using 'stop' bit. 

\      3       3    2                     2                          
\      1       0    9                     4
\  +-------+-------+-------+-------+-------+
\  | stop  | start |       pkt_size        |
\  +-------+-------+-------+-------+-------+

\ Packets between start & stop does not have any bit set, single packet
\ has both bits set.
h# 40	constant start-pkt-bit
h# 80	constant stop-pkt-bit
h# 3f	constant pkt-size-mask
h# c0	constant multi-bit-mask

\ Internal LDC Msg ctrl Codes
1 constant ldc-bulk-xfer

struct
   /l	field 	>ldc-chan-id
   /l 	field	>ldc-chan-used
   /l	field	>ldc-chan-pad1
   /l	field	>ldc-chan-pad2
constant /ldc-chan-state

h# 2000		constant	pagesize
d# 13		constant	pagesizeshift
0		constant	pagesize8K

\ LDC Map Table Entry 
\                                    
\  63  57    56    55     13  12    11   10  9   8   7  6  5  4  3     0
\ +------+--------+---------+-----+----+---+---+---+---+--+--+--+-------+
\ | rsvd | in-use |  raddr  | sw1 |sw2 |cpw|cpr|iow|ior|x |w |r | pgsz  |
\ +------+--------+---------+-----+----+---+---+---+---+--+--+--+-------+
\ |			revocation cookie	  		        |
\ +---------------------------------------------------------------------+

struct 
	/x 	field	>ldc-mt-ent1
	/x	field	>ldc-mt-rcookie
constant /ldc-mt-ent

d# 9	constant	ldc-cprw-shift
d# 13	constant 	ldcmtbl-ra-shift
   6	constant	num-cookies		\ max # of cookies in map table

3 ldc-cprw-shift << pagesize8K or 	constant mt-entry-misc

h# ffff.e000 h# 0fff.ffff  lxjoin 	constant	mt-ra-mask

\ LDC Cookie address format
\   6    6 5     
\  |3    0|9                         size|size-1            0|
\  +------+------------------------------+-------------------+
\  | pgsz |         table_idx            |     page_offset   |
\  +------+------------------------------+-------------------+

d# 60		constant	cookie-pgsz-shift

\ LDC Memory xfer related 

\ LDC Memory Copy Direction
0 constant ldc-mcopy-in		\ Copy data to VA from cookie-memory
1 constant ldc-mcopy-out	\ Copy data from VA to cookie-memory

headerless

