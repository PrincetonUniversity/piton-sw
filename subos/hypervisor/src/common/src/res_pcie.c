/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_pcie.c
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

#pragma ident	"@(#)res_pcie.c	1.7	07/06/07 SMI"


/*
 * (re)-configuration code to handle HV PCI-E resources
 */

#include <stdarg.h>
#include <sys/htypes.h>
#include <hypervisor.h>
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
#include <proto.h>
#include <debug.h>

#ifdef CONFIG_PCIE

/*
 * resource processing support
 */
static void res_pcie_bus_commit_config(int i);
static void res_pcie_bus_commit_unconfig(int i);
static hvctl_status_t res_pcie_bus_parse_1(bin_md_t *mdp,
		md_element_t *pcie_nodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp);

void config_a_guest_pcie_bus(pcie_device_t *pciep);
void unconfig_a_guest_pcie_bus(pcie_device_t *pciep);


void
res_pcie_bus_prep()
{
	int i;
	pcie_device_t	 *pciep;

	pciep = (pcie_device_t *)config.pcie_busses;

	/* if the bus is configured mark it for unconfiguring */
	for (i = 0; i < NUM_PCIE_BUSSES; i++) {
		pciep[i].pip.res.flags =
		    pciep[i].guestp == NULL ? RESF_Noop : RESF_Unconfig;
	}
}


hvctl_status_t
res_pcie_bus_parse(bin_md_t *mdp, hvctl_res_error_t *fail_codep,
			md_element_t **failnodepp, int *fail_res_idp)
{
	md_element_t	*mdep, *pcie_nodep, *rootnodep;
	uint64_t	arc_token;
	uint64_t	name_token;

	mdp = (bin_md_t *)config.parse_hvmd;

	rootnodep = md_find_node(mdp, NULL, MDNAME(root));
	if (rootnodep == NULL) {
		DBG(c_printf("Missing root node in HVMD\n"));
		goto fail;
	}
	DBGPE(c_printf("PCI-E configuration:\n"));

	arc_token = MDARC(MDNAME(fwd));
	name_token = MDNODE(MDNAME(devices));

	if (md_find_node_by_arc(mdp, rootnodep, arc_token, name_token,
	    &mdep) == NULL) {
		DBG(c_printf("Missing devices node in HVMD\n"));
fail:;
		*failnodepp = NULL;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	DBG(md_dump_node(mdp, mdep));

	name_token = MDNODE(MDNAME(pcie_bus));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    arc_token, name_token, &pcie_nodep))) {
		hvctl_status_t status;

		status = res_pcie_bus_parse_1(mdp, pcie_nodep, fail_codep,
		    fail_res_idp);
		if (status != HVctl_st_ok) {
			*failnodepp = pcie_nodep;
			return (status);
		}
	}
	return (HVctl_st_ok);
}


hvctl_status_t
res_pcie_bus_parse_1(bin_md_t *mdp, md_element_t *pcie_nodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp)
{
	pcie_device_t	*pciep;
	uint64_t	id;
	uint64_t	guestid;
	uint64_t	cfg_handle;
	md_element_t	*guestnodep;
	bool_t		allow_bypass;
	uint64_t	dummy;

	DBGPE(c_printf("Parse PCIE node\n"));

	DBG(md_dump_node(mdp, pcie_nodep));

	if (!md_node_get_val(mdp, pcie_nodep, MDNAME(resource_id), &id)) {
		DBGPE(c_printf("Missing id in PCIE node\n"));
		*fail_res_idp = 0;
		*fail_codep = HVctl_e_pcie_missing_prop;
		return (HVctl_st_badmd);
	}
	if (!md_node_get_val(mdp, pcie_nodep, MDNAME(cfghandle), &cfg_handle)) {
		DBGPE(c_printf("Missing cfg-handle in PCIE node\n"));
		*fail_res_idp = 0;
		*fail_codep = HVctl_e_pcie_missing_prop;
		return (HVctl_st_badmd);
	}

	if (id >= NUM_PCIE_BUSSES) {
		DBGPE(c_printf("Invalid PCIE id 0x%x in PCIE node\n", id));
		*fail_res_idp = 0;
ill_prop:
		*fail_codep = HVctl_e_pcie_illegal_prop;
		return (HVctl_st_badmd);
	}

	DBGPE(c_printf("\tPCIE bus 0x%x :\n", id));

	allow_bypass = false;
	if (md_node_get_val(mdp, pcie_nodep, MDNAME(allow_bypass), &dummy) &&
	    dummy == 1LL)
		allow_bypass = true;

	if (NULL == md_find_node_by_arc(mdp, pcie_nodep, MDARC(MDNAME(back)),
	    MDNODE(MDNAME(guest)), &guestnodep)) {
		DBG(c_printf("Missing back arc to guest node in "
		    "pcie_bus node\n"));
		*fail_codep = HVctl_e_pcie_missing_guest;
		goto ill_prop;
	}
	if (!md_node_get_val(mdp, guestnodep, MDNAME(resource_id), &guestid)) {
		DBG(c_printf("Missing resource_id in guest node\n"));
		*fail_codep = HVctl_e_guest_missing_id;
		goto ill_prop;
	}
	if (guestid >= NGUESTS) {
		DBG(c_printf("Invalid resource_id %d in guest node\n",
		    guestid));
		*fail_codep = HVctl_e_guest_invalid_id;
		goto ill_prop;
	}

	pciep = config.pcie_busses;
	pciep = &(pciep[id]);
	pciep->cfg_handle = cfg_handle;
	pciep->id = id;

	/* Possible sanity checks on guest validity */
	if (pciep->guestp == NULL) {
		pciep->pip.res.flags = RESF_Config;
		pciep->pip.guestid = guestid;
		pciep->pip.allow_bypass = allow_bypass;
		DBGPE(c_printf("\tElected to config PCIE bus\n"));
	} else {
		guest_t	*guestp;

		guestp = config.guests;
		if (&(guestp[guestid]) != pciep->guestp ||
		    pciep->allow_bypass != allow_bypass) {
			DBGPE(c_printf("Cannot rebind/modify a PCIE device\n"));
			*fail_codep = HVctl_e_pcie_rebind_na;
			return (HVctl_st_eillegal);
		}
		DBGPE(c_printf("Elected to ignore PCIE bus\n"));
		pciep->pip.res.flags = RESF_Noop;
	}

	return (HVctl_st_ok);
}


hvctl_status_t
res_pcie_bus_postparse(hvctl_res_error_t *res_error, int *fail_res_id)
{
	return (HVctl_st_ok);
}


void
res_pcie_bus_commit(int flag)
{
	int		i;
	pcie_device_t	*pcie_busses;

	pcie_busses = (pcie_device_t *)config.pcie_busses;

	for (i = 0; i < NUM_PCIE_BUSSES; i++) {
		pcie_device_t	*pciep;

		pciep = &(pcie_busses[i]);

		/* if not this ops turn move on */
		if (pciep->pip.res.flags != flag) continue;

		switch (pciep->pip.res.flags) {
		case RESF_Noop:
			DBG(c_printf("pcie 0x%x : noop\n", i));
			break;
		case RESF_Unconfig:
			res_pcie_bus_commit_unconfig(i);
			break;
		case RESF_Config:
			res_pcie_bus_commit_config(i);
			break;
		case RESF_Rebind:
			DBG(c_printf("pcie 0x%x : rebind\n", i));
			ASSERT(0);	/* not supported */
			break;
		case RESF_Modify:
			DBG(c_printf("pcie 0x%x : modify\n", i));
			ASSERT(0);	/* not supported */
			break;
		default:
			ASSERT(0);
		}

		pciep->pip.res.flags = RESF_Noop; /* cleanup */
	}
}


void
res_pcie_bus_commit_config(int bus)
{
	pcie_device_t	*pciep;
	guest_t		*guestp;

	pciep = (pcie_device_t *)config.pcie_busses;
	guestp = (guest_t *)config.guests;

	pciep = &(pciep[bus]);

	ASSERT(pciep->guestp == NULL);

	DBG(c_printf("\tpcie 0x%x configuring for guest 0x%x\n", bus,
	    pciep->pip.guestid));

	guestp = &(guestp[pciep->pip.guestid]);

	pciep->guestp = guestp;
	pciep->allow_bypass = pciep->pip.allow_bypass;

	config_a_guest_pcie_bus(pciep);
}


void
res_pcie_bus_commit_unconfig(int bus)
{
	pcie_device_t *pciep;

	pciep = (pcie_device_t *)config.pcie_busses;
	pciep = &(pciep[bus]);

	ASSERT(pciep->guestp != NULL);

	/*
	 * If the owning guest is still live we have a problem.
	 * We would like to reset the pcie bus as part of the
	 * unconfigure, but the reset delay will cause a mondo timeout
	 * on the hvctl channel vcpu.
	 *
	 * So we assume that since we can't DR PCI busses, that
	 * the guest must be stopped before this can be done.
	 */
	if (pciep->guestp->state != GUEST_STATE_STOPPED) {
		DBG(c_printf("\tWARNING: pcie unconfigure should reset "
		    "pcie bus 0x%x\n", bus));
	}

	DBG(c_printf("\tpcie 0x%x unconfigured\n", bus));
	unconfig_a_guest_pcie_bus(pciep);
	pciep->guestp = NULL;
}

#endif
