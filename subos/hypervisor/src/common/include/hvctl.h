/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hvctl.h
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

#ifndef	_HVCTL_H
#define	_HVCTL_H

#pragma ident	"@(#)hvctl.h	1.8	07/06/06 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <hypervisor.h>
#include <support.h>

#define	HVCTL_MSG_MAXLEN	64


#define	HVCTL_STATE_UNCONNECTED	0
#define	HVCTL_STATE_CHALLENGED	1
#define	HVCTL_STATE_CONNECTED	2

#define	HVCTL_VERSION_MAJOR_NUMBER	1
#define	HVCTL_VERSION_MINOR_NUMBER	0

#define	HVCTL_HV_CHALLENGE_K	0xbadbeef20	/* to go away */
#define	HVCTL_ZEUS_CHALLENGE_K	0x12cafe42a	/* to go away */

#define	HVCTL_RES_STATUS_DATA_SIZE	40

#if !defined(_ASM)	/* { */

/*
 * Hypervisor control message definitions
 */


/*
 * Type codes for HV control messages
 */


/*
 * The operation code
 */
typedef enum {
	HVctl_op_hello = 0,	/* Initial request to open hvctl channel */
				/* yields a response of the same if fails */
	HVctl_op_challenge,	/* challenge returned from HV to Zeus */
	HVctl_op_response,	/* Response from Zeus */
	HVctl_op_get_hvconfig,	/* Get the HV config pointers */
	HVctl_op_reconfigure,	/* Reconfigure request */
	HVctl_op_guest_start,	/* Start a guest */
	HVctl_op_guest_stop,	/* Stop a guest */
	HVctl_op_guest_delayed_reconf,	/* Delayed reconfigure on guest exit */
	HVctl_op_guest_suspend,	/* Suspend a guest */
	HVctl_op_guest_resume,	/* Resume a guest */
	HVctl_op_guest_panic,	/* Panic a guest */
	HVctl_op_get_res_stat,	/* Get resource status if supported */
	HVctl_op_new_res_stat,	/* Aync resource status update if supported */
	HVctl_op_cancel_reconf,	/* Cancel any pending delayed reconfigure */
} hvctl_op_t;

/*
 * Response codes.
 */
typedef enum {
	HVctl_st_ok	= 0,
	HVctl_st_bad_seqn,	/* Bad sequence number (dropped packet) */
	HVctl_st_eauth,		/* Not authorised */
	HVctl_st_enotsupp,	/* OP is not supported */
	HVctl_st_badmd,		/* Broken MD */
	HVctl_st_mdnotsupp,	/* Unsupported MD format */
	HVctl_st_rc_failed,	/* Reconfig failed */
	HVctl_st_einval,	/* Invalid argument specified */
	HVctl_st_eillegal,	/* Illegal operation requested */
	HVctl_st_stop_failed,	/* Stop request failed */
} hvctl_status_t;


/*
 * Resource codes ... in parse process order
 */
typedef enum {
	HVctl_res_guest = 0,	/* guest resource */
	HVctl_res_vcpu,		/* virtual cpu resource */
	HVctl_res_memory,	/* memory block */
	HVctl_res_mau,		/* Niagara crypto unit */
	HVctl_res_cwq,		/* Niagara II crypto unit */
	HVctl_res_ldc,		/* LDC */
	HVctl_res_console,	/* Console nodes */
	HVctl_res_hv_ldc,	/* HV LDC - to be deleted */
	HVctl_res_pcie_bus,	/* PCIE bus */
	HVctl_res_guestmd,	/* guest md */
	HVctl_res_network_device,	/* Network */
} hvctl_res_t;


/*
 * Resource specific error codes.
 *
 * The encoding of these may be specific to each resource. In other
 * words a given code may have two or more different meanings depending
 * on the resource that flags it.
 * For the moment we keep the codes unique since it makes it easier to
 * debug with, but I reserve the right to go and double these up later,
 * so careful how you code.
 *
 * NOTE: with a well formed MD you should never see these errors. They are
 * here to help debug and in case someone ignores the HVCTL versioning.
 */
typedef enum {
		/* Guest specific errors */
	HVctl_e_guest_missing_id,
	HVctl_e_guest_invalid_id,
	HVctl_e_guest_missing_property,
	HVctl_e_guest_nocpus,
	HVctl_e_guest_active,
	HVctl_e_guest_stopped,
	HVctl_e_guest_base_mblock_too_small,
		/* vcpu specific errors */
	HVctl_e_vcpu_missing_id,
	HVctl_e_vcpu_invalid_id,
	HVctl_e_vcpu_missing_strandid,
	HVctl_e_vcpu_invalid_strandid,
	HVctl_e_vcpu_missing_vid,
	HVctl_e_vcpu_invalid_vid,
	HVctl_e_vcpu_missing_guest,
	HVctl_e_vcpu_missing_parttag,
	HVctl_e_vcpu_invalid_parttag,
	HVctl_e_vcpu_rebind_na,		/* rebind not allowed */
		/* memory specific errors */
	HVctl_e_mblock_missing_id,
	HVctl_e_mblock_invalid_id,
	HVctl_e_mblock_missing_membase,
	HVctl_e_mblock_missing_memsize,
	HVctl_e_mblock_invalid_parange,
	HVctl_e_mblock_missing_realbase,
	HVctl_e_mblock_invalid_rarange,
	HVctl_e_mblock_missing_guest,
	HVctl_e_mblock_rebind_na,
	HVctl_e_mblock_guest_active,
		/* mau specific errors */
	HVctl_e_mau_missing_id,
	HVctl_e_mau_invalid_id,
	HVctl_e_mau_missing_cpu,
	HVctl_e_mau_missing_strandid,
	HVctl_e_mau_invalid_strandid,
	HVctl_e_mau_missing_ino,
	HVctl_e_mau_missing_guest,
	HVctl_e_mau_rebind_na,		/* rebind not allowed */
		/* cwq specific errors */
	HVctl_e_cwq_missing_id,
	HVctl_e_cwq_invalid_id,
	HVctl_e_cwq_missing_cpu,
	HVctl_e_cwq_missing_strandid,
	HVctl_e_cwq_invalid_strandid,
	HVctl_e_cwq_missing_ino,
	HVctl_e_cwq_missing_guest,
	HVctl_e_cwq_rebind_na,		/* rebind not allowed */
		/* pcie_bus specific errors */
	HVctl_e_pcie_missing_prop,
	HVctl_e_pcie_illegal_prop,
	HVctl_e_pcie_rebind_na,
	HVctl_e_pcie_missing_guest,
		/* network specific errors */
	HVctl_e_network_missing_prop,
	HVctl_e_network_illegal_prop,
	HVctl_e_network_rebind_na,
	HVctl_e_network_missing_guest,
		/* ldc specific errors */
	HVctl_e_ldc_missing_prop,
	HVctl_e_ldc_illegal_prop,
	HVctl_e_ldc_rebind_na,
		/* hv_ldc */
	HVctl_e_hv_ldc_missing_prop,
	HVctl_e_hv_ldc_illegal_prop,
	HVctl_e_hv_ldc_rebind_na,
		/* console configuration errors */
	HVctl_e_cons_missing_id,
	HVctl_e_cons_missing_guest,
	HVctl_e_cons_missing_guest_id,
	HVctl_e_cons_invalid_guest_id,
	HVctl_e_cons_missing_ldc_id,
	HVctl_e_cons_invalid_ldc_id,
	HVctl_e_cons_missing_ino,
	HVctl_e_cons_invalid_ino,
	HVctl_e_cons_missing_uartbase,
		/* common */
	HVctl_e_invalid_infoid,
} hvctl_res_error_t;


/*
 * Format for initial hello.
 * Used for both init handshake, and for a nack response.
 */
typedef struct hvctl_hello {
	uint16_t	major;
	uint16_t	minor;
} hvctl_hello_t;

/*
 * Format used for an ack response to a handshake
 * holds the challenge code required by the HV.
 * And returned to the HV by Zeus using HVctl_op_response
 */
typedef struct hvctl_challenge {
	uint64_t	code;
} hvctl_challenge_t;

/*
 * Request to return the HVs current config info
 */
typedef struct hvctl_hvconfig {
	uint64_t	hv_membase;
	uint64_t	hv_memsize;
	uint64_t	hvmdp;
	uint64_t	del_reconf_hvmdp;
	uint32_t	del_reconf_gid;
} hvctl_hvconfig_t;


/*
 * Configuration change request.
 *
 * HV figures out the rest and lets us know what if anything can't be done.
 *
 * guestid is invalid if this is not a delayed config request
 *
 * The command is acked if the MD parses OK, but the actual reconfigure
 * is pended until the guest defined by guestid requests an exit or a reboot.
 */
typedef struct hvctl_reconfig {
	uint64_t	hvmdp;
	uint32_t	guestid;
} hvctl_reconfig_t;

/*
 * If the new config fails for some reason this is the response packet.
 *
 * The HV stops on first failure.
 *
 * The packet contains the node index of the resource that could not be
 * configured. The resource type (see above) and a resource type specific
 * failure code as to why. The remainder of the packet may (at some point)
 * contain further resource specific information.
 */
typedef struct hvctl_rc_fail {
	uint64_t	hvmdp;	/* the one that failed */
	uint32_t	res;	/* code of the resource the failed */
	uint32_t	code;	/* resource specific failure code */
	uint32_t	nodeidx;	/* idx of node in given HVMD */
	uint32_t	resid;	/* resource id of resource */
} hvctl_rc_fail_t;

/*
 * Payload and response packet used for other guest operations:
 * HVctl_op_guest_start
 * HVctl_op_guest_stop
 * HVctl_op_guest_suspend
 * HVctl_op_guest_resume
 * HVctl_op_guest_panic
 *
 * code is unused (set 0) in request from Zeus, but may contain a guest
 * resource specific error code from the HV in the event that the op fails
 * and more info than just the hvctl_status_t in the pkt header is needed.
 */
typedef struct hvctl_guest_op {
	uint32_t	guestid;
	uint32_t	code;
} hvctl_guest_op_t;


/*
 * Resource status/statistics request and async notice packet. The payload
 * is resource specific, and so left in a general form here.
 *
 * In the get request payload the data field is ignored.
 *
 * For example, this is used for a guest status update notification
 *	The data payload holds the guest state info.
 *	The side-effect of the get form in this case is to clear
 *	any no-notify on change state.
 */
typedef struct hvctl_res_status {
	uint32_t	res;	/* code of the resource type */
	uint32_t	resid;	/* ID of the instance of resource type */
	uint32_t	infoid;	/* ID of the info within the resource */
	uint32_t	code;	/* resource specific failure code */
	uint8_t		data[HVCTL_RES_STATUS_DATA_SIZE];
} hvctl_res_status_t;

/*
 * Info identifiers for guest resource.
 */
typedef enum {
	HVctl_info_guest_state,
	HVctl_info_guest_soft_state,
	HVctl_info_guest_tod,
	HVctl_info_guest_utilisation,
	HVctl_info_guest_max,
} hvctl_guest_info_t;

/*
 * Resource state returned in data for the
 * HVctl_info_guest_state infoid.
 */
typedef struct rs_guest_state {
	uint64_t	state;
} rs_guest_state_t;

/*
 * Resource state returned in data for the
 * HVctl_info_guest_soft_state infoid.
 */
typedef struct rs_guest_soft_state {
	uint8_t		soft_state;
	char		soft_state_str[SOFT_STATE_SIZE];
} rs_guest_soft_state_t;

/*
 * Resource state returned in data for the
 * HVctl_info_guest_tod infoid.
 */
typedef struct rs_guest_tod {
	uint64_t	tod;
} rs_guest_tod_t;

/*
 * Rsource state returned in data for the
 * HVctl_info_guest_utilisation infoid.
 * (this structure is full)
 */

typedef struct rs_guest_util {
	uint64_t	lifespan;
	uint64_t	wallclock_delta;
	uint64_t	active_delta;
	uint64_t	stopped_cycles;
	uint64_t	yielded_cycles;
} rs_guest_util_t;


/*
 * Info identifiers for vcpu resource.
 */
typedef enum {
	HVctl_info_vcpu_state,
	HVctl_info_vcpu_max,
} hvctl_vcpu_info_t;

/*
 * Resource state returned in data for the
 * HVctl_info_vcpu_state infoid.
 */
typedef struct rs_vcpu_state {
	uint8_t		state;
	uint64_t	lifespan;
	uint64_t	wallclock_delta;
	uint64_t	active_delta;
	uint64_t	yielded_cycles;
} rs_vcpu_state_t;


/*
 * Standard message header
 *
 * Applies to both requests and responses.
 *
 * The op field corresponds to an operation code or a reply code.
 * The sequence number is specific to the sender and is merely
 * used to detect dropped message packets.
 *
 * The status response accompanies an op field when in response to
 * a request to do something.
 */

/*
 * Basic header
 *
 * In requests to the HV the status field is ignored, in responses to
 * requests from Zeus, status corresponds to the relevent error code for
 * the request (op) field.
 *
 * For all messages (except the initial hello messages) the sequence number
 * is tracked to determine dropped requests.
 *
 * In the event of a dropped request, all future messages are dumped until
 * Zeus re-negotiates the HV control channel connection.
 */

typedef struct hvctl_header {
	uint16_t	op;
	uint16_t	seqn;
	uint16_t	chksum;
	uint16_t	status;	/* = 0 for commands, status for responses */
} hvctl_header_t;


typedef struct hvctl_msg {
	hvctl_header_t	hdr;
	union {
		hvctl_hello_t		hello;
		hvctl_challenge_t	clnge;
		hvctl_hvconfig_t	hvcnf;
		hvctl_reconfig_t	reconfig;
		hvctl_rc_fail_t		rcfail;
		hvctl_guest_op_t	guestop;
		hvctl_res_status_t	resstat;
	} msg;
} hvctl_msg_t;


/*
 * HV functions
 */
void		reloc_resource_info();
hvctl_status_t	op_reconfig(hvctl_msg_t *cmdp, hvctl_msg_t *replyp,
			bool_t isdelayed);
hvctl_status_t	op_guest_start(hvctl_msg_t *cmdp, hvctl_msg_t *replyp);


#endif	/* } !ASM */

#ifdef __cplusplus
}
#endif

#endif	/* _HVCTL_H */
