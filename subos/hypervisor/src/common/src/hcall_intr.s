/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_intr.s
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

	.ident	"@(#)hcall_intr.s	1.99	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sun4v/vpci.h>
#include <asi.h>
#include <offsets.h>
#include <util.h>
#include <vdev_ops.h>
#include <vdev_intr.h>

/*
 * intr_devino2sysino
 *
 * arg0 dev handle [dev config pa] (%o0)
 * arg1 devino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 sysino (%o1)
 *
 */
	ENTRY_NP(hcall_intr_devino2sysino)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_DEVINO2VINO, %g1, %g2, %g3, \
	    herr_inval)
	SET_SIZE(hcall_intr_devino2sysino)

/*
 * intr_getenabled
 *
 * arg0 sysino (%o0)
 * --
 * ret0 status (%o0)
 * ret1 intr valid state (%o1)
 */
	ENTRY_NP(hcall_intr_getenabled)
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_GETVALID, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_getenabled)

/*
 * intr_setenabled
 *
 * arg0 sysino (%o0)
 * arg1 intr valid state (%o1) 1: Valid 0: Invalid
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_intr_setenabled)
	cmp	%o1, INTR_ENABLED_MAX_VALUE
	bgu,pn	%xcc, herr_inval
	nop
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_SETVALID, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_setenabled)

/*
 * intr_getstate
 *
 * arg0 sysino (%o0)
 * --
 * ret0 status (%o0)
 * ret1 (%o1) 0: idle 1: received 2: delivered
 */
	ENTRY_NP(hcall_intr_getstate)
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_GETSTATE, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_getstate)

/*
 * intr_setstate
 *
 * arg0 sysino (%o0)
 * arg1 (%o1) 0: idle 1: received 2: delivered
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_intr_setstate)
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_SETSTATE, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_setstate)

/*
 * intr_gettarget
 *
 * arg0 sysino (%o0)
 * --
 * ret0 status (%o0)
 * ret1 cpuid (%o1)
 */
	ENTRY_NP(hcall_intr_gettarget)
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_GETTARGET, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_gettarget)

/*
 * intr_settarget
 *
 * arg0 sysino (%o0)
 * arg1 cpuid (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_intr_settarget)
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_SETTARGET, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_settarget)


/*
 * vintr_getcookie
 *
 * arg0 dev handle [dev config pa] (%o0)
 * arg1 devino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 cookie (%o1)
 */
	ENTRY_NP(hcall_vintr_getcookie)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_VGETCOOKIE, %g1, %g2, %g3, \
		herr_inval)
	SET_SIZE(hcall_vintr_getcookie)

/*
 * vintr_setcookie
 *
 * arg0 dev handle [dev config pa] (%o0)
 * arg1 devino (%o1)
 * arg2 cookie (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_vintr_setcookie)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_VSETCOOKIE, %g1, %g2, %g3, \
		herr_inval)
	SET_SIZE(hcall_vintr_setcookie)

/*
 * vintr_getvalid
 *
 * arg0 dev handle [dev config pa] (%o0)
 * arg1 devino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 intr valid state (%o1)
 */
	ENTRY_NP(hcall_vintr_getvalid)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_VGETVALID, %g1, %g2, %g3, \
		herr_inval)
	SET_SIZE(hcall_vintr_getvalid)

/*
 * vintr_setvalid
 *
 * arg0 dev handle [dev config pa] (%o0)
 * arg1 devino (%o1)
 * arg2 intr valid state (%o2) 1: Valid 0: Invalid
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_vintr_setvalid)
	cmp	%o2, INTR_ENABLED_MAX_VALUE
	bgu,pn	%xcc, herr_inval
	nop
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_VSETVALID, %g1, %g2, %g3, \
		herr_inval)
	SET_SIZE(hcall_vintr_setvalid)

/*
 * vintr_gettarget
 *
 * arg0 dev handle [dev config pa] (%o0)
 * arg1 devino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 cpuid (%o1)
 */
	ENTRY_NP(hcall_vintr_gettarget)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_VGETTARGET, %g1, %g2, %g3, \
		herr_inval)
	SET_SIZE(hcall_vintr_gettarget)

/*
 * vintr_settarget
 *
 * arg0 dev handle [dev config pa] (%o0)
 * arg1 devino (%o1)
 * arg2 cpuid (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_vintr_settarget)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_VSETTARGET, %g1, %g2, %g3, \
		herr_inval)
	SET_SIZE(hcall_vintr_settarget)

/*
 * vintr_getstate
 *
 * arg0 dev handle [dev config pa] (%o0)
 * arg1 devino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 (%o1) 0: idle 1: received 2: delivered
 */
	ENTRY_NP(hcall_vintr_getstate)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_VGETSTATE, %g1, %g2, %g3, \
		herr_inval)
	SET_SIZE(hcall_vintr_getstate)

/*
 * vintr_setstate
 *
 * arg0 dev handle [dev config pa] (%o0)
 * arg1 devino (%o1)
 * arg2 (%o2) 0: idle 1: received 2: delivered
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_vintr_setstate)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_VSETSTATE, %g1, %g2, %g3, \
		herr_inval)
	SET_SIZE(hcall_vintr_setstate)
