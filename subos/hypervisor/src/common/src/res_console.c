/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_console.c
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

#pragma ident	"@(#)res_console.c	1.6	07/06/07 SMI"

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
#include <debug.h>

/*
 * (re)-configuration code to handle HV guest consoles
 */
static hvctl_status_t res_console_parse_1(bin_md_t *mdp,
		md_element_t *cons_nodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp);

static void res_console_commit_config(guest_t *guestp);
static void res_console_commit_unconfig(guest_t *guestp);
static void res_console_commit_modify(guest_t *guestp);


void
init_consoles()
{
	guest_t *gp;
	int	i;

	gp = (guest_t *)config.guests;

	for (i = 0; i < NGUESTS; i++, gp++) {
		gp->console.type = CONS_TYPE_UNCONFIG;
	}
}

/*
 * Console MD support functions.
 */
void
res_console_prep()
{
	guest_t	*gp;
	int	i;

	gp = config.guests;

	for (i = 0; i < NGUESTS; i++, gp++) {
		gp->console.pip.res.flags =
		    (gp->console.type == CONS_TYPE_UNCONFIG) ?
		    RESF_Noop : RESF_Unconfig;
	}
}


hvctl_status_t
res_console_parse(bin_md_t *mdp, hvctl_res_error_t *fail_codep,
			md_element_t **failnodepp, int *fail_res_idp)
{
	md_element_t	*mdep;
	uint64_t	arc_token;
	uint64_t	node_token;
	md_element_t	*cons_nodep;

	mdp = (bin_md_t *)config.parse_hvmd;

	DBG(c_printf("\nConsole configuration:\n"));

	mdep = md_find_node(mdp, NULL, MDNAME(consoles));
	if (mdep == NULL) {
		DBG(c_printf("Missing consoles node in HVMD\n"));
		*failnodepp = NULL;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(console));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep, arc_token,
	    node_token, &cons_nodep))) {
		hvctl_status_t status;
		status = res_console_parse_1(mdp, cons_nodep, fail_codep,
		    fail_res_idp);
		if (status != HVctl_st_ok) {
			*failnodepp = cons_nodep;
			return (status);
		}
	}
	DBG(c_printf("\nConsole configuration: OK \n"));
	return (HVctl_st_ok);
}


hvctl_status_t
res_console_parse_1(bin_md_t *mdp, md_element_t *cons_nodep,
		hvctl_res_error_t *fail_codep, int *fail_res_idp)
{
	uint64_t	resource_id, guest_id, channel_id, ino;
	guest_t		*guestp;
	md_element_t	*guest_nodep, *ldc_nodep, *mdep;

	DBG(md_dump_node(mdp, cons_nodep));

	if (!md_node_get_val(mdp, cons_nodep, MDNAME(resource_id),
	    &resource_id)) {
		DBG(c_printf("Missing resource_id in console node\n"));
		*fail_codep = HVctl_e_cons_missing_id;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	*fail_res_idp = resource_id;

		/*
		 * This console node needs to point back to the guest
		 * that owns it.
		 */

	mdep = md_find_node_by_arc(mdp, cons_nodep, MDARC(MDNAME(back)),
	    MDNODE(MDNAME(guest)), &guest_nodep);
	if (mdep == NULL) {
		DBG(c_printf("Missing guest for console 0x%x", resource_id));
		*fail_codep = HVctl_e_cons_missing_guest;
		goto fail;
	}

	if (!md_node_get_val(mdp, guest_nodep, MDNAME(resource_id),
	    &guest_id)) {
		DBG(c_printf("Missing resource_id in console's guest node\n"));
		*fail_codep = HVctl_e_cons_missing_guest_id;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}
	if (guest_id >= NGUESTS) {
		DBG(c_printf("Invalid resource_id in console's guest node\n"));
		*fail_codep = HVctl_e_cons_invalid_guest_id;
		*fail_res_idp = 0;
		return (HVctl_st_badmd);
	}

	guestp = config.guests;
	guestp = &(guestp[guest_id]);

	DBG(c_printf("\tconsole 0x%x for guest 0x%x @ 0x%x\n",
	    resource_id, guest_id, (uint64_t)guestp));

		/*
		 * This console node points fwd to the LDC node
		 * that it needs. Failing that there should be a
		 * UART address in the node for this specific
		 * console.
		 */

	mdep = md_find_node_by_arc(mdp, cons_nodep, MDARC(MDNAME(fwd)),
	    MDNODE(MDNAME(ldc_endpoint)), &ldc_nodep);
	if (mdep == NULL) {
#ifdef CONFIG_CN_UART /* { */
		uint64_t uartbase;
		if (!md_node_get_val(mdp, cons_nodep, MDNAME(uartbase),
		    &uartbase)) {
			DBG(c_printf("Missing ldc arc or uartbase in console"
			    " node\n"));
			*fail_codep = HVctl_e_cons_missing_uartbase;
			goto fail;
		}
		guestp->console.pip.type = CONS_TYPE_UART;
		guestp->console.pip.uartbase = uartbase;
		DBG(c_printf("UART specified for console\n"));
#else /* } { */
		DBG(c_printf("No ldc endpoint specified for console\n"));
		*fail_codep = HVctl_e_cons_missing_ldc_id;
		goto fail;
#endif /* } */
	} else {

		/*
		 * FIXME: LDC errors shouldn't really be possible here
		 * we should have already parsed all the LDC endpoints
		 * so if properties were wrong or missing by this point
		 * we would already have found out.
		 * We leave the checks in here for sanity for now.
		 */

		if (!md_node_get_val(mdp, ldc_nodep, MDNAME(channel),
		    &channel_id)) {
			DBG(c_printf("Missing channel_id in console's"
			    " ldc node\n"));
			*fail_codep = HVctl_e_cons_missing_ldc_id;
			*fail_res_idp = 0;
			goto fail;
		}
		if (channel_id >= MAX_LDC_CHANNELS) {
			DBG(c_printf("Invalid channel id in console's ldc"
			    " node\n"));
			*fail_codep = HVctl_e_cons_invalid_ldc_id;
			*fail_res_idp = 0;
			goto fail;
		}

		DBG(c_printf("\tconsole 0x%x for guest 0x%x [@ 0x%x]"
		    " uses LDC channel 0x%x\n",
		    resource_id, guest_id, (uint64_t)guestp, channel_id));

		guestp->console.pip.type = CONS_TYPE_LDC;
		guestp->console.pip.ldc_channel = channel_id;
	}


		/* Determine the interrupt the console is bound to */
	if (!md_node_get_val(mdp, cons_nodep, MDNAME(ino), &ino)) {
		DBG(c_printf("Missing ino in console node\n"));
		*fail_codep = HVctl_e_cons_missing_ino;
		goto fail;
	}
	if (ino >= NINOSPERDEV) {
		DBG(c_printf("Invalid ino in console node\n"));
		*fail_codep = HVctl_e_cons_invalid_ino;
		goto fail;
	}
	guestp->console.pip.ino = ino;

	/*
	 * Now we go and figureout what we need to do to the
	 * guest console to update or configure its state.
	 */
	if (guestp->console.type == CONS_TYPE_UNCONFIG) {
		DBG(c_printf("\t\tElected to config console of "
		    "guest 0x%x\n", guest_id));
		guestp->console.pip.res.flags = RESF_Config;
	} else {
/* BEGIN CSTYLED */
		if (guestp->console.type != guestp->console.pip.type ||
			(guestp->console.type == CONS_TYPE_LDC &&
			guestp->console.endpt !=
				guestp->console.pip.ldc_channel) ||
			(guestp->console.vintr_mapreg->ino !=
				guestp->console.pip.ino)
#ifdef CONFIG_CN_UART /* { */
			|| ((guestp->console.type == CONS_TYPE_UART) &&
			(guestp->console.uartbase !=
				guestp->console.pip.uartbase))
#endif /* } */
			) {

			DBG(c_printf("\t\tElected to modify console of "
				"guest 0x%x\n", guest_id));
			guestp->console.pip.res.flags = RESF_Modify;
		} else {
			DBG(c_printf("\t\tElected to ignore console of "
				"guest 0x%x\n", guest_id));
			guestp->console.pip.res.flags = RESF_Noop;
		}
/* END CSTYLED */
	}

	return (HVctl_st_ok);

fail:;
	return (HVctl_st_badmd);
}


hvctl_status_t
res_console_postparse(hvctl_res_error_t *res_error, int *fail_res_id)
{
	return (HVctl_st_ok);
}


void
res_console_commit(int flag)
{
	guest_t	*gp;
	int	i;

	gp = config.guests;

	for (i = 0; i < NGUESTS; i++, gp++) {
		/* if not this ops turn move on */
		if (gp->console.pip.res.flags != flag) continue;

		switch (gp->console.pip.res.flags) {
		case RESF_Noop:
			DBG(c_printf("console for guest 0x%x : noop\n", i));
			break;
		case RESF_Unconfig:
			res_console_commit_unconfig(gp);
			break;
		case RESF_Config:
			DBG(c_printf("console for guest 0x%x : config\n", i));
			res_console_commit_config(gp);
			break;
		case RESF_Rebind:
			DBG(c_printf("console for guest 0x%x : rebind\n", i));
			ASSERT(0);	/* not supported */
			break;
		case RESF_Modify:
			res_console_commit_modify(gp);
			break;
		default:
			ASSERT(0);
		}

		gp->console.pip.res.flags = RESF_Noop; /* cleanup */
	}
}


void
res_console_commit_modify(guest_t *guestp)
{
	DBG(c_printf("commit modify for guest 0x%x console\n",
	    guestp->guestid));
	ASSERT(guestp->console.type != CONS_TYPE_UNCONFIG);
	res_console_commit_unconfig(guestp);
	res_console_commit_config(guestp);
}


void
res_console_commit_config(guest_t *guestp)
{
	int		channelid;
	int		ino;
	ldc_endpoint_t	*ldc_ep;
	vdev_mapreg_t	*mapregp;

	DBG(c_printf("commit config for guest 0x%x console\n",
	    guestp->guestid));
	ASSERT(guestp->console.type == CONS_TYPE_UNCONFIG);

	guestp->console.type = guestp->console.pip.type;

#ifdef CONFIG_CN_UART /* { */
	if (guestp->console.type == CONS_TYPE_UART) {
		guestp->console.uartbase = guestp->console.pip.uartbase;
		return;
	}
#endif /* } */

	ASSERT(guestp->console.type == CONS_TYPE_LDC);

	channelid = guestp->console.pip.ldc_channel;

	guestp->console.endpt = channelid;

	guestp->console.in_head = 0;
	guestp->console.in_tail = 0;
	guestp->console.status = LDC_CONS_READY;

	ldc_ep = &(guestp->ldc_endpoint[channelid]);

		/* Quick check that the LDC endpoint was configured */
	ASSERT(ldc_ep->is_live);
	ASSERT(ldc_ep->is_private);
	ASSERT(ldc_ep->svc_id == LDC_CONSOLE_SVC);

	ino = guestp->console.pip.ino;
	DBG(c_printf("\tconsole - ino 0x%x\n", ino));

	mapregp = &(guestp->vdev_state.mapreg[(ino & DEVINOMASK)]);

	guestp->console.vintr_mapreg = mapregp;
	ldc_ep->rx_vintr_cookie = mapregp;
	mapregp->ino = ino;

	config_a_guest_device_vino(guestp, ino, DEVOPS_VDEV);

	ldc_ep->tx_qbase_pa =
	    (uint64_t)&cons_queues[guestp->guestid].cons_txq;

	ldc_ep->rx_qbase_pa =
	    (uint64_t)&cons_queues[guestp->guestid].cons_rxq;

	ldc_ep->tx_qsize = Q_EL_SIZE * LDC_CONS_QSIZE;
	ldc_ep->rx_qsize = Q_EL_SIZE * LDC_CONS_QSIZE;

#if defined(CONFIG_FPGA)	/* { */
	if (ldc_ep->target_type == LDC_SP_ENDPOINT) {
		sp_ldc_endpoint_t *sp_ept;
		sram_ldc_qd_t *sram_qd_pa;

		sp_ept = config.sp_ldcs;
		sp_ept = &(sp_ept[ldc_ep->target_channel]);
		sram_qd_pa = sp_ept->rx_qd_pa;

		sram_qd_pa->state_updated = 1;
		sram_qd_pa->state = 1;
		sram_qd_pa->state_notify = 1;
		c_ldc_send_sp_intr(sp_ept, SP_LDC_STATE_CHG);
	}
#endif	/* } CONFIG_FPGA */

	DBG(c_printf("\tguest has LDC based console.\n"));
}


void
res_console_commit_unconfig(guest_t *guestp)
{
	ldc_endpoint_t	*ldc_ep;
	int		ino;

	DBG(c_printf("commit unconfig for guest 0x%x console\n",
	    guestp->guestid));
	ASSERT(guestp->console.type != CONS_TYPE_UNCONFIG);

#ifdef	CONFIG_CN_UART /* { */
	if (guestp->console.type == CONS_TYPE_UART) {
		guestp->console.type = CONS_TYPE_UNCONFIG;
		return;
	}
#endif /* } */

	ldc_ep = &(guestp->ldc_endpoint[guestp->console.endpt]);

		/* Quick check that the LDC endpoint was configured */
	ASSERT(ldc_ep->is_live);
	ASSERT(ldc_ep->is_private);
	ASSERT(ldc_ep->svc_id == LDC_CONSOLE_SVC);

	ino = guestp->console.vintr_mapreg->ino;
	unconfig_a_guest_device_vino(guestp, ino, DEVOPS_VDEV);

	guestp->console.vintr_mapreg = NULL;
	ldc_ep->rx_vintr_cookie = NULL;
	ldc_ep->rx_qsize = 0;
	ldc_ep->tx_qsize = 0;
		/* Leave the Q bases incase packets are in flight */
	guestp->console.type = CONS_TYPE_UNCONFIG;
}
