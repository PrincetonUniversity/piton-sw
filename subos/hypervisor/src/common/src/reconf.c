/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: reconf.c
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

#pragma ident	"@(#)reconf.c	1.22	07/07/19 SMI"

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
#include <debug.h>
#include <util.h>
#ifdef CONFIG_SVC
#include <svc.h>
#endif

/*
 * (re)-configuration code to handle HV resources
 */
static void config_a_hvldc(bin_md_t *mdp, md_element_t *hvldc_nodep);
static void config_a_spldc(bin_md_t *mdp, md_element_t *spldc_nodep);
static void config_a_vcpu(bin_md_t *mdp, md_element_t *cpunodep);
static void config_a_guest(bin_md_t *mdp, md_element_t *guest_nodep);
static void config_a_guest_ldc_endpoint(guest_t *guestp, bin_md_t *mdp,
    md_element_t *ldce_nodep);

uint64_t	hv_debug_flags = (0x0);

/*
 * (re-)configuration code to support setup of the hypervisor based on
 * the HV MD contents
 */
void
config_basics(void)
{
	bin_md_t	*mdp;
	md_element_t	*mdep;
	md_element_t	*rootnodep;
	const uint64_t	seconds_per_day = 24LL*60LL*60LL;
	uint64_t	val;
	uint64_t	content_version;

	mdp = (bin_md_t *)config.parse_hvmd;

	/*
	 * First find the root node
	 */
	rootnodep = md_find_node(mdp, NULL, MDNAME(root));
	if (rootnodep == NULL) {
		DBG(c_printf("Missing root node in HVMD\n"));
		c_hvabort();
	}

	/*
	 * Get content-version from the SP's MD.
	 */

	if (!md_node_get_val(mdp, rootnodep, MDNAME(content_version),
	    &content_version)) {
		DBG(c_printf("config-basics: MD content-version not found\n"));
		c_hvabort();
	}

	/*
	 * Major numbers must be equal.
	 */

	if (MDCONT_VER_MAJOR(content_version) != HV_MDCONT_VER_MAJOR) {
		DBG(c_printf("config_basics: HV MD content-version mismatch: "
		    "supported major ver %x, found %x\n", HV_MDCONT_VER_MAJOR,
		    MDCONT_VER_MAJOR(content_version)));
		c_hvabort();
	}

	DBG(c_printf("config_basics: HV MD content-version  %x.%x \n",
	    MDCONT_VER_MAJOR(content_version),
	    MDCONT_VER_MINOR(content_version)));


	/*
	 * Is there a HV Uart to use?
	 */
#ifdef	CONFIG_HVUART
	if (!md_node_get_val(mdp, rootnodep, MDNAME(hvuart), &val))
		val = 0;
	config.hvuart_addr = val;
#endif

	/*
	 * Configure basic time stuff
	 *
	 * We'll warp and align tick/stick later if necessary
	 * when we start the other cpus.
	 */

	if (!md_node_get_val(mdp, rootnodep, MDNAME(tod), &val))
		val = 0;
	config.tod = val;

	/* default of divide by 1 */
	if (!md_node_get_val(mdp, rootnodep, MDNAME(todfrequency), &val))
		val = 1;
	config.todfrequency = val;

	if (!md_node_get_val(mdp, rootnodep, MDNAME(stickfrequency), &val))
		val = 0;
	config.stickfrequency = val;

	config.cyclic_maxd = CYCLIC_MAX_DAYS * seconds_per_day *
	    config.stickfrequency;

	/*
	 * Configure MMU HWTW mode
	 */
	if (!md_node_get_val(mdp, rootnodep, MDNAME(sys_hwtw_mode), &val))
		val = -1;
	config.sys_hwtw_mode = val;

#ifdef CONFIG_CLEANSER
	/*
	 * Look for the "l2scrub_interval" property to initialize the interval
	 * for the L2 Cache Cleanser
	 */
	if (!md_node_get_val(mdp, rootnodep, MDNAME(l2scrub_interval), &val))
		/* using default if not present */
		val = L2_CACHE_CLEANSER_INTERVAL;
	/*
	 * convert internal value (max is 1000 secs) to ticks in terms of
	 * stick frequency
	 */
	config.l2scrub_interval = MIN(val, 1000) * config.stickfrequency;
	DBG(c_printf("l2scrub_interval = 0x%x\n", config.l2scrub_interval));

	/*
	 * Look for the "l2scrub_entries" property to initialize the number of
	 * cache entries scrubbed by the L2 Cache Cleanser on each invocation
	 *
	 */
	if (!md_node_get_val(mdp, rootnodep, MDNAME(l2scrub_entries), &val))
		/* using default if not present */
		val = L2_CACHE_CLEANSER_ENTRIES;
	/*
	 * l2scrub_entries specifies the percentage of l2 cache entries.
	 * So a value of 100 (100%) means the whole L2 cache is cleansed
	 * on each invocation
	 */
	val = MIN(val, L2_CACHE_CLEANSER_ENTRIES);
	config.l2scrub_entries = (L2_CACHE_ENTRIES*val)/100;
	DBG(c_printf("l2scrub_entries = 0x%x\n", config.l2scrub_entries));
#endif

	/*
	 * Poll frequency for CE errors
	 */
	if (!md_node_get_val(mdp, rootnodep, MDNAME(cepollsec), &val))
		val = 30; /* default value of 30 seconds */
	config.ce_poll_time = val * seconds_per_day * config.stickfrequency;

	if (md_find_node_by_arc(mdp, rootnodep,
	    MDARC(MDNAME(fwd)), MDNODE(MDNAME(guests)), &mdep) == NULL) {
		DBG(c_printf("No guests node\n"));
		c_hvabort();
	}
	config.guests_dtnode = mdep;

	if (md_find_node_by_arc(mdp, rootnodep,
	    MDARC(MDNAME(fwd)), MDNODE(MDNAME(cpus)), &mdep) == NULL) {
		DBG(c_printf("No cpus node\n"));
		c_hvabort();
	}
	config.cpus_dtnode = mdep;

	/*
	 * The ldc endpoints are bothersome ... there are  multiple such nodes
	 * ones per guest, one in root for the HV itself, and another in
	 * root for the sp ! ... need to clean this up.. FIXME.
	 */

	config.hv_ldcs_dtnode = (md_find_node_by_arc(mdp, rootnodep,
	    MDARC(MDNAME(fwd)), MDNODE(MDNAME(ldc_endpoints)),
	    &mdep) == NULL) ? NULL : mdep;

	config.devs_dtnode = (md_find_node_by_arc(mdp, rootnodep,
	    MDARC(MDNAME(fwd)), MDNODE(MDNAME(devices)),
	    &mdep) == NULL) ? NULL : mdep;

	if (!md_node_get_val(mdp, rootnodep, MDNAME(erpt_pa), &val)) val = 0;
	config.erpt_pa = val;

	if (!md_node_get_val(mdp, rootnodep, MDNAME(erpt_size), &val)) val = 0;
	config.erpt_size = val;

#ifdef PLX_ERRATUM_LINK_HACK
	if (!md_node_get_val(mdp, rootnodep,
	    MDNAME(ignore_plx_link_hack), &val))
		val = 0;
	config.ignore_plx_link_hack = val;
#endif

	/*
	 * Initialize the max length we impose on any memory APIs to the guest.
	 */
	config.memscrub_max = MEMSCRUB_MAX_DEFAULT;
	DBG(c_printf("memscrubmax = 0x%x\n", config.memscrub_max));

	/*
	 * Initialize the blackout time for correctable errors.
	 */
	config.ce_blackout = 6 * config.stickfrequency;	/* six seconds */
	DBG(c_printf("ce_blackout = 0x%x\n", config.ce_blackout));

	config.del_reconf_gid = INVALID_GID;
	config.hvctl_ldc_lock = 0;	/* FIXME: macro needed */
	config.error_lock = 0;		/* FIXME: macro needed */
	config.fpga_status_lock = 0;	/* FIXME: macro needed */
	config.sram_erpt_buf_inuse = 0;	/* FIXME: macro needed */

	/*
	 * User-defined DEBUG PRINT ?
	 */
	if (md_node_get_val(mdp, rootnodep, MDNAME(debugprintflags), &val))
		hv_debug_flags = val;
}

#ifdef	CONFIG_SVC

/*
 * Replace the old HVALLOC code with a simpler allocator only
 * for service channels
 */

#define	SVC_MTU	0x200
static hv_svc_data_t	hv_svc_data;
static uint8_t		svc_rx_buf[MAX_SVCS][SVC_MTU];
static uint8_t		svc_tx_buf[MAX_SVCS][SVC_MTU];

static void
config_a_svc(uint32_t sid, uint32_t xid, uint32_t flags, uint32_t mtu,
    uint32_t ino)
{
	svc_ctrl_t *svcp;
	int svcidx;

	if (hv_svc_data.num_svcs >= MAX_SVCS) {
		DBGSVC(c_printf("Too many services\n"));
		c_hvabort(-1);
	}

	svcidx = hv_svc_data.num_svcs ++;

	svcp = &(hv_svc_data.svcs[svcidx]);

	DBGSVC(c_printf("SVC 0x%x @ 0x%x : sid=0x%x, xid=0x%x, mtu=0x%x, "
	    "flags=0x%x, ino=0x%x\n", svcidx, svcp, sid, xid, mtu, flags, ino));

	if (mtu != SVC_MTU) {
		DBGSVC(c_printf(
		    "SVC channels now constrained to MTU = 512 B\n"));
		c_hvabort(-1);
	}

	svcp->sid = sid;
	svcp->xid = xid;
	svcp->config = flags;
	svcp->mtu = mtu;
	svcp->ino = ino;

		/* assign the RX buffer */
	if (flags & SVC_CFG_RX) {
		svcp->recv.size = 0;
		svcp->recv.next = svcp + 1;	/* next svcp */
		svcp->recv.pa = (uint64_t)&(svc_rx_buf[svcidx][0]);
		DBGSVC(c_printf("\trecv pa @ 0x%x\n", svcp->recv.pa));
	}

		/* assign the TX buffer */
	if (flags & SVC_CFG_TX) {
		svcp->send.size = 0;
		svcp->send.next = 0;
		svcp->send.pa = (uint64_t)&(svc_tx_buf[svcidx][0]);
		DBGSVC(c_printf("\tsend pa @ 0x%x\n", svcp->send.pa));
	}
}

static void
config_a_svcchan(bin_md_t *mdp, md_element_t *svc_nodep)
{
	uint64_t sid, xid, mtu, flags, ino;

	DBGSVC(c_printf("service node @ 0x%x\n", (uint64_t)svc_nodep));
	DBGSVC(md_dump_node(mdp, svc_nodep));

	if (!md_node_get_val(mdp, svc_nodep, MDNAME(sid), &sid)) {
		DBG(c_printf("Missing sid in service node\n"));
		c_hvabort(-1);
	}
	if (!md_node_get_val(mdp, svc_nodep, MDNAME(xid), &xid)) {
		DBG(c_printf("Missing xid in service node\n"));
		c_hvabort(-1);
	}
	if (!md_node_get_val(mdp, svc_nodep, MDNAME(flags), &flags)) {
		DBG(c_printf("Missing flags in service node\n"));
		c_hvabort(-1);
	}
	if (!md_node_get_val(mdp, svc_nodep, MDNAME(mtu), &mtu)) {
		DBG(c_printf("Missing mtu in service node\n"));
		c_hvabort(-1);
	}

	if (flags & (SVC_CFG_RE | SVC_CFG_TE)) {
		if (!md_node_get_val(mdp, svc_nodep, MDNAME(ino), &ino)) {
			DBG(c_printf("Missing ino in service node\n"));
			c_hvabort(-1);
		}
	} else {
		ino = 0;
	}

	config_a_svc(sid, xid, flags, mtu, ino);
}

void
config_svcchans(void)
{
	bin_md_t	*mdp;
	md_element_t	*mdep, *svc_nodep, *rootnodep;
	uint64_t	arc_token;
	uint64_t	name_token;
#ifdef CONFIG_FPGA
	volatile uint16_t	*fpgap;
#endif
		/* basic svc setup */

	config.svc = &hv_svc_data;
	hv_svc_data.num_svcs = 0;
	DBGSVC(c_printf("Services @ 0x%x\n", &hv_svc_data));

#ifdef CONFIG_FPGA
		/* determine FPGA locations */
	fpgap = (uint16_t *)(FPGA_Q_BASE + FPGA_QIN_BASE);
	hv_svc_data.rxbase = FPGA_BASE + FPGA_SRAM_BASE + *fpgap;

	fpgap = (uint16_t *)(FPGA_Q_BASE + FPGA_QOUT_BASE);
	hv_svc_data.txbase = FPGA_BASE + FPGA_SRAM_BASE + *fpgap;

#else
	hv_svc_data.rxbase = -1;
	hv_svc_data.txbase = -1;
#endif

	hv_svc_data.rxchannel = FPGA_QIN_BASE;
	hv_svc_data.txchannel = FPGA_QOUT_BASE;

	DBGSVC(c_printf("service rxbase=0x%x, rxchan=0x%x\n"
	    "\ttxbase=0x%x, txchan=0x%x\n",
	    hv_svc_data.rxbase, hv_svc_data.rxchannel,
	    hv_svc_data.txbase, hv_svc_data.txchannel));

		/* permanent channels */

	config_a_svc(VBSC_HV_ERRORS_SVC_SID, VBSC_HV_ERRORS_SVC_XID,
	    VBSC_HV_ERRORS_SVC_FLAGS, VBSC_HV_ERRORS_SVC_MTU, 0);

	config_a_svc(VBSC_DEBUG_SVC_SID, VBSC_DEBUG_SVC_XID,
	    VBSC_DEBUG_SVC_FLAGS, VBSC_DEBUG_SVC_MTU, 0);

		/* channels from the HVMD */

	mdp = (bin_md_t *)config.parse_hvmd;

	/*
	 * First find the root node
	 */
	rootnodep = md_find_node(mdp, NULL, MDNAME(root));
	if (rootnodep == NULL) {
		DBG(c_printf("Missing root node in HVMD\n"));
		c_hvabort();
	}

	if (md_find_node_by_arc(mdp, rootnodep, MDARC(MDNAME(services)),
	    MDNODE(MDNAME(services)), &mdep) == NULL)
		mdep = NULL;

	config.svcs_dtnode = mdep;

	if (mdep == NULL)
		return;

	DBG(c_printf("svcs_dtnode @ 0x%x\n", config.svcs_dtnode));
	DBG(md_dump_node(mdp, mdep));

	arc_token = MDARC(MDNAME(service));
	name_token = MDNODE(MDNAME(service));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    arc_token, name_token, &svc_nodep))) {
		config_a_svcchan(mdp, svc_nodep);
	}
}
#endif

void
config_hv_ldcs(void)
{
	bin_md_t	*mdp;
	md_element_t	*mdep, *hvldc_nodep;
	uint64_t	arc_token;
	uint64_t	name_token;

	mdp = (bin_md_t *)config.parse_hvmd;

	DBGHL(c_printf("LDC configuration:\n"));

	mdep = config.hv_ldcs_dtnode;
	if (mdep == NULL) {
		DBG(c_printf("No LDC enpoints node - nothing to do\n"));
		return;
	}

	DBGHL(md_dump_node(mdp, mdep));

	arc_token = MDARC(MDNAME(fwd));
	name_token = MDNODE(MDNAME(ldc_endpoint));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    arc_token, name_token, &hvldc_nodep))) {
		config_a_hvldc(mdp, hvldc_nodep);
	}
}

static void
config_a_hvldc(bin_md_t *mdp, md_element_t *hvldc_nodep)
{
	uint64_t	chid, type;
	uint64_t	guestid, svc_id;
	uint64_t	tchan_id;
	ldc_endpoint_t	*hvep;

	extern void hvctl_svc_callback();	/* FIXME: in a header */

	if (!md_node_get_val(mdp, hvldc_nodep, MDNAME(svc_id), &svc_id)) {
		/* Not a HV endpoint - skip it */
		return;
	}

	DBGHL(c_printf("Configuring HV LDC endpoint\n"));
	DBGHL(md_dump_node(mdp, hvldc_nodep));

	if (!md_node_get_val(mdp, hvldc_nodep, MDNAME(channel), &chid)) {
		DBG(c_printf("Missing channel id in HV LDC node\n"));
		c_hvabort();
	}
	if (chid >= MAX_HV_LDC_CHANNELS) {
		DBG(c_printf("Invalid channel id in HV LDC node\n"));
		c_hvabort();
	}

	DBGHL(c_printf("\tHV endpoint 0x%x :", chid));

	if (!md_node_get_val(mdp, hvldc_nodep, MDNAME(target_type), &type)) {
		DBG(c_printf("Missing target_type in HV LDC node\n"));
		c_hvabort();
	}

	hvep = config.hv_ldcs;
	hvep = &(hvep[chid]);

	hvep->channel_idx = chid;
	hvep->target_type = type;

	switch (type) {
	case LDC_GUEST_ENDPOINT:	/* guest<->HV LDC */
		if (!md_node_get_val(mdp, hvldc_nodep, MDNAME(target_guest),
		    &guestid)) {
			DBG(c_printf("Missing target_guest in HV LDC node\n"));
			c_hvabort();
		}

		/* point to target guest */
		hvep->target_guest = &(((guest_t *)config.guests)[guestid]);

		DBGHL(c_printf("\tConnected to guest 0x%x endpoint ", guestid));
		break;

	case LDC_SP_ENDPOINT:	/* HV<->SP LDC */
		hvep->target_guest = NULL;
		DBGHL(c_printf("\tConnected to SP endpoint "));
		break;

	default:
		DBGHL(c_printf("Illegal target_type 0x%x\n", type));
		c_hvabort();
	}


	if (!md_node_get_val(mdp, hvldc_nodep, MDNAME(target_channel),
	    &tchan_id)) {
		DBG(c_printf("Missing target channel id in HV LDC node\n"));
		c_hvabort();
	}
	if (tchan_id >= MAX_LDC_CHANNELS) {
		DBG(c_printf("Invalid target channel id in HV LDC node\n"));
		c_hvabort();
	}

	DBGHL(c_printf("0x%x ", tchan_id));

	hvep->target_channel = tchan_id;


	switch (svc_id) {
	case LDC_HVCTL_SVC:
		/*
		 * We don't yet allow for HVCTL channel between the
		 * hypervisor and SP.  Maybe one day we will have a
		 * Zeus or Zeus-lite running on the SP and at that
		 * point we can remove this check.
		 */
		if (hvep->target_type == LDC_SP_ENDPOINT) {
			DBG(c_printf("No HVCTL LDC to the SP allowed yet\n"));
			c_hvabort();
		}

		/*
		 * FIXME: Why did we save the endpoint number
		 * instead of a pointer to the endpoint ?
		 */
		config.hvctl_ldc = chid; /* save the HVCTL channel id */

		hvep->rx_cb = (uint64_t)&hvctl_svc_callback;
		hvep->rx_cbarg = (uint64_t)&config;

		DBGHL(c_printf(" for HVCTL service\n"));
		break;

	default:
		DBGHL(c_printf("Unknown service type 0x%x\n", svc_id));
		c_hvabort();

	}

	/* Mark channel as live */
	hvep->is_live = 1;
}

void
config_vcpus(void)
{
	bin_md_t	*mdp;
	md_element_t	*mdep;
	uint64_t	arc_token;
	uint64_t	node_token;
	md_element_t	*cpunodep;

	mdp = (bin_md_t *)config.parse_hvmd;

	DBG(c_printf("\nCPU configuration:\n"));

	mdep = config.cpus_dtnode;

	DBGVCPU(md_dump_node(mdp, mdep));

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(cpu));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    arc_token, node_token, &cpunodep))) {
		config_a_vcpu(mdp, cpunodep);
	}
}

static void
config_a_vcpu(bin_md_t *mdp, md_element_t *cpunodep)
{
	uint64_t	resource_id, strand_id, vid, gid, parttag;
	vcpu_t		*vcpup;
	strand_t	*strandp;
	md_element_t	*guestnodep;
	guest_t		*guestp;

	DBGVCPU(md_dump_node(mdp, cpunodep));

	if (!md_node_get_val(mdp, cpunodep, MDNAME(resource_id),
	    &resource_id)) {
		DBGVCPU(c_printf("Missing resource_id in cpu node\n"));
		c_hvabort();
	}

	if (resource_id >= NVCPUS) {
		DBGVCPU(c_printf("Invalid resource_id in cpu node\n"));
		c_hvabort();
	}

	DBGVCPU(c_printf("config_a_vcpu(0x%x)\n", resource_id));

	vcpup = config.vcpus;
	vcpup = &(vcpup[resource_id]);

	/*
	 * FIXME: rename pid prop to strandid
	 */
	if (!md_node_get_val(mdp, cpunodep, MDNAME(pid), &strand_id)) {
		DBGVCPU(c_printf("Missing strandid in cpu node\n"));
		c_hvabort();
	}

	if (strand_id >= NSTRANDS) {
		DBGVCPU(c_printf("Invalid strandid in cpu node\n"));
		c_hvabort();
	}

	/*
	 * Assign the vcpu its carrier strand.
	 * Note: this does not schedule the cpu.
	 */
	strandp = config.strands;
	strandp = &(strandp[strand_id]);

	vcpup->strand = strandp;
	vcpup->strand_slot = 0;	/* FIXME fixed for the moment */

	/* Get virtual ID within guest */
	if (!md_node_get_val(mdp, cpunodep, MDNAME(vid), &vid)) {
		DBGVCPU(c_printf("Missing VID in cpu node\n"));
		c_hvabort();
	}
	vcpup->vid = vid;
	vcpup->devq_lock = 0;

	if (NULL == md_find_node_by_arc(mdp, cpunodep,
	    MDARC(MDNAME(back)), MDNODE(MDNAME(guest)), &guestnodep)) {
		DBGVCPU(
		    c_printf("Missing back arc to guest node in cpu node\n"));
		c_hvabort();
	}

	if (!md_node_get_val(mdp, guestnodep, MDNAME(resource_id), &gid)) {
		DBGVCPU(
		    c_printf("WARNING: Missing resource_id in guest node\n"));
		c_hvabort();
	}

	if (gid >= NGUESTS) {
		DBGVCPU(
		    c_printf("WARNING: Invalid resource_id in guest node\n"));
		c_hvabort();
	}

	/* Get partid tag for this cpu */
	if (!md_node_get_val(mdp, cpunodep, MDNAME(parttag), &parttag)) {
		DBGVCPU(c_printf("WARNING: Missing parttag in cpu node - "
		    "using guest id 0x%x\n", gid));
		parttag = gid;	/* use guest ID if none given */
	}
	vcpup->parttag = parttag;

	guestp = config.guests;
	guestp = &(guestp[gid]);

	guestp->guestid = gid;	/* FIXME: This should be done earlier ! */
				/* Should be an assert ... */

	vcpup->guest = guestp;

	/* reset the utilization yield stats for the VCPU */
	c_bzero(&vcpup->util, sizeof (vcpup->util));

	guestp->vcpus[vid] = vcpup;
	DBG(c_printf("XXXX config_a_vcpu(0x%x) gid 0x%x guestp 0x%x \n",
	    resource_id, gid, guestp));

	/*
	 * Assume guest rtba starts at the base of memory
	 * until the guest reconfigures this. The entry point
	 * is computed from this.
	 */
	vcpup->rtba = guestp->real_base;

	/* Assert the legacy entry point had better be the same */
	ASSERT(guestp->entry == guestp->real_base);

	DBGVCPU(c_printf("Virtual cpu 0x%x in guest 0x%x (pid 0x%x) "
	    "entry @ 0x%x rtba @ 0x%x\n",
	    vcpup->res_id, vcpup->guest->guestid, vcpup->vid,
	    guestp->entry, vcpup->rtba));


	/*
	 * Reset the basic sun4v cpu state.
	 * FIXME: should be done by the strand as the CPU is started?
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
	if (config.strand_active & (1LL<<strand_id)) {
		vcpup->status = CPU_STATE_STOPPED;
	} else {
		vcpup->status = CPU_STATE_ERROR;
	}
}

/*
 * This function configures the basic saved state of a sun4v cpu - ready
 * to be resurrected onto a strand for execution.
 */
void
reset_vcpu_state(vcpu_t *vp)
{
	vcpustate_t	*vsp;
	int		i;

	/*
	 * Initialise the remainder of the vCPU struct
	 */

	vp->mmu_area = 0LL;
	vp->mmu_area_ra = 0LL;
	vp->root = &config;	/* FIXME: need this ? */

	vsp = &(vp->state_save_area);

	vp->launch_with_retry = false;	/* enter guest with done */

	/*
	 * Everything is null unless we configure it
	 * otherwise.
	 */
	c_bzero(vsp, sizeof (*vsp));

	/*
	 * We are going to return with a done or a retry
	 * so we setup with the tl & gl at the level above.
	 */
	vsp->tl = MAXPTL +1;

#define	INITIAL_PSTATE		((uint64_t)(PSTATE_PRIV | PSTATE_MM_TSO))
#define	INITIAL_TSTATE(_x)	((INITIAL_PSTATE << TSTATE_PSTATE_SHIFT) | \
					(((uint64_t)(_x)) << TSTATE_GL_SHIFT))
#define	INITIAL_HTSTATE(_x)	(0)


	/*
	 * We store the trapstack off by 1, so trapstack[0]
	 * corresponds to the trapstack registers when tl=1 etc.
	 */
	for (i = 0; i < vsp->tl; i++) {
		vsp->trapstack[i].htstate = INITIAL_HTSTATE(i);
		vsp->trapstack[i].tstate = INITIAL_TSTATE(i);
		vsp->trapstack[i].tpc = 0;
		vsp->trapstack[i].tnpc = vp->start_pc;
		vsp->trapstack[i].tt = 0;
	}

	vsp->gl = vsp->tl;

	vsp->pil = PIL_15;

	vsp->cansave = NWINDOWS - 2;
	vsp->cleanwin = NWINDOWS - 2;

	vp->ntsbs_ctx0 = 0;
	vp->ntsbs_ctxn = 0;

	vp->mmustat_area = 0;
	vp->mmustat_area_ra = 0;

	vp->ttrace_buf_size = 0;
	vp->ttrace_buf_ra = 0;

	vp->mmu_area = 0;
	vp->mmu_area_ra = 0;

	vp->cpuq_size = 0;
	vp->cpuq_base_ra = 0;
	vp->devq_size = 0;
	vp->devq_base_ra = 0;
	vp->errqr_size = 0;
	vp->errqr_base_ra = 0;
	vp->errqnr_size = 0;
	vp->errqnr_base_ra = 0;

	/* clear out the vcpu mailbox */
	vp->command = CPU_CMD_READY;
}

#ifdef CONFIG_FPGA
void
config_sp_ldcs(void)
{
	md_element_t	*spldc_nodep, *mdep;
	uint64_t	arc_token, node_token;
	bin_md_t	*mdp;

	mdp = (bin_md_t *)config.parse_hvmd;

	DBG(c_printf("config_sp_ldcs()\n"));

	mdep = config.hv_ldcs_dtnode;
	if (mdep == NULL) {
		DBG(c_printf("No LDC enpoints node - nothing to do\n"));
		return;
	}

	DBG(md_dump_node(mdp, mdep));

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(ldc_endpoint));

	/*
	 * Spin through the "ldc_endpoint" arcs in the
	 * ldc_endpoints node and config each endpoint !
	 * FIXME; what if already configured !
	 */
	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    arc_token, node_token, &spldc_nodep))) {

		config_a_spldc(mdp, spldc_nodep);
	}
}

/*
 * The domain manager does not have any information about the internal
 * implementation of the SP LDCs, and specifically where they are
 * located in SRAM. This requires a mechanism for the SP to inform
 * the HV of the LDC SRAM queue details. Until we have this, the data
 * will reside in this table.
 */
#ifdef CONFIG_SPLIT_SRAM_ERRATUM
static sp_ldc_sram_ptrs_t sp_ldc_sram_data[MAX_SP_LDC_CHANNELS] = {
	{0xfff0e04320, 0xfff0e00460, 4, 0xfff0e04361, 0xfff0e019a0, 4},
	{0xfff0e04325, 0xfff0e005a0, 4, 0xfff0e04366, 0xfff0e01ae0, 4},
	{0xfff0e0432a, 0xfff0e006e0, 4, 0xfff0e0436b, 0xfff0e01c20, 4},
	{0xfff0e0432f, 0xfff0e00820, 4, 0xfff0e04370, 0xfff0e01d60, 4},
	{0xfff0e04334, 0xfff0e00960, 4, 0xfff0e04375, 0xfff0e01ea0, 4},
	{0xfff0e04339, 0xfff0e00aa0, 4, 0xfff0e0437a, 0xfff0e01fe0, 4},
	{0xfff0e0433e, 0xfff0e00be0, 4, 0xfff0e0437f, 0xfff0e02120, 4},
	{0xfff0e04343, 0xfff0e00d20, 4, 0xfff0e04384, 0xfff0e02260, 4},
	{0xfff0e04348, 0xfff0e00e60, 4, 0xfff0e04389, 0xfff0e023a0, 4},
	{0, 0, 0, 0, 0, 0},
	{0, 0, 0, 0, 0, 0},
	{0xfff0e04357, 0xfff0e01220, 4, 0xfff0e04398, 0xfff0e02760, 4},
	{0xfff0e0435c, 0xfff0e01360, 4, 0xfff0e0439d, 0xfff0e028a0, 4},
	{0, 0, 0, 0, 0, 0}
};
#endif

static void
config_a_spldc(bin_md_t *mdp, md_element_t *spldc_nodep)
{
	uint64_t	chid;
	uint64_t	type, scr;
	uint64_t	guestid;
	uint64_t	tchan_id;
	sp_ldc_endpoint_t *spep;
#if defined(CONFIG_SPLIT_SRAM) && !defined(CONFIG_SPLIT_SRAM_ERRATUM)
	uint64_t	val;
	md_element_t	*ptrs_node;
#endif

	if (md_node_get_val(mdp, spldc_nodep, MDNAME(svc_id), &scr)) {
		/* Not a SP endpoint - skip it */
		return;
	}
	if (md_node_get_val(mdp, spldc_nodep, MDNAME(tx_ino), &scr)) {
		/* Not a SP endpoint - skip it */
		return;
	}

	DBGL(c_printf("Configuring SP LDC endpoint\n"));
	DBGL(md_dump_node(mdp, spldc_nodep));

	if (!md_node_get_val(mdp, spldc_nodep, MDNAME(channel), &chid)) {
		DBG(c_printf("Missing channel id in SP LDC node\n"));
		c_hvabort();
	}

	if (chid > config.sp_ldc_max_cid)
		config.sp_ldc_max_cid = chid;

	if (chid >= MAX_SP_LDC_CHANNELS) {
		DBG(c_printf("Invalid channel id in SP LDC node\n"));
		c_hvabort();
	}

	DBGL(c_printf("\tSP endpoint 0x%x :", chid));

	if (!md_node_get_val(mdp, spldc_nodep, MDNAME(target_type), &type)) {
		DBG(c_printf("Missing target_type in SP LDC node\n"));
		c_hvabort();
	}

	spep = config.sp_ldcs;
	spep = &(spep[chid]);
	spep->target_type = type;

	spep->channel_idx = chid;
#ifdef CONFIG_SPLIT_SRAM

#ifdef CONFIG_SPLIT_SRAM_ERRATUM
	spep->tx_qd_pa = (sram_ldc_qd_t *)sp_ldc_sram_data[chid].inq_offset;
	spep->tx_q_data_pa = (sram_ldc_q_data_t *)
	    sp_ldc_sram_data[chid].inq_data_offset;
	spep->rx_qd_pa = (sram_ldc_qd_t *)sp_ldc_sram_data[chid].outq_offset;
	spep->rx_q_data_pa = (sram_ldc_q_data_t *)
	    sp_ldc_sram_data[chid].outq_data_offset;
#else
	if (!md_find_node_by_arc(mdp, spldc_nodep, MDARC(MDNAME(fwd)),
	    MDNODE(MDNAME(sram_ptrs)), &ptrs_node)) {
		DBG(c_printf("Missing sram_ptrs arc in SP LDC node\n"));
		c_hvabort();
	}
	DBGL(md_dump_node(mdp, ptrs_node));

	if (!md_node_get_val(mdp, ptrs_node, MDNAME(inq_offset), &val)) {
		DBG(c_printf("Missing inq_offset in sram_ptrs node\n"));
		c_hvabort();
	}
	spep->tx_qd_pa = (sram_ldc_qd_t *)val;

	if (!md_node_get_val(mdp, ptrs_node, MDNAME(inq_data_offset), &val)) {
		DBG(c_printf("Missing inq_data_offset in sram_ptrs node\n"));
		c_hvabort();
	}
	spep->tx_q_data_pa = (sram_ldc_q_data_t *)val;

	if (!md_node_get_val(mdp, ptrs_node, MDNAME(inq_num_pkts), &val)) {
		DBG(c_printf("Missing inq_num_pkts in sram_ptrs node\n"));
		c_hvabort();
	}
	/* FIXME: set num_pkts */

	if (!md_node_get_val(mdp, ptrs_node, MDNAME(outq_offset), &val)) {
		DBG(c_printf("Missing outq_offset in sram_ptrs node\n"));
		c_hvabort();
	}
	spep->rx_qd_pa = (sram_ldc_qd_t *)val;

	if (!md_node_get_val(mdp, ptrs_node, MDNAME(outq_data_offset), &val)) {
		DBG(c_printf("Missing outq_data_offset in sram_ptrs node\n"));
		c_hvabort();
	}
	spep->rx_q_data_pa = (sram_ldc_q_data_t *)val;

	if (!md_node_get_val(mdp, ptrs_node, MDNAME(outq_num_pkts), &val)) {
		DBG(c_printf("Missing outq_num_pkts in sram_ptrs node\n"));
		c_hvabort();
	}
	/* FIXME: set num_pkts */

#endif	/* !CONFIG_SPLIT_SRAM_ERRATUM */

#else	/* !CONFIG_SPLIT_SRAM */

	spep->tx_qd_pa = (sram_ldc_qd_t *)((SRAM_LDC_QD_SIZE * chid) +
	    LDC_SRAM_CHANNEL_TXBASE);
	spep->rx_qd_pa = (sram_ldc_qd_t *)((SRAM_LDC_QD_SIZE * chid) +
	    LDC_SRAM_CHANNEL_RXBASE);

#endif	/* CONFIG_SPLIT_SRAM */

	switch (type) {
	case LDC_GUEST_ENDPOINT:	/* guest<->SP LDC */
		if (!md_node_get_val(mdp, spldc_nodep, MDNAME(target_guest),
		    &guestid)) {
			DBG(c_printf("Missing target_guest in SP LDC node\n"));
			c_hvabort();
		}

		/* point to target guest */
		spep->target_guest = &(((guest_t *)config.guests)[guestid]);

		DBGL(c_printf("\tConnected to guest 0x%x endpoint ", guestid));
		break;

	case LDC_HV_ENDPOINT:	/* HV<->SP LDC */
		/* Mark link status in SRAM as UP for SP<->HV channels */
		((struct sram_ldc_qd *)spep->rx_qd_pa)->state = 1;
		DBGL(c_printf("\tConnected to HV endpoint "));
		break;

	default:
		DBG(c_printf("Illegal target_type 0x%x\n", type));
		c_hvabort();
	}


	if (!md_node_get_val(mdp, spldc_nodep, MDNAME(target_channel),
	    &tchan_id)) {
		DBG(c_printf("Missing target channel id in SP LDC node\n"));
		c_hvabort();
	}

	if (tchan_id >= MAX_LDC_CHANNELS) {
		DBG(c_printf("Invalid target channel id in SP LDC node\n"));
		c_hvabort();
	}

	DBGL(c_printf("0x%x ", tchan_id));

	spep->target_channel = tchan_id;

	spep->tx_lock = 0;
	spep->rx_lock = 0;

	/* Zero out remainder of struct */
	spep->tx_scr_txhead = 0;
	spep->tx_scr_txtail = 0;
	spep->tx_scr_txsize = 0;
	spep->tx_scr_tx_qpa = 0;
	spep->tx_scr_rxhead = 0;
	spep->tx_scr_rxtail = 0;
	spep->tx_scr_rxsize = 0;
	spep->tx_scr_rx_qpa = 0;
	spep->tx_scr_target = 0;

	spep->rx_scr_txhead = 0;
	spep->rx_scr_txtail = 0;
	spep->rx_scr_txsize = 0;
	spep->rx_scr_tx_qpa = 0;
	spep->rx_scr_rxhead = 0;
	spep->rx_scr_rxtail = 0;
	spep->rx_scr_rxsize = 0;
	spep->rx_scr_rx_qpa = 0;
	spep->rx_scr_target = 0;

	/* Mark channel as live */
	spep->is_live = 1;
}
#endif

void
config_guests(void)
{
	bin_md_t	*mdp;
	md_element_t	*mdep;
	uint64_t	arc_token;
	uint64_t	node_token;
	md_element_t	*guest_nodep;

	mdp = (bin_md_t *)config.parse_hvmd;

	DBGG(c_printf("\nGuest configuration:\n"));

	mdep = config.guests_dtnode;

	DBGG(md_dump_node(mdp, mdep));

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(guest));

	while (NULL != (mdep = md_find_node_by_arc(mdp, mdep,
	    arc_token, node_token, &guest_nodep))) {
		config_a_guest(mdp, guest_nodep);
	}
}

static void
config_a_guest(bin_md_t *mdp, md_element_t *guest_nodep)
{
	uint64_t	guest_id, ino, base_memsize;
	guest_t		*guestp;
	int		x;
	md_element_t	*snet_nodep;
	uint64_t	snet_ino;
	uint64_t	snet_pa;
	md_element_t	*devices_nodep;
	md_element_t	*mblock_nodep;
	md_element_t	*services_nodep;
	md_element_t	*svc_nodep;
	uint64_t	arc_token;
	uint64_t	node_token;
	uint64_t	cfg_handle;
	md_element_t	*elemp;
	md_element_t	*base_mblock;

	DBGG(md_dump_node(mdp, guest_nodep));

	if (!md_node_get_val(mdp, guest_nodep, MDNAME(resource_id),
	    &guest_id)) {
		DBGG(c_printf("Missing resource_id in guest node\n"));
		c_hvabort();
	}
	if (guest_id >= NGUESTS) {
		DBGG(c_printf("Invalid resource_id in guest node\n"));
		c_hvabort();
	}

	guestp = config.guests;
	guestp = &(guestp[guest_id]);

	DBGG(c_printf("Guest 0x%x @ 0x%x\n", guest_id, (uint64_t)guestp));

	/* init stuff necessary first time we touch a guest */

	if (guestp->state == GUEST_STATE_UNCONFIGURED) {

		reset_api_hcall_table(guestp);
		DBGG(c_printf("\tguest hcall table @ 0x%x\n",
		    guestp->hcall_table));

		reset_guest_perm_mappings(guestp);

		reset_guest_ldc_mapins(guestp);

		/* until we boot it ... */
		guestp->state = GUEST_STATE_STOPPED;
	}


	/*
	 * Now fill in basic properties for this guest ...
	 *
	 * FIXME: These should be available is the guest is
	 * live yes ?
	 */

#define	GET_PROPERTY(_g_val, _mdp, _guest_nodep, _md_name)	\
	do {								\
		uint64_t _x;						\
		if (!md_node_get_val(_mdp, _guest_nodep,		\
			MDNAME(_md_name), &_x)) {			\
			DBGG(c_printf("Missing "#_md_name " in "	\
				"guest node\n"));			\
			c_hvabort();					\
		}							\
		_g_val = _x;					\
	} while (0)

	GET_PROPERTY(guestp->rom_base, mdp, guest_nodep, rombase);
	GET_PROPERTY(guestp->rom_size, mdp, guest_nodep, romsize);

	/*
	 * Assume entry point is at base of real memory.
	 * Search all guest mblocks for lowest real memory address.
	 */
	guestp->real_base = UINT64_MAX;

	arc_token = MDARC(MDNAME(fwd));
	node_token = MDNODE(MDNAME(mblock));

	base_mblock = NULL;
	elemp = guest_nodep;

	while (NULL != (elemp = md_find_node_by_arc(mdp, elemp,
	    arc_token, node_token, &mblock_nodep))) {
		uint64_t realbase, membase;
		if (!md_node_get_val(mdp, mblock_nodep, MDNAME(realbase),
		    &realbase)) {
			DBG(c_printf("Missing realbase in mblock node\n"));
			c_hvabort();
		}

		/*
		 * Initialise guest real_base, real_limit and mem_offset
		 * Note: real_limit/mem_offset are required for N2 MMu HWTW
		 * FIXME: real_limit will not work for segmented memory
		 */
		if (realbase < guestp->real_base) {
			guestp->real_base = realbase;
			base_mblock = mblock_nodep;
			if (!md_node_get_val(mdp, mblock_nodep, MDNAME(membase),
			    &membase)) {
				membase = guestp->real_base;
			}
			guestp->mem_offset = membase - guestp->real_base;
		}
		if (!md_node_get_val(mdp, base_mblock, MDNAME(memsize),
		    &base_memsize)) {
			base_memsize = 0;
		}
		if (guestp->real_limit < (realbase + base_memsize))
			guestp->real_limit = (realbase + base_memsize);
	}

	DBG(c_printf("REAL BASE 0x%x LIMIT 0x%x MEM_OFFSET 0x%x\r\n",
	    guestp->real_base, guestp->real_limit,  guestp->mem_offset));

	if (base_mblock == NULL) {
		DBG(c_printf("Missing mblock node in guest node\n"));
		c_hvabort();
	}

	if (!md_node_get_val(mdp, base_mblock, MDNAME(memsize),
	    &base_memsize)) {
		DBG(c_printf(
		    "Missing memsize in mblock node\n"));
		c_hvabort();
	}

	if (guestp->rom_size > base_memsize) {
		DBG(c_printf("ROM image does not fit in base guest mblock\n"));
		c_hvabort(-1);
	}

	GET_PROPERTY(guestp->md_pa, mdp, guest_nodep, mdpa);

#undef GET_PROPERTY

#ifdef	CONFIG_DISK
	guestp->disk.size = 0LL;
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(diskpa),
	    &guestp->disk.pa)) {
		guestp->disk.pa = -1LL;
	}
#endif

	/*
	 * Assume entry point is at base of real memory
	 */
	guestp->entry = guestp->real_base;

	/*
	 * Compute the Guests MD size
	 */
	config_guest_md(guestp);

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
	    &guestp->reset_reason)) {
		guestp->reset_reason = RESET_REASON_POR;
	}

	/* FIXME: Map in range should be done another way */
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(ldc_mapinrabase),
	    &guestp->ldc_mapin_basera) ||
	    !md_node_get_val(mdp, guest_nodep, MDNAME(ldc_mapinsize),
	    &guestp->ldc_mapin_size)) {
		guestp->ldc_mapin_basera = LDC_MAPIN_BASERA;
		DBGG(c_printf("WARNING: default mapinrbase 0x%x selected\n",
		    guestp->ldc_mapin_basera));
		guestp->ldc_mapin_size = LDC_MAPIN_RASIZE;
		DBGG(c_printf("WARNING: default mapinrsize 0x%x selected\n",
		    guestp->ldc_mapin_size));
	}

	/*
	 * Look for the "perfctraccess" property. This property
	 * must be present and set to a non-zero value for the
	 * guest to have access to the JBUS/DRAM perf counters
	 */
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(perfctraccess),
	    &guestp->perfreg_accessible)) {
		guestp->perfreg_accessible = 0;
	}

	/*
	 * Look for "diagpriv" property.  This property enables
	 * the guest to execute arbitrary hyperprivileged code.
	 */
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(diagpriv),
	    &guestp->diagpriv)) {
#ifdef CONFIG_BRINGUP
		guestp->diagpriv = -1;
#else
		guestp->diagpriv = 0;
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
	 * FIXME: what if already live !
	 */
	if (!md_node_get_val(mdp, guest_nodep, MDNAME(todoffset),
	    &guestp->tod_offset)) {
		guestp->tod_offset = 0;
	}

	/*
	 * Now look for the guest devices ...
	 * FIXME: Needs updating so devices can be DR'd in.
	 */
	/*
	 * Configure vino2inst and dev2inst by marking the entries reserved.
	 * These will be filled from the MD properties later.
	 */
	for (x = 0; x < NVINOS; x++) {
		guestp->vino2inst.vino[x] = DEVOPS_RESERVED;
	}

	for (x = 0; x < NDEVIDS; x++) {
		guestp->dev2inst[x] = DEVOPS_RESERVED;
	}

	DBG(c_printf("Setup guest devices\n"));

	if (NULL != md_find_node_by_arc(mdp, guest_nodep, MDARC(MDNAME(fwd)),
	    MDNODE(MDNAME(virtual_devices)), &devices_nodep)) {
		if (!md_node_get_val(mdp, devices_nodep, MDNAME(cfghandle),
		    &cfg_handle)) {
			DBG(c_printf("Missing cfg_handle in device node\n"));
			c_hvabort();
		}
		config_guest_virtual_device(guestp, cfg_handle);
	} else {
		c_hvabort();
	}

	if (NULL != md_find_node_by_arc(mdp, guest_nodep, MDARC(MDNAME(fwd)),
	    MDNODE(MDNAME(channel_devices)), &devices_nodep)) {
		if (!md_node_get_val(mdp, devices_nodep, MDNAME(cfghandle),
		    &cfg_handle)) {
			DBG(c_printf("Missing cfg_handle in device node\n"));
			c_hvabort();
		}
		config_guest_channel_device(guestp, cfg_handle);
	} else {
		c_hvabort();
	}

#ifdef	T1_FPGA_SNET
	if (NULL != md_find_node_by_arc(mdp, guest_nodep, MDARC(MDNAME(fwd)),
	    MDNODE(MDNAME(snet)), &snet_nodep)) {
		if (!md_node_get_val(mdp, snet_nodep, MDNAME(snet_ino),
		    &snet_ino)) {
			DBG(c_printf("Missing ino in snet node\n"));
			c_hvabort();
		}
		if (!md_node_get_val(mdp, snet_nodep, MDNAME(snet_pa),
		    &snet_pa)) {
			DBG(c_printf("Missing pa in snet node\n"));
			c_hvabort();
		}
                config_a_guest_device_vino(guestp, snet_ino, DEVOPS_VDEV);
		guestp->snet.ino = snet_ino;
		guestp->snet.pa = snet_pa;
	}
#endif /* ifdef	T1_FPGA_SNET */


#ifdef	CONFIG_SVC
	/*
	 * Find and setup svc channels for the guest.
	 * we only enable the vinos here.
	 */
	if (md_find_node_by_arc(mdp, guest_nodep,
	    MDARC(MDNAME(services)), MDNODE(MDNAME(services)),
	    &services_nodep) != NULL) {

		arc_token = MDARC(MDNAME(service));
		node_token = MDNODE(MDNAME(service));

		while (NULL != (services_nodep =  md_find_node_by_arc(mdp,
		    services_nodep, arc_token, node_token, &svc_nodep))) {
			if (!md_node_get_val(mdp, svc_nodep,
			    MDNAME(ino), &ino)) {
				DBG(c_printf("Missing ino in service node\n"));
				c_hvabort(-1);
			}
			DBG(c_printf("Configuring service node 0x%x\n", ino));
			config_a_guest_device_vino(guestp, ino, DEVOPS_VDEV);
		}
	}

#endif	/* CONFIG_SVC */


	DBGG(c_printf("Initialize guest.ldc_endpoints\n"));
	/*
	 * NOTE: we may bump this value as a side-effect of
	 * adding new channels with config_a_guest_ldc_endpoint
	 *
	 * FIXME: Should we really care to track this - why not
	 * just use the constant; MAX_LDC_CHANNELS
	 */
	/* guestp->ldc_max_channel_idx = 0LL; */
	guestp->ldc_max_channel_idx = MAX_LDC_CHANNELS;

	{
		md_element_t	*ldce_nodep, *elemp;
		uint64_t	arc_token;
		uint64_t	node_token;

		arc_token = MDARC(MDNAME(fwd));
		node_token = MDNODE(MDNAME(ldc_endpoint));

		/*
		 * Spin through the "ldc_endpoint" arcs in the
		 * ldc_endpoints node and config each endpoint !
		 * FIXME; what if already configured !
		 */

		elemp = guest_nodep;
		while (NULL != (elemp = md_find_node_by_arc(mdp, elemp,
		    arc_token, node_token, &ldce_nodep))) {
			config_a_guest_ldc_endpoint(guestp, mdp, ldce_nodep);
		}
	}

		/* Now figure out what kind of console this guest has */

		/*
		 * GAH FIXME:
		 * Console type seems to be set as a side effect of
		 * setting up the service or LDC channels .. not
		 * during guest initialization. This needs to seriously
		 * get fixed.
		 */

	DBGG(c_printf("End of guest setup\n"));
}

/*
 * Based on the header info, compute the size of the
 * guests MD.
 */
void
config_guest_md(guest_t *guestp)
{
	bin_md_t *gmdp;

	gmdp = (bin_md_t *)guestp->md_pa;

	/*
	 * Make sure we can handle the version ...
	 * FIXME:
	 * This is not really an abort scenario, the guest
	 * might be able to handle this - we just dont know how
	 * big it is ..
	 */
	if (TR_MAJOR(ntoh32(gmdp->hdr.transport_version)) !=
	    TR_MAJOR(MD_TRANSPORT_VERSION)) {
		DBG(c_printf("Guest MD major version mismatch\n"));
		c_hvabort();
	}

	guestp->md_size = sizeof (gmdp->hdr) + ntoh32(gmdp->hdr.node_blk_sz) +
	    ntoh32(gmdp->hdr.name_blk_sz) + ntoh32(gmdp->hdr.data_blk_sz);
}

/*
 * Configure a guest's LDC endpoint.
 */
static void
config_a_guest_ldc_endpoint(guest_t *guestp, bin_md_t *mdp,
    md_element_t *ldce_nodep)
{
	uint64_t	endpt_id;
	ldc_endpoint_t	*ldc_ep;
	uint64_t	target_type;
	uint64_t	target_channel;
	uint64_t	tx_ino;
	uint64_t	rx_ino;
	uint64_t	pvt_svc;

	if (!md_node_get_val(mdp, ldce_nodep, MDNAME(channel),
	    &endpt_id)) {
		DBG(c_printf("Missing channel (endpoint number) in "
		    "ldc_endpoint node\n"));
		c_hvabort();
	}
	ASSERT(endpt_id < MAX_LDC_CHANNELS);

	DBG(c_printf("\tHas LDC endpoint 0x%x", endpt_id));

	/*
	 * NOTE; endpoint id may push up the max ID of the guests
	 * channels. FIXME: isn't it better to remove this.
	 */
	if (endpt_id >= guestp->ldc_max_channel_idx)
		guestp->ldc_max_channel_idx = endpt_id + 1LL;

	ldc_ep = &(guestp->ldc_endpoint[endpt_id]);

	/*
	 * Bail out if the endpoint is already alive.
	 */
	if (ldc_ep->is_live) {
		DBG(c_printf("\n\t\tAlready configured\n"));
		return;
	}

	if (!md_node_get_val(mdp, ldce_nodep, MDNAME(target_type),
	    &target_type)) {
		DBG(c_printf("Missing target_type in ldc_endpoint node\n"));
		c_hvabort();
	}
	if (!md_node_get_val(mdp, ldce_nodep, MDNAME(target_channel),
	    &target_channel)) {
		DBG(c_printf("Missing target_channel in ldc_endpoint node\n"));
		c_hvabort();
	}

	ldc_ep->target_type = target_type;
	ldc_ep->target_channel = target_channel;

	switch (target_type) {
	uint64_t target_guest_id;
	guest_t *target_guestp;
	case LDC_HV_ENDPOINT:
		DBG(c_printf("\t\tConnected to HV endpoint 0x%x",
		    target_channel));
			/* nothing more to do */
		break;

	case LDC_GUEST_ENDPOINT:
		if (!md_node_get_val(mdp, ldce_nodep, MDNAME(target_guest),
		    &target_guest_id)) {
			DBG(c_printf("Missing target_guest in ldc_endpoint "
			    "node\n"));
			c_hvabort();
		}

		DBG(c_printf("\t\tConnected to guest 0x%x endpoint 0x%x",
		    target_guest_id, target_channel));

		target_guestp = config.guests;
		target_guestp = &(target_guestp[target_guest_id]);
		ldc_ep->target_guest = target_guestp;
		break;

#ifdef CONFIG_FPGA
	case LDC_SP_ENDPOINT:
		DBG(c_printf("\t\tConnected to SP endpoint 0x%x",
		    target_channel));
		break;
#endif

	default:
		DBG(c_printf("Invalid target_type in ldc-endpoint node\n"));
		c_hvabort();
	}

	if (md_node_get_val(mdp, ldce_nodep, MDNAME(private_svc), &pvt_svc)) {

		ldc_ep->is_private = 1;
		ldc_ep->svc_id = pvt_svc;

		switch (ldc_ep->svc_id) {
		case LDC_CONSOLE_SVC:
			break;

		default:
			DBG(c_printf("Invalid private service type\n"));
			c_hvabort();
		}

	} else {
		ldc_ep->is_private = 0;

		if (!md_node_get_val(mdp, ldce_nodep, MDNAME(tx_ino),
		    &tx_ino)) {
			DBG(c_printf("Missing tx_ino in ldc_endpoint node\n"));
			c_hvabort();
		}
		if (!md_node_get_val(mdp, ldce_nodep, MDNAME(rx_ino),
		    &rx_ino)) {
			DBG(c_printf("Missing rx_ino in ldc_endpoint node\n"));
			c_hvabort();
		}

		DBG(c_printf(" tx-ino 0x%x rx-ino 0x%x\n", tx_ino, rx_ino));

		ldc_ep->tx_mapreg.ino = tx_ino;
		guestp->ldc_ino2endpoint[tx_ino].endpointp = ldc_ep;
		guestp->ldc_ino2endpoint[tx_ino].mapregp = &(ldc_ep->tx_mapreg);

		config_a_guest_device_vino(guestp, tx_ino, DEVOPS_CDEV);

		ldc_ep->rx_mapreg.ino = rx_ino;
		guestp->ldc_ino2endpoint[rx_ino].endpointp = ldc_ep;
		guestp->ldc_ino2endpoint[rx_ino].mapregp = &(ldc_ep->rx_mapreg);

		config_a_guest_device_vino(guestp, rx_ino, DEVOPS_CDEV);

		ldc_ep->tx_qbase_pa = 0;
		ldc_ep->tx_qsize = 0;
		ldc_ep->rx_qbase_pa = 0;
		ldc_ep->rx_qsize = 0;
	}
		/*
		 * Configure remaining endpoint fields
		 */
	ldc_ep->tx_qbase_ra = 0;
	ldc_ep->tx_qhead = 0;
	ldc_ep->tx_qtail = 0;

	ldc_ep->rx_qbase_ra = 0;
	ldc_ep->rx_qhead = 0;
	ldc_ep->rx_qtail = 0;

	ldc_ep->is_live = 1;
}

/*
 * This code initializes a guest's LDC mapin structure.
 * We assume the guest is not in use during this time,
 * so the init code does not have to operate atomically.
 */
void
reset_guest_ldc_mapins(guest_t *guestp)
{
	int i;

	DBG(c_printf("\tinit guest ldc mapin entries\n"));

	guestp->ldc_mapin_free_idx = -1ULL;

	for (i = LDC_NUM_MAPINS-1; i >= 0; i--) {
		guestp->ldc_mapin[i].perms = 0;
		guestp->ldc_mapin[i].ldc_mapin_next_idx =
		    guestp->ldc_mapin_free_idx;
		guestp->ldc_mapin_free_idx = i;
	}
}

/*
 * Initialize the API call table for a newly created guest
 */
void
reset_api_hcall_table(guest_t *guestp)
{
	uint64_t	addr;
	int		i;
	uint64_t	*api_entryp;
	extern uint64_t hcall_tables[];	/* FIXME */
	extern void 	herr_badtrap();
	uint64_t	fcn;

	fcn = (uint64_t)((void *)herr_badtrap);

	/*
	 * First step - allocate a table.
	 * FIXME: why is this not fixed in the guest structure.
	 */
	addr = (uint64_t)&hcall_tables;
	/* align to cache line size ... FIXME: why ?! */
	addr = (addr + L2_LINE_SIZE-1)&~(L2_LINE_SIZE-1);
	addr += HCALL_TABLE_SIZE*guestp->guestid;
	guestp->hcall_table = addr;

	/*
	 * Clear out negotiated groups
	 */
	for (i = 0; i < NUM_API_GROUPS; i++) {
		guestp->api_groups[i].version_num = 0;
		guestp->api_groups[i].verptr = NULL;
	}

	/*
	 * Init the jump table to point to a bad trap error
	 */
	api_entryp = (uint64_t *)addr;
	for (i = 0; i < NUM_API_CALLS; i++) {
		*api_entryp++ = (uint64_t)fcn;
	}
}

/*
 * Initialize the permanent mapping structure for a newly created guest.
 */
void
reset_guest_perm_mappings(guest_t *guestp)
{
	guestp->perm_mappings_lock = 0;

	c_bzero(&(guestp->perm_mappings[0]),
	    sizeof (guestp->perm_mappings[0]) * NPERMMAPPINGS);

#ifdef PERMMAP_STATS
	guestp->perm_mappings_count = 0;
#endif
}

/* ************************************************************************* */

/*
 * The order in which resources are processed is important.
 * Rather than duplicate effort while parsing nodes, some
 * resources pick up information from others.
 */

RES_PROTO(guest)
RES_PROTO(memory)
RES_PROTO(vcpu)
RES_PROTO(hv_ldc)
RES_PROTO(ldc)
#ifdef CONFIG_CRYPTO
RES_PROTO(mau)
RES_PROTO(cwq)
#endif
#ifdef CONFIG_PCIE
RES_PROTO(pcie_bus)
#endif
RES_PROTO(console)
#ifdef STANDALONE_NET_DEVICES
RES_PROTO(network_device)
#endif


typedef struct {
	char		*namep;
	hvctl_res_t	type;
	void		(*prep)();
	hvctl_status_t	(*parse)(bin_md_t *, hvctl_res_error_t *,
				md_element_t **, int *);
	hvctl_status_t	(*postparse)(hvctl_res_error_t *, int *);
	void		(*commit)(int flags);
} res_info_t;


#define	RI(_name)	{						\
	.namep = #_name,						\
	.type = HVctl_res_##_name,					\
	.prep = &res_##_name##_prep,					\
	.parse = &res_##_name##_parse,					\
	.postparse = &res_##_name##_postparse,				\
	.commit = &res_##_name##_commit,				\
	}

res_info_t resource_info[] = {
	RI(guest),
	RI(memory),
	RI(vcpu),
	RI(hv_ldc),
	RI(ldc),
	RI(console),
#ifdef CONFIG_CRYPTO
	RI(mau),
	RI(cwq),
#endif
#ifdef CONFIG_PCIE
	RI(pcie_bus),
#endif
#ifdef STANDALONE_NET_DEVICES
	RI(network_device),
#endif
	{ NULL }
};

#undef	RI


void
reloc_resource_info(void)
{
	res_info_t *resp;

	for (resp = resource_info; resp->namep != NULL; resp++) {
		resp->namep = (char *)reloc_ptr((void*)resp->namep);
		resp->prep = (void (*)())reloc_ptr((void*)resp->prep);
		resp->parse = (hvctl_status_t (*)(bin_md_t *,
		    hvctl_res_error_t *, md_element_t **, int *))
		    reloc_ptr((void*)resp->parse);
		resp->postparse = (hvctl_status_t (*)(hvctl_res_error_t *,
		    int *)) reloc_ptr((void*)resp->postparse);
		resp->commit = (void (*)(int))reloc_ptr((void*)resp->commit);
	}
}

/*
 * Phase 3 - commit phase
 */
void
commit_reconfig(void)
{
	res_info_t *resp;

	/*
	 * NOTE: This is brute force, but for each resource
	 * can be made much faster by building a chain for
	 * each op during the parse phase.
	 * ... another day perhaps.
	 */

	/* unconfig is done in reverse order, find last resource */
	for (resp = resource_info; (resp + 1)->namep != NULL; resp++)
		/* LINTED */
		;

	for (; resp != &(resource_info[-1]); resp--) {
		DBG(c_printf("\nphase 3a : unconfig %s\n\n", resp->namep));
		resp->commit(RESF_Unconfig);
	}

	for (resp = resource_info; resp->namep != NULL; resp++) {
		DBG(c_printf("\nphase 3b: config %s\n\n", resp->namep));
		resp->commit(RESF_Config);
	}

	for (resp = resource_info; resp->namep != NULL; resp++) {
		DBG(c_printf("\nphase 3c: rebind %s\n\n", resp->namep));
		resp->commit(RESF_Rebind);
	}

	for (resp = resource_info; resp->namep != NULL; resp++) {
		DBG(c_printf("\nphase 3d: modify %s\n\n", resp->namep));
		resp->commit(RESF_Modify);
	}

	accept_hvmd();
}

static void
init_reconfig_error_reply(hvctl_msg_t *replyp, int code)
{
	replyp->msg.rcfail.hvmdp = hton64(0);
	replyp->msg.rcfail.res = hton32(HVctl_res_guest);
	replyp->msg.rcfail.code = hton32(code);
	replyp->msg.rcfail.nodeidx = hton32(-1);
	replyp->msg.rcfail.resid = hton32(-1);
}

/*
 * This is the core reconfiguration function employed by the hv
 * control channel.
 *
 * The operation basically divides into 7 steps, the relevent functions
 * are called for each resource type for each of the steps in turn.
 *
 *    1. prep phase   - prepare structures for a reconfig
 *    2. parse phase  - parse, cache and sanity check resource info based on MD
 *      2a parse      - parse and cache resource info
 *      2b postparse  - sanity check after all parsing is done
 *    3. commit phase - based on parse results commit operations.
 *      3a unconfig   - in reverse priority order unconfig resources
 *      3b config     - configure resources.
 *      3c rebind     - rebind resources.
 *      3d modify     - modify resources.
 *
 * In the commit phase doing the unconfigs first is important
 * since they need to be detached in reverse order from their
 * parent resources. For example, to add a cpu to a guest the guest
 * has to be configured first. For an unconfigure a guest should be
 * unconfigured *after* the cpus have been removed.
 *
 * Hence the inverse priority ordering in the resource management.
 */
hvctl_status_t
op_reconfig(hvctl_msg_t *cmdp, hvctl_msg_t *replyp, bool_t isdelayed)
{
	hvctl_status_t	status;
	bin_md_t	*mdp;
	md_element_t	*mdep;
	md_element_t	*rootnodep;
	res_info_t	*resp;
	uint64_t	guestid, content_version;
	guest_t		*guestp;

	/* Grab the new hvmd cookie given to us by Zeus */
	mdp = (bin_md_t *)ntoh64(cmdp->msg.reconfig.hvmdp);

	DBG(c_printf("\nhvmd @ 0x%x\n", ntoh64(cmdp->msg.reconfig.hvmdp)));

	if (isdelayed) {
		guestid = ntoh32(cmdp->msg.reconfig.guestid);
		if (guestid >= NGUESTS) {
			init_reconfig_error_reply(replyp,
			    HVctl_e_guest_invalid_id);
			return (HVctl_st_einval);
		}

		guestp = &((guest_t *)config.guests)[guestid];
		if (guestp->state == GUEST_STATE_UNCONFIGURED) {
			init_reconfig_error_reply(replyp,
			    HVctl_e_guest_invalid_id);
			return (HVctl_st_einval);
		}

		spinlock_enter(&config.del_reconf_lock);

		DBG(c_printf("current delayed reconfig: guestid=0x%x\n",
		    config.del_reconf_gid));

		if (config.del_reconf_gid != INVALID_GID) {
			/* a delayed reconfig is pending */
			if (config.del_reconf_gid != guestid) {
				/* it's for a different guest, error */
				spinlock_exit(&config.del_reconf_lock);
				init_reconfig_error_reply(replyp,
				    HVctl_e_guest_invalid_id);
				return (HVctl_st_eillegal);
			}
		}
	} else {
		spinlock_enter(&config.del_reconf_lock);
		if (config.del_reconf_gid != INVALID_GID) {
			/* no reconfig allowed if delayed reconfig is pending */
			spinlock_exit(&config.del_reconf_lock);
			init_reconfig_error_reply(replyp,
			    HVctl_e_guest_invalid_id);
			return (HVctl_st_eillegal);
		}
		spinlock_exit(&config.del_reconf_lock);
	}

	/* Setup the new HVMD */
	status = preparse_hvmd(mdp);
	if (status != HVctl_st_ok) {
		if (isdelayed) {
			/* cancel any pending delayed reconfig */
			config.del_reconf_gid = INVALID_GID;
			spinlock_exit(&config.del_reconf_lock);
		}

		return (status);
	}

	/*
	 * First find the root node
	 */
	rootnodep = md_find_node(mdp, NULL, MDNAME(root));
	if (rootnodep == NULL) {
		DBG(c_printf("Missing root node in HVMD\n"));
		return (HVctl_st_badmd);
	}

	/*
	 * Check content-version in the newly downloaded MD.
	 */

	if (!md_node_get_val(mdp, rootnodep, MDNAME(content_version),
	    &content_version)) {
		DBG(c_printf("reconfig: HV MD Content version not found\n"));
		return (HVctl_st_mdnotsupp);
	}

	/*
	 * Major numbers must be equal.
	 */

	if (MDCONT_VER_MAJOR(content_version) != HV_MDCONT_VER_MAJOR) {
		DBG(c_printf("reconfig: HV MD content-version mismatch: "
		    "supported major ver %x, found %x\n", HV_MDCONT_VER_MAJOR,
		    MDCONT_VER_MAJOR(content_version)));
		return (HVctl_st_mdnotsupp);
	}

	DBG(c_printf("reconfig: HV MD Content version  %x.%x \n",
	    MDCONT_VER_MAJOR(content_version),
	    MDCONT_VER_MINOR(content_version)));

	/* Phase 1 - prep each resource */

	for (resp = resource_info; resp->namep != NULL; resp++) {
		DBG(c_printf("\nphase 1 : %s\n\n", resp->namep));
		resp->prep();
	}

	/* Phase 2a - parse MD for each resource */
	/*
	 * Note: when we move to a collective node for each
	 * resource type in the HV MD we can move the basic
	 * parse functions into this level.
	 */
	for (resp = resource_info; resp->namep != NULL; resp++) {
		hvctl_res_error_t fail_code;
		md_element_t	*failnodep;
		int		fail_res_id;

		DBG(c_printf("\nphase 2a : %s\n\n", resp->namep));

		status = resp->parse(mdp, &fail_code, &failnodep, &fail_res_id);
		if (status != HVctl_st_ok) {
			int idx = failnodep != NULL ?
			    failnodep - &mdp->elem[0] : 0;
			replyp->msg.rcfail.hvmdp = hton64((uint64_t)mdp);
			replyp->msg.rcfail.res = hton32(resp->type);
			replyp->msg.rcfail.code = hton32(fail_code);
			replyp->msg.rcfail.nodeidx = hton32(idx);
			replyp->msg.rcfail.resid = hton32(fail_res_id);
			DBG(c_printf("fail status 0x%x\n", status));

			if (isdelayed) {
				/* cancel any pending delayed reconfig */
				config.del_reconf_gid = INVALID_GID;
				spinlock_exit(&config.del_reconf_lock);
			}

			return (status);
		}
	}

	/* Phase 2b - post parse sanity checking for each resource */

	for (resp = resource_info; resp->namep != NULL; resp++) {
		hvctl_res_error_t fail_code;
		int fail_res_id;

		DBG(c_printf("\nphase 2b : %s\n\n", resp->namep));

		status = resp->postparse(&fail_code, &fail_res_id);
		if (status != HVctl_st_ok) {
			replyp->msg.rcfail.hvmdp = hton64((uint64_t)mdp);
			replyp->msg.rcfail.res = hton32(resp->type);
			replyp->msg.rcfail.code = hton32(fail_code);
			replyp->msg.rcfail.nodeidx = hton32(0);
			replyp->msg.rcfail.resid = hton32(fail_res_id);
			DBG(c_printf("fail status 0x%x\n", status));

			if (isdelayed) {
				/* cancel any pending delayed reconfig */
				config.del_reconf_gid = INVALID_GID;
				spinlock_exit(&config.del_reconf_lock);
			}

			return (status);
		}
	}

	/* only get here if there were no errors */

	if (isdelayed) {
		DBG(c_printf("setting delayed reconfig: guestid=0x%x\n",
		    guestid));
		config.del_reconf_gid = guestid;
		spinlock_exit(&config.del_reconf_lock);
	} else {
		/*
		 * Phase 3 - commit phase
		 */
		commit_reconfig();
	}

	return (HVctl_st_ok);
}

/*
 * Cancel any outstanding delayed reconfiguration.
 */
/* ARGSUSED */
hvctl_status_t
op_cancel_reconfig(hvctl_msg_t *cmdp, hvctl_msg_t *replyp)
{
	hvctl_status_t	status;

	spinlock_enter(&config.del_reconf_lock);

	if (config.del_reconf_gid == INVALID_GID) {
		status = HVctl_st_eillegal;
	} else {
		config.del_reconf_gid = INVALID_GID;
		status = HVctl_st_ok;
	}

	spinlock_exit(&config.del_reconf_lock);

	return (status);
}
