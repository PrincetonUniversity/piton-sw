/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vdev_simdisk.s
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

	.ident	"@(#)vdev_simdisk.s	1.4	07/05/03 SMI"

#ifdef CONFIG_DISK

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <asi.h>
#include <mmu.h>

#include <guest.h>
#include <offsets.h>
#include <util.h>
#include <vdev_simdisk.h>


/*
 * fake-disk read
 *
 * arg0 disk offset (%o0)
 * arg1 target real address (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 */
	ENTRY_NP(hcall_disk_read)
#ifndef SIMULATION
	ba	herr_inval
	nop
#endif
	GUEST_STRUCT(%g1)
	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o1, %o2, herr_noraddr, %g3, %g2)
	! %g2	paddr

	set	GUEST_DISK, %g3
	add	%g1, %g3, %g1
	! %g1 = diskp

	ldx	[%g1 + DISK_SIZE], %g3
	brnz,pt	%g3, 1f
	  cmp	%o0, %g3	! XXX this doesn't matter, just %o0+%o2

	ldx	[%g1 + DISK_PA], %g4 ! base of disk
	cmp	%g4, -1
	be,pn	%xcc, herr_inval
	nop

	ld	[%g4 + DISK_S2NBLK_OFFSET], %g5	! read nblks from s2
	sllx	%g5, DISK_BLKSIZE_SHIFT, %g5		! multiply by blocksize
	stx 	%g5, [%g1 + DISK_SIZE]	! store disk size
	mov	%g5, %g3

	cmp	%o0, %g3
1:	bgeu,pn	%xcc, herr_inval
	add	%o0, %o2, %g4
	cmp	%g4, %g3
	bgu,pn	%xcc, herr_inval
	ldx	[%g1 + DISK_PA], %g3 ! base of disk

	/* bcopy(%g3 + %o0, %g2, %o2) */
	add	%g3, %o0, %g1
	! %g2 already set up
	mov	%o2, %g3
	ba	bcopy
	rd	%pc, %g7

	mov	%o2, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_disk_read)

/*
 * fake-disk write
 *
 * arg0 disk offset (%o0)
 * arg1 source real address (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 */
	ENTRY_NP(hcall_disk_write)
#ifndef SIMULATION
	ba	herr_inval
	nop
#endif
	GUEST_STRUCT(%g1)
	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o1, %o2, herr_noraddr, %g2, %g3)
	! %g3	paddr

	set	GUEST_DISK, %g2
	add	%g1, %g2, %g1
	! %g1 = diskp

	ldx	[%g1 + DISK_SIZE], %g2
	brnz,pt	%g2, 1f
	  cmp	%o0, %g2

	ldx	[%g1 + DISK_PA], %g4	 ! base of disk
	cmp	%g4, -1
	be,pn	%xcc, herr_inval
	nop

	ld	[%g4 + DISK_S2NBLK_OFFSET], %g5	! read nblks from s2
	sllx	%g5, DISK_BLKSIZE_SHIFT, %g5	! multiply by blocksize
	stx 	%g5, [%g1 + DISK_SIZE]	! store disk size
	mov	%g5, %g2

	cmp	%o0, %g2
1:	bgeu,pn	%xcc, herr_inval
	add	%o0, %o2, %g4
	cmp	%g4, %g2
	bgu,pn	%xcc, herr_inval
	ldx	[%g1 + DISK_PA], %g2	! base of disk

	/* bcopy(%g3, %g2 + %o0, %o2) */
	mov	%g3, %g1
	add	%g2, %o0, %g2
	mov	%o2, %g3
	ba	bcopy
	rd	%pc, %g7

	mov	%o2, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_disk_write)

#endif /* CONFIG_DISK */
