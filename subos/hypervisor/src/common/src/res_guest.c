/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_guest.c
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

#pragma ident	"@(#)res_guest.c	1.6	07/06/07 SMI"

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
 * (re)-configuration code to handle HV guest resources
 */

static hvctl_status_t res_guest_parse_1(bin_md_t *mdp, md_element_t *guestnodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp);

static void res_guest_commit_config(guest_t *guestp);
static void res_guest_commit_unconfig(guest_t *guestp);
static void res_guest_commit_modify(guest_t *guestp);


void config_a_guest_device_vino(guest_t *guestp, int ino, uint8_t type);
void unconfig_a_guest_device_vino(guest_t *guestp, int ino, uint8_t type);
void config_guest_virtual_device(guest_t *guestp, uint64_t cfg_handle);
void unconfig_guest_virtual_device(guest_t *guestp);
void config_guest_channel_device(guest_t *guestp, uint64_t cfg_handle);
void unconfig_guest_channel_device(guest_t *guestp);

void
init_guest(int i)
{
	guest_t *gp;
	hvctl_msg_t *asmsg;
	int	j;

	gp = (guest_t *)config.guests;
	gp = &(gp[i]);

	/* clear out everything ! */
	c_bzero(gp, sizeof (*gp));

	gp->guestid = i;
	gp->state = GUEST_STATE_UNCONFIGURED;

	/* FIXME: remove the configp pointer */
	gp->configp = &config;

	gp->pip.vdev_cfghandle = INVALID_CFGHANDLE;
	gp->pip.cdev_cfghandle = INVALID_CFGHANDLE;

	for (j = 0; j < NUM_RA2PA_SEGMENTS; j++) {
		init_ra2pa_segment(&(gp->ra2pa_segment[j]));
	}

	asmsg = (hvctl_msg_t *)gp->async_buf;
	asmsg->hdr.op = HVctl_op_new_res_stat;

	/* Everything else gets whacked when we (re)config the guest */
}




/*
 * Guest MD support functions.
 */
void
res_guest_prep()
{
	guest_t	*gp;
	int	i;

	gp = config.guests;

	for (i = 0; i < NGUESTS; i++, gp++) {
		gp->pip.res.flags = (gp->state == GUEST_STATE_UNCONFIGURED) ?
		    RESF_Noop : RESF_Unconfig;
	}
}


hvctl_status_t
res_guest_parse(bin_md_t *mdp, hvctl_res_error_t *fail_codep,
			md_element_t **failnodepp, int *fail_res_idp)
{
	md_element_t	*mdep;
	uint64_t	arc_token;
	uint64_t	node_token;
	md_element_t	*guest_nodep;

	mdp = (bin_md_t *)config.parse_hvmd;

	DBG(c_printf("\nGuest configuration:\n"));

	mdep = md_find_node(mdp, NULL, MDNAME(guests));
	if (mdep == NULL) {
		DBG(c_printf("Missing guests node in HVMD\n"));
		*failnodepp = NULL;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(guest));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep, arc_token,
	    node_token, &guest_nodep))) {
		hvctl_status_t status;
		status = res_guest_parse_1(mdp, guest_nodep, fail_codep,
		    fail_res_idp);
		if (status != HVctl_st_ok) {
			*failnodepp = guest_nodep;
			return (status);
		}
	}
	return (HVctl_st_ok);
}

hvctl_status_t
res_guest_parse_1(bin_md_t *mdp, md_element_t *guest_nodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp)
{
	uint64_t	resource_id, unbind, cfg_handle, base_memsize;
	uint64_t	arc_token, node_token;
	guest_t		*guestp;
	md_element_t	*mblock_nodep, *mdep, *base_mblock;
	md_element_t	*devices_nodep;

	DBG(c_printf("res_guest_parse_1\n"));
	DBG(md_dump_node(mdp, guest_nodep));

	if (!md_node_get_val(mdp, guest_nodep, MDNAME(resource_id),
	    &resource_id)) {
		DBG(c_printf("Missing resource_id in guest node\n"));
		*fail_codep = HVctl_e_guest_missing_id;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}
	if (resource_id >= NGUESTS) {
		DBG(c_printf("Invalid resource_id in guest node\n"));
		*fail_codep = HVctl_e_guest_invalid_id;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	guestp = config.guests;
	guestp = &(guestp[resource_id]);

	DBG(c_printf("Guest 0x%x @ 0x%x\n", resource_id, (uint64_t)guestp));

	*fail_res_idp = resource_id;

	/*
	 * If guest is being unbound check that it is stopped.
	 */
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(unbind), &unbind))
		unbind = 0;
	if (unbind != 0) {
		if (guestp->state != GUEST_STATE_STOPPED) {
			*fail_codep = HVctl_e_guest_active;
			return (HVctl_st_eillegal);
		}
	}

	/*
	 * Now fill in basic properties for this guest ...
	 *
	 * FIXME: These should be available is the guest is
	 * live yes ?
	 */

#define	GET_PROPERTY(_g_val, _md_name)					\
	do {								\
		uint64_t _x;						\
		if (!md_node_get_val(mdp, guest_nodep,			\
			MDNAME(_md_name), &_x)) {			\
			DBG(c_printf("Missing "#_md_name" in "		\
				"guest node\n"));			\
			goto missing_prop;				\
		}							\
		_g_val = _x;						\
	} while (0)

	/* A guest can't change ID, so just push it in */
	GET_PROPERTY(guestp->guestid, resource_id);
	GET_PROPERTY(guestp->pip.rom_base, rombase);
	GET_PROPERTY(guestp->pip.rom_size, romsize);

	GET_PROPERTY(guestp->pip.md_pa, mdpa);

#ifdef	CONFIG_CN_UART
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(uartbase),
	    &guestp->pip.uartbase)) {
		guestp->pip.uartbase = -1LL;
	}
#endif

#ifdef	CONFIG_DISK
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(diskpa),
	    &guestp->pip.diskpa)) {
		guestp->pip.diskpa = -1LL;
	}
#endif

	/*
	 * Check for a reset-reason property
	 *
	 * FIXME: How sensible is this in an LDoms world?
	 * This is fine unless master start gets called somehow as
	 * part of the guest reconfig - so dont do that unless
	 * you really mean it !
	 *
	 * FIXME: Again - why re-do if guest configured already
	 */
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(reset_reason),
	    &guestp->pip.reset_reason)) {
		guestp->pip.reset_reason = RESET_REASON_POR;
	}

	/*
	 * Determine guest realbase.
	 */
	guestp->pip.real_base = UINT64_MAX;
	guestp->pip.real_limit = 0;
	guestp->pip.mem_offset = 0;

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(mblock));

	base_mblock = NULL;
	mdep = guest_nodep;

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    arc_token, node_token, &mblock_nodep))) {
		uint64_t realbase, membase;
		if (!md_node_get_val(mdp, mblock_nodep, MDNAME(realbase),
		    &realbase)) {
			DBG(c_printf("Missing realbase in mblock node\n"));
			goto missing_prop;
		}

		/*
		 * Initialise guest real_base, real_limit and mem_offset
		 * Note: real_limit/mem_offset are required for N2 MMu HWTW
		 * FIXME: real_limit will not work for segmented memory
		 */
		if (realbase < guestp->pip.real_base) {
			guestp->pip.real_base = realbase;
			base_mblock = mblock_nodep;
			if (!md_node_get_val(mdp, mblock_nodep, MDNAME(membase),
			    &membase)) {
				membase = guestp->pip.real_base;
			}
			guestp->pip.mem_offset = membase -
			    guestp->pip.real_base;
		}
		if (!md_node_get_val(mdp, base_mblock, MDNAME(memsize),
		    &base_memsize)) {
			base_memsize = 0;
		}
		if (guestp->pip.real_limit < (realbase + base_memsize))
			guestp->pip.real_limit = (realbase + base_memsize);
	}

	if (base_mblock == NULL) {
		DBG(c_printf("Missing mblock node in guest node\n"));
		goto missing_prop;
	}

	if (!md_node_get_val(mdp, base_mblock, MDNAME(memsize),
	    &base_memsize)) {
		DBG(c_printf("Missing memsize in mblock node\n"));
		goto missing_prop;
	}

	if (guestp->pip.rom_size > base_memsize) {
		*fail_codep = HVctl_e_guest_base_mblock_too_small;
		return (HVctl_st_badmd);
	}

#undef GET_PROPERTY


	/*
	 * Look for the "perfctraccess" property. This property
	 * must be present and set to a non-zero value for the
	 * guest to have access to the JBUS/DRAM perf counters
	 */

	/*
	 * FIXME; These probably need to be their own resource !
	 */

	if (!md_node_get_val(mdp, guest_nodep, MDNAME(perfctraccess),
	    &guestp->pip.perfreg_accessible)) {
		guestp->pip.perfreg_accessible = 0;
	}

	/*
	 * Look for "diagpriv" property.  This property enables
	 * the guest to execute arbitrary hyperprivileged code.
	 */
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(diagpriv),
	    &guestp->pip.diagpriv)) {
#ifdef CONFIG_BRINGUP
		guestp->pip.diagpriv = -1;
#else
		guestp->pip.diagpriv = 0;
#endif
	}

	/*
	 * Look for "rngctlaccessible" property.  This property enables
	 * the guest to access the N2 RNG if available.
	 */
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(rngctlaccessible),
	    &guestp->rng_ctl_accessible)) {
		guestp->rng_ctl_accessible = 0;
	}

	/*
	 * Look for "perfctrhtaccess" property.  This property enables
	 * the guest to access the N2 hyper-privileged events if available.
	 */
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(perfctrhtaccess),
	    &guestp->perfreght_accessible)) {
		guestp->perfreght_accessible = 0;
	}

	/*
	 * Per guest TOD offset ...
	 * FIXME:
	 * This property doesn't trigger a modify op if the guest is already
	 * live. So changes are only visible after a reconfig when the
	 * domain is stopped.
	 */
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(todoffset),
	    &guestp->pip.tod_offset)) {
		guestp->pip.tod_offset = 0;
	}

	/*
	 * Now look for the guest devices ...
	 * FIXME: Needs updating so devices can be DR'd in.
	 */

	if (NULL != md_find_node_by_arc(mdp, guest_nodep, MDARC(MDNAME(fwd)),
	    MDNODE(MDNAME(virtual_devices)), &devices_nodep)) {
		if (!md_node_get_val(mdp, devices_nodep, MDNAME(cfghandle),
		    &cfg_handle)) {
			DBG(c_printf("Missing cfg_handle in device node\n"));
			goto missing_prop;
		}
		DBG(md_dump_node(mdp, devices_nodep));
		guestp->pip.vdev_cfghandle = cfg_handle;
	}

	if (NULL != md_find_node_by_arc(mdp, guest_nodep, MDARC(MDNAME(fwd)),
	    MDNODE(MDNAME(channel_devices)), &devices_nodep)) {
		if (!md_node_get_val(mdp, devices_nodep, MDNAME(cfghandle),
		    &cfg_handle)) {
			DBG(c_printf("Missing cfg_handle in device node\n"));
			goto missing_prop;
		}
		DBG(md_dump_node(mdp, devices_nodep));
		guestp->pip.cdev_cfghandle = cfg_handle;
	}
	DBG(c_printf("End of guest parse 1\n"));

	/*
	 * Now we go and figureout what we need to do to the
	 * guest to update or configure its state.
	 *
	 * Memory was dealt with earlier.
	 */
	if (guestp->state == GUEST_STATE_UNCONFIGURED) {
		DBG(c_printf("\t\tElected to config guest\n"));
		guestp->pip.res.flags = RESF_Config;
	} else {
		/*
		 * what kind of a re-configure is this ?
		 * Since guest structures dont really bind to anything, stuff
		 * binds to them, this is a modify IMHO, but only if stuff
		 * actually got modified ..
		 *
		 * Note: it is implicit in this test that an MD update
		 * *requires* that the mdpa changes. Since the prospect of
		 * and MD update inplace while the guest is running is
		 * frightening and likely to break the guest this is a
		 * suffient condion. If Zeus updates the MD in place we
		 * have really big problems on our hands .. not sure we
		 * can detect this easily.
		 *
		 * We ignore dynamic updates of uartbase and diskpa
		 * since they should be detected above and denied if the
		 * the domain is running.
		 */

		if (guestp->pip.rom_base != guestp->rom_base ||
		    guestp->pip.rom_size != guestp->rom_size ||
		    guestp->pip.md_pa != guestp->md_pa ||
		    guestp->pip.reset_reason != guestp->reset_reason ||
		    guestp->pip.perfreg_accessible !=
		    guestp->perfreg_accessible ||
		    guestp->pip.diagpriv != guestp->diagpriv ||
		    ((guestp->pip.vdev_cfghandle != INVALID_CFGHANDLE) &&
		    (guestp->pip.vdev_cfghandle != guestp->vdev_cfghandle)) ||
		    ((guestp->pip.cdev_cfghandle != INVALID_CFGHANDLE) &&
		    (guestp->pip.cdev_cfghandle != guestp->cdev_cfghandle)) ||
		    guestp->pip.tod_offset != guestp->tod_offset) {
			DBG(c_printf("\t\tElected to modify guest\n"));
			guestp->pip.res.flags = RESF_Modify;
		} else {
			guestp->pip.res.flags = RESF_Noop;
			DBG(c_printf("\t\tElected to ignore guest\n"));
		}
	}

	return (HVctl_st_ok);

missing_prop:;
	*fail_codep = HVctl_e_guest_missing_property;
	return (HVctl_st_badmd);
}


	/*
	 * Simple suite of checks based on the flags for this resource
	 */

hvctl_status_t
res_guest_postparse(hvctl_res_error_t *fail_codep, int *fail_res_idp)
{
	guest_t	*gp;
	int	i;

	gp = config.guests;

	for (i = 0; i < NGUESTS; i++, gp++) {
		switch (gp->pip.res.flags) {
		case RESF_Noop:
			break;
		case RESF_Unconfig:
			if (gp->state != GUEST_STATE_STOPPED) {
				*fail_codep = HVctl_e_guest_active;
				goto fail;
			}
			break;
		case RESF_Config:
			break;
		case RESF_Rebind:
			ASSERT(0);	/* not supported */
			break;
		case RESF_Modify:
			break;
		default:
			ASSERT(0);
		}
	}
	return (HVctl_st_ok);

fail:
	*fail_res_idp = i;
	return (HVctl_st_badmd);
}




void
res_guest_commit(int flag)
{
	guest_t	*gp;
	int	i;

	gp = config.guests;

	for (i = 0; i < NGUESTS; i++, gp++) {
		/* if not this ops turn move on */
		if (gp->pip.res.flags != flag) continue;

		switch (gp->pip.res.flags) {
		case RESF_Noop:
			DBG(c_printf("guest 0x%x : noop\n", i));
			break;
		case RESF_Unconfig:
			res_guest_commit_unconfig(gp);
			break;
		case RESF_Config:
			res_guest_commit_config(gp);
			break;
		case RESF_Rebind:
			DBG(c_printf("guest 0x%x : rebind\n", i));
			ASSERT(0);	/* not supported */
			break;
		case RESF_Modify:
			res_guest_commit_modify(gp);
			break;
		default:
			ASSERT(0);
		}

		gp->pip.res.flags = RESF_Noop; /* cleanup */
	}
}


void
reset_guest_state(guest_t *guestp)
{
	ASSERT(guestp->state == GUEST_STATE_STOPPED);

	reset_api_hcall_table(guestp);
	DBG(c_printf("\tguest hcall table @ 0x%x\n", guestp->hcall_table));

	reset_guest_perm_mappings(guestp);

	reset_guest_ldc_mapins(guestp);
}


/*
 * reconfigure common path - also shared with commit
 */
void
res_guest_commit_modify(guest_t *guestp)
{
	DBG(c_printf("modify guest 0x%x\n", guestp->guestid));
	ASSERT(guestp->state != GUEST_STATE_UNCONFIGURED);

	guestp->rom_base = guestp->pip.rom_base;
	guestp->rom_size = guestp->pip.rom_size;
	guestp->real_base = guestp->pip.real_base;
	guestp->real_limit = guestp->pip.real_limit;
	guestp->mem_offset = guestp->pip.mem_offset;

	guestp->md_pa = guestp->pip.md_pa;
	/*
	 * Compute the Guests MD size
	 */
	config_guest_md(guestp);


#ifdef	CONFIG_DISK
	guestp->disk.size = 0LL;
	guestp->disk.pa = guestp->pip.diskpa;
#endif

#ifdef	T1_FPGA_SNET
	guestp->snet.ino = guestp->pip.snet_ino;
	guestp->snet.pa  = guestp->pip.snet_pa;
#endif

	/*
	 * Look for the "perfctraccess" property. This property
	 * must be present and set to a non-zero value for the
	 * guest to have access to the JBUS/DRAM perf counters
	 */
	guestp->perfreg_accessible = guestp->pip.perfreg_accessible;

	/*
	 * Look for "diagpriv" property.  This property enables
	 * the guest to execute arbitrary hyperprivileged code.
	 */
	guestp->diagpriv = guestp->pip.diagpriv;

	/*
	 * Assume entry point is at base of real memory
	 */
	guestp->entry = guestp->real_base;
	guestp->reset_reason = guestp->pip.reset_reason;

	/*
	 * Modify devops.
	 */
	unconfig_guest_virtual_device(guestp);
	unconfig_guest_channel_device(guestp);
	config_guest_virtual_device(guestp, guestp->pip.vdev_cfghandle);
	config_guest_channel_device(guestp, guestp->pip.cdev_cfghandle);

}


void
res_guest_commit_config(guest_t *guestp)
{
	int	x;

	DBG(c_printf("commit config guest 0x%x : config\n", guestp->guestid));
	ASSERT(guestp->state == GUEST_STATE_UNCONFIGURED);

	/*
	 * Now fill in basic properties for this guest ...
	 *
	 * FIXME: These should be available if the guest is
	 * live yes ?
	 */
	guestp->ldc_mapin_basera = LDC_MAPIN_BASERA;
	guestp->ldc_mapin_size = LDC_MAPIN_RASIZE;

	guestp->state = GUEST_STATE_STOPPED;
	res_guest_commit_modify(guestp);

	/*
	 * TOD is configured once at the begining of time.
	 * we don't allow external modifies as that would warp
	 * the time value each time the guest gets and update
	 * after the guest had modified itself.
	 */
	guestp->tod_offset = guestp->pip.tod_offset;

	/*
	 * At the time of first guest config mark all INO2LDC
	 * mappings as NULL
	 */
	for (x = 0; x < MAX_LDC_INOS; x++) {
		guestp->ldc_ino2endpoint[x].endpointp = NULL;
		guestp->ldc_ino2endpoint[x].mapregp = NULL;
	}

	/*
	 * FIXME: Should we really care to track this - why not
	 * just use the constant; MAX_LDC_CHANNELS
	 */
	guestp->ldc_max_channel_idx = MAX_LDC_CHANNELS;
	/* we might check that all the LDC endpoints are !live */
	/* kind of pointless since we are moving them to a global */


	/*
	 * clear out the devops table.
	 */
	for (int y = 0; y < NVINOS; y++) {
		guestp->vino2inst.vino[y] = DEVOPS_RESERVED;
	}

	for (int x = 0; x < NDEVIDS; x++) {
		guestp->dev2inst[x] = DEVOPS_RESERVED;
	}

	config_guest_virtual_device(guestp, guestp->pip.vdev_cfghandle);
	config_guest_channel_device(guestp, guestp->pip.cdev_cfghandle);


	/* until we boot it ... */
	ASSERT(guestp->state == GUEST_STATE_STOPPED);
	reset_guest_state(guestp);


	DBG(c_printf("End of guest setup\n"));
}


void
res_guest_commit_unconfig(guest_t *guestp)
{
	/* preserve the guest ID ... err thats about it */

	DBG(c_printf("guest 0x%x : unconfig\n", guestp->guestid));

	ASSERT(guestp->state == GUEST_STATE_STOPPED);

	unconfig_guest_virtual_device(guestp);
	unconfig_guest_channel_device(guestp);
	/*
	 * clear out the devops table.
	 */
	for (int y = 0; y < NVINOS; y++) {
		guestp->vino2inst.vino[y] = DEVOPS_RESERVED;
	}

	for (int x = 0; x < NDEVIDS; x++) {
		guestp->dev2inst[x] = DEVOPS_RESERVED;
	}


	init_guest(guestp->guestid);

	/* Just incase we add more phases */
	guestp->pip.res.flags  = RESF_Noop;
}

void
config_a_guest_device_vino(guest_t *guestp, int ino, uint8_t type)
{
	uint64_t cfg_handle = INVALID_CFGHANDLE;

	switch (type) {
		case DEVOPS_VDEV:
			cfg_handle = guestp->vdev_cfghandle;
			break;
		case DEVOPS_CDEV:
			cfg_handle = guestp->cdev_cfghandle;
			break;
		default:
			break;
	};

	DBG(c_printf("guest device:\n\tcfg handle 0x%x 0x%x\n",
	    cfg_handle, ino));
	ASSERT(cfg_handle != INVALID_CFGHANDLE);
	guestp->vino2inst.vino[cfg_handle + ino] = type;

}

void
unconfig_a_guest_device_vino(guest_t *guestp, int ino, uint8_t type)
{
	uint64_t cfg_handle = INVALID_CFGHANDLE;

	switch (type) {
		case DEVOPS_VDEV:
			cfg_handle = guestp->vdev_cfghandle;
			break;
		case DEVOPS_CDEV:
			cfg_handle = guestp->cdev_cfghandle;
			break;
		default:
			break;
	};

	ASSERT(cfg_handle != INVALID_CFGHANDLE);
	guestp->vino2inst.vino[cfg_handle + ino] = DEVOPS_RESERVED;

}

void
config_guest_virtual_device(guest_t *guestp, uint64_t cfg_handle)
{
	uint8_t devid;

	ASSERT(cfg_handle != INVALID_CFGHANDLE);
	if (cfg_handle == INVALID_CFGHANDLE)
		return;

	guestp->vdev_cfghandle = cfg_handle;

	devid = guestp->vdev_cfghandle >> DEVCFGPA_SHIFT;
	guestp->dev2inst[devid] = DEVOPS_VDEV;
}

void
unconfig_guest_virtual_device(guest_t *guestp)
{
	uint8_t devid;

	devid = guestp->vdev_cfghandle >> DEVCFGPA_SHIFT;
	guestp->dev2inst[devid] = DEVOPS_RESERVED;

	guestp->vdev_cfghandle = INVALID_CFGHANDLE;

}

void
config_guest_channel_device(guest_t *guestp, uint64_t cfg_handle)
{
	uint8_t devid, edevid;
	int  	x;

	ASSERT(cfg_handle != INVALID_CFGHANDLE);
	if (cfg_handle == INVALID_CFGHANDLE)
		return;

	guestp->cdev_cfghandle = cfg_handle;

	devid = guestp->cdev_cfghandle >> DEVCFGPA_SHIFT;
	edevid = (guestp->cdev_cfghandle + MAX_LDC_INOS) >> DEVCFGPA_SHIFT;

	for (x = devid; x < edevid; x++)
		guestp->dev2inst[x] = DEVOPS_CDEV;

}

void
unconfig_guest_channel_device(guest_t *guestp)
{
	uint8_t devid, edevid;
	int	 x;

	devid = guestp->cdev_cfghandle >> DEVCFGPA_SHIFT;
	edevid = (guestp->cdev_cfghandle + MAX_LDC_INOS) >> DEVCFGPA_SHIFT;

	for (x = devid; x < edevid; x++)
		guestp->dev2inst[x] = DEVOPS_RESERVED;

	guestp->cdev_cfghandle = INVALID_CFGHANDLE;

}
