/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_niu_network.c
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


#pragma ident	"@(#)res_niu_network.c	1.9	07/08/16 SMI"

#include <stdarg.h>

#include <sys/htypes.h>
#include <hypervisor.h>
#include <traps.h>
#include <sun4v/asi.h>
#include <sun4v/errs_defs.h>
#include <vdev_ops.h>
#include <vdev_intr.h>
#include <config.h>
#include <ncs.h>
#include <mmu.h>
#include <cyclic.h>
#include <vcpu.h>
#include <strand.h>
#include <guest.h>
#include <segments.h>
#include <memory.h>
#include <network.h>
#include <support.h>
#include <md.h>
#include <abort.h>
#include <proto.h>
#include <niu.h>
#include <fpga.h>

#ifdef STANDALONE_NET_DEVICES

extern const struct niu_cookie niu_dev[];

/*
 * (re)-configuration code to handle HV NIU network resources
 */

void
reset_platform_network_devices(guest_t *guestp, network_device_t *netp)
{
	extern const struct niu_cookie niu_dev[];
	int	i;

	/* reset attached network devices */
	netp = config.network_devices;
	for (i = 0; i < NUM_NETWORK_DEVICES; i++) {

		DBGNET(c_printf("network device 0x%x assigned to guest 0x%x\n",
		    &netp[i], netp[i].guestp));

		/* if device is assigned to this guest, soft reset the device */
		if (netp[i].guestp == guestp) {
			DBGNET(c_printf(
			    "Soft Reset network device 0x%x cookie 0x%x\n",
			    i, niu_dev[i]));

			niu_reset();
			xaui_reset();

			c_bzero(guestp->guest_m.niu_statep,
			    sizeof (struct niu_state));

			niu_init();
		}
	}
}

#define	ASSIGN_NIU_SEGMENTS(_guestp)					\
		assign_ra2pa_segments(guestp, NIU_ADDR_BASE,		\
		    NIU_ADDR_LIMIT - NIU_ADDR_BASE, 0, IO_SEGMENT);

#define	UNASSIGN_NIU_SEGMENTS(_guestp)					\
		assign_ra2pa_segments(guestp, NIU_ADDR_BASE,		\
		    NIU_ADDR_LIMIT - NIU_ADDR_BASE, 0, INVALID_SEGMENT);

void
config_a_guest_network_device(network_device_t *netp)
{
	guest_t *guestp;
	int id, vinobase, x;
	uint8_t devid;

	guestp = netp->guestp;
	id = netp->id;

	ASSERT(guestp != NULL);

	devid = (netp->cfg_handle) >> DEVCFGPA_SHIFT;
	vinobase = netp->cfg_handle;

	switch (id) {
		case (0):
			guestp->dev2inst[devid] = DEVOPS_NIU;
			ASSIGN_NIU_SEGMENTS(guestp);
			DBGNET(c_printf("\tNOTICE NIU 0x%x "	\
			    "configured for guest 0x%x\n", id,
			    guestp->guestid));
			break;
		default:
			DBGNET(c_printf("\tWARNING NIU 0x%x not "
			    "supported for guest 0x%x\n", id, guestp->guestid));
			/* should probably panic here */
			break;
	}

	for (x = 0; x < NINOSPERDEV; x++) {
		guestp->vino2inst.vino[vinobase + x] = DEVOPS_NIU;
	}

	guestp->guest_m.niu_statep = &niu_state;

	niu_init();
}

void
unconfig_a_guest_network_device(network_device_t *netp)
{
	guest_t *guestp;
	int id, vinobase, x;
	uint8_t devid;

	guestp = netp->guestp;
	id = netp->id;

	ASSERT(guestp != NULL);

	devid = (netp->cfg_handle) >> DEVCFGPA_SHIFT;
	vinobase = netp->cfg_handle;

	guestp->dev2inst[devid] = DEVOPS_RESERVED;
	for (x = 0; x < NINOSPERDEV; x++) {
		guestp->vino2inst.vino[vinobase + x] = DEVOPS_RESERVED;
	}

	guestp->guest_m.niu_statep = NULL;

	/*
	 * We clear out the NIU address segments by setting their size
	 * to INVALID_SEGMENT_SIZE and flags to INVALID_SEGMENT.
	 */
	switch (id) {
	case (0):
		UNASSIGN_NIU_SEGMENTS(guestp);
		break;
	default:
		break;
	}
}

#endif	/* STANDALONE_NET_DEVICES */
