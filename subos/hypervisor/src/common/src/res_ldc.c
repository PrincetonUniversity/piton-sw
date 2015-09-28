/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_ldc.c
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

#pragma ident	"@(#)res_ldc.c	1.7	07/06/07 SMI"

#include <stdarg.h>
#include <sys/htypes.h>
#include <traps.h>
#include <mmu.h>
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
#include <debug.h>


/*
 * (re)-configuration code to handle HV LDC resources
 */
static void res_ldc_commit_config(guest_t *gp, ldc_endpoint_t *ldcp);
static void res_ldc_commit_unconfig(guest_t *gp, ldc_endpoint_t *ldcp);

static hvctl_status_t res_ldc_parse_1(bin_md_t *mdp, md_element_t *guest_nodep,
		hvctl_res_error_t *fail_codep,
		md_element_t **failnodepp, int *fail_res_idp);

static hvctl_status_t res_ldc_parse_2(bin_md_t *mdp, int guest_id,
		md_element_t *ldce_nodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp);

static void res_hv_ldc_commit_config(int ch_id);
static void res_hv_ldc_commit_unconfig(int ch_id);

static hvctl_status_t res_hv_ldc_parse_1(bin_md_t *mdp,
		md_element_t *hvldc_nodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp);



/*
 * LDC support functions
 *
 * FIXME: This changes when LDC endpoints have their own
 * global IDs. This means for now the uniq ID for an endpoints
 * is the tuple: (guest_id, channel_id)
 *
 * We'll fix this later...
 */
void
res_ldc_prep()
{
	guest_t		*gp;
	int		i;

	gp = config.guests;

	for (i = 0; i < NGUESTS; i++, gp++) {
		int j;

		/*
		 * If the guest is already unconfigured, then
		 * we've nothing to potentially unconfigure
		 * So we could optimise by skipping all the
		 * channels, but it's pointless because the
		 * per-guest endpoints are going away.
		 * So for now we brute force all endpoints.
		 */
		for (j = 0; j < MAX_LDC_CHANNELS; j++) {
			ldc_endpoint_t	*ep;

			ep = &(gp->ldc_endpoint[j]);

			/* unconfigd guest cannot have live channel */
			ASSERT(!(gp->state == GUEST_STATE_UNCONFIGURED &&
			    ep->is_live));

			/* if live potentially unconfig it */
			ep->pip.res.flags = ep->is_live ?
			    RESF_Unconfig : RESF_Noop;
		}
	}
}


hvctl_status_t
res_ldc_parse(bin_md_t *mdp, hvctl_res_error_t *fail_codep,
			md_element_t **failnodepp, int *fail_res_idp)
{
	md_element_t	*mdep;
	uint64_t	arc_token;
	uint64_t	node_token;
	md_element_t	*guest_nodep;
	hvctl_status_t	status;

	mdp = (bin_md_t *)config.parse_hvmd;

	DBGL(c_printf("\nLDC configuration:\n"));

	mdep = md_find_node(mdp, NULL, MDNAME(guests));
	if (mdep == NULL) {
		DBG(c_printf("Missing guests node in HVMD\n"));
		*failnodepp = NULL;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	/*
	 * FIXME: this multistep process goes away once the top-level
	 * ldc-endpoints aggregator includes all endpoints.
	 */
	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(guest));

	status = HVctl_st_ok;
	while (status == HVctl_st_ok &&
	    NULL != (mdep = md_find_node_by_arc(mdp, mdep, arc_token,
	    node_token, &guest_nodep))) {
		status = res_ldc_parse_1(mdp, guest_nodep, fail_codep,
		    failnodepp, fail_res_idp);
	}
	return (status);
}


hvctl_status_t
res_ldc_parse_1(bin_md_t *mdp, md_element_t *guest_nodep,
		hvctl_res_error_t *fail_codep,
		md_element_t **failnodepp, int *fail_res_idp)
{
	md_element_t	*elemp;
	md_element_t	*ldce_nodep;
	int		dummy;
	uint64_t	guest_id;
	uint64_t	arc_token;
	uint64_t	node_token;

	/*
	 * by now we know its here because we passed the guest parse
	 * which is higher priority than this parse function.
	 */
	dummy = md_node_get_val(mdp, guest_nodep, MDNAME(resource_id),
	    &guest_id);
	ASSERT(dummy);

#if defined(lint)
	dummy = dummy;
#endif

	DBGL(c_printf("\tGuest 0x%x for ldcs:\n", guest_id));

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(ldc_endpoint));

	/*
	 * Spin through the "ldc_endpoint" arcs in the
	 * ldc_endpoints node and config each endpoint !
	 * FIXME; what if already configured !
	 */
	elemp = guest_nodep;
	while (NULL != (elemp = md_find_node_by_arc(mdp, elemp, arc_token,
	    node_token, &ldce_nodep))) {
		hvctl_status_t status;

		status = res_ldc_parse_2(mdp, guest_id, ldce_nodep,
		    fail_codep, fail_res_idp);
		if (status != HVctl_st_ok) {
			*failnodepp = ldce_nodep;
			return (HVctl_st_badmd);
		}
	}
	return (HVctl_st_ok);
}


hvctl_status_t
res_ldc_parse_2(bin_md_t *mdp, int guest_id, md_element_t *ldce_nodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp)
{
	uint64_t	endpt_id;
	ldc_endpoint_t	*ldc_ep;
	uint64_t	target_type;
	uint64_t	target_channel;
	uint64_t	tx_ino;
	uint64_t	rx_ino;
	guest_t		*guestp;
	bool_t		check_guest;
	guest_t		*target_guestp;
	uint64_t	pvt_svc;

	guestp = config.guests;
	guestp = &(guestp[guest_id]);

	if (!md_node_get_val(mdp, ldce_nodep, MDNAME(channel),
	    &endpt_id)) {
		DBGL(c_printf("Missing channel (endpoint number) in"
		    " ldc_endpoint node\n"));
		*fail_res_idp = 0;
miss_prop:
		*fail_codep = HVctl_e_ldc_missing_prop;
		return (HVctl_st_badmd);
	}

	if (endpt_id >= MAX_LDC_CHANNELS) {
		DBGL(c_printf("Illegal channel (endpoint number) in"
		    " ldc_endpoint node\n"));
		*fail_res_idp = 0;
ill_prop:
		*fail_codep = HVctl_e_ldc_illegal_prop;
		return (HVctl_st_badmd);
	}

	DBGL(c_printf("\t\tGuest 0x%x endpoint 0x%x\n", guest_id, endpt_id));

	ldc_ep = &(guestp->ldc_endpoint[endpt_id]);

	ldc_ep->pip.channel = endpt_id;

	*fail_res_idp = endpt_id;

	if (!md_node_get_val(mdp, ldce_nodep, MDNAME(target_type),
	    &target_type)) {
		DBGL(c_printf("Missing target_type in ldc_endpoint node\n"));
		goto miss_prop;
	}
	if (!md_node_get_val(mdp, ldce_nodep, MDNAME(target_channel),
	    &target_channel)) {
		DBGL(c_printf("Missing target_channel in "
		    "ldc_endpoint node\n"));
		goto ill_prop;
	}

	ldc_ep->pip.target_type = target_type;
	ldc_ep->pip.target_channel = target_channel;

	check_guest = false;	/* a flag for later change check */

	switch (target_type) {
	uint64_t	target_guest_id;
	case LDC_HV_ENDPOINT:
			/* nothing more to do */
		DBGL(c_printf("\t\tConnected to HV endpoint 0x%x\n",
		    target_channel));
		break;

	case LDC_GUEST_ENDPOINT:
		if (!md_node_get_val(mdp, ldce_nodep, MDNAME(target_guest),
		    &target_guest_id)) {
			DBGL(c_printf("Missing target_guest in "
			    "ldc_endpoint node\n"));
			goto miss_prop;
		}

		DBGL(c_printf("\t\t\tConnected to guest 0x%x endpoint 0x%x\n",
		    target_guest_id, target_channel));

		/* This goes away with single target ID */
		target_guestp = config.guests;
		target_guestp = &(target_guestp[target_guest_id]);
		ldc_ep->pip.target_guestp = target_guestp;
		check_guest = true;
		break;

#ifdef	CONFIG_FPGA /* { */
	case LDC_SP_ENDPOINT:
		DBGL(c_printf("\t\t\tConnected to SP endpoint 0x%x\n",
		    target_channel));
		break;
#endif /* } */

	default:
		DBGL(c_printf("Invalid target_type in ldc-endpoint node\n"));
		goto ill_prop;
	}


	if (md_node_get_val(mdp, ldce_nodep, MDNAME(private_svc), &pvt_svc)) {

		ldc_ep->pip.is_private = 1;
		ldc_ep->pip.svc_id = pvt_svc;

		switch (ldc_ep->pip.svc_id) {
		case LDC_CONSOLE_SVC:

			if (target_type == LDC_HV_ENDPOINT) {
				DBG(c_printf("Console cannot use HV "
				    "endpoint\n"));
				goto ill_prop;
			}

			if (!md_node_get_val(mdp, ldce_nodep, MDNAME(rx_ino),
			    &rx_ino)) {
				DBG(c_printf("Missing rx_ino in ldc_endpoint "
				    "node\n"));
				goto miss_prop;
			}

			ldc_ep->pip.tx_ino = ldc_ep->pip.rx_ino = tx_ino =
			    rx_ino;

			break;

		default:
			DBG(c_printf("Invalid private service type\n"));
			goto ill_prop;
		}
	} else {
		ldc_ep->pip.is_private = 0;

		if (!md_node_get_val(mdp, ldce_nodep, MDNAME(tx_ino),
		    &tx_ino)) {
			DBGL(c_printf("Missing tx-ino in ldc_endpoint node\n"));
			goto miss_prop;
		}
		if (!md_node_get_val(mdp, ldce_nodep, MDNAME(rx_ino),
		    &rx_ino)) {
			DBGL(c_printf("Missing rx-ino in ldc_endpoint node\n"));
			goto miss_prop;
		}

		DBGL(c_printf("\t\t\t\ttx-ino 0x%x rx-ino 0x%x\n", tx_ino,
		    rx_ino));

		ldc_ep->pip.tx_ino = tx_ino;
		ldc_ep->pip.rx_ino = rx_ino;
	}

	/*
	 * OK figure out if something changed, or if this is a
	 * noop or a config.
	 */
	if (!ldc_ep->is_live) {
		ldc_ep->pip.res.flags = RESF_Config;
		DBGL(c_printf("\t\tElected to config LDC endpoint\n"));
	} else
	if (ldc_ep->target_type != target_type ||
	    ldc_ep->target_channel != target_channel ||
	    (!(ldc_ep->pip.is_private) && (ldc_ep->tx_mapreg.ino != tx_ino)) ||
	    (!(ldc_ep->pip.is_private) && (ldc_ep->rx_mapreg.ino != rx_ino)) ||
	    (check_guest && (ldc_ep->target_guest != target_guestp))) {

#define	E(_e)	DBGL(if (_e) c_printf("\t\t\t%s\n", #_e));
		E(ldc_ep->target_type != target_type);
		E(ldc_ep->target_channel != target_channel);
		E(ldc_ep->tx_mapreg.ino != tx_ino);
		E(ldc_ep->rx_mapreg.ino != rx_ino);
		E((check_guest && (ldc_ep->target_guest != target_guestp)));
#undef	E
		DBGL(c_printf("\t\tModify not supported on LDC channels\n"));
		*fail_codep = HVctl_e_ldc_rebind_na;
		return (HVctl_st_badmd);
	} else {
		DBGL(c_printf("\t\tElected to ignore LDC endpoint\n"));
		ldc_ep->pip.res.flags = RESF_Noop;
	}

	return (HVctl_st_ok);
}


hvctl_status_t
res_ldc_postparse(hvctl_res_error_t *res_error, int *fail_res_id)
{
	return (HVctl_st_ok);
}


void
res_ldc_commit(int flag)
{
	guest_t	*gp;
	int	i;

	gp = config.guests;

	for (i = 0; i < NGUESTS; i++, gp++) {
		int j;

		/*
		 * FIXME:again can optimise around guest configdness
		 * and to skip the unsupported flags
		 */
		for (j = 0; j < MAX_LDC_CHANNELS; j++) {
			ldc_endpoint_t	*ep;

			ep = &(gp->ldc_endpoint[j]);

				/* if not this ops turn move on */
			if (ep->pip.res.flags != flag) continue;

			switch (ep->pip.res.flags) {
			case RESF_Noop:
				DBG(c_printf("guest 0x%x ldc 0x%x : noop\n",
				    gp->guestid, j));
				ASSERT(0);	/* not supported */
				break;
			case RESF_Unconfig:
				res_ldc_commit_unconfig(gp, ep);
				break;
			case RESF_Config:
				res_ldc_commit_config(gp, ep);
				break;
			case RESF_Rebind:
				DBG(c_printf("guest 0x%x ldc 0x%x : rebind\n",
				    gp->guestid, j));
				ASSERT(0);	/* not supported */
				break;
			case RESF_Modify:
				DBG(c_printf("guest 0x%x ldc 0x%x : rebind\n",
				    gp->guestid, j));
				ASSERT(0);	/* not supported */
				break;
			default:
				ASSERT(0);
			}

			ep->pip.res.flags = RESF_Noop; /* cleanup */
		}
	}
}


void
reset_ldc_endpoint(ldc_endpoint_t *ldc_ep)
{
	ldc_ep->tx_qbase_ra = 0;
	ldc_ep->tx_qhead = 0;
	ldc_ep->tx_qtail = 0;

	ldc_ep->rx_qbase_ra = 0;
	ldc_ep->rx_qhead = 0;
	ldc_ep->rx_qtail = 0;
}


void
res_ldc_commit_config(guest_t *guestp, ldc_endpoint_t *ldc_ep)
{
	int tx_ino;
	int rx_ino;

	DBG(c_printf("res_ldc_commit_config guest 0x%x ldce 0x%x\n",
	    guestp->guestid, ldc_ep - guestp->ldc_endpoint));

	ldc_ep->target_type = ldc_ep->pip.target_type;
	ldc_ep->target_channel = ldc_ep->pip.target_channel;
	ldc_ep->is_private = ldc_ep->pip.is_private;
	ldc_ep->svc_id = ldc_ep->pip.svc_id;

	switch (ldc_ep->target_type) {
	case LDC_HV_ENDPOINT:
		DBG(c_printf("\tHV"));
		break;
	case LDC_GUEST_ENDPOINT:
		ldc_ep->target_guest = ldc_ep->pip.target_guestp;
		DBG(c_printf("\tguest 0x%x", ldc_ep->target_guest->guestid));
		break;
	case LDC_SP_ENDPOINT:
		DBG(c_printf("\tSP"));
		break;
	default:
		ASSERT(0);
	}

	DBG(c_printf(" endpoint 0x%x\n", ldc_ep->target_channel));


	if (!ldc_ep->is_private) {
		tx_ino = ldc_ep->pip.tx_ino;

		ldc_ep->tx_mapreg.ino = tx_ino;
		guestp->ldc_ino2endpoint[tx_ino].endpointp = ldc_ep;
		guestp->ldc_ino2endpoint[tx_ino].mapregp = &(ldc_ep->tx_mapreg);

		ASSERT(guestp->cdev_cfghandle != 0);
		config_a_guest_device_vino(guestp, tx_ino, DEVOPS_CDEV);
		rx_ino = ldc_ep->pip.rx_ino;

		ldc_ep->rx_mapreg.ino = rx_ino;
		guestp->ldc_ino2endpoint[rx_ino].endpointp = ldc_ep;
		guestp->ldc_ino2endpoint[rx_ino].mapregp = &(ldc_ep->rx_mapreg);

		config_a_guest_device_vino(guestp, rx_ino, DEVOPS_CDEV);

		ldc_ep->tx_qbase_pa = 0;
		ldc_ep->tx_qsize = 0;

		ldc_ep->rx_qbase_pa = 0;
		ldc_ep->rx_qsize = 0;
		ldc_ep->rx_updated = 1;
	}

	reset_ldc_endpoint(ldc_ep);

	ldc_ep->is_live = true;
}


void
res_ldc_commit_unconfig(guest_t *guestp, ldc_endpoint_t *ldc_ep)
{
	int tx_ino;
	int rx_ino;

	DBG(c_printf("res_ldc_commit_unconfig guest 0x%x ldce 0x%x\n",
	    guestp->guestid, ldc_ep - guestp->ldc_endpoint));

	ASSERT(ldc_ep->is_live);

	/*
	 * Undo the interrupt back maps
	 */
	if (ldc_ep->is_private == 0) {
		tx_ino = ldc_ep->tx_mapreg.ino;
		guestp->ldc_ino2endpoint[tx_ino].endpointp = NULL;
		guestp->ldc_ino2endpoint[tx_ino].mapregp = NULL;

		unconfig_a_guest_device_vino(guestp, tx_ino, DEVOPS_CDEV);

		rx_ino = ldc_ep->rx_mapreg.ino;
		guestp->ldc_ino2endpoint[rx_ino].endpointp = NULL;
		guestp->ldc_ino2endpoint[rx_ino].mapregp = NULL;

		unconfig_a_guest_device_vino(guestp, rx_ino, DEVOPS_CDEV);
	}

	/* This is about it for an unconfigure */
	ldc_ep->is_live = false;
}


/*
 * Now the HV LDCs ... which should be vanishing into
 * becomming regular LDCs sometime in the very newar future.
 */
void
res_hv_ldc_prep()
{
	int i;

	for (i = 0; i < MAX_HV_LDC_CHANNELS; i++) {
		ldc_endpoint_t	*hvep;

		hvep = config.hv_ldcs;
		hvep = &(hvep[i]);

		hvep->pip.res.flags = (!hvep->is_live) ?
		    RESF_Noop : RESF_Unconfig;
	}
}


hvctl_status_t
res_hv_ldc_parse(bin_md_t *mdp, hvctl_res_error_t *fail_codep,
			md_element_t **failnodepp, int *fail_res_idp)
{
	md_element_t	*mdep, *hvldc_nodep, *rootnodep;
	uint64_t	arc_token;
	uint64_t	name_token;

	mdp = (bin_md_t *)config.parse_hvmd;

	DBGHL(c_printf("HV LDC configuration:\n"));

	/*
	 * First find the root node
	 */
	rootnodep = md_find_node(mdp, NULL, MDNAME(root));
	if (rootnodep == NULL) {
		DBGHL(c_printf("Missing root node in HVMD\n"));
		*failnodepp = NULL;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	/* if no ldc_endpoints node under root nothing to parse */
	if (md_find_node_by_arc(mdp, rootnodep, MDARC(MDNAME(fwd)),
	    MDNODE(MDNAME(ldc_endpoints)), &mdep) == NULL) {
		return (HVctl_st_ok);
	}

	arc_token = MDARC(MDNAME(fwd));
	name_token = MDNODE(MDNAME(ldc_endpoint));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep, arc_token,
	    name_token, &hvldc_nodep))) {
		hvctl_status_t status;

		status = res_hv_ldc_parse_1(mdp, hvldc_nodep, fail_codep,
		    fail_res_idp);
		if (status != HVctl_st_ok) {
			*failnodepp = hvldc_nodep;
			return (status);
		}
	}
	return (HVctl_st_ok);
}


hvctl_status_t
res_hv_ldc_parse_1(bin_md_t *mdp, md_element_t *hvldc_nodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp)
{
	uint64_t	chid;
	uint64_t	type;
	uint64_t	guestid;
	uint64_t	svc_id;
	uint64_t	tchan_id;
	ldc_endpoint_t	*hvep;

	if (!md_node_get_val(mdp, hvldc_nodep, MDNAME(svc_id), &svc_id)) {
		/* Not a HV endpoint - skip it */
		return (HVctl_st_ok);
	}

	DBGHL(c_printf("Parse HV LDC endpoints\n"));

	if (!md_node_get_val(mdp, hvldc_nodep, MDNAME(channel), &chid)) {
		DBGHL(c_printf("Missing channel id in HV LDC node\n"));
		*fail_res_idp = 0;
miss_prop:
		*fail_codep = HVctl_e_hv_ldc_missing_prop;
		return (HVctl_st_badmd);
	}
	if (chid >= MAX_HV_LDC_CHANNELS) {
		DBGHL(c_printf("Invalid channel id 0x%x in HV LDC node\n",
		    chid));
		*fail_res_idp = 0;
ill_prop:
		*fail_codep = HVctl_e_hv_ldc_illegal_prop;
		return (HVctl_st_badmd);
	}

	DBGHL(c_printf("\tHV endpoint 0x%x :", chid));

	if (!md_node_get_val(mdp, hvldc_nodep, MDNAME(target_type), &type)) {
		DBG(c_printf("Missing target_type in HV LDC node\n"));
		goto miss_prop;
	}

	hvep = config.hv_ldcs;
	hvep = &(hvep[chid]);

	*fail_res_idp = chid;

	hvep->pip.target_type = type;

	switch (type) {
	case LDC_GUEST_ENDPOINT:	/* guest<->HV LDC */
		if (!md_node_get_val(mdp, hvldc_nodep, MDNAME(target_guest),
		    &guestid)) {
			DBGHL(c_printf("Missing target_guest in HV "
			    "LDC node\n"));
			goto miss_prop;
		}

		/* point to target guest */
		hvep->pip.target_guestp =
		    &(((guest_t *)config.guests)[guestid]);

		DBGHL(c_printf("\tConnected to endpoint in guest 0x%x\n",
		    guestid));
		break;

	case LDC_SP_ENDPOINT:	/* HV<->SP LDC */
		DBGHL(c_printf("\tConnected to SP endpoint\n"));
		break;

	default:
		DBGHL(c_printf("Illegal target_type 0x%x\n", type));
		goto ill_prop;
	}


	if (!md_node_get_val(mdp, hvldc_nodep, MDNAME(target_channel),
	    &tchan_id)) {
		DBGHL(c_printf("Missing target channel id in HV LDC node\n"));
		goto miss_prop;
	}
	if (tchan_id >= MAX_LDC_CHANNELS) {
		DBGHL(c_printf("Invalid target channel id 0x%x in HV "
		    "LDC node\n", tchan_id));
		goto ill_prop;
	}

	DBGHL(c_printf("\t\tTarget channel = 0x%x ", tchan_id));

	hvep->pip.target_channel = tchan_id;

	hvep->pip.svc_id = svc_id;

	switch (svc_id) {
	case LDC_HVCTL_SVC:
		/*
		 * We don't yet allow for HVCTL channel between the
		 * hypervisor and SP.  Maybe one day we will have a
		 * Zeus or Zeus-lite running on the SP and at that
		 * point we can remove this check.
		 */
		if (hvep->pip.target_type == LDC_SP_ENDPOINT) {
			DBGHL(c_printf("No HVCTL LDC to the SP "
			    "allowed yet\n"));
			goto ill_prop;
		}

		DBGHL(c_printf(" for HVCTL service\n"));

		break;

	default:
		DBGHL(c_printf("Unknown service type 0x%x\n", svc_id));
		goto miss_prop;
	}

	/*
	 * Now figure if this is a config or a modify
	 */
	if (!hvep->is_live) {
		hvep->pip.res.flags = RESF_Config;
		DBGHL(c_printf("Elected to Configure"));
	} else {
		if (hvep->pip.target_type != hvep->target_type ||
		    (hvep->target_type == LDC_GUEST_ENDPOINT &&
		    hvep->pip.target_guestp != hvep->target_guest) ||
		    hvep->pip.target_channel != hvep->target_channel) {
			DBGHL(c_printf("A HV LDC channel must be unconfiged "
			    "before it can be re-bound\n"));
			*fail_codep = HVctl_e_hv_ldc_rebind_na;
			return (HVctl_st_eillegal);
		} else {
			hvep->pip.res.flags = RESF_Noop;
			DBGHL(c_printf("Elected to Ignore"));
		}
	}

	return (HVctl_st_ok);
}


hvctl_status_t
res_hv_ldc_postparse(hvctl_res_error_t *res_error, int *fail_res_id)
{
	return (HVctl_st_ok);
}


void
res_hv_ldc_commit(int flag)
{
	int i;

	for (i = 0; i < MAX_HV_LDC_CHANNELS; i++) {
		ldc_endpoint_t *hvep;

		hvep = config.hv_ldcs;
		hvep = &(hvep[i]);

		/* if not this ops turn move on */
		if (hvep->pip.res.flags != flag) continue;

		switch (hvep->pip.res.flags) {
		case RESF_Noop:
			DBG(c_printf("hv_ldc 0x%x : noop\n", i));
			break;
		case RESF_Unconfig:
			res_hv_ldc_commit_unconfig(i);
			break;
		case RESF_Config:
			res_hv_ldc_commit_config(i);
			break;
		case RESF_Rebind:
			DBG(c_printf("hv_ldc 0x%x : rebind\n", i));
			ASSERT(0);	/* not supported */
			break;
		case RESF_Modify:
			DBG(c_printf("hv_ldc 0x%x : modify\n", i));
			ASSERT(0);	/* not supported */
			break;
		default:
			ASSERT(0);
		}

		hvep->pip.res.flags = RESF_Noop; /* cleanup */
	}
}


void
res_hv_ldc_commit_config(int ch_id)
{
	ldc_endpoint_t *hvep;
	extern void hvctl_svc_callback();	/* FIXME: in a header */

	hvep = config.hv_ldcs;
	hvep = &(hvep[ch_id]);

	DBGHL(c_printf("\t\tConfig endpoint\n"));
	ASSERT(!hvep->is_live);

	hvep->target_type = hvep->pip.target_type;

	switch (hvep->target_type) {
	case LDC_GUEST_ENDPOINT:	/* guest<->HV LDC */
		hvep->target_guest = hvep->pip.target_guestp;
		break;

	case LDC_SP_ENDPOINT:	/* HV<->SP LDC */
		break;
	default:
		ASSERT(0);
	}

	hvep->target_channel = hvep->pip.target_channel;

	/* svc id determines the callback setup */
	switch (hvep->pip.svc_id) {

	case LDC_HVCTL_SVC:
		/*
		 * FIXME: Why did we save the endpoint number
		 * instead of a pointer to the endpoint ?
		 */
		config.hvctl_ldc = ch_id; /* save the HVCTL channel id */

		hvep->rx_cb = (uint64_t)&hvctl_svc_callback;
		hvep->rx_cbarg = (uint64_t)&config;
		break;

	default:
		DBG(c_printf("Unknown service type 0x%x\n", hvep->pip.svc_id));
		ASSERT(0);
	}

	/* Mark channel as live */
	ASSERT(!hvep->is_live);
	hvep->is_live = true;
}


void
res_hv_ldc_commit_unconfig(int ch_id)
{
	ldc_endpoint_t *hvep;

	hvep = config.hv_ldcs;
	hvep = &(hvep[ch_id]);

	DBGHL(c_printf("\t\tUnconfig endpoint %d\n", ch_id));
	ASSERT(hvep->is_live);

	hvep->is_live = false;
}
