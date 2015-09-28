/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hvcontrol.c
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

#pragma ident	"@(#)hvcontrol.c	1.12	07/07/10 SMI"

#include <sys/htypes.h>
#include <traps.h>
#include <cache.h>
#include <mmu.h>
#include <vdev_ops.h>
#include <vdev_intr.h>
#include <ncs.h>
#include <cyclic.h>
#include <config.h>
#include <vcpu.h>
#include <strand.h>
#include <guest.h>
#include <support.h>
#include <ldc.h>
#include <hvctl.h>
#include <md.h>
#include <abort.h>
#include <proto.h>
#include <debug.h>

#if DEBUG
void dump_control_pkt();
#endif

void hvctl_send_pkt(hvctl_msg_t *replyp);
void bad_sequence_number(int seqn, hvctl_msg_t *fromp);
void reply_cmd(hvctl_msg_t *replyp, hvctl_status_t status);
void op_start_hello(hvctl_msg_t *rcptp, hvctl_msg_t *replyp);
void op_start_hello2(hvctl_msg_t *rcptp, hvctl_msg_t *replyp);
void op_get_configp(hvctl_msg_t *replyp);
hvctl_status_t op_reconfig(hvctl_msg_t *cmdp, hvctl_msg_t *replyp,
    bool_t isdelayed);
hvctl_status_t op_cancel_reconfig(hvctl_msg_t *cmdp, hvctl_msg_t *replyp);
hvctl_status_t op_get_hvconfig(hvctl_msg_t *replyp);
hvctl_status_t op_guest_start(hvctl_msg_t *cmdp, hvctl_msg_t *replyp);
hvctl_status_t op_guest_stop(hvctl_msg_t *cmdp, hvctl_msg_t *replyp);
hvctl_status_t op_guest_panic(hvctl_msg_t *cmdp, hvctl_msg_t *replyp);
hvctl_status_t op_get_res_stat(hvctl_msg_t *cmdp, hvctl_msg_t *replyp);

void get_guest_utilisation(guest_t *guestp, rs_guest_util_t *statp);

extern void c_hvldc_send(int hv_endpt, void *payload);

/*
 * This function is essentially a callback when a HV control
 * packet is received.
 *
 * It receives the request, performs the required action, and then
 * formulates the appropriate response.
 *
 * Eventually the response will be returned via an ldc_send to the
 * contributing domain, but for the moment the response packet is built,
 * then finally copied into the temp buffer in the config structure - from
 * where it is returned by the calling assembler layer.
 */
void
hv_control_pkt()
{
	hvctl_msg_t	*rcptp;
	hvctl_msg_t	*replyp;
	hvctl_op_t	op;
	int		seqn;
	hvctl_status_t	status;

	rcptp = (hvctl_msg_t *)&config.hvctl_ibuf[0];
	replyp = (hvctl_msg_t *)&config.hvctl_obuf[0];

	DBGHL(c_printf("HV control interface\n"));
	DBGHL(dump_control_pkt(rcptp));

	op = ntoh16(rcptp->hdr.op);
	seqn = ntoh16(rcptp->hdr.seqn);

	/*
	 * Prime response by copying over command
	 */
	replyp->hdr.op = hton16(op);

	switch (config.hvctl_state) {
	case HVCTL_STATE_UNCONNECTED:
		DBGHL(c_printf("\t\tstate: UNKNOWN\n"));
		if (op != HVctl_op_hello) {
			reply_cmd(replyp, HVctl_st_eauth);
			return;
		}
		/*
		 * We special case the Hello command.
		 * It should have sequence number 1, and resets the
		 * rest of the command channel state machine.
		 */
hello_cmd:;
		op_start_hello(rcptp, replyp);
		return;

	case HVCTL_STATE_CHALLENGED:
		DBGHL(c_printf("\t\tstate: STATE_1\n"));
		if (op == HVctl_op_hello) goto hello_cmd;

		if (config.hvctl_zeus_seq != seqn) {
			config.hvctl_state = HVCTL_STATE_UNCONNECTED;
			bad_sequence_number(seqn, replyp);
			return;
		}
		config.hvctl_zeus_seq++;	/* ready for next CMD packet */

		if (op != HVctl_op_response) {
			config.hvctl_state = HVCTL_STATE_UNCONNECTED;
			reply_cmd(replyp, HVctl_st_eauth);
			return;
		}
		op_start_hello2(rcptp, replyp);
		return;

	case HVCTL_STATE_CONNECTED:
		DBGHL(c_printf("\t\tstate: STATE_2\n"));
		if (op == HVctl_op_hello) goto hello_cmd;

		if (config.hvctl_zeus_seq != seqn) {
			config.hvctl_state = HVCTL_STATE_UNCONNECTED;
			bad_sequence_number(seqn, replyp);
			return;
		}
		config.hvctl_zeus_seq++;	/* ready for next CMD packet */
		break;

	default:
		DBGHL(c_printf("Internal HVCTL error - reached state 0x%x\n",
		    config.hvctl_state));
		config.hvctl_state = HVCTL_STATE_UNCONNECTED;
		return;
	}

	/* Only the STATE_2 case makes it here */

	/*
	 * we get here in the normal case because the hvctl channel
	 * stat indicates that the communication path has authenticated and
	 * is in fact now open.
	 *
	 * What remains is to handle each of the incomming control commands
	 */

	status = HVctl_st_eauth;
	switch (op) {
	case HVctl_op_get_hvconfig:
		DBGHL(c_printf("HVctl_op_get_hvconfig\n"));
		status = op_get_hvconfig(replyp);
		break;
	case HVctl_op_reconfigure:
		DBGHL(c_printf("HVctl_op_reconfigure\n"));
		status = op_reconfig(rcptp, replyp, false);
		break;
	case HVctl_op_guest_delayed_reconf:
		DBGHL(c_printf("HVctl_op_guest_delayed_reconf\n"));
		status = op_reconfig(rcptp, replyp, true);
		break;
	case HVctl_op_guest_start:
		DBGHL(c_printf("HVctl_op_guest_start\n"));
		status = op_guest_start(rcptp, replyp);
		break;
	case HVctl_op_guest_stop:
		DBGHL(c_printf("HVctl_op_guest_stop\n"));
		status = op_guest_stop(rcptp, replyp);
		break;
	case HVctl_op_guest_suspend:
		DBGHL(c_printf("HVctl_op_guest_suspend\n"));
		break;
	case HVctl_op_guest_resume:
		DBGHL(c_printf("HVctl_op_guest_resume\n"));
		break;
	case HVctl_op_guest_panic:
		DBGHL(c_printf("HVctl_op_guest_panic\n"));
		status = op_guest_panic(rcptp, replyp);
		break;
	case HVctl_op_get_res_stat:
		DBGHL(c_printf("HVctl_op_get_res_stat\n"));
		status = op_get_res_stat(rcptp, replyp);
		break;
	case HVctl_op_cancel_reconf:
		DBGHL(c_printf("HVctl_op_cancel_reconf\n"));
		status = op_cancel_reconfig(rcptp, replyp);
		break;
	default:
		break;
	}

	reply_cmd(replyp, status);
}

/*
 * This function is used to start a guest that is in the stopped state.
 *
 * We ack the command, and then when the guest actually gets going the
 * domain manager should get an async state update indicating that the
 * guest has actually been entered.
 *
 * That way we don't do things like memory scrub and prom copying in this
 * function.
 */
hvctl_status_t
op_guest_start(hvctl_msg_t *cmdp, hvctl_msg_t *replyp)
{
	int			guestid;
	guest_t			*guestp = (guest_t *)config.guests;
	hvctl_res_error_t	errcode;
	hvctl_status_t		status;

	guestid = cmdp->msg.guestop.guestid;
	errcode = 0;
	status = HVctl_st_ok;

	if (guestid < 0 || guestid >= NGUESTS) {
		errcode = HVctl_e_guest_invalid_id;
		status = HVctl_st_einval;
		goto done;
	}

	guestp = &guestp[guestid];

	spinlock_enter(&guestp->state_lock);

	switch (guestp->state) {
	case GUEST_STATE_SUSPENDED:
	case GUEST_STATE_NORMAL:
	case GUEST_STATE_EXITING:
	case GUEST_STATE_RESETTING:
		errcode = HVctl_e_guest_active;
		status = HVctl_st_eillegal;
		spinlock_exit(&guestp->state_lock);
		goto done;
	case GUEST_STATE_STOPPED:
		break;
	case GUEST_STATE_UNCONFIGURED:
	default:
		errcode = HVctl_e_guest_invalid_id;
		status = HVctl_st_einval;
		spinlock_exit(&guestp->state_lock);
		goto done;
	}

	guestp->state = GUEST_STATE_RESETTING;

	spinlock_exit(&guestp->state_lock);

	if (!guest_ignition(guestp)) {
		errcode = HVctl_e_guest_nocpus;
		status = HVctl_st_einval;
	}

done:
	replyp->msg.guestop.code = errcode;
	return (status);
}


/*
 * Find an appropriate target strand to drive the guest exit
 * operation. The criteria for a valid target is a strand that
 * is not in error and not in transition.
 *
 * Returns the ID of the selected strand, or -1 if no suitable
 * strand could be found.
 */
static uint8_t
find_target_strand_for_exit(guest_t *guestp)
{
	int	i;
	vcpu_t	**vcpulistp;
	vcpu_t	*vcpup;

	vcpulistp = &(guestp->vcpus[0]);

	for (i = 0; i < NVCPUS; i++) {

		vcpup = vcpulistp[i];

		if (vcpup == NULL)
			continue;

		ASSERT(vcpup->guest == guestp);

		if ((vcpup->status != CPU_STATE_RUNNING) &&
		    (vcpup->status != CPU_STATE_STOPPED) &&
		    (vcpup->status != CPU_STATE_SUSPENDED))
			continue;

		return (vcpup->strand->id);
	}

	return (-1);
}

/*
 * This function is used to stop a guest that is in the running or
 * suspended state.
 *
 * We ack the command, and then when the guest actually shuts down the
 * domain manager should get an async state update indicating that the
 * guest has actually been entered.
 *
 * This avoids having to busy wait in this function while other parts of
 * the hypervisor shuts down.
 *
 * If Zeus doesn't get a timely response to this command it should assume
 * that some or all of the strands associated with this command are dead
 * or off in the weeds ...
 */
hvctl_status_t
op_guest_stop(hvctl_msg_t *cmdp, hvctl_msg_t *replyp)
{
	int			guestid;
	guest_t			*guestp = (guest_t *)config.guests;
	hvctl_res_error_t	errcode;
	hvctl_status_t		status;
	uint8_t			tgt_strand;
	hvm_t			hvxcmsg;

	guestid = cmdp->msg.guestop.guestid;
	errcode = 0;
	status = HVctl_st_ok;

	if (guestid < 0 || guestid >= NGUESTS) {
		errcode = HVctl_e_guest_invalid_id;
		status = HVctl_st_einval;
		goto done;
	}

	guestp = &guestp[guestid];

	spinlock_enter(&guestp->state_lock);

	switch (guestp->state) {
	case GUEST_STATE_NORMAL:
	case GUEST_STATE_SUSPENDED:
		/* state is fine to proceed */
		break;

	case GUEST_STATE_STOPPED:
		errcode = HVctl_e_guest_stopped;
		status = HVctl_st_eillegal;
		spinlock_exit(&guestp->state_lock);
		goto done;

	case GUEST_STATE_RESETTING:
		/*
		 * The guest is already resetting, so it cannot
		 * be stopped and it is not appropriate to wait
		 * for the reset to complete. Fail the operation.
		 */
		status = HVctl_st_stop_failed;
		spinlock_exit(&guestp->state_lock);
		goto done;

	case GUEST_STATE_EXITING:
		/*
		 * The guest is already stopping, so return
		 * success and let the LDom manager wait for
		 * the asynchronous notification that the
		 * prior stop has completed.
		 */
		spinlock_exit(&guestp->state_lock);
		goto done;

	case GUEST_STATE_UNCONFIGURED:
	default:
		errcode = HVctl_e_guest_invalid_id;
		status = HVctl_st_einval;
		spinlock_exit(&guestp->state_lock);
		goto done;
	}

	/*
	 * The stop operation must be driven by a strand
	 * in the guest being stopped. Find an appropriate
	 * strand and send it a xcall to do the real work.
	 */
	tgt_strand = find_target_strand_for_exit(guestp);
	if (tgt_strand == -1) {
		status = HVctl_st_stop_failed;
		spinlock_exit(&guestp->state_lock);
		goto done;
	}

	guestp->state = GUEST_STATE_EXITING;
	spinlock_exit(&guestp->state_lock);

	DBG(c_printf("sending xcall to stop guest...\n"));

	/* pack and send the xcall */
	hvxcmsg.cmd = HXCMD_STOP_GUEST;
	hvxcmsg.args.stopguest.guestp = (uint64_t)guestp;

	DBG(c_printf("stop guest target 0x%x ..\n", tgt_strand));

	c_hvmondo_send(&strands[tgt_strand], &hvxcmsg);

done:
	replyp->msg.guestop.code = errcode;
	return (status);
}


hvctl_status_t
op_guest_panic(hvctl_msg_t *cmdp, hvctl_msg_t *replyp)
{
	int		i;
	uint32_t	guestid;
	guest_t		*guestp;
	ldc_endpoint_t	*hvctl_ep;
	vcpu_t		*vcpup;
	hvm_t		hvxcmsg;

	guestid = ntoh32(cmdp->msg.guestop.guestid);

	if (guestid >= NGUESTS) {
		replyp->msg.guestop.code = hton32(HVctl_e_guest_invalid_id);
		return (HVctl_st_einval);
	}

	guestp = &((guest_t *)config.guests)[guestid];
	hvctl_ep = &((ldc_endpoint_t *)config.hv_ldcs)[config.hvctl_ldc];

	/*
	 * Prevent attempts to panic the control domain.
	 * By definition, that is the domain initiating
	 * this request.
	 */
	if (guestp == hvctl_ep->target_guest) {
		replyp->msg.guestop.code = hton32(HVctl_e_guest_invalid_id);
		return (HVctl_st_einval);
	}

	switch (guestp->state) {
	case GUEST_STATE_NORMAL:
	case GUEST_STATE_SUSPENDED:
	case GUEST_STATE_EXITING:
		break;
	case GUEST_STATE_STOPPED:
		replyp->msg.guestop.code = hton32(HVctl_e_guest_stopped);
		return (HVctl_st_eillegal);
	case GUEST_STATE_UNCONFIGURED:
	default:
		replyp->msg.guestop.code = hton32(HVctl_e_guest_invalid_id);
		return (HVctl_st_einval);
	}

	/* find a running vcpu in the guest domain */
	for (i = 0; i < NVCPUS; i++) {
		vcpup = guestp->vcpus[i];
		if (vcpup == NULL)
			continue;

		if (vcpup->status == CPU_STATE_RUNNING)
			break;
	}

	if (i == NVCPUS) {
		replyp->msg.guestop.code = hton32(HVctl_e_guest_nocpus);
		return (HVctl_st_einval);
	}

	/* send a mondo to the chosen vcpu */
	hvxcmsg.cmd = HXCMD_GUEST_PANIC;
	hvxcmsg.args.guestcmd.vcpup = (uint64_t)vcpup;

	c_hvmondo_send(vcpup->strand, &hvxcmsg);

	return (HVctl_st_ok);
}

hvctl_status_t
get_guest_status(hvctl_msg_t *cmdp, hvctl_msg_t *replyp)
{
	int guestid;
	int infoid;
	int status;
	guest_t *guestp;
	void *dptr;

	guestid = cmdp->msg.resstat.resid;
	infoid = cmdp->msg.resstat.infoid;

	if (guestid < 0 || guestid >= NGUESTS) {
		replyp->msg.resstat.code = HVctl_e_guest_invalid_id;
		return (HVctl_st_einval);
	}

	status = HVctl_st_ok;
	guestp = &((guest_t *)config.guests)[guestid];

	dptr = &(replyp->msg.resstat.data[0]);

	if (infoid < 0 || infoid >= HVctl_info_guest_max) {
		replyp->msg.resstat.code = HVctl_e_invalid_infoid;
		status = HVctl_st_einval;
	} else {
		spinlock_enter(&guestp->async_lock[infoid]);

		switch (infoid) {
		case HVctl_info_guest_state: {
			rs_guest_state_t *statp = dptr;

			statp->state = guestp->state;
			guestp->async_busy[infoid] = 0;
			break;
		}
		case HVctl_info_guest_soft_state: {
			rs_guest_soft_state_t *statp = dptr;

			statp->soft_state = guestp->soft_state;
			c_memcpy(statp->soft_state_str, guestp->soft_state_str,
			    SOFT_STATE_SIZE);
			guestp->async_busy[infoid] = 0;
			break;
		}
		case HVctl_info_guest_tod: {
			rs_guest_tod_t *statp = dptr;

			statp->tod = guestp->tod_offset;
			guestp->async_busy[infoid] = 0;
			break;
		}
		case HVctl_info_guest_utilisation:
			get_guest_utilisation(guestp, dptr);
			break;
		default:
			replyp->msg.resstat.code = HVctl_e_invalid_infoid;
			status = HVctl_st_einval;
		}

		spinlock_exit(&guestp->async_lock[infoid]);
	}

	return (status);
}

/*
 * Returns the number of yielded cycles for the specified vcpu since
 * the last time the utilization statistics were gathered.
 *
 * Each vcpu maintains a count of the yielded cycles since the guest
 * was bound to it. By tracking only the delta from the last time the
 * count was read, it is not necessary to reset the yield count or
 * use atomic operations to update the yielded cycles per-guest and
 * yielded cycles per-vcpu counters.
 */
static uint64_t
get_vcpu_yielded_cycle_delta(vcpu_t *vcpup, uint64_t now, uint64_t last_count)
{
	uint64_t yield_count;
	uint64_t yield_curr;

	/* start with the total yielded cycles */
	yield_count = vcpup->util.yield_count;

	/* check if the vcpu is currently yielded */
	if ((yield_curr = vcpup->util.yield_start) == 0) {
		/*
		 * The vcpu is not currently yielded. Read
		 * the yield count again to make sure that
		 * if a yield just completed, those cycles
		 * are accounted for.
		 */
		yield_count = vcpup->util.yield_count;

	} else if (yield_curr < now) {
		/* add the cycles for the current yield */
		yield_count += (now - yield_curr);
	}

	/*
	 * Return the change in the number of yielded cycles
	 * since the last time the yield stats were gathered
	 * for this vcpu.
	 */
	return (yield_count - last_count);
}

/*
 * Returns the utilisation stats for a guest since the last
 * time they were read. The side effect of this call is to
 * reset the stat collecting again.
 */
void
get_guest_utilisation(guest_t *guestp, rs_guest_util_t *statp)
{
	uint64_t now;
	vcpu_t	*vcpup;
	int	i;

	now = GET_STICK_TIME();

	/*
	 * When this HV supports sub-cpu scheduling
	 * these figures have to come from the guest struct
	 */
	statp->lifespan = now - guestp->start_stick;
	statp->wallclock_delta = now - guestp->util.stick_last;
	statp->active_delta = now - guestp->util.stick_last;
	/*
	 * Number of cycles CPUs have been stopped for
	 * - not the same as yielded cycles.
	 * FIXME: assume zero for now.
	 */
	statp->stopped_cycles = 0;

	/*
	 * Aggregate the yield cycles for each vcpu assigned to
	 * this guest for the last timing interval.
	 */
	statp->yielded_cycles = 0;
	vcpup = &((vcpu_t *)config.vcpus)[0];

	for (i = 0; i < NVCPUS; i++) {

		if (vcpup->guest == guestp) {
			uint64_t delta;

			/*
			 * Get the number of yielded cycles since the
			 * guest stats were last gathered.
			 */
			delta = get_vcpu_yielded_cycle_delta(vcpup, now,
			    vcpup->util.last_yield_count_guest);

			/* set the guest last yield count to 'now' */
			vcpup->util.last_yield_count_guest += delta;

			/*
			 * Aggregate the vcpu delta with the total guest
			 * yielded cycle count.
			 */
			statp->yielded_cycles += delta;
		}
		vcpup++;
	}

	guestp->util.stick_last = now;
}

/*
 * Return the status of a vcpu resource
 */
hvctl_status_t
get_vcpu_status(hvctl_msg_t *cmdp, hvctl_msg_t *replyp)
{
	int	vcpuid;
	int	infoid;
	int	status;
	vcpu_t	*vcpup;
	void	*dptr;

	vcpuid = cmdp->msg.resstat.resid;
	infoid = cmdp->msg.resstat.infoid;

	if (vcpuid < 0 || vcpuid >= NVCPUS) {
		replyp->msg.resstat.code = HVctl_e_vcpu_invalid_id;
		return (HVctl_st_einval);
	}

	status = HVctl_st_ok;
	vcpup = &((vcpu_t *)config.vcpus)[vcpuid];

	dptr = &(replyp->msg.resstat.data[0]);

	switch (infoid) {
	case HVctl_info_vcpu_state: {
		rs_vcpu_state_t *statp = dptr;
		uint64_t	now;
		uint64_t	delta;

		now = GET_STICK_TIME();

		statp->state = vcpup->status;
		statp->lifespan = now - vcpup->start_stick;
		statp->wallclock_delta = now - vcpup->util.stick_last;
		statp->active_delta = now - vcpup->util.stick_last;

		/*
		 * Get the number of yielded cycles since the
		 * vcpu stats were last gathered.
		 */
		delta = get_vcpu_yielded_cycle_delta(vcpup, now,
		    vcpup->util.last_yield_count_vcpu);

		/* set the vcpu last yield count to 'now' */
		vcpup->util.last_yield_count_vcpu += delta;

		/* clamp if necessary */
		statp->yielded_cycles = (delta > statp->active_delta) ?
		    statp->active_delta : delta;

		vcpup->util.stick_last = now;
		break;
	}
	default:
		replyp->msg.resstat.code = HVctl_e_invalid_infoid;
		status = HVctl_st_einval;
	}

	return (status);
}

/*
 * This function is used to request the status of a resource.
 */
static hvctl_status_t
op_get_res_stat(hvctl_msg_t *cmdp, hvctl_msg_t *replyp)
{
	hvctl_status_t status;

	switch (cmdp->msg.resstat.res) {
	case HVctl_res_guest:
		status = get_guest_status(cmdp, replyp);
		break;

	case HVctl_res_vcpu:
		status = get_vcpu_status(cmdp, replyp);
		break;

	case HVctl_res_memory:
	case HVctl_res_mau:
#ifdef CONFIG_PCIE
	case HVctl_res_pcie_bus:
#endif
	case HVctl_res_ldc:
	case HVctl_res_hv_ldc:
	case HVctl_res_guestmd:
#ifdef STANDALONE_NET_DEVICES
	case HVctl_res_network_device:
#endif
		status = HVctl_st_enotsupp;
		break;

	default:
		status = HVctl_st_einval;
		break;
	}

	return (status);
}


void
bad_sequence_number(int seqn, hvctl_msg_t *replyp)
{
	DBGHL(c_printf("Bad sequence number received 0x%x - expected 0x%x\n",
	    seqn, config.hvctl_zeus_seq));

	config.hvctl_state = HVCTL_STATE_UNCONNECTED;
	reply_cmd(replyp, HVctl_st_bad_seqn);
}

void
reply_cmd(hvctl_msg_t *replyp, hvctl_status_t status)
{
	replyp->hdr.status = hton16(status);

	switch (status) {
	case HVctl_st_ok:
		break;
	case HVctl_st_bad_seqn:
	case HVctl_st_eauth:
		config.hvctl_state = HVCTL_STATE_UNCONNECTED;
	default:
		DBGHL(c_printf(
		    "\tCommand failed with error code %x\n", status));
		break;
	}

	hvctl_send_pkt(replyp);
}


/*
 * Initial hello handshake from the Domain Manager
 *
 * We check the major and minor version numbers offered for the protocol
 * negotiation, and note the sequence number offered to us by the domain
 * manager ... this is how we'll detect that a message got dropped later.
 * We also "invent" our own sequence number so the domain
 * manager can spot "dropped" packets later also.
 */
#define	RANDOM_SEQ_OFFSET 2909 /* ! */

void
op_start_hello(hvctl_msg_t *rcptp, hvctl_msg_t *replyp)
{
	config.hvctl_zeus_seq = ntoh16(rcptp->hdr.seqn);
	config.hvctl_zeus_seq++;	/* For the next packet */

	config.hvctl_hv_seq = config.hvctl_zeus_seq + RANDOM_SEQ_OFFSET;

	DBGHL(c_printf("Requested HV channel version %d.%d\n",
	    ntoh64(rcptp->msg.hello.major),
	    ntoh64(rcptp->msg.hello.minor)));

	if (ntoh64(rcptp->msg.hello.major) != HVCTL_VERSION_MAJOR_NUMBER) {
		/* Currently only support 1 version */
		replyp->hdr.op = hton16(HVctl_op_hello);
		replyp->hdr.status = hton16(HVctl_st_enotsupp);
		replyp->msg.hello.major = hton64(HVCTL_VERSION_MAJOR_NUMBER);
		replyp->msg.hello.minor = hton64(HVCTL_VERSION_MINOR_NUMBER);

		config.hvctl_state = HVCTL_STATE_UNCONNECTED;

		DBGHL(c_printf("Version refused\n"));

	} else {
		config.hvctl_rand_num = __LINE__;	/* FIXME */

		replyp->hdr.op = hton16(HVctl_op_challenge);
		replyp->hdr.status = hton16(HVctl_st_ok);
		replyp->msg.clnge.code =
		    hton64(HVCTL_HV_CHALLENGE_K ^ config.hvctl_rand_num);

		config.hvctl_state = HVCTL_STATE_CHALLENGED;

		DBGHL(c_printf("Version accepted; challenge = 0x%x\n",
		    ntoh64(replyp->msg.clnge.code)));
	}

	hvctl_send_pkt(replyp);
}

/*
 * Second stage in the handshake process ..  try and retrieve our key
 * from the packet
 */
void
op_start_hello2(hvctl_msg_t *rcptp, hvctl_msg_t *replyp)
{
	uint64_t key;

	DBGHL(c_printf("\tHello 2:\n"));

	key = ntoh64(rcptp->msg.clnge.code);

	if ((key ^ HVCTL_ZEUS_CHALLENGE_K) != config.hvctl_rand_num) {
		DBGHL(c_printf("\t\tFailed key check\n"));
		reply_cmd(replyp, HVctl_st_eauth);
		return;
	}

	DBGHL(c_printf("\t\tPassed key check\n"));
	config.hvctl_state = HVCTL_STATE_CONNECTED;

	reply_cmd(replyp, HVctl_st_ok);
}


/*
 * For the moment simply fills in the required reply
 * fields, and lets the outer asm layer do the send.
 */
void
hvctl_send_pkt(hvctl_msg_t *replyp)
{
	replyp->hdr.seqn = hton16(config.hvctl_hv_seq);
	config.hvctl_hv_seq++;
}


/*
 * Used by Zeus to pull out the hypervisor's machine description plus the
 * current delayed reconfiguration status and machine description if any.
 *
 * Membase and memsize is the range of memory that the HV has reserved
 * for itself.
 */
hvctl_status_t
op_get_hvconfig(hvctl_msg_t *replyp)
{
	replyp->msg.hvcnf.hv_membase = hton64(config.membase);
	replyp->msg.hvcnf.hv_memsize = hton64(config.memsize);

	spinlock_enter(&config.del_reconf_lock);

	replyp->msg.hvcnf.hvmdp = hton64((uint64_t)config.active_hvmd);
	replyp->msg.hvcnf.del_reconf_gid = hton32(config.del_reconf_gid);
	if (config.del_reconf_gid != INVALID_GID)
		replyp->msg.hvcnf.del_reconf_hvmdp =
		    hton64((uint64_t)config.parse_hvmd);
	else
		replyp->msg.hvcnf.del_reconf_hvmdp = hton64((uint64_t)NULL);

	spinlock_exit(&config.del_reconf_lock);

	return (HVctl_st_ok);
}

/*
 * Send an asynchronous notification on the HVctl channel that
 * a guest's soft state has changed.
 */
void
guest_soft_state_notify(guest_t *guestp)
{
	hvctl_msg_t ssmsg;

	c_bzero(&ssmsg, sizeof (ssmsg));

	spinlock_enter(&guestp->async_lock[HVctl_info_guest_soft_state]);
	if (guestp->async_busy[HVctl_info_guest_soft_state] == 0) {
		guestp->async_busy[HVctl_info_guest_soft_state] = 1;

		ssmsg.hdr.op = HVctl_op_new_res_stat;
		ssmsg.msg.resstat.res = HVctl_res_guest;
		ssmsg.msg.resstat.resid = guestp->guestid;
		ssmsg.msg.resstat.infoid = HVctl_info_guest_soft_state;
		ssmsg.msg.resstat.code = 0;
		((rs_guest_soft_state_t *)ssmsg.msg.resstat.data)->soft_state =
		    guestp->soft_state;
		c_memcpy(((rs_guest_soft_state_t *)ssmsg.msg.resstat.data)->
		    soft_state_str, guestp->soft_state_str, SOFT_STATE_SIZE);

		spinlock_enter(&config.hvctl_ldc_lock);
		c_hvldc_send(config.hvctl_ldc, &ssmsg);
		spinlock_exit(&config.hvctl_ldc_lock);
	}
	spinlock_exit(&guestp->async_lock[HVctl_info_guest_soft_state]);
}

/*
 * Send an asynchronous notification on the HVctl channel that
 * a guest's state has changed.
 */
void
guest_state_notify(guest_t *guestp)
{
	hvctl_msg_t smsg;

	spinlock_enter(&guestp->async_lock[HVctl_info_guest_state]);
	if (guestp->async_busy[HVctl_info_guest_state] != 0) {
		spinlock_exit(&guestp->async_lock[HVctl_info_guest_state]);
		return;
	}

	guestp->async_busy[HVctl_info_guest_state] = 1;

	c_bzero(&smsg, sizeof (smsg));

	smsg.hdr.op = hton16(HVctl_op_new_res_stat);
	smsg.msg.resstat.res = hton32(HVctl_res_guest);
	smsg.msg.resstat.resid = hton32(guestp->guestid);
	smsg.msg.resstat.infoid = hton32(HVctl_info_guest_state);
	smsg.msg.resstat.code = hton32(0);
	((rs_guest_state_t *)smsg.msg.resstat.data)->state =
	    hton64(guestp->state);

	/*
	 * Take the hvctl_ldc_lock while holding the async lock to ensure that
	 * state notifications maintain ordering and then release the async
	 * lock to minimize the time it is held.
	 */
	spinlock_enter(&config.hvctl_ldc_lock);
	spinlock_exit(&guestp->async_lock[HVctl_info_guest_state]);

	c_hvldc_send(config.hvctl_ldc, &smsg);

	spinlock_exit(&config.hvctl_ldc_lock);
}


#if DEBUG

void
dump_control_pkt()
{
	hvctl_msg_t	*rcptp;
	char		*sp;

	rcptp = (hvctl_msg_t *)&config.hvctl_ibuf[0];

	DBGHL(c_printf("\tCommand op 0x%x : seq# 0x%x : chksum # 0x%x\n",
	    rcptp->hdr.op, rcptp->hdr.seqn, rcptp->hdr.chksum));

#define	OP(_s, _n)	case _s : sp = #_s##" : "##_n; break;
	switch (rcptp->hdr.op) {
	OP(HVctl_op_hello, "Initial request to open hvctl channel")
	OP(HVctl_op_challenge, "challenge returned from HV to Zeus")
	OP(HVctl_op_response, "Response from Zeus")
	OP(HVctl_op_get_hvconfig, "Get the HV config pointers")
	OP(HVctl_op_reconfigure, "Reconfigure request")
	OP(HVctl_op_guest_start, "Start a guest")
	OP(HVctl_op_guest_stop, "Stop a guest")
	OP(HVctl_op_guest_delayed_reconf, "Delayed reconfigure on guest exit")
	OP(HVctl_op_guest_suspend, "Suspend a guest")
	OP(HVctl_op_guest_resume, "Resume a guest")
	OP(HVctl_op_guest_panic, "Panic a guest")
	OP(HVctl_op_get_res_stat, "Get resource status if supported")
	OP(HVctl_op_new_res_stat, "Async resource status update if supported")
#undef	OP
	default:
		sp = "Unknown command";
		break;
	}
	DBGHL(c_printf("\t%s\n", sp));
}

#endif
