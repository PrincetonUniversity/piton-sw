\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ds-h.fth
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
id: @(#)ds-h.fth 1.2 07/02/12
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ FWARC 2006/055

headerless

1 value ds-major		\ these should probably be words backed by
0 value ds-minor		\ buffer: (vectors)

0 value svc-handle

0 value ds-debug?

\ message header
struct
   /l	field >msg-type
   /l	field >payload-len
constant /ds-hdr

\ Openboot is not always able to dynamically allocate packets to match the
\ data being transmitted.  (For example if Solaris has taken control), so we
\ allocate a large buffer

h# 2000 dup /ds-hdr + buffer: ds-pkt-buffer
constant MAX-DS-PAYLOAD

: >payload  	( pkt -- payload-start ) 	/ds-hdr + ;
: payload>pkt	( payload-start -- pkt )	/ds-hdr - ;
: payload-len@  ( size pkt -- )			>payload-len l@  ;
: payload-len!  ( size pkt -- )			>payload-len l!  ;
: msg-type@ 	( type pkt -- )			>msg-type l@  ;
: msg-type! 	( type pkt -- )			>msg-type l!  ;
: pkt-size@ 	( pkt -- pkt-size )		>payload-len l@ /ds-hdr + ;

\ Initiate Connection request
struct
   /w	field >init-major-ver
   /w	field >init-minor-ver
constant /ds-init-req

\ Initition Acknowlegment
struct
   /w	field >init-ack-minor-vers
constant /ds-init-ack

\ Initiation Negative Acknowledgment
struct
   /w	field >init-nack-major-vers
constant /ds-init-nack

\ Register Service payload
struct
   /x	field >reg-svc-handle
   /w	field >reg-major-ver
   /w	field >reg-minor-ver
   0    field >reg-svc-id	\ actually a variable string with max len 1024
constant /ds-reg-req

\ Regiser Acknowledgment
struct
   /x	field >regack-svc-handle
   /w	field >regack-minor-vers
constant /ds-reg-ack

\ Register Negative Acknowledgment
struct
   /x	field >regnack-svc-handle
   /x	field >regnack-status
   /w	field >regnack-major-vers
constant /ds-reg-nack

\ Unregister request
struct
   /x  field >unreg-svc-handle
constant /ds-unreg-req

\ Data packet
struct
   /x  field >data-svc-handle
constant /ds-data

\ Data Error
struct
   /x	field >dsnack-svc-handle
   /x	field >dsnack-status
constant /ds-nack

\ dsnack-status values
1	constant DS-INV-HDL
2	constant DS-TYPE-UNKOWN

\ message types
0 	constant DS-INIT-REQ
1	constant DS-INIT-ACK
2	constant DS-INIT-NACK
3	constant DS-REG-REQ
4	constant DS-REG-ACK
5	constant DS-REG-NACK
6	constant DS-UNREG
7	constant DS-UNREG-ACK
8	constant DS-UNREG-NACK
9	constant DS-DATA

0 	constant DS-CLOSED
1 	constant DS-OPEN
2 	constant DS-ERROR

DS-CLOSED value domain-service-state
