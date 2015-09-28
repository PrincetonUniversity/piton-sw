/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: init_ontario.c
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

#pragma ident	"@(#)init_ontario.c	1.2	07/05/07 SMI"

#include  <stdarg.h>

#include  <sys/htypes.h>
#include  <hypervisor.h>
#include  <traps.h>
#include  <cache.h>
#include  <mmu.h>
#include  <sun4v/asi.h>
#include  <sun4v/errs_defs.h>
#include  <cpu_errs_defs.h>
#include  <cpu_errs.h>
#include  <vpci_errs_defs.h>
#include  <vdev_ops.h>
#include  <vdev_intr.h>
#include  <ncs.h>
#include  <cyclic.h>
#include  <config.h>
#include  <vcpu.h>
#include  <strand.h>
#include  <guest.h>
#include  <memory.h>
#include  <pcie.h>
#include  <support.h>
#include  <fpga.h>
#include  <svc.h>
#include  <ldc.h>
#include  <hvctl.h>
#include  <md.h>
#include  <abort.h>
#include  <proto.h>
#ifdef CONFIG_FIRE
#include <fire.h>
#endif

#ifdef CONFIG_CRYPTO /* { */
extern void init_mau_crypto_units();
#endif /* } */

#ifdef CONFIG_FIRE
extern const struct fire_cookie fire_dev[];
void c_fire_leaf_soft_reset(const struct fire_cookie *, int root);
#endif

/*
 * FIXME: This needs to be moved into a platform
 * specific file.
 */
void
reloc_plat_devops()
{
	extern devopsvec_t vdev_ops;
#ifdef CONFIG_FIRE /* { */
	extern devopsvec_t fire_dev_ops;
	extern devopsvec_t fire_int_ops;
	extern devopsvec_t fire_msi_ops;
	extern devopsvec_t fire_err_int_ops;
#endif /* } */
	extern devopsvec_t cdev_ops;

	reloc_devopsvec(&vdev_ops);
#ifdef	CONFIG_FIRE
	reloc_devopsvec(&fire_dev_ops);
	reloc_devopsvec(&fire_int_ops);
	reloc_devopsvec(&fire_msi_ops);
	reloc_devopsvec(&fire_err_int_ops);
#endif
	reloc_devopsvec(&cdev_ops);
}

void
config_a_guest_niu(guest_t *guestp)
{
	DBG(c_printf("\tWARNING NIU not supported for guest 0x%x\n",
	    guestp->guestid));
	/* should probably panic here */
}

#ifdef CONFIG_CRYPTO
/*
 * cwq support functions.
 */
void
res_cwq_prep()
{
}

hvctl_status_t
res_cwq_parse(bin_md_t *mdp, hvctl_res_error_t *fail_codep,
			md_element_t **failnodepp, int *fail_res_idp)
{
	DBG(c_printf("CWQ NOT SUPPORTED\n"));
	return (HVctl_st_ok);
}

void
res_cwq_commit(int flag)
{
	DBG(c_printf("CWQ NOT SUPPORTED\n"));
}

hvctl_status_t
res_cwq_postparse(hvctl_res_error_t *res_error, int *fail_res_id)
{
	DBG(c_printf("CWQS in HVMD - NOT SUPPORTED\n"));
	return (HVctl_st_ok);
}
#endif /* CONFIG_CRYPTO */


void
init_plat_hook(void)
{
#ifdef CONFIG_CRYPTO
	init_mau_crypto_units();
#endif	/* CONFIG_CRYPTO */
}
