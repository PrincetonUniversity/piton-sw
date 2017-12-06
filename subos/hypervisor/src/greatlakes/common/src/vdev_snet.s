/*
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */



#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <asi.h>
#include <mmu.h>

#include <guest.h>
#include <offsets.h>
#include <util.h>

#ifdef PITON_NET

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
 * arg1 source physical address (%o0)
 * --
 * ret0 status (%o0)
 * ret1 source data word (%o1)
 *
 */
	ENTRY_NP(hcall_snet_read)

	lduw [%o0], %o1

	HCALL_RET(EOK)
	SET_SIZE(hcall_snet_read)

/*
 * snet write
 *
 * arg1 data word (%o0)
 * arg2 destination physical address (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_snet_write)

	stw	%o0, [%o1]

	HCALL_RET(EOK)
	SET_SIZE(hcall_snet_write)

#endif /* ifdef T1_FPGA_SNET */

/*
 * byte read
 *
 * arg1 source physical address (%o0)
 * --
 * ret0 status (%o0)
 * ret1 source data word (%o1)
 *
 */
	ENTRY_NP(hcall_byte_read)

	ldub [%o0], %o1

	HCALL_RET(EOK)
	SET_SIZE(hcall_byte_read)

/*
 * byte write
 *
 * arg1 data word (%o0)
 * arg2 destination physical address (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_byte_write)

	stb	%o0, [%o1]

	HCALL_RET(EOK)
	SET_SIZE(hcall_byte_write)
