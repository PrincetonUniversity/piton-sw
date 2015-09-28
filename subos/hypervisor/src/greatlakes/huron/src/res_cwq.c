/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_cwq.c
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

#pragma ident	"@(#)res_cwq.c	1.2	07/06/07 SMI"

#include  <stdarg.h>

#include  <sys/htypes.h>
#include  <hypervisor.h>
#include  <hprivregs.h>
#include  <traps.h>
#include  <mmu.h>
#include  <sun4v/asi.h>
#include <vdev_intr.h>
#include <vdev_ops.h>
#include  <ncs.h>
#include  <config.h>
#include  <cyclic.h>
#include  <vcpu.h>
#include  <strand.h>
#include  <guest.h>
#include  <memory.h>
#include  <support.h>
#include  <md.h>
#include  <abort.h>
#include  <proto.h>

#ifdef CONFIG_CRYPTO

static void res_cwq_commit_config(cwq_t *cwqp);
static void res_cwq_commit_unconfig(cwq_t *cwqp);
static void res_cwq_commit_modify(cwq_t *cwqp);

static hvctl_status_t res_cwq_parse_1(bin_md_t *mdp, md_element_t *cwqnodep,
    hvctl_res_error_t *fail_codep, int *fail_res_idp);

static void setup_a_cwq(vcpu_t *vcpup, cwq_t *cwqp, uint64_t ino);
extern bool_t strand_in_vcpu_list(uint64_t strand_id, vcpu_t *vcpu_list,
    uint64_t *found_idx);
static void unconfig_strand_from_cwq(cwq_t *cwqp, uint64_t strand_num);
static void init_cwq(cwq_t *cwqp);
static vcpu_t *cwq_to_vcpu(cwq_t *cwqp, int strand_id);

/*
 * Initialise N2 CWQ units
 */
void
init_cwq_crypto_units()
{
	cwq_t	*cwqp;
	int	i, j;

	config.config_m.cwqs = &cwqs[0];
	cwqp = (cwq_t *)config.config_m.cwqs;

	for (i = 0; i < NCWQS; i++) {
		cwqp[i].handle = 0LL;
		cwqp[i].res_id = i;
		cwqp[i].ino = 0LL;
		cwqp[i].cpuset = 0LL;
		cwqp[i].guest = NULL;
		for (j = 0; j < NSTRANDS_PER_CORE; j++) {
			cwqp[i].cpu_active[j] = 0;
		}
		cwqp[i].state = CWQ_STATE_UNCONFIGURED;
	}
}

/*
 * cwq support functions.
 */
void
res_cwq_prep()
{
	cwq_t	*cwqp;
	int	i;

	cwqp = config.config_m.cwqs;

	for (i = 0; i < NCWQS; i++, cwqp++) {
		cwqp->pip.res.flags = (cwqp->state == CWQ_STATE_UNCONFIGURED) ?
		    RESF_Noop : RESF_Unconfig;
		cwqp->pip.cpuset = 0;
	}
}

hvctl_status_t
res_cwq_parse(bin_md_t *mdp, hvctl_res_error_t *fail_codep,
			md_element_t **failnodepp, int *fail_res_idp)
{
	md_element_t	*mdep;
	uint64_t	arc_token;
	uint64_t	node_token;
	md_element_t	*cwqnodep;

	mdp = (bin_md_t *)config.parse_hvmd;

	mdep = md_find_node(mdp, NULL, MDNAME(cwqs));
	if (mdep == NULL) {
		DBG_CWQ(c_printf("Missing cwqs node in HVMD\n"));
		*failnodepp = NULL;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(cwq));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep, arc_token,
	    node_token, &cwqnodep))) {
		hvctl_status_t status;
		status = res_cwq_parse_1(mdp, cwqnodep, fail_codep,
		    fail_res_idp);
		if (status != HVctl_st_ok) {
			*failnodepp = cwqnodep;
			return (status);
		}
	}
	return (HVctl_st_ok);
}

hvctl_status_t
res_cwq_parse_1(bin_md_t *mdp, md_element_t *cwqnodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp)
{
	uint64_t	strand_id, thread_id, cwq_id, gid, ino;
	cwq_t		*cwqp = NULL;
	md_element_t	*guestnodep, *cpunodep, *mdep;

	DBG_CWQ(md_dump_node(mdp, cwqnodep));

#if 0 /* { FIXME: we still index by PID of CWQ, not reource_id */
	if (!md_node_get_val(mdp, cwqnodep, MDNAME(resource_id), &cwq_id)) {
		DBG_CWQ(c_printf("Missing resource_id in cwq node\n"));
		*fail_codep = HVctl_e_cwq_missing_id;
		goto fail;
	}
	if (cwq_id >= NCWQS) {
		DBG_CWQ(c_printf("Invalid resource_id in cwq node\n"));
		*fail_codep = HVctl_e_cwq_invalid_id;
		goto fail;
	}
#endif /* } */

	mdep = cwqnodep;
	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    MDARC(MDNAME(back)), MDNODE(MDNAME(cpu)), &cpunodep))) {

		if (!md_node_get_val(mdp, cpunodep, MDNAME(pid), &strand_id)) {
			DBG_CWQ(c_printf("Missing PID in cpu node\n"));
			*fail_codep = HVctl_e_cwq_missing_strandid;
			goto fail;
		}

		if (strand_id >= NSTRANDS) {
			DBG_CWQ(c_printf("Invalid PID in cpu node\n"));
			*fail_codep = HVctl_e_cwq_invalid_strandid;
			goto fail;
		}

		if (cwqp == NULL) {
			cwq_id = strand_id >> STRANDID_2_COREID_SHIFT;
			/* ASSERT(cwq_id < NCWQS); */
			cwqp = config.config_m.cwqs;
			cwqp = &(cwqp[cwq_id]);
			cwqp->pip.cpuset = 0;
			*fail_res_idp = cwq_id;
			DBG_CWQ(c_printf("res_cwq_parse_1(0x%x)\n", cwq_id));
		}

		thread_id = strand_id & NSTRANDS_PER_CORE_MASK;

		cwqp->pip.cpuset |= (1 << thread_id);

		if (NULL == md_find_node_by_arc(mdp, cpunodep,
		    MDARC(MDNAME(back)), MDNODE(MDNAME(guest)),
		    &guestnodep)) {
			DBG_CWQ(c_printf("Missing back arc to guest node in "
			    "cpu node\n"));
			*fail_codep = HVctl_e_cwq_missing_guest;
			goto fail;
		}

		if (!md_node_get_val(mdp, guestnodep, MDNAME(resource_id),
		    &gid)) {
			DBG_CWQ(c_printf(
			    "Missing resource_id in guest node\n"));
			*fail_codep = HVctl_e_guest_missing_id;
			goto fail;
		}
		if (gid >= NGUESTS) {
			DBG_CWQ(c_printf(
			    "Invalid resource_id in guest node\n"));
			*fail_codep = HVctl_e_guest_invalid_id;
			goto fail;
		}
		/* FIXME: check that all cpus belong to same guest */
		cwqp->pip.guestid = gid;
	}

	/* Get ino value for this cwq */
	if (!md_node_get_val(mdp, cwqnodep, MDNAME(ino), &ino)) {
		DBG_CWQ(c_printf("WARNING: Missing ino in cwq node\n"));
		*fail_codep = HVctl_e_cwq_missing_ino;
		goto fail;
	}

	DBG_CWQ(c_printf("Virtual cwq 0x%x in guest 0x%x ino 0x%x\n",
	    cwq_id, gid, ino));


	/*
	 * Now determine the delta - if relevent...
	 */
	cwqp->pip.pid = cwq_id;
	cwqp->pip.ino = ino;

	/*
	 * We can configure an unconfigured CWQ.
	 * Cannot (yet) support the dynamic re-binding of
	 * a configured / running cwq, except to modify the
	 * set of vcpus bound to it, which is handled as part of unconfig
	 * or config.
	 */
	DBG_CWQ(c_printf("\t\tCurrent cwq status = 0x%x\n",	cwqp->state));

	if (cwqp->state == CWQ_STATE_UNCONFIGURED) {
		DBG_CWQ(c_printf("\t\tElected to config cwq\n"));
		cwqp->pip.res.flags = RESF_Config;
	} else {
		if (cwqp->pid == cwqp->pip.pid &&
		    cwqp->guest->guestid == gid &&
		    cwqp->ino == ino &&
		    cwqp->cpuset != cwqp->pip.cpuset) {
			DBG_CWQ(c_printf("\t\tElected to modify cwq\n"));
			cwqp->pip.res.flags = RESF_Modify;
		} else if (cwqp->pid == cwqp->pip.pid &&
		    cwqp->guest->guestid == gid &&
		    cwqp->ino == ino) {
			DBG_CWQ(c_printf("\t\tElected to ignore cwq\n"));
			cwqp->pip.res.flags = RESF_Noop;
		} else {
			DBG_CWQ(c_printf("\t\tFailed MD update - no "
			    "rebind live\n"));
			*fail_codep = HVctl_e_cwq_rebind_na;
			goto fail;
		}
	}

	return (HVctl_st_ok);
fail:;
	return (HVctl_st_badmd);
}

hvctl_status_t
res_cwq_postparse(hvctl_res_error_t *res_error, int *fail_res_id)
{
	return (HVctl_st_ok);
}

void
res_cwq_commit(int flag)
{
	cwq_t	*cwqp;
	int	i;

	cwqp = config.config_m.cwqs;

	for (i = 0; i < NCWQS; i++, cwqp++) {
		/* if not this ops turn move on */
		DBG_CWQ(c_printf("res_cwq_commit: cwqid 0x%x : state 0x%x : "
		    "flags 0x%x - opflag 0x%x\n",
		    cwqp->pid, cwqp->state, cwqp->pip.res.flags, flag));

		if (cwqp->pip.res.flags != flag)
			continue;

		switch (cwqp->pip.res.flags) {
		case RESF_Noop:
			DBG_CWQ(c_printf("cwq 0x%x : noop\n", i));
			break;
		case RESF_Unconfig:
			DBG_CWQ(c_printf("cwq 0x%x : unconfig\n", i));
			res_cwq_commit_unconfig(cwqp);
			break;
		case RESF_Config:
			DBG_CWQ(c_printf("cwq 0x%x : config\n", i));
			res_cwq_commit_config(cwqp);
			break;
		case RESF_Rebind:
			DBG_CWQ(c_printf("cwq 0x%x : rebind\n", i));
			ASSERT(0);	/* not supported */
			break;
		case RESF_Modify:
			DBG_CWQ(c_printf("cwq 0x%x : modify\n", i));
			res_cwq_commit_modify(cwqp);
			break;
		default:
			ASSERT(0);
		}
		cwqp->pip.res.flags = RESF_Noop; /* cleanup */
	}
}

static void
res_cwq_commit_config(cwq_t *cwqp)
{
	guest_t		*guestp;
	vcpu_t		*cpup;
	uint64_t	strand_num, vcpu_num;
	int		i;

	DBG_CWQ(c_printf("res_cwq_commit_config\n"));

	/*
	 * Assign the cwq its bound vcpu.
	 * Note: this does not schedule the cwq.
	 */
	cwqp->pid = cwqp->pip.pid;

	guestp = config.guests;
	guestp = &(guestp[cwqp->pip.guestid]);
	ASSERT(guestp->guestid == cwqp->pip.guestid);
	ASSERT(guestp->cwqs[cwqp->pid] == NULL);
	guestp->cwqs[cwqp->pid] = cwqp;

	/*
	 * Initialise the remainder of the cwq struct.  Need to do this
	 * once for each cpu bound to this cwq.
	 */

	/*
	 * Loop through the cpus attached to this cwq
	 * FIXME: make independent of cpu arch
	 */
	strand_num = cwqp->pid << STRANDID_2_COREID_SHIFT;
	for (i = 0; i < NSTRANDS_PER_CORE; ++i, ++strand_num) {
		/* Skip cpus not being bound to this cwq */
		if ((cwqp->pip.cpuset & (1 << i)) == 0) {
			DBG_CWQ(c_printf("Skipping thread id %d for cwq %d "
			    "(pip.cpuset 0x%x)\n",
			    i, cwqp->pid, cwqp->pip.cpuset));
			continue;
		}
		cpup = config.vcpus;

		/* Convert strand to vid */
		if (strand_in_vcpu_list(strand_num, cpup, &vcpu_num)) {
			cpup = &(cpup[vcpu_num]);
		} else {
			DBG_CWQ(c_printf(
			    "strand 0x%x not found!\n", strand_num));
			c_hvabort();
		}

		cpup->cwqp = cwqp;

		DBG_CWQ(c_printf("\tBinding cwq (pid = 0x%x) to vcpu 0x%x on "
		    "strand 0x%x in guest 0x%x\n",
		    cwqp->pid, vcpu_num, strand_num, cwqp->pip.guestid));

		setup_a_cwq(cpup, cwqp, cwqp->pip.ino);
		config_a_guest_device_vino(cwqp->guest, cwqp->pip.ino,
		    DEVOPS_VDEV);
	}
}

static void
setup_a_cwq(vcpu_t *vcpup, cwq_t *cwqp, uint64_t ino)
{
	extern void c_setup_cwq(vcpu_t *, uint64_t, config_t *);

	c_setup_cwq(vcpup, ino, &config);
	cwqp->guest = vcpup->guest;
}

static void
res_cwq_commit_unconfig(cwq_t *cwqp)
{
	vcpu_t		*cpup;
	uint64_t	strand_num, vcpu_num;
	int i;

	ASSERT(cwqp->state == CWQ_STATE_RUNNING ||
	    cwqp->state == CWQ_STATE_ERROR);

	ASSERT(cwqp->guest != NULL);

	strand_num = cwqp->pid << STRANDID_2_COREID_SHIFT;
	for (i = 0; i < NSTRANDS_PER_CORE; ++i, ++strand_num) {
		/* Skip cpus not bound to this cwq */
		if ((cwqp->cpuset & (1 << i)) == 0) {
			DBG_CWQ(c_printf(
			    "Skipping thread id %d (strand 0x%x) for "
			    "cwq %d (cpuset 0x%x)\n",
			    i, strand_num, cwqp->pid, cwqp->cpuset));
			continue;
		}

		cpup = config.vcpus;

		/* Convert strand to vid */
		DBG_CWQ(c_printf(
		    "\tUnconfig cwq (pid = 0x%x) from strand 0x%x in "
		    "guest 0x%x\n", cwqp->pid, strand_num,
		    cwqp->guest->guestid));

		if (strand_in_vcpu_list(strand_num, cpup, &vcpu_num)) {
			cpup = &(cpup[vcpu_num]);
			DBG_CWQ(c_printf("\tstrand 0x%x is vcpu 0x%x\n",
			    strand_num, vcpu_num));
		} else {
			DBG_CWQ(c_printf(
			    "strand 0x%x not found!\n", strand_num));
			c_hvabort();
		}

		unconfig_a_guest_device_vino(cwqp->guest, cwqp->ino,
		    DEVOPS_VDEV);
		unconfig_strand_from_cwq(cwqp, strand_num);
	}
}

static void
unconfig_strand_from_cwq(cwq_t *cwqp, uint64_t strand_num)
{
	guest_t *guestp;
	int thread_id;

	guestp = cwqp->guest;

	/*
	 * Check if already unconfigured!
	 */
	ASSERT(guestp->cwqs[cwqp->pid] != NULL);
	ASSERT(cwqp->state != CWQ_STATE_UNCONFIGURED);

	thread_id = strand_num & NSTRANDS_PER_CORE_MASK;

	/*
	 * Force the cpu_active entry to 0.
	 * It is possible to come through the unconfig sequence
	 * without having gone through stop_cwq.  However, we
	 * assured that when we come into unconfig_cwq that the
	 * respective cpu is stopped.
	 */
	cwqp->cpu_active[thread_id] = 0;

	/*
	 * Remove cpu from CWQ's cpuset and if this
	 * is the last one, then clear the queue structure.
	 */
	DBG_CWQ(c_printf(
"\tunconfig_strand_from_cwq: cwq %d thread %d (strand %d) guest %d\n",
	    cwqp->pid, thread_id, strand_num, guestp->guestid));

	cwqp->cpuset &= ~(1 << thread_id);

	DBG_CWQ(c_printf("\tnew cpuset: %d\n", cwqp->cpuset));

	if (cwqp->cpuset == 0) {
		init_cwq(cwqp);
		cwqp->state = CWQ_STATE_UNCONFIGURED;
		cwqp->guest->cwqs[cwqp->pid] = NULL;
		cwqp->guest = NULL;
	}
}

static void
init_cwq(cwq_t *cwqp)
{
	cwqp->queue.cq_dr_base_ra = 0;
	cwqp->queue.cq_base = 0;
	cwqp->queue.cq_last = 0;
	cwqp->queue.cq_head = 0;
	cwqp->queue.cq_head_marker = 0;
	cwqp->queue.cq_tail = 0;
	cwqp->queue.cq_nentries = 0;
	cwqp->queue.cq_busy = 0;
}

/*
 * The only allowed modification on a CWQ is the list of vcpus which
 * are bound to it.
 */
void
res_cwq_commit_modify(cwq_t *cwqp)
{
	uint64_t	strand_id, thread_id;

	ASSERT(cwqp->state == CWQ_STATE_RUNNING ||
	    cwqp->state == CWQ_STATE_ERROR);
	ASSERT(cwqp->guest != NULL);

	/*
	 * Compare old & new cpusets, configuring or unconfiguring
	 * cpu->cwq bindings as appropriate.
	 */
	/*
	 * We can't determine which cpu->cwq bindings to unconfigure
	 * by walking the available vcpus, as they've already been
	 * unconfigured, so we find them by comparing the old & new
	 * cpuset mask values.
	 */
	strand_id = cwqp->pid << STRANDID_2_COREID_SHIFT;
	for (thread_id = 0; thread_id < NSTRANDS_PER_CORE;
	    ++thread_id, ++strand_id) {
		uint64_t mask = 1LL << thread_id;

		if ((cwqp->cpuset & mask) == (cwqp->pip.cpuset & mask)) {
			DBG_CWQ(c_printf(
			    "\tIgnoring cwq (pid = 0x%x) on strand "
			    "0x%x in guest 0x%x\n",
			    cwqp->pid, strand_id, cwqp->pip.guestid));
			continue;
		}
		/* Configure? */
		if ((cwqp->pip.cpuset & mask) != 0) {
			vcpu_t *cpup;

			cpup = cwq_to_vcpu(cwqp, strand_id);
			ASSERT(cpup != NULL);
			cpup->cwqp = cwqp;

			DBG_CWQ(c_printf("\tBinding cwq (pid = 0x%x) to strand "
			    "0x%x in guest 0x%x\n",
			    cwqp->pid, strand_id, cwqp->pip.guestid));

			setup_a_cwq(cpup, cwqp, cwqp->pip.ino);
		} else {
			/* Unconfigure */
			DBG_CWQ(c_printf("\tUnbinding cwq %d from strand 0x%x "
			    "in guest 0x%x\n",
			    cwqp->pid, strand_id, cwqp->guest->guestid));
			unconfig_strand_from_cwq(cwqp, strand_id);
		}
	}
}

static vcpu_t *
cwq_to_vcpu(cwq_t *cwqp, int strand_id)
{
	vcpu_t *cpup;
	int i;

	/*
	 * Walk all vcpus bound to guest which owns cwq, and find
	 * one with strand_id passed in.
	 */
	for (i = 0; i < NVCPUS; ++i) {
		cpup = cwqp->guest->vcpus[i];

		/* Is vcpu mapped to guest? */
		if (cpup == NULL)
			continue;

		ASSERT(cpup->strand != NULL);
		if (cpup->strand->id == strand_id) {
			DBG_CWQ(c_printf(
			    "\tcwq_to_vcpu: cwq %d strand %d is vcpu %d\n",
			    cwqp->pid, strand_id, cpup->vid));
			return (cpup);
		}
	}

	return (NULL);
}

#endif /* CONFIG_CRYPTO */
