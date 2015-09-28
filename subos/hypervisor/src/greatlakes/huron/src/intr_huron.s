/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: intr_huron.s
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

	.ident	"@(#)intr_huron.s	1.1	07/05/03 SMI"

	.file	"intr_huron.s"

#include <sys/asm_linkage.h>
#include <offsets.h>
#include <intr.h>
#include <util.h>


	! the mondo starting point.
	! %g1	cpup
	! %g2	mondo
	ENTRY_NP(vecintr)
	cmp	%g2, VECINTR_XCALL
	beq,pt	%xcc, cpu_mondo
	cmp	%g2, VECINTR_HVXCALL
	beq,pt	%xcc, hvxcall_mondo
	cmp	%g2, VECINTR_DEV
	beq,pt	%xcc, dev_mondo
	cmp	%g2, VECINTR_NIU_HI
	ble,pt	%xcc, niu_mondo
	cmp	%g2, VECINTR_VDEV
	bne,pt	%xcc, 1f
	nop
	HVCALL(vdev_mondo)
	retry
1:
#ifdef CONFIG_FPGA
	cmp	%g2, VECINTR_FPGA
	beq,pt	%xcc, fpga_intr
#endif
	cmp	%g2, VECINTR_SSIERR
	beq,pt	%xcc, ssi_mondo
	cmp	%g2, VECINTR_CPUINERR
	beq,pt	%xcc, cpu_err_rerouted 
	cmp	%g2, VECINTR_ERROR_XCALL
	beq,pt	%xcc, cpu_err_rerouted 
	nop

	! XXX unclaimed interrupt
	retry
	SET_SIZE(vecintr)
