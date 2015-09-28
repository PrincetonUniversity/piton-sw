/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vpci_msi.s
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

	.ident	"@(#)vpci_msi.s	1.5	07/07/17 SMI"

	.file	"vpci_msi.s"

/*
 * VPCI MSI hcalls
 */

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <sun4v/vpci.h>
#include <asi.h>
#include <hprivregs.h>
#include <vdev_intr.h>
#include <offsets.h>
#include <guest.h>
#include <util.h>


/*
 * msiq_conf
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 EQ base RA (%o2)
 * arg3 #entries (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_msiq_conf)
	/* XXX validate RA (arg2) + size (arg3) here */
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSIQ_CONF, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msiq_conf)


/*
 * msiq_info
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 ra (%o1)
 * ret2 #entries (%o2)
 */
	ENTRY_NP(hcall_msiq_info)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSIQ_INFO, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msiq_info)


/*
 * msiq_getvalid
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 EQ valid (0: Invalid 1: Valid) (%o1)
 */
	ENTRY_NP(hcall_msiq_getvalid)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSIQ_GETVALID, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msiq_getvalid)


/*
 * msiq_setvalid
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 EQ valid (0: Invalid 1: Valid) (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_msiq_setvalid)
	cmp	%o2, INTR_ENABLED_MAX_VALUE
	bgu,pn	%xcc, herr_inval
	nop
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSIQ_SETVALID, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msiq_setvalid)


/*
 * msiq_getstate
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 EQ state (0: Idle 1: Error) (%o1)
 */
	ENTRY_NP(hcall_msiq_getstate)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSIQ_GETSTATE, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msiq_getstate)


/*
 * msiq_setstate
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 EQ state (0: Idle 1: Error) (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_msiq_setstate)
	cmp	%o2, HVIO_MSIQSTATE_MAX_VALUE
	bgu,pn	%xcc, herr_inval
	nop
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSIQ_SETSTATE, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msiq_setstate)


/*
 * msiq_gethead
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 head index (%o1)
 */
	ENTRY_NP(hcall_msiq_gethead)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSIQ_GETHEAD, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msiq_gethead)

/*
 * msiq_sethead
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 head offset (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_msiq_sethead)
	btst	MSIEQ_REC_SIZE_MASK, %o2
	bnz,pn	%xcc, herr_inval
	nop
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSIQ_SETHEAD, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msiq_sethead)


/*
 * msiq_gettail
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 tail index (%o1)
 */
	ENTRY_NP(hcall_msiq_gettail)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSIQ_GETTAIL, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msiq_gettail)


/*
 * msi_getvalid
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI status (0: Invalid 1: Valid) (%o1)
 */
	ENTRY_NP(hcall_msi_getvalid)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSI_GETVALID, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msi_getvalid)


/*
 * msi_setvalid
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * arg2 MSI status (0: Invalid 1: Valid) (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_msi_setvalid)
	cmp	%o2, HVIO_MSI_VALID_MAX_VALUE
	bgu,pn	%xcc, herr_inval
	nop
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSI_SETVALID, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msi_setvalid)


/*
 * msi_getstate
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI state (0: Idle 1: Delivered) (%o1)
 */
	ENTRY_NP(hcall_msi_getstate)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSI_GETSTATE, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msi_getstate)


/*
 * msi_setstate
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * arg2 MSI state (0: Idle) (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_msi_setstate)
	/* XXX only idle or is that just fire?  bounds-check here */
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSI_SETSTATE, %g1, %g2,
	     %g3, herr_inval)
	SET_SIZE(hcall_msi_setstate)


/*
 * msi_getmsiq
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI EQ id (%o1)
 */
	ENTRY_NP(hcall_msi_getmsiq)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSI_GETMSIQ, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msi_getmsiq)


/*
 * msi_setmsiq
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * arg2 MSI EQ id (%o2)
 * arg3 MSI type (MSI32=0 MSI64=1) (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_msi_setmsiq)
	cmp	%o3, MSIQTYPE_MAX_VALUE
	bgu,pn	%xcc, herr_inval
	nop
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSI_SETMSIQ, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msi_setmsiq)


/*
 * msi_msg_getmsiq
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI EQ id (%o1)
 */
	ENTRY_NP(hcall_msi_msg_getmsiq)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSI_MSG_GETMSIQ, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msi_msg_getmsiq)


/*
 * msi_msg_setmsiq
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * arg2 MSI EQ id (%o2)
 * --
 * ret0 status (%o0)
 */

	ENTRY_NP(hcall_msi_msg_setmsiq)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSI_MSG_SETMSIQ, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msi_msg_setmsiq)


/*
 * msi_msg_getvalid
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI msg valid state (%o1)
 */
	ENTRY_NP(hcall_msi_msg_getvalid)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSI_MSG_GETVALID, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msi_msg_getvalid)


/*
 * msi_msg_setvalid
 *
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * arg2 MSI msg valid state (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_msi_msg_setvalid)
	cmp	%o2, HVIO_PCIE_MSG_VALID_MAX_VALUE
	bgu,pn	%xcc, herr_inval
	nop
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MSI_MSG_SETVALID, %g1, %g2,
	    %g3, herr_inval)
	SET_SIZE(hcall_msi_msg_setvalid)
