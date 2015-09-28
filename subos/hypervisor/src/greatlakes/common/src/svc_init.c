/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: svc_init.c
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

#pragma ident	"@(#)svc_init.c	1.4	07/08/14 SMI"

#ifdef CONFIG_SVC
#include  <stdarg.h>
#include  <sys/htypes.h>
#include  <vdev_ops.h>
#include  <vdev_intr.h>
#include  <ncs.h>
#include  <cyclic.h>
#include  <vcpu.h>
#include  <strand.h>
#include  <guest.h>
#include  <md.h>
#include  <debug.h>

#include <svc.h>
#include <svc_vbsc.h>


static uint64_t
c_svc_register(uint64_t cookie, uint64_t xid, uint64_t sid, uint64_t recv,
uint64_t send)
{
	hv_svc_data_t	*r_svcp = config.svc;

	if (r_svcp != NULL) {
		svc_ctrl_t	*r_svcsp = r_svcp->svcs;
		int	i;

		/* for the requested services */
		for (i = r_svcp->num_svcs; i > 0; i--, r_svcsp++) {

			if ((r_svcsp->xid == xid) && (r_svcsp->sid == sid)) {
				/*
				 * attach the callbacks to this service
				 * Ensure intrs are disabled on the channel
				 * and set the CALLBACK flag in both the svc
				 * config and state variables
				 */
				r_svcsp->config |= SVC_CFG_CALLBACK;
				r_svcsp->state |= SVC_CFG_CALLBACK;
				r_svcsp->callback.rx = (uint64_t)recv;
				r_svcsp->callback.tx = (uint64_t)send;
				r_svcsp->callback.cookie = cookie;
				return ((uint64_t)r_svcsp);
			}
		}
	}
	return (0);
}

/*
 * c_setup_err_svc - setup error service channel
 */
static void
c_setup_err_svc()
{
	uint64_t	rv;
	strand_t	*sp = c_mystrand();

	rv = c_svc_register((uint64_t)sp, XPID_HV, SID_ERROR,
	    (uint64_t)error_svc_rx, (uint64_t)error_svc_tx);

	if (rv == 0) {
		DBGINIT(c_printf("WARNING:c_setup_err_svc register fail\r\n"));
	}
	config.error_svch = rv;
}

#ifdef CONFIG_VBSC_SVC

/*
 * c_setup_vbsc_svc - setup vbsc service channel
 */
static void
c_setup_vbsc_svc()
{
	uint64_t	rv;
	strand_t	*sp = c_mystrand();

	/* Put error_svc handle into the debug structure */
	config.vbsc_dbgerror.error_svch = config.error_svch;

	rv = c_svc_register((uint64_t)sp, XPID_HV, SID_VBSC_CTL,
	    (uint64_t)vbsc_rx, (uint64_t)vbsc_tx);

	if (rv) {
		config.vbsc_svch = rv;
	} else {
		c_hvabort(-1);
	}
}

/*
 * c_vbsc_send_polled - send a vbsc command and poll for response
 */
static void
c_vbsc_send_polled(uint64_t cmd1, uint64_t cmd2, uint64_t cmd3)
{
	uint16_t		fpga_cmd_offset;
	volatile uint8_t	*fpga_statusp;
	uint16_t		*fpga_basep;
	uint64_t		*fpga_cmdp;
	uint8_t			fpga_cmd_status;

c_vbsc_send_polled_resend:
	fpga_basep = (uint16_t *)(FPGA_Q3OUT_BASE);
	fpga_statusp = (uint8_t *)fpga_basep;

	fpga_cmdp = (uint64_t *)(FPGA_BASE + FPGA_SRAM_BASE);
	fpga_cmd_offset = *((uint16_t *)((uint64_t)fpga_basep + FPGA_Q_BASE));

	/* sram buffer words */
	fpga_cmdp = (uint64_t *)((uint64_t)fpga_cmdp +
	    (uint64_t)fpga_cmd_offset);

	/* insert the command bytes */
	*(fpga_cmdp + 2) = cmd3;
	*(fpga_cmdp + 1) = cmd2;
	*(fpga_cmdp + 0) = cmd1;

	/* initiate the command */
	*((uint8_t *)((uint64_t)fpga_statusp + FPGA_Q_SEND)) = 1;

	/*
	 * Wait for a non-zero status.  If we get an ACK then we're done.
	 * Otherwise re-send the packet.  Failure is not an option, even
	 * to hv_abort we need to send a message to vbsc.  So keep trying.
	 */
	fpga_statusp = (uint8_t *)((uint64_t)fpga_statusp + FPGA_Q_STATUS);
	do {
		fpga_cmd_status = *fpga_statusp;
		fpga_cmd_status &= (QINTR_ACK | QINTR_NACK | QINTR_BUSY
		    | QINTR_ABORT);
	} while (fpga_cmd_status == 0);

	if (fpga_cmd_status & QINTR_ACK) {
		*fpga_statusp = fpga_cmd_status;	/* ack the command */
	} else {
		goto c_vbsc_send_polled_resend;
	}
}

/*
 *  c_vbsc_guest_start - send a message indicating guest is starting
 */
void
c_vbsc_guest_start(uint64_t gid)
{
	guest_t	 *guestp = (guest_t *)config.guests;

	guestp = &(guestp[gid]);

	c_vbsc_send_polled(VBSC_GUEST_ON, guestp->guestid + XPID_GUESTBASE, 0);
}
#endif /* CONFIG_VBSC_SVC */


/*
 * c_svc_init - initialize the service channels
 */
void
c_svc_init()
{
	hv_svc_data_t	*r_svcp = config.svc;
	svc_ctrl_t	*r_svcsp = r_svcp->svcs;
	int		i;

	/* for each of the configured services */
	for (i = r_svcp->num_svcs; i > 0; i--, r_svcsp++) {

		/* if there is an RCV or XMT configured */
		if (r_svcsp->config & (SVC_CFG_RE | SVC_CFG_TE)) {

			if (r_svcsp->xid >= XPID_GUESTBASE) {
				guest_t	 *guestp = (guest_t *)config.guests;

				/* determine the guest for this service */
				guestp = &(guestp[r_svcsp->xid-XPID_GUESTBASE]);

				/* register the interrupt; save the cookie */
				r_svcsp->intr_cookie = c_vdev_intr_register(
				    guestp, r_svcsp->ino, r_svcsp,
				    svc_intr_getstate, (intr_setstate_f)NULL);
			}
		}
	}

#ifdef CONFIG_FPGA
	/*
	 * Mailbox hardware initialization
	 */
	{
		volatile uint8_t	*fpgap;
		uint8_t			tmp;

		/* Clear previously-pending state */
		fpgap = (uint8_t *)(FPGA_Q_BASE + FPGA_Q_STATUS);
		tmp = *fpgap;
		*fpgap = tmp;

		/* Enable interrupts */
		fpgap = (uint8_t *)(FPGA_INTR_BASE + FPGA_MBOX_INTR_ENABLE);
		*fpgap = (IRQ_QUEUE_IN|IRQ_QUEUE_OUT|IRQ_LDC_OUT);
	}
#endif /* CONFIG_FPGA */

	/* Must be before setup_vbsc_svc */
	c_setup_err_svc();

#ifdef CONFIG_VBSC_SVC
	DBGINIT(c_printf("c_svc_init: setup vbsc_svc\n"));
	c_setup_vbsc_svc();
#endif /* CONFIG_VBSC_SVC */
}
#endif /* CONFIG_SVC */
