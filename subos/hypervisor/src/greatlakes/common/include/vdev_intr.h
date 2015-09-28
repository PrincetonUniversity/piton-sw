/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vdev_intr.h
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

#ifndef _VDEV_INTR_H
#define	_VDEV_INTR_H

#pragma ident	"@(#)vdev_intr.h	1.13	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <hypervisor.h>
#include <hprivregs.h>
#include <intr.h>

/* BEGIN CSTYLED */

/*
 *                                                   vino2inst
 *                                                   +--------+
 *     dev2inst                                   0x0|        |
 *    +--------+                                     +--------+
 * 0x0|        |           devinstances              |        |
 *    +--------+       +---------+--------+          +--------+
 *    |        |       |         |        |          |        |
 *    +--------+       +---------+--------+          +--------+
 *    | inst  -+-------> *cookiep| *ops   |    +-----|  inst  |
 *    +--------+       +---------+--------+    |     +--------+
 *    |        |       |         |        |    |     ..........
 *    +--------+       +---------+--------+    |     ..........
 *    ..........       | *cookiep| *ops   <----+     ..........
 *    ..........       +---------+--------+          ..........
 *    ..........       |         |        |          |        |
 *    ..........       +---------+--------+          +--------+
 *    |        |       | *cookiep| *ops   |--+       |        |
 *    +--------+       +---------+--------+  |       +--------+
 *    |        |                             |       |        |
 *    +--------+             devops          |       +--------+
 *    |        |           +----------+<---- +       |        |
 *    +--------+           | dev2vino |              +--------+
 *    |        |           +----------+         0x7ff|        |
 *    +--------+           | getvalid |              +--------+
 *0x1f|        |           +----------+
 *    +--------+           | setvalid |
 *                         +----------+
 *                         | getstate |
 *                         +----------+
 *                         | setstate |
 *                         ............
 *                         ............
 *                         ............
 *                         ............
 *                         +----------+
 *                         |          |
 *                         +----------+
 *                         |          |
 *                         +----------+
 *
 */


#define	NDEVIDS		0x20
#define	DEVIDMASK	(NDEVIDS - 1)
#define	NINOSPERDEV	64
#define	DEVINOMASK	(NINOSPERDEV - 1)
#define	NVINOS		(NINOSPERDEV * NDEVIDS)
#define NFIREDEVS	2


/*
 * Number of devinstances
 * defined to be <= 256 so a single byte
 * can be used to hold an index value to this table.
 */

#define	NDEV_INSTS	256

#define	DEVCFGPA_MASK	0x1f
#define	DEVCFGPA_SHIFT	6


/*
 * Find the "opsvec" structure for a "vino"
 */
#define	VINO2DEVINST(guest, vino, devinst, faillabel)	\
	cmp	vino, NVINOS				;\
	bgeu,pn	%xcc, faillabel				;\
	sethi	%hi(GUEST_VINO2INST), devinst		;\
	or	devinst, %lo(GUEST_VINO2INST), devinst	;\
	add	guest, devinst, devinst			;\
	ldub	[devinst + vino], devinst		;\
	brz,pn	devinst, faillabel			;\
	nop

/*
 * Get the cookie for a devinst
 *
 * devinst and cookie may be the same register
 */
#define	DEVINST2COOKIE(guest, devinst, cookie, scr, faillabel)	\
	brz,pn	devinst, faillabel			;\
	sllx	devinst, DEVINST_SIZE_SHIFT, cookie	;\
	ldx	[guest + GUEST_CONFIGP], scr		;\
	ldx	[scr + CONFIG_DEVINSTANCES], scr	;\
	add	scr, cookie, cookie			;\
	ldx	[cookie + DEVINST_COOKIE], cookie
	
/*
* Find the "opsvec" structure for devhandle "handle"
*/
#define	_DEVHANDLE2DEVINST(handle, opsvec, faillabel)	\
	btst	DEVINOMASK, handle			;\
	bnz,pn	%xcc, faillabel				;\
	srlx	handle, DEVCFGPA_SHIFT, opsvec		;\
	and	opsvec, DEVIDMASK, opsvec 

#define	DEVINST2INDEX(guest, devinst, index, scr, faillabel) \
	add	guest, GUEST_DEV2INST, scr		;\
	ldub	[scr + devinst], index			;\
	brz	index, faillabel			;\
	nop

#define	_DEVHANDLE2OPSVEC(guest, handle, opsvec, scr, faillabel) \
	_DEVHANDLE2DEVINST(handle, opsvec, faillabel)	;\
	DEVINST2INDEX(guest, opsvec, opsvec, scr, faillabel)

/*
 * Jump to a opsvec[devop] with a pointer to the "cookie"
 */
#define	_JMPL_DEVOP(guest, devinst, devop, cookie, faillabel) \
	sllx	devinst, DEVINST_SIZE_SHIFT, devinst	;\
	ldx	[guest + GUEST_CONFIGP], cookie		;\
	ldx	[cookie + CONFIG_DEVINSTANCES], cookie	;\
	add	cookie, devinst, cookie			;\
	ldx	[cookie + DEVINST_OPS], devinst		;\
	brz,pn	devinst, faillabel			;\
	ldx	[cookie + DEVINST_COOKIE], cookie	;\
	ldx	[devinst + devop], devinst		;\
	brz,pn	devinst, faillabel			;\
	nop						;\
	jmpl	devinst, %g0				;\
	nop

/*
 * Jmp to "devop" for "vino" with pointer to the "cookie"
 */
#define	JMPL_VINO2DEVOP(vino, devop, cookie, scr, label) \
	GUEST_STRUCT(cookie)				;\
	VINO2DEVINST(cookie, vino, scr, label)		;\
	_JMPL_DEVOP(cookie, scr, devop, cookie, label)

/*
 * Jmp to "devop" of device "handle" with "cookie"
 */
#define	JMPL_DEVHANDLE2DEVOP(handle, devop, cookie, scr1, scr2, faillabel) \
	GUEST_STRUCT(cookie)					;\
	_DEVHANDLE2OPSVEC(cookie, handle, scr1, scr2, faillabel) ;\
	_JMPL_DEVOP(cookie, scr1, devop, cookie, faillabel)
/* END CSTYLED */

/*
 * The virtual interrupt management framework.
 * When a guest binds to a vintr we lookup the virtual->physical
 * mapping and store the physical cpu info in the vintr table.
 */

#define	NUM_VINTRS	64	/* Must be a power of two */
#define	VINTR_INO_MASK	(NUM_VINTRS - 1)


/* BEGIN CSTYLED */

/* guest and vdevstate may NOT be the same register */
#define	GUEST2VDEVSTATE(guest, vdevstate)		\
	set	GUEST_VDEV_STATE, vdevstate		; \
	add	guest, vdevstate, vdevstate


/* vino and mapreg may be the same register */
#define	VINO2MAPREG(state, vino, mapreg)		\
	and	vino, DEVINOMASK, mapreg		; \
	sllx	mapreg, MAPREG_SHIFT, mapreg		; \
	add	state, mapreg, mapreg			; \
	add	mapreg, VDEV_STATE_MAPREG, mapreg

/* END CSTYLED */


#ifndef _ASM


struct devinst {
	void		*cookie;
	struct devopsvec *ops;
};

typedef struct devinst devinst_t;
extern devinst_t devinstances[];


/*
 * Virtual INO to Device Instance
 *
 * This byte array contains the indexes into array of struct devinst
 *
 * It is used to go from vINO => device instance
 */

typedef struct vino2inst vino2inst_t;

struct vino2inst {
	uint8_t	vino [NVINOS];
};

typedef struct vino_pcie vino_pcie_t;
struct vino_pcie {
	uint8_t vino [NPCIEDEVS][NINOSPERDEV];
};
extern const struct vino2inst config_vino2inst;
extern const uint8_t config_dev2inst[NDEVIDS];
extern const struct vino_pcie config_pcie_vinos;

/*
 * Virtual Interrupt Mapping Register (vmapreg), one per interrupt
 *
 * The virtual mapping register is split into two 32-bit words.  The
 * first word is modified by the hypervisor asynchronously.  The
 * second word contains state that is modified by the guest.
 *
 * The state field contains a sun4v interrupt state:
 * INTR_IDLE (0), INTR_RECEIVED (1), INTR_DELIVERED (2)
 *
 * The physical cpu number (pcu) is cached in the vmapreg and
 * is a translation of the guest's virtual cpu number.
 * This framework will require changes to support Dynamic
 * Reconfiguration (DR) of processors.
 * pcpu is never returned to a guest; this is for reverse lookup
 *
 * XXX have a flag or a pointer to 7 words to use in addition to data0
 */

typedef struct vdev_mapreg vdev_mapreg_t;

struct vdev_mapreg {
	uint8_t		state;
	uint8_t		valid;
	uint16_t	pcpu;
	uint16_t	vcpu;
	uint8_t		ino;
	uint8_t		reserved;
	uint64_t	data0;
	uint64_t	devcookie;
	uint64_t	getstate;
	uint64_t	setstate;
	uint64_t	_padding[3];
};


/*
 * vdev nexus state structure, one per guest
 */

typedef struct vdev_state vdev_state_t;

struct vdev_state {
	uint64_t	handle;
	struct vdev_mapreg mapreg[NUM_VINTRS];
	uint16_t	inomax;		/* Max INO */
	uint16_t	vinobase;	/* First Vino */
};


/*
 * Definitions for vdev_intr_register & its C wrapper
 */
typedef int (*intr_getstate_f)(void *);
typedef void (*intr_setstate_f)(void *, int);

extern uint64_t c_vdev_intr_register(void *, int, void *,
    intr_getstate_f, intr_setstate_f);

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _VDEV_INTR_H */
