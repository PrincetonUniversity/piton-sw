/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_vcpu.c
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

#pragma ident	"@(#)res_vcpu.c	1.8	07/07/09 SMI"

#include <stdarg.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <traps.h>
#include <cache.h>
#include <mmu.h>
#include <sun4v/asi.h>
#include <sun4v/errs_defs.h>
#include <vdev_intr.h>
#include <ncs.h>
#include <cyclic.h>
#include <support.h>
#include <strand.h>
#include <vcpu.h>
#include <guest.h>
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


/*
 * (re)-configuration code to handle HV vcpu resources
 */

static hvctl_status_t
res_vcpu_parse_1(bin_md_t *mdp, md_element_t *cpunodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp);
static void res_vcpu_commit_config(vcpu_t *vcpup);
static void res_vcpu_commit_unconfig(vcpu_t *vcpup);


/*
 * vcpu support functions.
 */
void
init_vcpu(int i)
{
	vcpu_t *vp;

	vp = (vcpu_t *)config.vcpus;
	vp = &(vp[i]);

	c_bzero(vp, sizeof (*vp));

	vp->res_id = i;
	vp->status = CPU_STATE_UNCONFIGURED;
}


void
res_vcpu_prep()
{
	vcpu_t	*vp;
	int	i;

	vp = config.vcpus;

	for (i = 0; i < NVCPUS; i++, vp++) {
		vp->pip.res.flags = (vp->status == CPU_STATE_UNCONFIGURED) ?
		    RESF_Noop : RESF_Unconfig;
	}
}


hvctl_status_t
res_vcpu_parse(bin_md_t *mdp, hvctl_res_error_t *fail_codep,
			md_element_t **failnodepp, int *fail_res_idp)
{
	md_element_t	*mdep;
	uint64_t	arc_token;
	uint64_t	node_token;
	md_element_t	*cpunodep;

	mdp = (bin_md_t *)config.parse_hvmd;

	mdep = md_find_node(mdp, NULL, MDNAME(cpus));
	if (mdep == NULL) {
		DBG(c_printf("Missing cpus node in HVMD\n"));
		*failnodepp = NULL;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(cpu));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    arc_token, node_token, &cpunodep))) {
		hvctl_status_t status;
		status = res_vcpu_parse_1(mdp, cpunodep,
		    fail_codep, fail_res_idp);
		if (status != HVctl_st_ok) {
			*failnodepp = cpunodep;
			return (status);
		}
	}
	return (HVctl_st_ok);
}


hvctl_status_t
res_vcpu_parse_1(bin_md_t *mdp, md_element_t *cpunodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp)
{
	uint64_t	strand_id, res_id, vid, gid, parttag;
	vcpu_t		*vcpup;
	md_element_t	*guestnodep;

	DBGVCPU(md_dump_node(mdp, cpunodep));

	if (!md_node_get_val(mdp, cpunodep, MDNAME(resource_id), &res_id)) {
		DBGVCPU(c_printf("Missing resource_id in cpu node\n"));
		*fail_codep = HVctl_e_vcpu_missing_id;
		*fail_res_idp = 0;
		goto fail;
	}
	if (res_id >= NVCPUS) {
		DBGVCPU(c_printf("Invalid resource_id in cpu node\n"));
		*fail_codep = HVctl_e_vcpu_invalid_id;
		*fail_res_idp = 0;
		goto fail;
	}

	*fail_res_idp = res_id;

	DBGVCPU(c_printf("res_vcpu_parse_1(0x%x)\n", res_id));

	if (!md_node_get_val(mdp, cpunodep, MDNAME(pid), &strand_id)) {
		DBGVCPU(c_printf("Missing PID in cpu node\n"));
		*fail_codep = HVctl_e_vcpu_missing_strandid;
		goto fail;
	}
	if (strand_id >= NSTRANDS) {
		DBGVCPU(c_printf("Invalid PID in cpu node\n"));
		*fail_codep = HVctl_e_vcpu_invalid_strandid;
		goto fail;
	}

	/* Get virtual ID within guest */
	if (!md_node_get_val(mdp, cpunodep, MDNAME(vid), &vid)) {
		DBGVCPU(c_printf("Missing VID in cpu node\n"));
		*fail_codep = HVctl_e_vcpu_missing_vid;
		goto fail;
	}

	if (NULL == md_find_node_by_arc(mdp, cpunodep, MDARC(MDNAME(back)),
	    MDNODE(MDNAME(guest)), &guestnodep)) {
		DBGVCPU(c_printf(
		    "Missing back arc to guest node in cpu node\n"));
		*fail_codep = HVctl_e_vcpu_missing_guest;
		goto fail;
	}

	if (!md_node_get_val(mdp, guestnodep, MDNAME(resource_id), &gid)) {
		DBGVCPU(c_printf("Missing resource_id in guest node\n"));
		*fail_codep = HVctl_e_guest_missing_id;
		goto fail;
	}

	if (gid >= NGUESTS) {
		DBGVCPU(c_printf("Invalid resource_id in guest node\n"));
		*fail_codep = HVctl_e_guest_invalid_id;
		goto fail;
	}


	/* Get partid tag for this cpu */
	if (!md_node_get_val(mdp, cpunodep, MDNAME(parttag), &parttag)) {
		DBGVCPU(c_printf("WARNING: Missing parttag in cpu node - "
		"using guest id 0x%x\n", gid));
		parttag = gid;	/* use guest ID if none given */
	}


	DBGVCPU(c_printf("Virtual cpu 0x%x in guest 0x%x (vid 0x%x)\n",
	    res_id, gid, vid));


	/*
	 * Now determine the delta - if relevent...
	 */
	vcpup = config.vcpus;
	vcpup = &(vcpup[res_id]);

	vcpup->pip.strand_id = strand_id;
	vcpup->pip.vid = vid;
	vcpup->pip.guestid = gid;
	vcpup->pip.parttag = parttag;

	ASSERT(vcpup->status != CPU_STATE_INVALID);

	/*
	 * We can configure an unconfigured CPU.
	 * Cannot (yet) support the dynamic re-binding of
	 * a configured / running cpu.
	 */
	DBGVCPU(c_printf("\t\tCurrent cpu status = 0x%x\n", vcpup->status));

	if (vcpup->status == CPU_STATE_UNCONFIGURED) {
		DBGVCPU(c_printf("\t\tElected to config vcpu\n"));
		vcpup->pip.res.flags = RESF_Config;
	} else {
		if (vcpup->strand->id == strand_id &&
		    vcpup->vid == vid &&
		    vcpup->guest->guestid == gid &&
		    vcpup->parttag == parttag) {
			DBGVCPU(c_printf("\t\tElected to ignore vcpu\n"));
			vcpup->pip.res.flags = RESF_Noop;
		} else {
			DBGVCPU(c_printf("\t\tFailed MD update - no "
			"rebind live\n"));
			*fail_codep = HVctl_e_vcpu_rebind_na;
			goto fail;
		}
	}

	return (HVctl_st_ok);
fail:;
	return (HVctl_st_badmd);
}


hvctl_status_t
res_vcpu_postparse(hvctl_res_error_t *res_error, int *fail_res_id)
{
	return (HVctl_st_ok);
}


void
res_vcpu_commit(int flag)
{
	vcpu_t	*vp;
	int	i;

	vp = config.vcpus;

	for (i = 0; i < NVCPUS; i++, vp++) {
		/* if not this ops turn move on */
		DBGVCPU(c_printf("res_vcpu_commit: vcpuid 0x%x : state 0x%x : "
		    "flags 0x%x - opflag 0x%x\n",
		    vp->vid, vp->status, vp->pip.res.flags, flag));

		if (vp->pip.res.flags != flag) continue;

		switch (vp->pip.res.flags) {
		case RESF_Noop:
			DBGVCPU(c_printf("vcpu 0x%x : noop\n", i));
			break;
		case RESF_Unconfig:
			DBGVCPU(c_printf("vcpu 0x%x : unconfig\n", i));
			res_vcpu_commit_unconfig(vp);
			break;
		case RESF_Config:
			DBGVCPU(c_printf("vcpu 0x%x : config\n", i));
			res_vcpu_commit_config(vp);
			break;
		case RESF_Rebind:
			DBGVCPU(c_printf("vcpu 0x%x : rebind\n", i));
			ASSERT(0);	/* not supported */
			break;
		case RESF_Modify:
			DBGVCPU(c_printf("vcpu 0x%x : modify\n", i));
			ASSERT(0);	/* not supported */
			break;
		default:
			ASSERT(0);
		}

		vp->pip.res.flags = RESF_Noop; /* cleanup */
	}
}


void
res_vcpu_commit_config(vcpu_t *vcpup)
{
	strand_t	*strandp;
	guest_t		*guestp;

	DBGVCPU(c_printf("res_vcpu_commit_config\n"));

	/*
	 * Assign the vcpu its carrier strand.
	 * Note: this does not schedule the cpu.
	 */
	DBGVCPU(c_printf("\tBinding vcpu (res_id = 0x%x) to strand 0x%x as "
	    "vid 0x%x in guest 0x%x\n", vcpup->res_id,
	    vcpup->pip.strand_id, vcpup->pip.vid, vcpup->pip.guestid));

	strandp = config.strands;
	strandp = &(strandp[vcpup->pip.strand_id]);

	vcpup->strand = strandp;
	vcpup->strand_slot = 0;	/* FIXME fixed for the moment */

	vcpup->vid = vcpup->pip.vid;
	vcpup->parttag = vcpup->pip.parttag;

	guestp = config.guests;
	guestp = &(guestp[vcpup->pip.guestid]);
	ASSERT(guestp->guestid == vcpup->pip.guestid);
	vcpup->guest = guestp;

	ASSERT(guestp->vcpus[vcpup->vid] == NULL);
	guestp->vcpus[vcpup->vid] = vcpup;

#ifdef CONFIG_CRYPTO
	/* gets setup later if crypto run */
	vcpup->maup = NULL;
	vcpup->cwqp = NULL;
#endif
	/*
	 * Initialise the remainder of the vCPU struct
	 */
	vcpup->mmu_area = 0LL;
	vcpup->mmu_area_ra = 0LL;
	vcpup->root = &config;	/* FIXME: need this ? */

	/*
	 * Assume guest rtba starts at the base of memory
	 * until the guest reconfigures this. The entry point
	 * is computed from this.
	 */
	vcpup->rtba = guestp->real_base;

	/* Assert the legacy entry point had better be the same */
	ASSERT(guestp->entry == guestp->real_base);

	DBGVCPU(c_printf("Virtual cpu 0x%x in guest 0x%x (vid 0x%x) "
	    "entry @ 0x%x rtba @ 0x%x\n",
	    vcpup->res_id, vcpup->guest->guestid, vcpup->vid,
	    guestp->entry, vcpup->rtba));


	/*
	 * Now for the basic sun4v cpu state.
	 */

	/*
	 * Guests entry point should be at the power on
	 * vector of the rtba - at least for the boot cpu.
	 */
	vcpup->start_pc = vcpup->rtba + TT_POR*TRAPTABLE_ENTRY_SIZE;

	reset_vcpu_state(vcpup);

	/*
	 * check to see if the strand the VCPU is bound
	 * to is in active state, if not mark the VCPU
	 * in error
	 */
	if (config.strand_active & (1LL<<vcpup->pip.strand_id)) {
		vcpup->status = CPU_STATE_STOPPED;
	} else {
		vcpup->status = CPU_STATE_ERROR;
	}

	/* initialize vcpu utilization information */
	c_bzero(&vcpup->util, sizeof (vcpup->util));
}


void
res_vcpu_commit_unconfig(vcpu_t *vcpup)
{
	ASSERT(vcpup->status == CPU_STATE_STOPPED ||
	    vcpup->status == CPU_STATE_ERROR);

	ASSERT(vcpup->guest != NULL);
	ASSERT(vcpup->strand != NULL);

		/* Clean up actions */
	vcpup->guest->vcpus[vcpup->vid] = NULL;

	vcpup->guest = NULL;
	vcpup->strand = NULL;
#ifdef CONFIG_CRYPTO
	vcpup->maup = NULL;
	vcpup->cwqp = NULL;
#endif
	/*
	 * stuff like cyclics should already have been turned off
	 * when we stop the cpu
	 */

	/* FIXME: need to cleanup */
	vcpup->status = CPU_STATE_UNCONFIGURED;
}
