/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_mau.c
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

#pragma ident	"@(#)res_mau.c	1.7	07/06/07 SMI"

#ifdef CONFIG_CRYPTO /* Compiled in if the CRYPTO option selected */

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
 * (re)-configuration code to handle HV MAU resources
 */

/*
 * resource processing support
 */

extern void c_unconfig_mau(vcpu_t *, guest_t *);
extern void c_setup_mau(vcpu_t *, uint64_t, config_t *);

static void res_mau_commit_config(mau_t *maup);
static void res_mau_commit_unconfig(mau_t *maup);
static void res_mau_commit_modify(mau_t *maup);

static hvctl_status_t res_mau_parse_1(bin_md_t *mdp, md_element_t *maunodep,
    hvctl_res_error_t *fail_codep, int *fail_res_idp);

static void setup_a_mau(vcpu_t *vcpup, mau_t *maup, uint64_t ino);

/*
 * mau support functions.
 */
void
res_mau_prep()
{
	mau_t	*mp;
	int	i;

	mp = config.config_m.maus;

	for (i = 0; i < NMAUS; i++, mp++) {
		mp->pip.res.flags = (mp->state == MAU_STATE_UNCONFIGURED) ?
		    RESF_Noop : RESF_Unconfig;
		mp->pip.cpuset = 0;
	}
}


hvctl_status_t
res_mau_parse(bin_md_t *mdp, hvctl_res_error_t *fail_codep,
			md_element_t **failnodepp, int *fail_res_idp)
{
	md_element_t	*mdep;
	uint64_t	arc_token;
	uint64_t	node_token;
	md_element_t	*maunodep;

	mdp = (bin_md_t *)config.parse_hvmd;

	mdep = md_find_node(mdp, NULL, MDNAME(maus));
	if (mdep == NULL) {
		DBG_MAU(c_printf("Missing maus node in HVMD\n"));
		*failnodepp = NULL;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(mau));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    arc_token, node_token, &maunodep))) {
		hvctl_status_t status;
		status = res_mau_parse_1(mdp, maunodep, fail_codep,
		    fail_res_idp);
		if (status != HVctl_st_ok) {
			*failnodepp = maunodep;
			return (status);
		}
	}
	return (HVctl_st_ok);
}

hvctl_status_t
res_mau_parse_1(bin_md_t *mdp, md_element_t *maunodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp)
{
	uint64_t	strand_id, thread_id, mau_id, gid, ino;
	mau_t		*maup = NULL;
	md_element_t	*guestnodep, *cpunodep, *mdep;

	DBG_MAU(md_dump_node(mdp, maunodep));

	mdep = maunodep;

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    MDARC(MDNAME(back)), MDNODE(MDNAME(cpu)), &cpunodep))) {

		if (!md_node_get_val(mdp, cpunodep, MDNAME(pid), &strand_id)) {
			DBG_MAU(c_printf("Missing PID in cpu node\n"));
			*fail_codep = HVctl_e_mau_missing_strandid;
			goto fail;
		}

		if (strand_id >= NSTRANDS) {
			DBG_MAU(c_printf("Invalid PID in cpu node\n"));
			*fail_codep = HVctl_e_mau_invalid_strandid;
			goto fail;
		}

		if (maup == NULL) {
			mau_id = strand_id >> STRANDID_2_COREID_SHIFT;
			ASSERT(mau_id < NMAUS);
			maup = config.config_m.maus;
			maup = &(maup[mau_id]);
			maup->pip.cpuset = 0;
			*fail_res_idp = mau_id;
			DBG_MAU(c_printf("res_mau_parse_1(0x%x)\n", mau_id));
		}

		thread_id = strand_id & NSTRANDS_PER_CORE_MASK;

		maup->pip.cpuset |= (1 << thread_id);

		if (NULL == md_find_node_by_arc(mdp, cpunodep,
		    MDARC(MDNAME(back)), MDNODE(MDNAME(guest)),
		    &guestnodep)) {
			DBG_MAU(c_printf("Missing back arc to guest node in "
			    "cpu node\n"));
			*fail_codep = HVctl_e_mau_missing_guest;
			goto fail;
		}

		if (!md_node_get_val(mdp, guestnodep, MDNAME(resource_id),
		    &gid)) {
			DBG_MAU(c_printf(
			    "Missing resource_id in guest node\n"));
			*fail_codep = HVctl_e_guest_missing_id;
			goto fail;
		}
		if (gid >= NGUESTS) {
			DBG_MAU(c_printf(
			    "Invalid resource_id in guest node\n"));
			*fail_codep = HVctl_e_guest_invalid_id;
			goto fail;
		}
		/* FIXME: check that all cpus belong to same guest */
		maup->pip.guestid = gid;
	}

	/* Get ino value for this mau */
	if (!md_node_get_val(mdp, maunodep, MDNAME(ino), &ino)) {
		DBG_MAU(c_printf("WARNING: Missing ino in mau node\n"));
		*fail_codep = HVctl_e_mau_missing_ino;
		goto fail;
	}

	DBG_MAU(c_printf("Virtual mau 0x%x in guest 0x%x ino 0x%x\n",
	    mau_id, gid, ino));


	/*
	 * Now determine the delta - if relevent...
	 */
	maup->pip.pid = mau_id;
	maup->pip.ino = ino;

	/*
	 * We can configure an unconfigured MAU.
	 * Cannot (yet) support the dynamic re-binding of
	 * a configured / running mau, except to modify the
	 * set of vcpus bound to it, which is handled as part of unconfig
	 * or config.
	 */
	DBG_MAU(c_printf("\t\tCurrent mau status = 0x%x\n",	maup->state));

	if (maup->state == MAU_STATE_UNCONFIGURED) {
		DBG_MAU(c_printf("\t\tElected to config mau\n"));
		maup->pip.res.flags = RESF_Config;
	} else {
		if (maup->pid == maup->pip.pid &&
		    maup->guest->guestid == gid &&
		    maup->ino == ino &&
		    maup->cpuset != maup->pip.cpuset) {
			DBG_MAU(c_printf("\t\tElected to modify mau\n"));
			maup->pip.res.flags = RESF_Modify;
		} else if (maup->pid == maup->pip.pid &&
		    maup->guest->guestid == gid &&
		    maup->ino == ino) {
			DBG_MAU(c_printf("\t\tElected to ignore mau\n"));
			maup->pip.res.flags = RESF_Noop;
		} else {
			DBG_MAU(c_printf("\t\tFailed MD update - no "
			    "rebind live\n"));
			*fail_codep = HVctl_e_mau_rebind_na;
			goto fail;
		}
	}

	return (HVctl_st_ok);
fail:;
	return (HVctl_st_badmd);
}

hvctl_status_t
res_mau_postparse(hvctl_res_error_t *res_error, int *fail_res_id)
{
	return (HVctl_st_ok);
}

void
res_mau_commit(int flag)
{
	mau_t	*mp;
	int	i;

	mp = config.config_m.maus;

	for (i = 0; i < NMAUS; i++, mp++) {
		/* if not this ops turn move on */
		DBG_MAU(c_printf("res_mau_commit: mauid 0x%x : state 0x%x : "
		    "flags 0x%x - opflag 0x%x\n",
		    mp->pid, mp->state, mp->pip.res.flags, flag));

		if (mp->pip.res.flags != flag)
			continue;

		switch (mp->pip.res.flags) {
		case RESF_Noop:
			DBG_MAU(c_printf("mau 0x%x : noop\n", i));
			break;
		case RESF_Unconfig:
			DBG_MAU(c_printf("mau 0x%x : unconfig\n", i));
			res_mau_commit_unconfig(mp);
			break;
		case RESF_Config:
			DBG_MAU(c_printf("mau 0x%x : config\n", i));
			res_mau_commit_config(mp);
			break;
		case RESF_Rebind:
			DBG_MAU(c_printf("mau 0x%x : rebind\n", i));
			ASSERT(0);	/* not supported */
			break;
		case RESF_Modify:
			DBG_MAU(c_printf("mau 0x%x : modify\n", i));
			res_mau_commit_modify(mp);
			break;
		default:
			ASSERT(0);
		}

		mp->pip.res.flags = RESF_Noop; /* cleanup */
	}
}

bool_t
strand_in_vcpu_list(uint64_t strand_id, vcpu_t *vcpu_list, uint64_t *found_idx)
{
	int i;

	for (i = 0; i < NVCPUS; ++i) {
		if (vcpu_list[i].strand && vcpu_list[i].strand->id ==
		    strand_id) {
			if (found_idx != NULL)
				*found_idx = i;
			return (true);
		}
	}
	return (false);
}

void
res_mau_commit_config(mau_t *maup)
{
	guest_t		*guestp;
	vcpu_t		*cpup;
	uint64_t	strand_num, vcpu_num;
	int		i;

	DBG_MAU(c_printf("res_mau_commit_config\n"));

	/*
	 * Assign the mau its bound vcpu.
	 * Note: this does not schedule the mau.
	 */
	maup->pid = maup->pip.pid;

	guestp = config.guests;
	guestp = &(guestp[maup->pip.guestid]);
	ASSERT(guestp->guestid == maup->pip.guestid);
	ASSERT(guestp->maus[maup->pid] == NULL);
	guestp->maus[maup->pid] = maup;

	/*
	 * Initialise the remainder of the mau struct.  Need to do this
	 * once for each cpu bound to this mau.
	 */

	/*
	 * Loop through the cpus attached to this mau.
	 * FIXME: make independent of cpu arch
	 */
	strand_num = maup->pid << STRANDID_2_COREID_SHIFT;
	for (i = 0; i < NSTRANDS_PER_CORE; ++i, ++strand_num) {
		/* Skip cpus not being bound to this mau */
		if ((maup->pip.cpuset & (1 << i)) == 0) {
			DBG_MAU(c_printf("Skipping thread id %d for mau %d "
			    "(pip.cpuset 0x%x)\n",
			    i, maup->pid, maup->pip.cpuset));
			continue;
		}
		cpup = config.vcpus;

		/* Convert strand to vid */
		if (strand_in_vcpu_list(strand_num, cpup, &vcpu_num)) {
			cpup = &(cpup[vcpu_num]);
		} else {
			DBG_MAU(c_printf(
			    "strand 0x%x not found!\n", strand_num));
			c_hvabort();
		}

		cpup->maup = maup;

		DBG_MAU(c_printf("\tBinding mau (pid = 0x%x) to vcpu 0x%x on "
		    "strand 0x%x in guest 0x%x\n",
		    maup->pid, vcpu_num, strand_num, maup->pip.guestid));

		setup_a_mau(cpup, maup, maup->pip.ino);
		config_a_guest_device_vino(maup->guest, maup->pip.ino,
		    DEVOPS_VDEV);
	}
}

void
init_mau(mau_t *maup)
{
#ifdef ERRATA_192
	maup->store_in_progr = 0;
	maup->enable_cwq = 0;
#endif
	maup->queue.mq_base_ra = 0;
	maup->queue.mq_base = 0;
	maup->queue.mq_end = 0;
	maup->queue.mq_head = 0;
	maup->queue.mq_tail = 0;
	maup->queue.mq_nentries = 0;
	maup->queue.mq_busy = 0;
}

void
unconfig_strand_from_mau(mau_t *maup, uint64_t strand_num)
{
	int thread_id;

	/*
	 * Check if already unconfigured!
	 */
	ASSERT(maup->guest->maus[maup->pid] != NULL);
	ASSERT(maup->state != MAU_STATE_UNCONFIGURED);

	thread_id = strand_num & NSTRANDS_PER_CORE_MASK;

	/*
	 * Force the cpu_active entry to 0.
	 * It is possible to come through the unconfig sequence
	 * without having gone through stop_mau.  However, we
	 * assured that when we come into unconfig_mau that the
	 * respective cpu is stopped.
	 */
	maup->cpu_active[thread_id] = 0;

	/*
	 * Remove cpu from MAU's cpuset and if this
	 * is the last one, then clear the queue structure.
	 */
	DBG_MAU(c_printf(
"\tunconfig_strand_from_mau: mau %d thread %d (strand %d) guest %d\n",
	    maup->pid, thread_id, strand_num, maup->guest->guestid));

	maup->cpuset &= ~(1 << thread_id);

	DBG_MAU(c_printf("\tnew cpuset: %d\n", maup->cpuset));

	if (maup->cpuset == 0) {
		init_mau(maup);
		maup->state = MAU_STATE_UNCONFIGURED;
		maup->guest->maus[maup->pid] = NULL;
		maup->guest = NULL;
	}
}

void
res_mau_commit_unconfig(mau_t *maup)
{
	vcpu_t		*cpup;
	uint64_t	strand_num, vcpu_num;
	int i;

	ASSERT(maup->state == MAU_STATE_RUNNING ||
	    maup->state == MAU_STATE_ERROR);

	ASSERT(maup->guest != NULL);

	strand_num = maup->pid << STRANDID_2_COREID_SHIFT;
	for (i = 0; i < NSTRANDS_PER_CORE; ++i, ++strand_num) {
		/* Skip cpus not bound to this mau */
		if ((maup->cpuset & (1 << i)) == 0) {
			DBG_MAU(c_printf(
			    "Skipping thread id %d (strand 0x%x) for "
			    "mau %d (cpuset 0x%x)\n",
			    i, strand_num, maup->pid, maup->cpuset));
			continue;
		}

		cpup = config.vcpus;

		/* Convert strand to vid */
		DBG_MAU(c_printf(
		    "\tUnconfig mau (pid = 0x%x) from strand 0x%x in "
		    "guest 0x%x\n", maup->pid, strand_num,
		    maup->guest->guestid));

		if (strand_in_vcpu_list(strand_num, cpup, &vcpu_num)) {
			cpup = &(cpup[vcpu_num]);
			DBG_MAU(c_printf("\tstrand 0x%x is vcpu 0x%x\n",
			    strand_num, vcpu_num));
		} else {
			DBG_MAU(c_printf(
			    "strand 0x%x not found!\n", strand_num));
			c_hvabort();
		}

		unconfig_a_guest_device_vino(maup->guest, maup->ino,
		    DEVOPS_VDEV);
		unconfig_strand_from_mau(maup, strand_num);
	}
}

vcpu_t *
mau_to_vcpu(mau_t *maup, int strand_id)
{
	vcpu_t *cpup;
	int i;

	/*
	 * Walk all vcpus bound to guest which owns mau, and find
	 * one with strand_id passed in.
	 */
	for (i = 0; i < NVCPUS; ++i) {
		cpup = maup->guest->vcpus[i];

		/* Is vcpu mapped to guest? */
		if (cpup == NULL)
			continue;

		ASSERT(cpup->strand != NULL);
		if (cpup->strand->id == strand_id) {
			DBG_MAU(c_printf(
			    "\tmau_to_vcpu: mau %d strand %d is vcpu %d\n",
			    maup->pid, strand_id, cpup->vid));
			return (cpup);
		}
	}

	return (NULL);
}

/*
 * The only allowed modification on a mau is the list of vcpus which
 * are bound to it.
 */
void
res_mau_commit_modify(mau_t *maup)
{
	uint64_t	strand_id, thread_id;

	ASSERT(maup->state == MAU_STATE_RUNNING ||
	    maup->state == MAU_STATE_ERROR);
	ASSERT(maup->guest != NULL);

	/*
	 * Compare old & new cpusets, configuring or unconfiguring
	 * cpu->mau bindings as appropriate.
	 */
	/*
	 * We can't determine which cpu->mau bindings to unconfigure
	 * by walking the available vcpus, as they've already been
	 * unconfigured, so we find them by comparing the old & new
	 * cpuset mask values.
	 */
	strand_id = maup->pid << STRANDID_2_COREID_SHIFT;
	for (thread_id = 0; thread_id < NSTRANDS_PER_CORE;
	    ++thread_id, ++strand_id) {
		uint64_t mask = 1LL << thread_id;

		if ((maup->cpuset & mask) == (maup->pip.cpuset & mask)) {
			DBG_MAU(c_printf(
			    "\tIgnoring mau (pid = 0x%x) on strand "
			    "0x%x in guest 0x%x\n",
			    maup->pid, strand_id, maup->pip.guestid));
			continue;
		}
		/* Configure? */
		if ((maup->pip.cpuset & mask) != 0) {
			vcpu_t *cpup;

			cpup = mau_to_vcpu(maup, strand_id);
			ASSERT(cpup != NULL);
			cpup->maup = maup;

			DBG_MAU(c_printf("\tBinding mau (pid = 0x%x) to strand "
			    "0x%x in guest 0x%x\n",
			    maup->pid, strand_id, maup->pip.guestid));

			setup_a_mau(cpup, maup, maup->pip.ino);
		} else {
			/* Unconfigure */
			DBG_MAU(c_printf("\tUnbinding mau %d from strand 0x%x "
			    "in guest 0x%x\n",
			    maup->pid, strand_id, maup->guest->guestid));
			unconfig_strand_from_mau(maup, strand_id);
		}
	}
}

/*
 * Setup an MAU ...
 *
 * FIXME: bunch of wierd stuff here .. check this is done right.
 * This is a copy of config_a_mau in reconf.c. The reconf.c version
 * will go away when we handle delayed reconfig.
 */
static void
setup_a_mau(vcpu_t *vcpup, mau_t *maup, uint64_t ino)
{
	c_setup_mau(vcpup, ino, &config);
	maup->guest = vcpup->guest;
}

/*
 * Initialise MAUs
 */
void
init_mau_crypto_units()
{
	mau_t	*maup;
	int	i, j;

	config.config_m.maus = &maus[0];

	maup = (mau_t *)config.config_m.maus;
	for (i = 0; i < NMAUS; i++) {
		maup[i].handle = 0LL;
#ifdef ERRATA_192
		maup[i].store_in_progr = 0LL;
		maup[i].enable_cwq = 0LL;
#endif
		maup[i].res_id = i;
		maup[i].cpuset = 0LL;
		for (j = 0; j < NSTRANDS_PER_CORE; j++) {
			maup[i].cpu_active[j] = 0;
		}
		maup[i].state = MAU_STATE_UNCONFIGURED;
	}
}

#endif
