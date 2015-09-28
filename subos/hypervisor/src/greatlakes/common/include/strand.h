/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: strand.h
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

#ifndef _STRAND_H
#define	_STRAND_H

#pragma ident	"@(#)strand.h	1.1	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	STRAND_STACK_SIZE	(64*1024)

#define	NUM_SCHED_SLOTS	2

/* These should become HV jump addresses */
/* Leave them as values for now to ease debugging */
#define	SLOT_ACTION_NOP		0x0
#define	SLOT_ACTION_RUN_VCPU	0x1

/* These mail box commands to go away with a proper Q */
#define	HXMB_IDLE		0x0
#define	HXMB_BUSY		(-1LL)	/* to go away with proper Q */
#define	HXMB_NEWMONDO		0x1

/* These commands are put into the first word of the mondo sent */

/* SCHED, DESCHED and STOP all use the hvm_sched struct as payload */
#define	HXCMD_SCHED_VCPU	0x1	/* start a vcpu from stop/suspend */
#define	HXCMD_DESCHED_VCPU	0x2	/* suspend a vcpu */
#define	HXCMD_STOP_VCPU		0x3	/* stop a vcpu */
/* SCRUB uses the hvm_scrub payload */
#define	HXCMD_SCRUBMEM		0x4
/* GUEST commands all use the hvm_guestcmd struct as payload */
#define	HXCMD_GUEST_SHUTDOWN	0x5	/* initiate a guest shutdown */
#define	HXCMD_GUEST_PANIC	0x6	/* initiate a guest panic */
#define	HXCMD_STOP_GUEST	0x7	/* force a remote guest to stop */

/*
 * mini-stack depth for each strand
 */
#define	MINI_STACK_DEPTH	48

/*
 * Number of per-strand scratch locations
 */
#define	NSTRANDSCRATCH		8


#ifndef _ASM

/*
 * Packet formats for the HV mondo messages
 */

typedef	struct hvm_sched {
	uint64_t	vcpup;
} hvm_sched_t;

typedef struct hvm_scrub {
	uint64_t	start_pa;
	uint64_t	len;
} hvm_scrub_t;

typedef struct hvm_guestcmd {
	uint64_t	vcpup;
	uint64_t	arg;
} hvm_guestcmd_t;

typedef struct hvm_stopguest {
	uint64_t	guestp;
} hvm_stopguest_t;

typedef	struct hvm {
	uint64_t	cmd;
	uint64_t	from_strandp;
	union {
		hvm_sched_t	sched;
		hvm_scrub_t	scrub;
		hvm_guestcmd_t	guestcmd;
		hvm_stopguest_t	stopguest;
		uint64_t	raw[6];
	} args;
} hvm_t;

typedef struct strand		strand_t;
typedef struct sched_slot	sched_slot_t;
typedef	struct xcall_mbox	xcall_mbox_t;	/* To be upgraded */

struct sched_slot	{
	uint64_t	action;
	uint64_t	arg;
};


struct xcall_mbox {
	uint64_t	command;
	uint64_t	mondobuf[8];
};

extern void c_hvmondo_send(strand_t *destp, hvm_t *msgp);

/*
 * Mini stack support
 *
 * Each strand has a very simple work stack.  Only 2 operations are supported:
 * Push and Pop. In the event the stack gets full or under poped, HV will
 * abort.
 */
struct mini_stack {
	uint64_t	ptr;			/* ptr */
	uint64_t	val[MINI_STACK_DEPTH];	/* value */
};

extern strand_t strands[];

#endif /* !_ASM */

#include <platform/strand.h>

#ifdef __cplusplus
}
#endif

#endif /* _STRAND_H */
