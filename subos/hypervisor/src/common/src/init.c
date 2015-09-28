/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: init.c
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

#pragma ident	"@(#)init.c	1.19	07/09/20 SMI"

#include  <stdarg.h>
#include  <sys/htypes.h>
#include  <vdev_ops.h>
#include  <vdev_intr.h>
#include  <ncs.h>
#include  <cyclic.h>
#include  <vcpu.h>
#include  <strand.h>
#include  <guest.h>
#include  <memory.h>
#include  <pcie.h>
#include  <fpga.h>
#include  <hvctl.h>
#include  <md.h>
#include  <proto.h>
#include  <debug.h>
#ifdef STANDALONE_NET_DEVICES
#include <network.h>
#endif

hvctl_status_t op_guest_start(hvctl_msg_t *cmdp, hvctl_msg_t *replyp);
void config_hv_ldcs();
void config_a_hvldc(bin_md_t *mdp, md_element_t *hvldc_nodep);
void config_vcpus();
void config_vcpu_state(vcpu_t *vp);
#ifdef CONFIG_FPGA
void config_sp_ldcs();
void c_fpga_uninit();
#endif
void config_guests();
void config_a_guest(bin_md_t *mdp, md_element_t *guest_nodep);
void config_guest_md(guest_t *guestp);
void config_a_guest_ldc_endpoint(guest_t *guestp, bin_md_t *mdp,
	md_element_t *ldce_nodep);
#ifdef CONFIG_PCIE
extern void config_platform_pcie();
extern void reset_platform_pcie_busses(guest_t *guestp, pcie_device_t *pciep);
#endif
#ifdef STANDALONE_NET_DEVICES
extern void reset_platform_network_devices(guest_t *guestp,
	network_device_t *netp);
#endif
void kickoff_guests();
void reset_ldc_endpoint(ldc_endpoint_t *ldc_ep);
void c_ldc_cpu_notify(ldc_endpoint_t *t_endpt, vcpu_t *t_vcpup);
void config_svcchans();

#ifdef CONFIG_SVC
extern void config_svcchans();
#endif

void
fake_reconfig(bin_md_t *hvmdp)
{
	hvctl_msg_t	cmd;
	hvctl_msg_t	reply;

	cmd.hdr.op = HVctl_op_reconfigure;
	cmd.hdr.status = 0;
	cmd.msg.reconfig.hvmdp = (uint64_t)hvmdp;
	cmd.msg.reconfig.guestid = 0;
	reply = cmd;

	DBGINIT(c_printf("Fake reconfig:\n"));
#ifdef DEBUG
	c_printf("returned status 0x%x\n", op_reconfig(&cmd, &reply, false));
#else
	(void) op_reconfig(&cmd, &reply, false);
#endif	/* DEBUG */
}


void
fake_hvm_guest_start(int i)
{
	hvctl_msg_t	cmd;
	hvctl_msg_t	reply;

	cmd.hdr.op = HVctl_op_guest_start;
	cmd.hdr.status = 0;
	cmd.msg.guestop.guestid = i;
	reply = cmd;

	DBGINIT(c_printf("Fake guest start 0x%x\n", i));
#ifdef DEBUG
	c_printf("returned status 0x%x\n", op_guest_start(&cmd, &reply));
#else
	(void) op_guest_start(&cmd, &reply);
#endif	/* DEBUG */
}


void
c_start(void)
{
	/* LINTED */
	void *pres_hvmd;	/* FIXME: to go away */

	DBGINIT(c_printf(
	    "\n\n\t\t\tHypervisor 2.0 (LDoms capable + console)\n\n"));

	DBGINIT(c_printf("relocation is 0x%x :\n", config.reloc));
	DBGINIT(c_printf("\tso PROM c_start is at 0x%x\n",
	    config.reloc + (uint64_t)&c_start));
	DBGINIT(c_printf("\tRAM c_start is at 0x%x\n", (uint64_t)c_start));

	/*
	 * The following setup need only be done once at the
	 * beginning of time.
	 */
	config.guests = &guests[0];
	config.mblocks = &mblocks[0];
	config.vcpus = &vcpus[0];
	config.strands = &strands[0];
	config.hv_ldcs = &hv_ldcs[0];
	config.sp_ldcs = &sp_ldcs[0];
#ifdef CONFIG_PCIE
	config.pcie_busses = &pcie_bus[0];
#endif
#ifdef STANDALONE_NET_DEVICES
	config.network_devices = &network_device[0];
#endif
	DBGINIT(c_printf("root config @ 0x%x (0x%x)\n", (uint64_t)&config,
	    sizeof (struct config)));
	DBGINIT(c_printf("%d guest(s) @ 0x%x (0x%x)\n", NGUESTS, config.guests,
	    sizeof (struct guest)));
	DBGINIT(c_printf("%d mblock(s) @ 0x%x (0x%x)\n",
	    NMBLOCKS, config.mblocks, sizeof (struct mblock)));
	DBGINIT(c_printf("%d vcpu(s) @ 0x%x (0x%x)\n", NVCPUS, config.vcpus,
	    sizeof (struct vcpu)));
	DBGINIT(c_printf("%d strand(s) @ 0x%x (0x%x)\n",
	    NSTRANDS, config.strands, sizeof (struct strand)));
	DBGINIT(c_printf("%d ldc(s) @ 0x%x (0x%x)\n", MAX_HV_LDC_CHANNELS,
	    config.hv_ldcs, sizeof (struct ldc_endpoint)));
	DBGINIT(c_printf("%d sp_ldc(s) @ 0x%x (0x%x)\n", MAX_SP_LDC_CHANNELS,
	    config.sp_ldcs, sizeof (struct sp_ldc_endpoint)));
#ifdef	CONFIG_PCIE
	DBGINIT(c_printf("%d pcie_bus(ses) @ 0x%x (0x%x)\n", NUM_PCIE_BUSSES,
	    config.pcie_busses, sizeof (struct pcie_device)));
#endif
#ifdef	STANDALONE_NET_DEVICES
	DBGINIT(c_printf("%d network_device(s) @ 0x%x (0x%x)\n",
	    NUM_NETWORK_DEVICES, config.network_devices,
	    sizeof (struct network_device)));
#endif

	init_hv_internals();

#ifndef	SIMULATION
	/*
	 * Download the hypervisor and guest MDs.
	 */
	c_bootload();
#endif

#if defined(CONFIG_PCIE) || defined(CONFIG_FIRE)
	init_pcie_buses();
#endif

	/*
	 * This configuration is done based on the MD contents
	 */
	preparse_hvmd((bin_md_t *)config.parse_hvmd);

	/*
	 * For error handling mark the strands we started as
	 * being the active strands.
	 * Even an idle (no vcpu) strand could/should be able
	 * to handle errors and interrupts if necessary.
	 */
	config.strand_active = config.strand_startset;
	DBGINIT(c_printf(
	    "Available strand mask = 0x%x\n", config.strand_startset));
	DBGINIT(c_printf("\tintrtgt = 0x%x\n", config.intrtgt));

	config_basics();
#ifdef  CONFIG_SVC
	config_svcchans();
#endif

	/*
	 * Initial HV LDC config needs to happen before
	 * config_guests, so the console is properly setup.
	 */
	config_hv_ldcs();

#ifdef CONFIG_FPGA
	config_sp_ldcs();
#endif

#if 1 /* FIXME: All this to be removed - init config should be by reconfig */

	config_guests();
			/* Fake up a config of the memory blocks */
			/* see op_reconfig */
	do {
		bin_md_t *mdp;
		hvctl_res_error_t	fail_code;
		md_element_t	*failnodep;
		int		fail_res_id;
		extern void	res_memory_prep();
		extern void	res_memory_commit(int flag);
		extern hvctl_status_t res_memory_parse(bin_md_t *mdp,
		    hvctl_res_error_t *fail_codep,
		    md_element_t **failnodepp, int *fail_res_idp);
		extern void	res_console_prep();
		extern void	res_console_commit(int flag);
		extern hvctl_status_t res_console_parse(bin_md_t *mdp,
		    hvctl_res_error_t *fail_codep,
		    md_element_t **failnodepp, int *fail_res_idp);
#ifdef	CONFIG_PCIE
		extern void	res_pcie_bus_prep();
		extern void	res_pcie_bus_commit(int flag);
		extern hvctl_status_t res_pcie_bus_parse(bin_md_t *mdp,
		    hvctl_res_error_t *fail_codep,
		    md_element_t **failnodepp, int *fail_res_idp);
#endif
#ifdef	CONFIG_CRYPTO
		extern void	res_mau_prep();
		extern void	res_mau_commit(int flag);
		extern hvctl_status_t res_mau_parse(bin_md_t *mdp,
		    hvctl_res_error_t *fail_codep,
		    md_element_t **failnodepp, int *fail_res_idp);
		extern void	res_cwq_prep();
		extern void	res_cwq_commit(int flag);
		extern hvctl_status_t res_cwq_parse(bin_md_t *mdp,
		    hvctl_res_error_t *fail_codep,
		    md_element_t **failnodepp, int *fail_res_idp);
#endif
#ifdef	STANDALONE_NET_DEVICES
		extern void	res_network_device_prep();
		extern void	res_network_device_commit(int flag);
		extern hvctl_status_t res_network_device_parse(bin_md_t *mdp,
		    hvctl_res_error_t *fail_codep,
		    md_element_t **failnodepp, int *fail_res_idp);
#endif

		mdp = (bin_md_t *)config.parse_hvmd;

		res_memory_prep();
		if (res_memory_parse(mdp, &fail_code, &failnodep, &fail_res_id)
		    != HVctl_st_ok) {
			DBGINIT(c_printf("Memory configure failed\n"));
			c_hvabort();
		}
		res_memory_commit(RESF_Config);
		res_console_prep();
		if (res_console_parse(mdp, &fail_code, &failnodep, &fail_res_id)
		    != HVctl_st_ok) {
			DBGINIT(c_printf("Console configure failed\n"));
			c_hvabort();
		}
		res_console_commit(RESF_Config);
#ifdef	CONFIG_PCIE
		res_pcie_bus_prep();
		if (res_pcie_bus_parse(mdp, &fail_code, &failnodep,
		    &fail_res_id)
		    != HVctl_st_ok) {
			DBGINIT(c_printf("pcie configure failed\n"));
			c_hvabort();
		}
		res_pcie_bus_commit(RESF_Config);
#endif
#ifdef	STANDALONE_NET_DEVICES
		/*
		 * Note that we will allow a system to be configured
		 * without the network devices if they are not present
		 * in the MD as these are not required for correct
		 * operation.
		 */
		DBGINIT(c_printf("Configuring network devices\r\n"));
		res_network_device_prep();
		if (res_network_device_parse(mdp, &fail_code, &failnodep,
		    &fail_res_id) == HVctl_st_ok) {
			res_network_device_commit(RESF_Config);
			DBGINIT(c_printf("network device(s) configured OK\n"));
		} else {
			DBGINIT(c_printf(
			    "network device(s) configuration failed\n"));
		}
#endif
		config_vcpus();		/* do after guests */
#ifdef	CONFIG_CRYPTO
		res_mau_prep();
		if (res_mau_parse(mdp, &fail_code, &failnodep,
		    &fail_res_id)
		    != HVctl_st_ok) {
			DBGINIT(c_printf("mau configure failed\n"));
			c_hvabort();
		}
		res_mau_commit(RESF_Config);
		res_cwq_prep();
		if (res_cwq_parse(mdp, &fail_code, &failnodep,
		    &fail_res_id)
		    != HVctl_st_ok) {
			DBGINIT(c_printf("cwq configure failed\n"));
			c_hvabort();
		}
		res_cwq_commit(RESF_Config);
#endif
	} while (0);
#else

		/*
		 * for the moment need to preserve the parse_hvmd
		 * beyond the reconfig - for setup_svc
		 */
	pres_hvmd = config.parse_hvmd;
	fake_reconfig(config.parse_hvmd);
	config.parse_hvmd = pres_hvmd;
#endif

#ifdef CONFIG_PCIE
	config_platform_pcie();
#endif

	accept_hvmd();

	/*
	 * Last step - make sure the configured guests get the boot
	 * cpus scheduled.
	 */
	kickoff_guests();

	DBGINIT(c_printf("c_start() done\n"));
}


/*
 * Initialise the basic internal data structures
 * HV uses before they are fully assigned.
 */
void
init_hv_internals()
{
	int i;

	DBGINIT(c_printf("\nInitialising internals\n"));

	DBGINIT(c_printf("WARNING TODO: \n"));
	DBGINIT(c_printf("\tSAVE_UE_GLOBALS may try to use the vcpu "
	    "scratchpad reg before it is initialized\n"));

	for (i = 0; i < NSTRANDS; i++)
		init_strand(i);

	for (i = 0; i < NGUESTS; i++)
		init_guest(i);

	init_mblocks();

	for (i = 0; i < NVCPUS; i++)
		init_vcpu(i);

	init_plat_hook();

	init_consoles();

	init_dummytsb();

	reloc_resource_info();

	reloc_hvmd_names();

	/* relocate vdev ops tables */
	reloc_plat_devops();

	/* relocate device instances */
	config.devinstancesp = devinstances;
	reloc_devinstances();
}

/*
 * Initialise the basic strand data structure
 */
void
init_strand(int i)
{
	strand_t *sp;
	int j;

	sp = config.strands;
	sp = &(sp[i]);

	sp->configp = &config;
	sp->id = i;

	/*
	 * DO NOT scrub the structure or the strand_stack because
	 * we're already using it!
	 */
	sp->current_slot = 0;
	for (j = 0; j < NUM_SCHED_SLOTS; j++) {
		sp->slot[j].action = SLOT_ACTION_NOP;
		sp->slot[j].arg = 0;
	}
	sp->err_seq_no = 0;
	sp->io_prot = 0;
	sp->io_error = 0;
}

/*
 * Used to relocate the dev ops of each virtual device
 */
void
reloc_devopsvec(devopsvec_t *devopsp)
{
	void **ptr;
	int i, limit;

	ptr = (void**)devopsp;
	limit = sizeof (*devopsp) / sizeof (*ptr);

	for (i = 0; i < limit; i++) {
		ptr[i] = reloc_ptr(ptr[i]);
	}
}


void
reloc_devinstances()
{
	devinst_t	*dp;
	int		i;

	dp = config.devinstancesp;

	for (i = 0; i < NDEV_INSTS; i++) {
		dp[i].cookie = reloc_ptr(dp[i].cookie);
		dp[i].ops = reloc_ptr(dp[i].ops);
	}
}


void *
reloc_ptr(void *ptr)
{
	return (ptr == NULL ? NULL :
	    (void*)(((uint64_t)ptr) - config.reloc));
}



/*
 * For a full power on no one is sending the relevent strands the schedule
 * mondo to bring the boot cpus of each guest on line so to get things
 * moving we put them there right from the get go.
 */
void
kickoff_guests()
{
	int i;
	guest_t *gp;

	gp = config.guests;

	for (i = 0; i < NGUESTS; i++) {
		if (gp->state != GUEST_STATE_UNCONFIGURED) {
			fake_hvm_guest_start(i);
		}
		gp++;
	}
}

/*
 * Attempt to shutdown a guest. Handles the cases where a guest exits,
 * requests a reset, or is stopped. Performs all the steps necessary
 * to put the guest in a state where it can be restarted. If the reason
 * for exiting is a reset, the guest is restarted before the strand
 * returns to go look for work.
 *
 * The assumption is that the guest state has already been set to one
 * of the transitional states (exiting or resetting). This prevents any
 * further attempts to change the state of the guest or any of its vcpus
 * while it is being shut down.
 */
hvctl_status_t
c_guest_exit(guest_t *guestp, int reason)
{
	int 		i;
	strand_t 	*mystrandp;
	vcpu_t		**vcpulistp;
	ldc_endpoint_t	*hvctlep;
#ifdef	CONFIG_PCIE
	pcie_device_t	*pciep;
#endif
#ifdef STANDALONE_NET_DEVICES
	network_device_t	*netp;
#endif

	ASSERT((reason == GUEST_EXIT_MACH_EXIT) ||
	    (reason == GUEST_EXIT_MACH_SIR));

	ASSERT((guestp->state == GUEST_STATE_EXITING) ||
	    (guestp->state == GUEST_STATE_RESETTING));

	DBGINIT(c_printf("guest_exit: reason=0x%x, state=0x%x\n",
	    reason, guestp->state));

	mystrandp = c_mystrand();
	vcpulistp = &(guestp->vcpus[0]);

	/*
	 * Stop all vcpus in the guest, including the local strand.
	 */
	for (i = 0; i < NVCPUS; i++) {
		hvm_t	hvxcmsg;
		vcpu_t	*vp;

		vp = vcpulistp[i];
		if (vp == NULL)
			continue;

		ASSERT(vp->guest == guestp);

		/* for the local strand, just stop it immediately */
		if (vp->strand == mystrandp) {
			ASSERT((vp->status == CPU_STATE_RUNNING) ||
			    (vp->status == CPU_STATE_STOPPED) ||
			    (vp->status == CPU_STATE_SUSPENDED));

			DBGINIT(c_printf("stopping local vCPU 0x%x...\n",
			    vp->vid));

			c_desched_n_stop_vcpu(vp);
			continue;
		}

		/*
		 * Wait for the vcpu to finish any state transition it
		 * may have started before the exit was initiated.
		 */
		while ((vp->status == CPU_STATE_STARTING) ||
		    (vp->status == CPU_STATE_STOPPING))
			/* LINTED */
			/* do nothing */;

		if (vp->status == CPU_STATE_ERROR)
			continue;

		ASSERT(vp->status == CPU_STATE_RUNNING ||
		    vp->status == CPU_STATE_STOPPED ||
		    vp->status == CPU_STATE_SUSPENDED);

		hvxcmsg.cmd = HXCMD_STOP_VCPU;
		hvxcmsg.args.sched.vcpup = (uint64_t)vp;
		c_hvmondo_send(vp->strand, &hvxcmsg);

		DBGINIT(c_printf("stop sent to vCPU 0x%x...\n", vp->vid));

		DBGINIT(c_printf("waiting for vCPU 0x%x id=0x%x, st=0x%x...\n",
		    vp, vp->vid, vp->status));

		/* wait for the vcpu to stop */
		while ((vp->status != CPU_STATE_STOPPED) &&
		    (vp->status != CPU_STATE_ERROR))
			/* LINTED */
			/* do nothing */;

		if (vp->status == CPU_STATE_STOPPED)
			DBGINIT(c_printf("vCPU 0x%x has stopped\n", vp->vid));
		if (vp->status == CPU_STATE_ERROR)
			DBGINIT(c_printf("vCPU 0x%x is in error\n", vp->vid));
	}

	DBGINIT(c_printf("all vCPUS have stopped \n"));

	/*
	 * Remove all the channels this guest is currently using.
	 */
	for (i = 0; i < guestp->ldc_max_channel_idx; i++) {
		if ((guestp->ldc_endpoint[i].is_live == false) ||
		    (guestp->ldc_endpoint[i].is_private))
			continue;

		guestp->ldc_endpoint[i].tx_qsize = 0;
		/* skip channel if it is not configured */
		if (guestp->ldc_endpoint[i].rx_qsize == 0)
			continue;
		guestp->ldc_endpoint[i].rx_qsize = 0;

		switch (guestp->ldc_endpoint[i].target_type) {

		case LDC_GUEST_ENDPOINT:
		{
			/* send interrupt notify */
			ldc_endpoint_t *my_endpt, *t_endpt;
			vcpu_t		*t_vcpup;
			uint64_t	t_ldcid;

			my_endpt = &guestp->ldc_endpoint[i];
			t_ldcid = my_endpt->target_channel;
			t_endpt =
			    &(my_endpt->target_guest->ldc_endpoint[t_ldcid]);
			t_vcpup = (vcpu_t *)t_endpt->rx_mapreg.pcpup;

			/* FIXME: revoke imported/exported LDC memory */


			if (t_vcpup != NULL) {
				DBGINIT(c_printf("disable ldc 0x%x -> notify "
				    "guest 0x%x, ldc 0x%x, cpu 0x%x ..\n",
				    i, my_endpt->target_guest, t_ldcid,
				    t_vcpup));

				c_ldc_cpu_notify(t_endpt, t_vcpup);
			}
			break;
		}
		case LDC_SP_ENDPOINT:
		{
#if defined(CONFIG_PCIE)  && !defined(DEBUG_LEGION)

			/* send interrupt notify */
			ldc_endpoint_t *my_endpt;
			struct sp_ldc_endpoint *sp_endpt;
			struct sram_ldc_qd *rx_qdp;
			uint64_t t_ldcid;

			my_endpt = &guestp->ldc_endpoint[i];
			t_ldcid = my_endpt->target_channel;
			sp_endpt =
			    &(((struct sp_ldc_endpoint *)
			    config.sp_ldcs)[t_ldcid]);

			rx_qdp = (struct sram_ldc_qd *)sp_endpt->rx_qd_pa;
			rx_qdp->state = 0;	    /* link is down */
			rx_qdp->state_updated = 1;  /* indicate link reset */
			rx_qdp->state_notify = 1;   /* notify SP */

			DBGINIT(c_printf("disable ldc 0x%x -> notify "
			    "SP ldc 0x%x ..\n", i, t_ldcid));

			c_ldc_send_sp_intr(sp_endpt, SP_LDC_STATE_CHG);
#endif
			break;
		}
		case LDC_HV_ENDPOINT:
			break;
		}

		/* reset the endpoint */
		reset_ldc_endpoint(&guestp->ldc_endpoint[i]);
	}

	DBGINIT(c_printf("all LDCs have been reset\n"));


#ifdef CONFIG_PCIE
	/* reset attached devices like the PCI busses */
	pciep = config.pcie_busses;
	reset_platform_pcie_busses(guestp, pciep);
#endif

#ifdef STANDALONE_NET_DEVICES
	netp = config.network_devices;
	reset_platform_network_devices(guestp, netp);
#endif

	/* FIXME: cleanup service channels */

	/*
	 * At this point - unless we're going to restart the guest
	 * we can mark the stop operation as complete.
	 */

	if (reason != GUEST_EXIT_MACH_SIR) {
		spinlock_enter(&guestp->state_lock);
		guestp->state = GUEST_STATE_STOPPED;
		spinlock_exit(&guestp->state_lock);
	}

	/*
	 * Do any pending delayed reconfiguration.
	 */
	spinlock_enter(&config.del_reconf_lock);
	if (config.del_reconf_gid == guestp->guestid) {
		DBGINIT(c_printf("performing delayed reconfig: guestid=0x%x\n",
		    guestp->guestid));
		commit_reconfig();
		config.del_reconf_gid = INVALID_GID;
	}
	spinlock_exit(&config.del_reconf_lock);

	/*
	 * send a msg to hvctl channel .. unless it
	 * is attached to the guest we just stopped ;-)
	 */
	hvctlep = config.hv_ldcs;
	hvctlep = &hvctlep[config.hvctl_ldc];

	if (hvctlep->target_guest != guestp) {
		DBGINIT(c_printf("sending async message on hvctl channel\n"));
		guest_state_notify(guestp);
	}

	/*
	 * If this was a stop or exit request
	 * we're done at this point.
	 */

	if (reason != GUEST_EXIT_MACH_SIR)
		return (HVctl_st_ok);

	ASSERT(guestp->state == GUEST_STATE_RESETTING);

	/*
	 * This is an SIR, so we have to restart a CPU from the
	 * guest. This is after a delayed reconfig, so the vcpu
	 * list in the guest is correct.
	 */
	(void) guest_ignition(guestp);
	return (HVctl_st_ok);
}

/*
 * Kicks off a guest. Returns true on success and false
 * if no boot cpus are to be found.
 */
bool_t
guest_ignition(guest_t *guestp)
{
	int		i;
	vcpu_t		*vcpup;
	strand_t	*mystrandp;

	/*
	 * Caller should already have set the guest state to
	 * indicate that this is the start of a new guest.
	 */
	ASSERT(guestp->state == GUEST_STATE_RESETTING);

	/*
	 * look for the first valid cpu in the guest
	 */
	for (i = 0; i < NVCPUS; i++) {
		vcpup = guestp->vcpus[i];
		if (vcpup != NULL && vcpup->status != CPU_STATE_ERROR) {
			ASSERT(vcpup->status == CPU_STATE_STOPPED);
			goto found_bootcpu;
		}
	}
	return (false);

found_bootcpu:

	ASSERT(vcpup->guest == guestp);
	ASSERT(vcpup->status == CPU_STATE_STOPPED);

	DBGINIT(c_printf("Starting guest 0x%x - using vcpu_id 0x%x "
	    "(vid 0x%x)\n", guestp->guestid, vcpup->res_id, vcpup->vid));
	DBGINIT(c_printf("Strand active=0x%x,idle=0x%x\n",
	    config.strand_active, config.strand_idle));

	/*
	 * We deliver this using a simple HVXCALL message to schedule
	 * the appropriate vcpu.
	 */
	/*
	 * FIXME: replacing the hvxcall mbox with a queue means
	 * we can skip this check and simply send a x-call msg
	 * to schedule the vcpu regardless of whether it is our
	 * strand or not.
	 */

	mystrandp = c_mystrand();

	if (vcpup->strand == mystrandp) {
		int slot;

		slot = vcpup->strand_slot;
		mystrandp->slot[slot].action = SLOT_ACTION_RUN_VCPU;
		mystrandp->slot[slot].arg = (uint64_t)vcpup;
	} else {
		hvm_t	hvxcmsg;
		/*
		 * Send the start message to the strand owning the
		 * boot cpu to schedule it.
		 *
		 * NOTE: There is a subtle race in here that will
		 * go away with hvctl transmit queues, but currently
		 * doesnt show because of the time it takes to scrub the guest
		 * and copy in its prom image.
		 *
		 * With the one stop HVCTL mailbox, we can start the boot cpu
		 * it can grab the HVCTL mailbox for the state change mesage
		 * thus blocking it for us to send the command reply.
		 * We busy wait here to send the command reply, but the
		 * mbox never unblocks because it is this strand executing the
		 * domain manager at the guest level.
		 *
		 * This blocking cant happen with a hvctl transmit queue ..
		 */
		hvxcmsg.cmd = HXCMD_SCHED_VCPU;
		hvxcmsg.args.sched.vcpup = (uint64_t)vcpup;

		c_hvmondo_send(vcpup->strand, &hvxcmsg);
	}

	return (true);
}

void
init_dummytsb()
{
	typedef struct {
		uint64_t	tag;
		uint64_t	data;
	} tsb_entry_t;
	extern tsb_entry_t dummytsb[DUMMYTSB_ENTRIES];
	tsb_entry_t *tsbep;
	int i;

	DBGINIT(c_printf("config_dumbtsb()\n"));

	/*
	 * Dummy tsb has to be carefully aligned so can't put it
	 * in the config struct directly.
	 */
	tsbep = &dummytsb[0];
	config.dummytsbp = tsbep;

	for (i = 0; i < DUMMYTSB_ENTRIES; i++) {
		tsbep[i].tag = (uint64_t)-1; /* Invalid tag */
		tsbep[i].data = (uint64_t)0;
	}
}
