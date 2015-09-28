/*
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */


#ifdef T1_FPGA_SNET

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <asi.h>
#include <mmu.h>

#include <guest.h>
#include <offsets.h>
#include <util.h>
#include <vdev_snet.h>
#include <vdev_intr.h>


#define PKT_BUF_ADDR_ALIGNMENT    8


/*
 * Propagate an interrupt received from an snet device to the
 * snet device driver.
 */
	ENTRY_NP(snet_mondo)
	GUEST_STRUCT(%g2)
	set GUEST_SNET, %g3
	add  %g2, %g3, %g3
	ldx  [%g3 + SNET_INO], %g3
	GUEST2VDEVSTATE(%g2, %g1)
	!! %g1 = &guestp->vdev_state
	VINO2MAPREG(%g1, %g3, %g2)
	mov     %g2, %g1
	brz,pt	%g0, vdev_intr_generate
	  rd	%pc, %g7
	retry
	SET_SIZE(snet_mondo)

/*
 * The hypervisor simply provides a mechanism for the device driver
 * to communicate with the snet device. The hypervisor doesn't
 * interpret the data.
 *
 * For performance reasons, ldx and stx are used in hcall_snet_read and
 * hcall_snet_write functions. Therefore the source and target buffer
 * must be double word aligned and also the size of the buffers must
 * be double word aligned.
 * 
 */

/*
 * snet read
 *
 * arg1 target real address (%o0)
 * arg2 size (%o1)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 *
 */
	ENTRY_NP(hcall_snet_read)

        btst    PKT_BUF_ADDR_ALIGNMENT - 1, %o0
        bnz,pn  %xcc, herr_badalign
          nop

	GUEST_STRUCT(%g1)
	add     %o1, 0x7, %g4
	andn    %g4, 0x7, %g4
	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o0, %g4, herr_noraddr, %g3, %g2)
	! %g2	paddr

	set  GUEST_SNET, %g3
	add  %g1, %g3, %g1
	ldx  [%g1 + SNET_PA], %g1

1:
	ldx     [%g1], %g3
	stx     %g3, [%g2]
	subcc   %g4, 8, %g4
	brnz,pt %g4, 1b
	add     %g2, 8, %g2

	HCALL_RET(EOK)
	SET_SIZE(hcall_snet_read)

/*
 * snet write
 *
 * arg1 source real address (%o0)
 * arg2 size (%o1)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 */
	ENTRY_NP(hcall_snet_write)

        btst    PKT_BUF_ADDR_ALIGNMENT - 1, %o0
        bnz,pn  %xcc, herr_badalign
          nop

	GUEST_STRUCT(%g1)
	add     %o1, 0x7, %g4
	andn    %g4, 0x7, %g4
	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o0, %g4, herr_noraddr, %g3, %g2)
	! %g2	paddr

	set  GUEST_SNET, %g3
	add  %g1, %g3, %g1
	ldx  [%g1 + SNET_PA], %g1

1:
	ldx     [%g2], %g3
	stx     %g3, [%g1]
	subcc   %g4, 8, %g4
	brnz,pt %g4, 1b
	add     %g2, 8, %g2

	HCALL_RET(EOK)
	SET_SIZE(hcall_snet_write)

#endif /* ifdef T1_FPGA_SNET */
