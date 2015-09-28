/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_memory.c
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
 * Copyright 2007 Sun Microsystems, Inc.	 All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident	"@(#)res_memory.c	1.5	07/06/07 SMI"

#include <stdarg.h>

#include <sys/htypes.h>
#include <traps.h>
#include <cache.h>
#include <mmu.h>
#include <sun4v/asi.h>
#include <vdev_intr.h>
#include <ncs.h>
#include <cyclic.h>
#include <support.h>
#include <strand.h>
#include <vcpu.h>
#include <guest.h>
#include <memory.h>
#include <pcie.h>
#include <vdev_ops.h>
#include <fpga.h>
#include <ldc.h>
#include <config.h>
#include <offsets.h>
#include <hvctl.h>
#include <md.h>
#include <abort.h>
#include <hypervisor.h>
#include <proto.h>
#include <debug.h>

/*
 * (re)-configuration code to handle HV memory resources
 *
 * We could use the resource identifier in each mblock of the
 * Hypervisor MD to simply identify memory blocks for (re/un)config
 * however for the moment - until code cleanup - we still treat memory
 * blocks as components of the guest structure for the purpose of
 * addition and removal.
 */

static void res_memory_commit_config(mblock_t *mbp);
static void res_memory_commit_unconfig(mblock_t *mbp);
static void res_memory_commit_modify(mblock_t *mbp);



void
init_ra2pa_segment(ra2pa_segment_t *rsp)
{
	rsp->limit = 0LL;
	rsp->base = -1LL;
	rsp->offset = -1LL;
	rsp->flags = INVALID_SEGMENT;
}

void
assign_ra2pa_segments(guest_t *guestp, uint64_t real_base,
		uint64_t size, uint64_t ra2pa_offset, uint8_t flags)
{
	uint64_t	idx;
	uint64_t	eidx;
	uint64_t	limit;

	DBG(c_printf("\t\tG 0x%x : [0x%x + 0x%x] -> 0x%x : slots",
	    guestp->guestid, real_base, size, real_base + ra2pa_offset));

	limit = real_base+size;

	idx = real_base >> RA2PA_SHIFT;
	eidx = (limit-1) >> RA2PA_SHIFT;

	ASSERT(eidx < NUM_RA2PA_SEGMENTS);

	while (idx <= eidx) {
		ra2pa_segment_t *sp;

		DBG(c_printf(" 0x%x", idx));

		sp = &(guestp->ra2pa_segment[idx]);

		sp->base = real_base;
		sp->limit = limit;
		sp->offset = ra2pa_offset;
		sp->flags = flags;
		idx++;
	}

	DBG(c_printf("\n"));
}



void
clear_ra2pa_segments(guest_t *guestp, uint64_t real_base,
		uint64_t size)
{
	uint64_t	idx;
	uint64_t	eidx;
	uint64_t	limit;

	DBG(c_printf("\t\tG 0x%x : [0x%x + 0x%x] -> XX : slots",
	    guestp->guestid, real_base, size));

	limit = real_base+size;

	idx = real_base >> RA2PA_SHIFT;
	eidx = (limit-1) >> RA2PA_SHIFT;

	ASSERT(eidx < NUM_RA2PA_SEGMENTS);

	while (idx <= eidx) {
		ra2pa_segment_t *sp;

		DBG(c_printf(" 0x%x", idx));

		sp = &(guestp->ra2pa_segment[idx]);
		init_ra2pa_segment(sp);
		idx++;
	}

	DBG(c_printf("\n"));
}


void
init_mblocks()
{
	mblock_t	*mbp;
	int		i;

	mbp = config.mblocks;

	for (i = 0; i < NMBLOCKS; i++, mbp++) {
		mbp->state = MBLOCK_STATE_UNCONFIGURED;
	}
}


	/*
	 * This goes through a global pool of memory blocks
	 * allocated by Zeus.
	 */
void
res_memory_prep()
{
	mblock_t	*mbp;
	int		i;

	mbp = config.mblocks;

	for (i = 0; i < NMBLOCKS; i++, mbp++) {
		mbp->pip.res.flags = mbp->state == MBLOCK_STATE_UNCONFIGURED ?
		    RESF_Noop : RESF_Unconfig;
	}
}


hvctl_status_t
res_memory_parse(bin_md_t *mdp, hvctl_res_error_t *fail_codep,
		md_element_t **failnodepp, int *fail_res_idp)
{
	md_element_t	*mdep;
	uint64_t	arc_token;
	uint64_t	node_token;
	md_element_t	*mbnodep;
	mblock_t	*mbp;
	int		i;

	mdp = (bin_md_t *)config.parse_hvmd;

	mdep = md_find_node(mdp, NULL, MDNAME(memory));
	if (mdep == NULL) {
		DBG(c_printf("Missing cpus node in HVMD\n"));
		*failnodepp = NULL;
		*fail_res_idp = 0;
		goto fail;
	}

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(mblock));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep, arc_token,
	    node_token, &mbnodep))) {

		uint64_t	guestid;
		uint64_t	res_id;
		uint64_t	membase;
		uint64_t	memsize;
		uint64_t	realbase;
		md_element_t	*guestnodep;

		if (!md_node_get_val(mdp, mbnodep,
		    MDNAME(resource_id), &res_id)) {
			DBG(c_printf("Missing resource_id in mblock node\n"));
			*fail_codep = HVctl_e_mblock_missing_id;
			*fail_res_idp = 0;
			goto fail;
		}
		if (res_id >= NMBLOCKS) {
			DBG(c_printf("Invalid resource_id in mblock node\n"));
			*fail_codep = HVctl_e_mblock_invalid_id;
			*fail_res_idp = 0;
			goto fail;
		}

		*fail_res_idp = res_id;

		DBG(c_printf("res_memory_parse(0x%x)\n", res_id));

		if (!md_node_get_val(mdp, mbnodep, MDNAME(membase), &membase)) {
			DBG(c_printf("Missing membase in mblock node\n"));
			*fail_codep = HVctl_e_mblock_missing_membase;
			goto fail;
		}
		if (!md_node_get_val(mdp, mbnodep, MDNAME(memsize), &memsize)) {
			DBG(c_printf("Missing memsize in mblock node\n"));
			*fail_codep = HVctl_e_mblock_missing_memsize;
			goto fail;
		}
			/* FIXME: test legit PA range(s) */
		if ((membase + memsize) <= membase) {
			DBG(c_printf("Invalid physical address range in "
			    "mblock node\n"));
			*fail_codep = HVctl_e_mblock_invalid_parange;
			goto fail;
		}
		if (!md_node_get_val(mdp, mbnodep,
		    MDNAME(realbase), &realbase)) {
			DBG(c_printf("Missing realbase in mblock node\n"));
			*fail_codep = HVctl_e_mblock_missing_realbase;
			goto fail;
		}
			/* FIXME: test legit range(s) */
		if ((realbase + memsize) <= realbase) {
			DBG(c_printf("Invalid physical address range in "
			    "mblock node\n"));
			*fail_codep = HVctl_e_mblock_invalid_rarange;
			goto fail;
		}

			/* Which guest is this mblock assigned to? */

		if (NULL == md_find_node_by_arc(mdp, mbnodep,
		    MDARC(MDNAME(back)), MDNODE(MDNAME(guest)), &guestnodep)) {
			DBG(c_printf("Missing back arc to guest node in "
			    "mblock node\n"));
			*fail_codep = HVctl_e_mblock_missing_guest;
			goto fail;
		}

		if (!md_node_get_val(mdp, guestnodep, MDNAME(resource_id),
		    &guestid)) {
			DBG(c_printf("Missing gid in guest node\n"));
			*fail_codep = HVctl_e_guest_missing_id;
			goto fail;
		}

			/*
			 * NOTE: This is probably redundant given that we
			 * have likely parsed the guest nodes once already
			 */
		if (guestid >= NGUESTS) {
			DBG(c_printf("Invalid gid in guest node\n"));
			*fail_codep = HVctl_e_guest_invalid_id;
			goto fail;
		}


		/*
		 * Now determine if any changes are relevent
		 */

		mbp = config.mblocks;
		mbp = &(mbp[res_id]);

		mbp->pip.membase = membase;
		mbp->pip.memsize = memsize;
		mbp->pip.realbase = realbase;
		mbp->pip.guestid = guestid;

		if (mbp->state == MBLOCK_STATE_UNCONFIGURED) {
			DBG(c_printf("\t\tElected to config mblock 0x%x\n",
			    res_id));
			mbp->pip.res.flags = RESF_Config;
		} else {
			/* an mblock cannot be rebound between guests */
			if (mbp->guestid != guestid) {
				DBG(c_printf("Rebinding mblocks not "
				    "allowed\n"));
				*fail_codep = HVctl_e_mblock_rebind_na;
				goto fail;
			}

			if (mbp->membase == membase &&
			    mbp->memsize == memsize &&
			    mbp->realbase == realbase &&
			    mbp->guestid == guestid) {
				mbp->pip.res.flags = RESF_Noop;
			} else {
				mbp->pip.res.flags = RESF_Modify;
			}
		}
	}


	/*
	 * As a final check in the parse stage:
	 * Only allow a config/unconfig or rebind if guest is !active
	 * LDOMS20: Future hypervisors supporting a dynamic memory
	 * reconfigure will remove the check below, and must in-line
	 * force a TLB flush for each of the vcpus who's mblocks are
	 * unconfigured.
	 */

	mbp = config.mblocks;

	for (i = 0; i < NMBLOCKS; i++, mbp++) {
		guest_t	*gp;

		if (mbp->pip.res.flags == RESF_Noop) continue;

		gp = config.guests;

		if (mbp->state == MBLOCK_STATE_CONFIGURED) {
			gp = &(gp[mbp->guestid]);
		} else {
			gp = &(gp[mbp->pip.guestid]);
		}
	}

	return (HVctl_st_ok);
fail:;
	return (HVctl_st_badmd);
}

hvctl_status_t
res_memory_postparse(hvctl_res_error_t *res_error, int *fail_res_id)
{
	return (HVctl_st_ok);
}

void
res_memory_commit(int flag)
{
	mblock_t	*mbp;
	int	i;

	mbp = config.mblocks;

	for (i = 0; i < NMBLOCKS; i++, mbp++) {
		/* if not this ops turn move on */
		if (mbp->pip.res.flags != flag) continue;

		switch (mbp->pip.res.flags) {
		case RESF_Noop:
			DBG(c_printf("mblock 0x%x : noop\n", i));
			break;
		case RESF_Unconfig:
			res_memory_commit_unconfig(mbp);
			break;
		case RESF_Config:
			res_memory_commit_config(mbp);
			break;
		case RESF_Rebind:
			DBG(c_printf("guest 0x%x : rebind\n", i));
			ASSERT(0);	/* not supported */
			break;
		case RESF_Modify:
			res_memory_commit_modify(mbp);
			break;
		default:
			ASSERT(0);
		}

		mbp->pip.res.flags = RESF_Noop; /* cleanup */
	}
}




void
res_memory_commit_config(mblock_t *mbp)
{
	guest_t *gp;

	ASSERT(mbp->state == MBLOCK_STATE_UNCONFIGURED);

	mbp->realbase = mbp->pip.realbase;
	mbp->membase = mbp->pip.membase;
	mbp->memsize = mbp->pip.memsize;
	mbp->guestid = mbp->pip.guestid;

	gp = config.guests;
	gp = &(gp[mbp->guestid]);

	assign_ra2pa_segments(gp, mbp->realbase, mbp->memsize,
	    mbp->membase - mbp->realbase, MEM_SEGMENT);

	mbp->state = MBLOCK_STATE_CONFIGURED;
}


void
res_memory_commit_unconfig(mblock_t *mbp)
{
	guest_t *gp;

	ASSERT(mbp->state == MBLOCK_STATE_CONFIGURED);

	gp = config.guests;
	gp = &(gp[mbp->guestid]);

	clear_ra2pa_segments(gp, mbp->realbase, mbp->memsize);

	mbp->state = MBLOCK_STATE_UNCONFIGURED;
}



	/*
	 * Modify is somewhat tricky, as it involves updating all the
	 * memory segments to account for what may have been movement
	 * shrinkage, or growth in the given mblock.
	 * Since this is constrained to be done while the assigned guest
	 * is not alive, we implement this simply as a call to unconfig
	 * followed by a call to config.
	 * LDOMS20: This interface has to be enhanced to force a TLB flush
	 * for all the active vcpus on the affected guest to remove
	 * any stale TLB and permanent mappings. The perm mapping table
	 * also needs scouring for stale entries.
	 */
void
res_memory_commit_modify(mblock_t *mbp)
{
	res_memory_commit_unconfig(mbp);
	res_memory_commit_config(mbp);
}
