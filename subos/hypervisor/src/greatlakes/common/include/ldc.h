/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: ldc.h
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

#ifndef _LDC_H
#define	_LDC_H

#pragma ident	"@(#)ldc.h	1.11	07/07/17 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <guest.h>
#include <sun4v/queue.h>
#include <platform/ldc.h>

/*
 * LDC Endpoint types
 */
#define	LDC_GUEST_ENDPOINT	0x0
#define	LDC_HV_ENDPOINT		0x1
#define	LDC_SP_ENDPOINT		0x2

/*
 * Private LDC channels has a service associated with it
 */
#define	LDC_HVCTL_SVC		0x1
#define	LDC_CONSOLE_SVC		0x2

/*
 * Maximum number of LDC packets to copy in one hcall (to avoid keeping
 * the CPU in HV too long). Let's say 8K worth of packets:
 */
#define	LDC_MAX_PKT_COPY	((8 * 1024) / Q_EL_SIZE)

/*
 * Size (in number of queue entries) of console TX/RX queues
 */
#define	LDC_CONS_QSIZE		128

/*
 * HV LDC Map Table Entry
 *
 *   6    5
 *  |3    6|                            psz|   13| 11|         4|    0 |
 *  +------+-------------------------------+-----+---+----------+------+
 *  | rsvd |                  rpfn         |  0  | 0 |   perms  | pgsz | word 0
 *  +------+-------------------------------+-----+---+----------+------+
 *  |                   Hypervisor invalidation cookie slot            | word 1
 *  +------------------------------------------------------------------+
 */


#define	LDC_MTE_PGSZ_SHIFT	(0)
#define	LDC_MTE_PGSZ_MASK	(0xf)

#define	LDC_MTE_RSVD_BITS	8

#define	LDC_MTE_PERM_RD_BIT	(LDC_MAP_R_BIT + LDC_MTE_PERM_SHIFT)
#define	LDC_MTE_PERM_WR_BIT	(LDC_MAP_W_BIT + LDC_MTE_PERM_SHIFT)
#define	LDC_MTE_PERM_EX_BIT	(LDC_MAP_X_BIT + LDC_MTE_PERM_SHIFT)
#define	LDC_MTE_PERM_IORD_BIT	(LDC_MAP_IOR_BIT + LDC_MTE_PERM_SHIFT)
#define	LDC_MTE_PERM_IOWR_BIT	(LDC_MAP_IOW_BIT + LDC_MTE_PERM_SHIFT)
#define	LDC_MTE_PERM_CPRD_BIT	(LDC_MAP_COPY_IN_BIT + LDC_MTE_PERM_SHIFT)
#define	LDC_MTE_PERM_CPWR_BIT	(LDC_MAP_COPY_OUT_BIT + LDC_MTE_PERM_SHIFT)

#define	LDC_MTE_PERM_SHIFT	4
#define	LDC_MTE_PERM_MASK	((1 << (LDC_MTE_PERM_CPWR_BIT - \
						LDC_MTE_PERM_RD_BIT + 1)) - 1)

#define	LDC_MTE_RA_SHIFT	13

#define	LDC_MAX_MAP_TABLE_ENTRIES	(1 << 30)
#define	LDC_MIN_MAP_TABLE_ENTRIES	2

#define	LDC_NUM_MAPINS_BITS	12		/* Modest for now */
#define	LDC_NUM_MAPINS		(1LL << LDC_NUM_MAPINS_BITS)

/*
 * NOTE: we should be careful and ensure that we get
 * this in a segment
 */
#define	LDC_MAPIN_BASERA	(0x10LL << 34)
#define	LDC_MAPIN_RASIZE	(LDC_NUM_MAPINS << LARGEST_PG_SIZE_BITS)


/*
 * LDC Cookie address format
 *
 *   6      6          m+n
 *  |3|     0|          |                  m|                  0|
 *  +-+------+----------+-------------------+-------------------+
 *  |X|pgszc |   rsvd   |      table_idx    |     page_offset   |
 *  +-+------+----------+-------------------+-------------------+
 */
#define	LDC_COOKIE_PGSZC_MASK	0x7
#define	LDC_COOKIE_PGSZC_SHIFT	60

/*
 * For the internal map table entry
 * we assign MMU control bits using the following constants
 * for the MMU_MAP bit-mask - assuming a 64bit word to hold the flags
 */

#define	MIE_VA_MMU_SHIFT	0
#define	MIE_RA_MMU_SHIFT	8
#define	MIE_IO_MMU_SHIFT	16
#define	MIE_CPU_TO_MMU_SHIFT	2	/* 4 strands per MMU */


/*
 * For now we will have 64 channels in the HV
 * and 8 channels between the HV and SP
 * NOTE: keep this in sync with Zeus' PRI
 */
#define	MAX_HV_LDC_CHANNELS	1
#define	MAX_SP_LDC_CHANNELS	14


#define	IVDR_THREAD	8
/*
 * Macro to get the mapin table entry from the RA offset
 * ra_offset = (ra - rabase)
 *
 * Parameters:
 *  guest_endpt (unmodified)    - guest endpoint stuct pointer
 *  ra_offset   (modified)      - RA offset into mapin region
 *  mapin_entry (return value)  - addr of mapin entry
 */
/* BEGIN CSTYLED */
#define	GET_MAPIN_ENTRY(guest_endpt, ra_offset, mapin_entry)	 \
	srlx	ra_offset, LARGEST_PG_SIZE_BITS, mapin_entry	;\
	mulx	mapin_entry, LDC_MAPIN_SIZE, mapin_entry	;\
	set	GUEST_LDC_MAPIN, ra_offset			;\
	add	ra_offset, guest_endpt, ra_offset		;\
	add	mapin_entry, ra_offset, mapin_entry
/* END CSTYLED */

/*
 * Macro to get the LDC IOMMU PA from the RA
 *
 * Parameters:
 *  guest       (unmodified)    - guest endpoint stuct pointer
 *  pa          (unmodified)    - RA
 *  paddr scr1  (modified)      - scratch registers
 * Results:
 *  paddr        - Physical Address
 */
/* BEGIN CSTYLED */
#define	LDC_IOMMU_GET_PA(guest, ra, paddr, scr1, no_ra_lbl, no_perm_lbl) \
	set	GUEST_LDC_MAPIN_BASERA, paddr				;\
	ldx	[guest + paddr], scr1					;\
	subcc	ra, scr1, scr1						;\
	bneg,pn	%xcc, no_ra_lbl						;\
	.empty								;\
	set	GUEST_LDC_MAPIN_SIZE, paddr				;\
	ldx	[guest + paddr], paddr					;\
	cmp	scr1, paddr						;\
	bgu,pt	%xcc, no_ra_lbl						;\
	.empty								;\
	GET_MAPIN_ENTRY(guest, scr1, paddr)				;\
	/* !! paddr mapin entry addr */					;\
	/* check permissions */						;\
	ldub	[paddr + LDC_MI_PERMS], scr1				;\
	srlx	scr1, LDC_MAP_IOR_BIT, scr1				;\
	andcc	scr1, 0x3, %g0						;\
	beq,pn	%xcc, no_perm_lbl					;\
	.empty								;\
	/* get the PA */						;\
	ldx	[paddr + LDC_MI_PA], paddr
/* END CSTYLED */


#if defined(CONFIG_FPGA)	/* { */
/*
 * Macro to copy a packet from an LDC queue into an SRAM LDC queue.
 *
 * Inputs:
 *    src  - (modified) - PA of the source
 *    dst  - (modified) - PA of the destination
 *    scr1 - (modified) - Scratch register
 *    scr2 - (modified) - Scratch register
 *
 * Outputs:
 *    src  - PA of the byte following the source packet just copied
 *    dst  - PA of the byte following the destination packet just filled
 *
 * XXX - TODO This is probably where we will want to compute checksum
 * and fill in other SRAM LDC header stuff.
 */
/* BEGIN CSTYLED */
#define	LDC_COPY_PKT_TO_SRAM(src, dst, scr1, scr2)			\
	.pushlocals;							\
	set	Q_EL_SIZE - 1, scr1;					\
0:									\
	ldub	[src], scr2;						\
	stb	scr2, [dst];						\
	inc	src;							\
	dec	scr1;							\
	brgez,pt scr1, 0b;						\
	inc	dst;							\
	.poplocals
/* END CSTYLED */


/*
 * Macro to copy a packet from an SRAM queue into an LDC queue.
 *
 * Inputs:
 *    src  - (modified) - PA of the source
 *    dst  - (modified) - PA of the destination
 *    scr1 - (modified) - Scratch register
 *    scr2 - (modified) - Scratch register
 *
 * Outputs:
 *    src  - PA of the byte following the source packet just copied
 *    dst  - PA of the byte following the destination packet just filled
 *
 * XXX - TODO This is probably where we will want to verify checksum
 */
/* BEGIN CSTYLED */
#define	LDC_COPY_PKT_FROM_SRAM(src, dst, scr1, scr2)			\
	.pushlocals;							\
	set	SRAM_LDC_QENTRY_SIZE - 1, scr1;				\
0:									\
	ldub	[src], scr2;						\
	stb	scr2, [dst];						\
	inc	src;							\
	dec	scr1;							\
	brgez,pt scr1, 0b;						\
	inc	dst;							\
	.poplocals
/* END CSTYLED */


/*
 * Macro to calculate how many bytes of data are available to be read
 * from a given LDC queue in one pass.
 *
 * Inputs:
 *    head - (unmodified) - byte offset of the head pointer
 *    tail - (modified)   - byte offset of the tail pointer
 *   qsize - (unmodified) - size (in bytes) of the queue
 *
 * Output:
 *    tail - Contains the number of bytes of data available.
 */
/* BEGIN CSTYLED */
#define	LDC_QUEUE_DATA_AVAILABLE(head, tail, qsize)			\
	.pushlocals;							\
	brz,a	qsize, 0f;	/* obvious case */			\
	clr	tail;							\
	sub	tail, head, tail;	/* check (tail - head)  */	\
	brgez	tail, 0f;	/* If non-negative, then that's */	\
	nop;			/* how many bytes are available */	\
	sub	qsize, head, tail;	/* else (size - head) bytes */	\
0:									\
	.poplocals
/* END CSTYLED */


/*
 * Macro to calculate how many bytes of space are available to be written
 * into a given LDC queue in one pass.
 *
 * Inputs:
 *    head         - (modified)   - byte offset of the head pointer
 *    tail         - (unmodified) - byte offset of the tail pointer
 *    qsize        - (modified)   - size (in bytes) of the queue
 *    element_size - (contant)    - size (in bytes) of one queue element
 *
 * Output:
 *    head - Amount of space (in bytes) available in the queue.
 */
/* BEGIN CSTYLED */
#define	LDC_QUEUE_SPACE_AVAILABLE(head, tail, qsize, element_size)	\
	.pushlocals;							\
	brz,a	qsize, 1f;	/* no space available if qsize is 0 */	\
	clr	head;							\
	brz,a,pn head, 0f;	/* cannot fill queue completely so.. */	\
	sub	qsize, element_size, qsize;	/* adjust qsize if.. */	\
0:						/* head  is zero */	\
	sub	head, tail, head;	/* space = (head - tail) ... */	\
	sub	head, element_size, head;	/* minus 1 element */	\
	brlz,a	head, 1f;		/* If negative value, then */	\
	sub	qsize, tail, head;	/* space = (size - tail) */	\
1:									\
	.poplocals
/* END CSTYLED */


/*
 * For LDC, we use the FPGA interrupt status bits for LDC specific
 * purposes that don't quite map well to thier original names in the
 * context of service mailboxes.
 */
#define	SP_LDC_SPACE		QINTR_ACK
#define	SP_LDC_DATA		QINTR_BUSY
#define	SP_LDC_STATE_CHG	QINTR_NACK

/*
 * Send the SP an interrupt on the LDC IN channel.
 */
/* BEGIN CSTYLED */
/*
 * Assume for now, that we are not adding any header information
 * to the LDC packets as they go through the SRAM. This assumption
 * will break if the sram_ldc_qentry struct changes.
 */
#define	LDC_SRAM_Q_EL_SIZE_SHIFT	Q_EL_SIZE_SHIFT

/*
 * NOTE: If SRAM_LDC_QENTRY_SIZE remains a power of 2, then we can
 * use shifts. Otherwise, we will have to use mulx/udivx.
 */
#define	LDC_SRAM_IDX_TO_OFFSET(idx)			\
	sllx	idx, LDC_SRAM_Q_EL_SIZE_SHIFT, idx

#define	LDC_SRAM_OFFSET_TO_IDX(offset)			\
	srlx	offset, LDC_SRAM_Q_EL_SIZE_SHIFT, offset

#define	LDC_IDX_TO_OFFSET(idx)				\
	sllx	idx, Q_EL_SIZE_SHIFT, idx

#define	LDC_OFFSET_TO_IDX(offset)			\
	srlx	offset, Q_EL_SIZE_SHIFT, offset


/*
 * following must be defined (identically) on both sides of the _ASM boundary
 */
#endif	/* } CONFIG_FPGA */

	/* FIXME: see comment below about structures used by CONFIG_FPGA */
#if 1 || defined(CONFIG_FPGA)
#define	SRAM_LDC_ENTRIES_PER_QUEUE 4
#endif

#ifndef _ASM

/*
 * Each LDC endpoint has a Tx and Rx interrupt associated
 * with it. the mapreg structure stores the INO, the target
 * CPU and guest specified cookie for the interrupt.
 * It also stores info on whether the interrupt is valid,
 * along with its current state.
 *
 * There is a back pointer to the endpoint the interrupt
 * is associated with
 */
typedef struct ldc_mapreg	ldc_mapreg_t;

struct ldc_mapreg {
	uint32_t	state;		/* interrupt state */
	uint8_t		valid;		/* valid ? */

	uint64_t	ino;		/* devino -- from MD */
	uint64_t	pcpup;		/* tgt cpu to which notif sent */
	uint64_t	cookie;		/* intr cookie sent to the tgt cpu */

	uint64_t	endpoint;	/* endpoint to which this belongs */
};

/*
 * An LDC endpoint within a guest or hypervisor
 * Dont need a global LDC structure, since Zeus maintains the
 * global information.
 */

typedef struct ldc_endpoint	ldc_endpoint_t;
typedef struct ldce_parse	ldce_parse_t;

struct ldce_parse {
	resource_t	res;
	uint8_t		svc_id;
	uint8_t		is_private;
	uint8_t		target_type;
	uint16_t	target_channel;
	uint16_t	channel;
	uint16_t	tx_ino;
	uint16_t	rx_ino;
	struct guest	*target_guestp;
};

struct ldc_endpoint {
	/* Note: channel_idx must be first element in endpoint struct */
	uint8_t		channel_idx;	/* channel index */
	uint8_t		is_live;	/* is non-zero if LDC channel is open */
	uint8_t		is_private;	/* private svc guest endpoint */
	uint8_t		svc_id;
	uint8_t		rx_updated;	/* updated Rx queue was updated */

	uint8_t		txq_full;	/* flag used for TX notifications */

	uint64_t	tx_qbase_ra;
	uint64_t	tx_qbase_pa;
	uint64_t	tx_qsize;
	uint32_t	tx_qhead;
	uint32_t	tx_qtail;

	uint64_t	tx_cb;		/* Tx callback */
	uint64_t	tx_cbarg;	/* Tx callback arg */

	struct ldc_mapreg tx_mapreg;

	uint64_t	rx_qbase_ra;
	uint64_t	rx_qbase_pa;
	uint64_t	rx_qsize;
	uint32_t	rx_qhead;
	uint32_t	rx_qtail;

	uint64_t	rx_cb;		/* Rx callback */
	uint64_t	rx_cbarg;	/* Rx callback arg */

	struct ldc_mapreg rx_mapreg;

	vdev_mapreg_t *rx_vintr_cookie;

	/*
	 * The other end point for sending to
	 * Must be in another guest .. and another cpu
	 * 	! Zeus takes care of this
	 */
	uint8_t		target_type;	/* guest, HV, or SP */
	struct guest 	*target_guest;
	uint64_t	target_channel;

	uint64_t	map_table_ra;		/* RA of assigned map table */
	uint64_t	map_table_pa;		/* PA of assigned map table */
	uint64_t	map_table_nentries;	/* Map table entries */
	uint64_t	map_table_sz;		/* Size of map table */

	ldce_parse_t	pip;
};

/*
 * LDC devino to endpoint mapping
 *
 * For each device INO the corresponfing channel enpoint
 * is kept in a lookup table for fast access. This allows
 * all interrupt mgmt calls to obtain the corresponding
 * endpoint quickly
 */
struct ldc_ino2endpoint {
	void	*endpointp;
	void	*mapregp;
};


extern ldc_endpoint_t			hv_ldcs[];
extern struct guest_console_queues	cons_queues[];

/*
 * LDC shared memory mapin entry
 */

struct ldc_mapin {
	uint64_t	pa;
#define	ldc_mapin_next_idx	pa	/* use as next_idx field when free */

	uint64_t	mmu_map;

	uint64_t	io_va;
	uint64_t	va;
	uint16_t	va_ctx;

	uint16_t	local_endpoint;

	uint8_t		pg_size;
	uint8_t		perms;

	uint32_t	map_table_idx;
};


/*
 * space for guest to guest console queues is allocated in HV memory
 */
struct guest_console_queues {
	uint8_t	cons_rxq[Q_EL_SIZE * LDC_CONS_QSIZE];
	uint8_t	cons_txq[Q_EL_SIZE * LDC_CONS_QSIZE];
};

/*
 * XXX - For the moment the offsets generation
 * can't handle the fact that we may not define these
 * structures in all cases, so we have to have these defines
 * enabled even if CONFIG_FPGA is not defined (sigh)
 */

#if 1 || defined(CONFIG_FPGA)	/* { */

/*
 * These structures describes the Queue/header structure as laid out in SRAM
 * for use by both Hypervisor and VBSC.
 * Obviously this represents an interface of sorts between HV and VBSC and
 * thus we have to keep these structure definitions in sync between HV and
 * VBSC.
 *
 * N.B. All accesses to the SRAM must be single byte (uint8_t) so that the
 * read or write operation is atomic. Thus the fields in our SRAM struct
 * are all uint8_t. This mean we have to store a head/tail index rather
 * than offset so that it fits within a single byte.
 */

struct sram_ldc_qentry {
	uint64_t	pkt_data[8];		/* 64 byte packets */
};

typedef struct sram_ldc_qd sram_ldc_qd_t;

/*
 * If CONFIG_SPLIT_SRAM is defined, the queue data is stored separately
 * from the queue descriptor data
 */
#ifdef CONFIG_SPLIT_SRAM
typedef struct sram_ldc_q_data sram_ldc_q_data_t;
#endif

struct sram_ldc_qd {
#ifndef CONFIG_SPLIT_SRAM
	struct sram_ldc_qentry	ldc_queue[SRAM_LDC_ENTRIES_PER_QUEUE];
#endif
	uint8_t	head;		/* head index for queue */
	uint8_t	tail;		/* tail index for queue */
	uint8_t	state;		/* link UP (1) or DOWN (0) */
	uint8_t	state_updated;	/* flag indicating link has been reset */
	uint8_t	state_notify;	/* flag indicating reset notification */
#ifndef CONFIG_SPLIT_SRAM
	uint8_t	padding[59];	/* reserve some space for future */
#endif
};

#ifdef CONFIG_SPLIT_SRAM
struct sram_ldc_q_data {
	struct sram_ldc_qentry	ldc_queue[SRAM_LDC_ENTRIES_PER_QUEUE];
};
#endif

/*
 * SP LDC Endpoint
 */
typedef struct sp_ldc_endpoint sp_ldc_endpoint_t;

struct sp_ldc_endpoint {
	/* Note: channel_idx must be first element in endpoint struct */
	uint8_t		channel_idx;	/* channel index */
	uint8_t		is_live;	/* is non-zero if LDC channel is open */
	uint8_t		target_type;	/* guest or HV */

	sram_ldc_qd_t *tx_qd_pa;
	sram_ldc_qd_t *rx_qd_pa;
#ifdef CONFIG_SPLIT_SRAM
	sram_ldc_q_data_t *tx_q_data_pa;
	sram_ldc_q_data_t *rx_q_data_pa;
#endif

	struct guest 	*target_guest;	/* The guest at the other endpoint */
	uint64_t	target_channel;	/* Channel num of the other endpt */
	uint64_t	tx_lock;	/* synchronize access to endpoints */
	uint64_t	rx_lock;	/* synchronize access to endpoints */

	uint32_t	tx_scr_txhead;	/* use freely if you own tx_lock */
	uint32_t	tx_scr_txtail;	/* use freely if you own tx_lock */
	uint64_t	tx_scr_txsize;	/* use freely if you own tx_lock */
	uint64_t	tx_scr_tx_qpa;	/* use freely if you own tx_lock */
	uint32_t	tx_scr_rxhead;	/* use freely if you own tx_lock */
	uint32_t	tx_scr_rxtail;	/* use freely if you own tx_lock */
	uint64_t	tx_scr_rxsize;	/* use freely if you own tx_lock */
	uint64_t	tx_scr_rx_qpa;	/* use freely if you own tx_lock */
#ifdef CONFIG_SPLIT_SRAM
	uint64_t	tx_scr_rx_qdpa;	/* use freely if you own tx_lock */
#endif
	uint64_t	tx_scr_target;	/* use freely if you own tx_lock */

	uint32_t	rx_scr_txhead;	/* use freely if you own rx_lock */
	uint32_t	rx_scr_txtail;	/* use freely if you own rx_lock */
	uint64_t	rx_scr_txsize;	/* use freely if you own rx_lock */
	uint64_t	rx_scr_tx_qpa;	/* use freely if you own rx_lock */
#ifdef CONFIG_SPLIT_SRAM
	uint64_t	rx_scr_tx_qdpa;	/* use freely if you own rx_lock */
#endif
	uint32_t	rx_scr_rxhead;	/* use freely if you own rx_lock */
	uint32_t	rx_scr_rxtail;	/* use freely if you own rx_lock */
	uint64_t	rx_scr_rxsize;	/* use freely if you own rx_lock */
	uint64_t	rx_scr_rx_qpa;	/* use freely if you own rx_lock */
	uint64_t	rx_scr_target;	/* use freely if you own rx_lock */

	struct sram_ldc_qentry rx_scr_pkt;	/* scratch buffer */
};

extern sp_ldc_endpoint_t sp_ldcs[];

#endif	/* } CONFIG_FPGA */


#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _LDC_H */
