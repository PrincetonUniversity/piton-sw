/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: svc.h
* 
* Copyright (c) 2006 Sun Microsystems, Inc. All Rights Reserved.
* 
*  - Do no alter or remove copyright notices
* 
*  - Redistribution and use of this software in source and binary forms, with 
*    or without modification, are permitted provided that the following 
*    conditions are met: 
* 
*  - Redistribution of source code must retain the above copyright notice, 
*    this list of conditions and the following disclaimer.
* 
*  - Redistribution in binary form must reproduce the above copyright notice,
*    this list of conditions and the following disclaimer in the
*    documentation and/or other materials provided with the distribution. 
* 
*    Neither the name of Sun Microsystems, Inc. or the names of contributors 
* may be used to endorse or promote products derived from this software 
* without specific prior written permission. 
* 
*     This software is provided "AS IS," without a warranty of any kind. 
* ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, 
* INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A 
* PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY EXCLUDED. SUN 
* MICROSYSTEMS, INC. ("SUN") AND ITS LICENSORS SHALL NOT BE LIABLE FOR 
* ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR 
* DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES. IN NO EVENT WILL SUN 
* OR ITS LICENSORS BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA, OR 
* FOR DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE 
* DAMAGES, HOWEVER CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, 
* ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF 
* SUN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
* 
* You acknowledge that this software is not designed, licensed or
* intended for use in the design, construction, operation or maintenance of
* any nuclear facility. 
* 
* ========== Copyright Header End ============================================
*/
/*
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SVC_H_
#define	_SVC_H_

#pragma ident	"@(#)svc.h	1.10	07/05/30 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifdef CONFIG_SVC

#define	XPID_RESET	0
#define	XPID_POST	1
#define	XPID_HV		2
#define	XPID_GUESTBASE	16
#define	XPID_GUEST(n)	(XPID_GUESTBASE + (n))

#define	SID_CONSOLE	0
#define	SID_ERROR	2
#define	SID_VBSC_CTL	3
#define	SID_ECHO	4
#define	SID_LOOP1	5
#define	SID_LOOP2	6
#define	SID_FMA		7

/* the service config bits */
#define	SVC_CFG_RX	0x00000001 /* support RECV */
#define	SVC_CFG_RE	0x00000002 /* support RECV intr */
#define	SVC_CFG_TX	0x00000004 /* support SEND */
#define	SVC_CFG_TE	0x00000008 /* support SEND intr */
#define	SVC_CFG_GET	0x00000010 /* support GETSTATUS */
#define	SVC_CFG_SET	0x00000020 /* support SETSTATUS */
#define	SVC_CFG_LINK	0x00000100 /* cross linked svc */
#define	SVC_CFG_MAGIC	0x00000200 /* legion magic trap */
#define	SVC_CFG_CALLBACK 0x0000800 /* hypervisor callback */
#define	SVC_CFG_PRIV	0x80000000

#define	ABORT_SHIFT	11

#define	SVC_DUPLEX	(	   \
	    SVC_CFG_RX | SVC_CFG_RI | \
	    SVC_CFG_TX | SVC_CFG_TI | \
	    SVC_CFG_GET | SVC_CFG_SET)

/* the service status/flag bits */
#define	SVC_FLAGS_RI	0x00000001 /* RECV pending */
#define	SVC_FLAGS_RE	0x00000002 /* RECV intr enabled */
#define	SVC_FLAGS_TI	0x00000004 /* SEND complete */
#define	SVC_FLAGS_TE	0x00000008 /* SEND intr enabled */
#define	SVC_FLAGS_TP	0x00000010 /* TX pending (queued) */
#define	SVC_FLAG_ABORT	(1 << ABORT_SHIFT) /* ABORT XXX interrupt ? */

/* the offsets in the svc register tables */
#define	SVC_REG_XID	0x0
#define	SVC_REG_SID	0x4
#define	SVC_REG_RECV	0x8
#define	SVC_REG_SEND	0xC

/* fixed services between HV and VBSC */
#define	VBSC_HV_ERRORS_SVC_SID		0x2
#define	VBSC_HV_ERRORS_SVC_XID		0x2
#define	VBSC_HV_ERRORS_SVC_FLAGS	0x35
#define	VBSC_HV_ERRORS_SVC_MTU		0x200

#define	VBSC_DEBUG_SVC_SID		0x3
#define	VBSC_DEBUG_SVC_XID		0x2
#define	VBSC_DEBUG_SVC_FLAGS		0x35
#define	VBSC_DEBUG_SVC_MTU		0x200


/* May not modify condition codes */
#define	LOCK(r_base, offset, r_tmp, r_tmp1)	\
	.pushlocals				;\
	add	r_base, offset, r_tmp		;\
	sub	%g0, 1, r_tmp1			;\
1:	casx	[r_tmp], %g0, r_tmp1		;\
	brlz,pn r_tmp1, 1b			;\
	  sub	%g0, 1, r_tmp1			;\
	.poplocals

/* May not modify condition codes */
/* watchout!! the branch will use the delay slot.. */
#define	TRYLOCK(r_base, offset, r_tmp0, r_tmp1)	\
	add	r_base, offset, r_tmp0		;\
	sub	%g0, 1, r_tmp1			;\
	casx	[r_tmp0], %g0, r_tmp1		;\
	brlz,pn r_tmp1, herr_wouldblock		;

#ifdef SVCDEBUG
#define	TRACE(x)	PRINT(x); PRINT("\r\n")
#define	TRACE1(x)	PRINT(x); PRINT(": "); PRINTX(%o0); PRINT("\r\n")

#define	TRACE2(x)	\
	PRINT(x); PRINT(": ");\
	PRINTX(%o0)	;\
	PRINT(", ")	;\
	PRINTX(%o1)	;\
	PRINT("\r\n")	;

#define	TRACE3(x)	\
	PRINT(x); PRINT(": ");\
	PRINTX(%o0)	;\
	PRINT(", ")	;\
	PRINTX(%o1)	;\
	PRINT(", ")	;\
	PRINTX(%o2)	;\
	PRINT("\r\n")	;
#else
#define	TRACE(s)
#define	TRACE1(s)
#define	TRACE2(s)
#define	TRACE3(s)
#endif

#ifdef INTR_DEBUG
#define	SEND_SVC_TRACE						\
	PRINT("svc root: "); PRINTX(r_root);			\
	PRINT(", "); PRINTX(r_svc); PRINT("\r\n");
#else
#define	SEND_SVC_TRACE
#endif

#define	SEND_SVC_PACKET(r_root, r_svc, sc0, sc1, sc2, sc3)	\
	SEND_SVC_TRACE					;	\
	ldx	[r_root + HV_SVC_DATA_TXBASE], sc0 ;		\
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], sc1;	\
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], sc2;	\
	SMALL_COPY_MACRO(sc1, sc2, sc0, sc3)	;		\
	ldx	[r_root + HV_SVC_DATA_TXCHANNEL], sc1 ;		\
	mov	1, sc0; 					\
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], sc2;	\
	sth	sc2, [sc1 + FPGA_Q_SIZE] ;			\
	stb	sc0, [sc1 + FPGA_Q_SEND] ;

#ifdef _ASM

#define	UNLOCK(r_base, offset)		\
	stx	%g0, [r_base + offset]

#endif /* _ASM */

#define	SVCCN_TYPE_BREAK	0x80
#define	SVCCN_TYPE_HUP		0x81
#define	SVCCN_TYPE_CHARS	0x00

#endif /* CONFIG_SVC */

#ifndef _ASM

/*
 * The svc_data blocks are back-to-back in memory (a linear array)
 * if we get to the end then this is a bad service request.
 */
struct svc_link {
	uint64_t	size;
	uint64_t	pa;
	struct svc_ctrl *next;
};

struct svc_callback {
	uint64_t	rx; 		/* called on rx intr */
	uint64_t	tx;
	uint64_t	cookie; 	/* your callback cookie */
};

typedef struct svc_ctrl svc_ctrl_t;

struct svc_ctrl {
	uint32_t	xid;
	uint32_t	sid;
	uint32_t	ino;			/* virtual INO  */
	uint32_t	mtu;
	uint32_t	config;			/* API control bits */
	uint32_t	state;			/* device state */
	uint32_t	dcount;			/* defer count */
	uint32_t	dstate;			/* defer state 0=NACK, 1=BUSY */
	uint64_t	lock;			/* simple mutex */
	uint64_t	intr_cookie;		/* intr gen cookie */
	struct svc_callback callback; 		/* HV call backhandle */
	struct svc_ctrl *link;			/* cross link */
	struct svc_link	recv;
	struct svc_link send;
};

struct svc_pkt {
	uint32_t	xid;			/* service guest ID */
	uint16_t	sum;			/* packet checksum */
	uint16_t	sid;			/* svcid */
};

#define	MAX_SVCS	9

typedef struct hv_svc_data hv_svc_data_t;

struct hv_svc_data {
	uint64_t	rxbase;			/* PA of RX buffer (SRAM) */
	uint64_t	txbase;			/* PA of TX buffer (SRAM) */
	uint64_t	rxchannel;		/* RX channel regs PA */
	uint64_t	txchannel;		/* TX channel regs PA */
	uint64_t	scr[2];			/* reg scratch */
	uint32_t	num_svcs;
	uint32_t	sendbusy;
	struct svc_ctrl *sendh;			/* intrs send from here */
	struct svc_ctrl *sendt;			/* sender adds here */
	struct svc_ctrl *senddh;		/* holding.. (nack/busy) */
	struct svc_ctrl *senddt;
	uint64_t	lock;			/* need mutex?? */
	struct svc_ctrl svcs[MAX_SVCS];		/* the svc buffers follow */
};


/*
 * Console protocol packet definition
 */
struct svccn_packet {
	uint8_t		type;
	uint8_t		len;
	uint8_t		data[1];
};

#endif /* _ASM */

#ifdef __cplusplus
}
#endif

#endif /* _SVC_H_ */
