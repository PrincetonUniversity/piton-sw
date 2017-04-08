/*
 * Copyright 2016 Princeton University.
 * Use is subject to license terms.
 */

#include <sys/asm_linkage.h>
#include <hypervisor.h>

#include <guest.h>
#include <offsets.h>
#include <util.h>
#include <debug.h>
#include <mitts.h>

#define	MITTS_BINS_MASK	0xFFFFFFFFFFFFFFF0
#define	MITTS_FN_EN_BIT	0x1
#define	MITTS_FS_EN_BIT	0x3
#define	MITTS_PR_LD_SHF	0x2

/*
 * Writes the values in r0 and r1 to MITTS configuration
 * registers r0 and r1, respectively.
 */

/*
 * mmu set mitts regs
 *
 * arg1 mitts r0 value (%o0)
 * arg2 mitts r1 value (%o1)
 * --
 * ret0 status (%o0)
 *
 */
	ENTRY_NP(hcall_mmu_set_mitts_regs)

	/* Clear R1 Entirely to turn off MITTS */
        setx	MITTS_REG1_ADDR, %g6, %g1
        stx	%g0, [%g1]

        /* Write R2 */
        setx	MITTS_REG2_ADDR, %g6, %g2
        stx	%o1, [%g2]

        /* Write upper bits of R1 */
        setx	MITTS_BINS_MASK, %g6, %g5
        and	%o0, %g5, %g2
        stx	%g2, [%g1]

        /* Mask in func_en */
	or	%g5, MITTS_FN_EN_BIT, %g5
        and	%o0, %g5, %g2
        stx	%g2, [%g1]

        /* proc_ld->1 */
        add	%g0, 1, %g3
        sllx	%g3, MITTS_PR_LD_SHF, %g3
        or	%g2, %g3, %g4
        stx	%g4, [%g1]

        /* proc_ld->0 */
        stx	%g2, [%g1]

        /* Mask in stall_en */
	or	%g5, MITTS_FS_EN_BIT, %g5
        and	%o0, %g5, %g2
        stx	%g2, [%g1]

	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_set_mitts_regs)


/*
 * mmu start mitts
 * --
 * ret0 status (%o0)
 *
 */
	ENTRY_NP(hcall_mmu_start_mitts)

	/* Load in R1 */
	setx	MITTS_REG1_ADDR, %g6, %g1
	ldx	[%g1], %g2

	/* Mask in func_en */
	or	%g2, MITTS_FS_EN_BIT, %g2

	/* Write R1 */
	stx	%g2, [%g1]

	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_start_mitts)
