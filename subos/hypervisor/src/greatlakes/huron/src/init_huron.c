/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: init_huron.c
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

#pragma ident	"@(#)init_huron.c	1.2	07/06/06 SMI"

#include  <stdarg.h>

#include  <sys/htypes.h>
#include  <hypervisor.h>
#include  <traps.h>
#include  <cache.h>
#include  <mmu.h>
#include  <sun4v/asi.h>
#include  <sun4v/errs_defs.h>
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
#ifdef CONFIG_PIU
#include <piu.h>
#endif

#ifdef CONFIG_PIU
extern const struct piu_cookie piu_dev[];
void c_piu_leaf_soft_reset(const struct piu_cookie *, int root);
#endif

#ifdef CONFIG_CRYPTO
static void init_rng(void);
extern void init_mau_crypto_units(void);
extern void init_cwq_crypto_units(void);
#endif

/*
 * FIXME: This needs to be moved into a platform
 * specific file.
 */
void
reloc_plat_devops()
{
	extern devopsvec_t vdev_ops;
#ifdef CONFIG_PIU /* { */
	extern devopsvec_t piu_dev_ops;
	extern devopsvec_t piu_int_ops;
	extern devopsvec_t piu_msi_ops;
	extern devopsvec_t piu_err_int_ops;
#ifdef	CONFIG_FPGA_UART
	extern devopsvec_t fpga_uart_ops;
#endif /* CONFIG_FPGA_UART */
#endif /* } */
	extern devopsvec_t niu_ops;
	extern devopsvec_t cdev_ops;

	reloc_devopsvec(&vdev_ops);
#ifdef	CONFIG_PIU
	reloc_devopsvec(&piu_dev_ops);
	reloc_devopsvec(&piu_int_ops);
	reloc_devopsvec(&piu_msi_ops);
	reloc_devopsvec(&piu_err_int_ops);
#ifdef	CONFIG_FPGA_UART
	reloc_devopsvec(&fpga_uart_ops);
#endif /* CONFIG_FPGA_UART */
#endif
	reloc_devopsvec(&niu_ops);
	reloc_devopsvec(&cdev_ops);
}

#ifdef CONFIG_CRYPTO
static void
init_rng(void)
{
	rng_t	*rngp;

	config.config_m.rng = &rng;

	rngp = (rng_t *)config.config_m.rng;

	rngp->lock = 0;
	rngp->ctl.rc_state = RNG_STATE_ERROR;
	rngp->ctl.rc_guestid = -1;
}
#endif

void
init_plat_hook(void)
{
#ifdef CONFIG_CRYPTO
	init_mau_crypto_units();
	init_cwq_crypto_units();
	init_rng();
#endif	/* CONFIG_CRYPTO */
}
