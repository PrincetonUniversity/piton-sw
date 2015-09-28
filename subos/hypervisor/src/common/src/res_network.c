/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_network.c
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

#pragma ident	"@(#)res_network.c	1.3	07/06/07 SMI"


/*
 * (re)-configuration code to handle HV network resources
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
#include <network.h>
#include <vdev_ops.h>
#include <config.h>
#include <offsets.h>
#include <hvctl.h>
#include <md.h>
#include <abort.h>
#include <proto.h>
#include <debug.h>

#ifdef STANDALONE_NET_DEVICES

/*
 * resource processing support
 */
static void res_network_device_commit_config(int i);
static void res_network_device_commit_unconfig(int i);
static hvctl_status_t res_network_device_parse_1(bin_md_t *mdp,
		md_element_t *network_device_nodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp);

void config_a_guest_network_device(network_device_t *netp);
void unconfig_a_guest_network_device(network_device_t *netp);

void
res_network_device_prep()
{
	int i;
	network_device_t	 *netp;

	netp = (network_device_t *)config.network_devices;

	/* if the device is configured mark it for unconfiguring */
	for (i = 0; i < NUM_NETWORK_DEVICES; i++) {
		netp[i].pip.res.flags =
		    netp[i].guestp == NULL ? RESF_Noop : RESF_Unconfig;
	}
}


hvctl_status_t
res_network_device_parse(bin_md_t *mdp, hvctl_res_error_t *fail_codep,
			md_element_t **failnodepp, int *fail_res_idp)
{
	md_element_t	*mdep, *net_nodep, *rootnodep;
	uint64_t	arc_token;
	uint64_t	name_token;

	mdp = (bin_md_t *)config.parse_hvmd;

	rootnodep = md_find_node(mdp, NULL, MDNAME(root));
	if (rootnodep == NULL) {
		DBG(c_printf("Missing root node in HVMD\n"));
		goto fail;
	}
	DBGNET(c_printf("Network configuration:\n"));

	arc_token = MDARC(MDNAME(fwd));
	name_token = MDNODE(MDNAME(devices));

	if (md_find_node_by_arc(mdp, rootnodep, arc_token, name_token,
	    &mdep) == NULL) {
		DBGNET(c_printf("Missing devices node in HVMD\n"));
fail:;
		*failnodepp = NULL;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	DBGNET(md_dump_node(mdp, mdep));

	name_token = MDNODE(MDNAME(network_device));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    arc_token, name_token, &net_nodep))) {
		hvctl_status_t status;

		status = res_network_device_parse_1(mdp, net_nodep, fail_codep,
		    fail_res_idp);
		if (status != HVctl_st_ok) {
			*failnodepp = net_nodep;
			return (status);
		}
	}
	return (HVctl_st_ok);
}


hvctl_status_t
res_network_device_parse_1(bin_md_t *mdp, md_element_t *net_nodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp)
{
	network_device_t	*netp;
	uint64_t	id;
	uint64_t	guestid;
	uint64_t	cfg_handle;
	md_element_t	*guestnodep;

	DBGNET(c_printf("Parse network node\n"));

	DBGNET(md_dump_node(mdp, net_nodep));

	if (!md_node_get_val(mdp, net_nodep, MDNAME(resource_id), &id)) {
		DBGNET(c_printf("Missing id in network node\n"));
		*fail_res_idp = 0;
		*fail_codep = HVctl_e_network_missing_prop;
		return (HVctl_st_badmd);
	}
	if (!md_node_get_val(mdp, net_nodep, MDNAME(cfghandle), &cfg_handle)) {
		DBGNET(c_printf("Missing cfg-handle in network node\n"));
		*fail_res_idp = 0;
		*fail_codep = HVctl_e_network_missing_prop;
		return (HVctl_st_badmd);
	}

	if (id >= NUM_NETWORK_DEVICES) {
		DBGNET(c_printf("Invalid id 0x%x in network node\n", id));
		*fail_res_idp = 0;
ill_prop:
		*fail_codep = HVctl_e_network_illegal_prop;
		return (HVctl_st_badmd);
	}

	DBGNET(c_printf("\tNetwork device 0x%x :\n", id));

	if (NULL == md_find_node_by_arc(mdp, net_nodep,
	    MDARC(MDNAME(back)), MDNODE(MDNAME(guest)), &guestnodep)) {
		DBGNET(c_printf("Missing back arc to guest node in "
		"network node\n"));
		*fail_codep = HVctl_e_network_missing_guest;
		goto ill_prop;
	}
	if (!md_node_get_val(mdp, guestnodep, MDNAME(resource_id), &guestid)) {
		DBGNET(c_printf("Missing resource_id in guest node\n"));
		*fail_codep = HVctl_e_guest_missing_id;
		goto ill_prop;
	}
	if (guestid >= NGUESTS) {
		DBGNET(c_printf("Invalid resource_id %d in guest node\n",
		    guestid));
		*fail_codep = HVctl_e_guest_invalid_id;
		goto ill_prop;
	}

	netp = config.network_devices;
	netp = &(netp[id]);
	netp->cfg_handle = cfg_handle;
	netp->id = id;

	/* Possible sanity checks on guest validity */
	if (netp->guestp == NULL) {
		netp->pip.res.flags = RESF_Config;
		netp->pip.guestid = guestid;
		DBGNET(c_printf("\tElected to config network device\n"));
	} else {
		guest_t	*guestp;

		guestp = config.guests;
		if (&(guestp[guestid]) != netp->guestp) {
			DBGNET(c_printf(
			    "Cannot rebind/modify a network device\n"));
			*fail_codep = HVctl_e_network_rebind_na;
			return (HVctl_st_eillegal);
		}
		DBGNET(c_printf("Elected to ignore network device\n"));
		netp->pip.res.flags = RESF_Noop;
	}

	return (HVctl_st_ok);
}


hvctl_status_t
res_network_device_postparse(hvctl_res_error_t *res_error, int *fail_res_id)
{
	return (HVctl_st_ok);
}


void
res_network_device_commit(int flag)
{
	int		i;
	network_device_t	*network_devices;

	network_devices = (network_device_t *)config.network_devices;

	for (i = 0; i < NUM_NETWORK_DEVICES; i++) {
		network_device_t	*netp;

		netp = &(network_devices[i]);

		/* if not this ops turn move on */
		if (netp->pip.res.flags != flag) continue;

		switch (netp->pip.res.flags) {
		case RESF_Noop:
			DBGNET(c_printf("network 0x%x : noop\n", i));
			break;
		case RESF_Unconfig:
			res_network_device_commit_unconfig(i);
			break;
		case RESF_Config:
			res_network_device_commit_config(i);
			break;
		case RESF_Rebind:
			DBGNET(c_printf("network  0x%x : rebind\n", i));
			ASSERT(0);	/* not supported */
			break;
		case RESF_Modify:
			DBGNET(c_printf("Network 0x%x : modify\n", i));
			ASSERT(0);	/* not supported */
			break;
		default:
			ASSERT(0);
		}

		netp->pip.res.flags = RESF_Noop; /* cleanup */
	}
}


void
res_network_device_commit_config(int devid)
{
	network_device_t	*netp;
	guest_t			*guestp;

	netp = (network_device_t *)config.network_devices;
	guestp = (guest_t *)config.guests;

	netp = &(netp[devid]);

	ASSERT(netp->guestp == NULL);

	DBGNET(c_printf("\tnetwork device 0x%x configuring for guest 0x%x\n",
	    devid, netp->pip.guestid));

	guestp = &(guestp[netp->pip.guestid]);

	netp->guestp = guestp;

	config_a_guest_network_device(netp);
}


void
res_network_device_commit_unconfig(int devid)
{
	network_device_t *netp;

	netp = (network_device_t *)config.network_devices;
	netp = &(netp[devid]);

	ASSERT(netp->guestp != NULL);

	/*
	 * If the owning guest is still live we have a problem.
	 * We would like to reset the network device as part of the
	 * unconfigure, but the reset delay could cause a mondo timeout
	 * on the hvctl channel vcpu.
	 *
	 * So we assume that since we can't DR network devices, that
	 * the guest must be stopped before this can be done.
	 */
	if (netp->guestp->state != GUEST_STATE_STOPPED) {
		DBGNET(c_printf(
		    "\tWARNING: network device unconfigure should reset "
		    "network device 0x%x\n", devid));
	}

	DBGNET(c_printf("\tnetwork device 0x%x unconfigured\n", devid));
	unconfig_a_guest_network_device(netp);
	netp->guestp = NULL;
}

#endif	/* STANDALONE_NET_DEVICES */
