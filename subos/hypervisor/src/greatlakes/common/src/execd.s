/*
 * Copyright 2017 Princeton University.
 * Use is subject to license terms.
 */

#include <sys/asm_linkage.h>
#include <hypervisor.h>

#include <guest.h>
#include <offsets.h>
#include <util.h>
#include <debug.h>

/* 
* Only do stuff when ED is enabled: TODO ask about this
* ifdef ED_ENABLE
*/


/* Values for accessing and modifying ExecD config registers */
#define CFG_REG_ASI                 0x1a
#define ED0_CFG_OFFSET              0x0
#define ED1_CFG_OFFSET              0x8
#define ED_SEED_VALUE_ENABLE_MASK   0xaaaa8
#define ED_SEED_DISABLE_MASK        0xfffffffffff7ffff

/* Enable mask based on sync method */
#define ED_ENABLE_MASK              0x1

	ENTRY_NP(hcall_cpu_enable_execd)

    /* Set the offset for the ED0 config reg */
    mov ED0_CFG_OFFSET, %l1

    /* Load ED0 configuration register default value */
    ldxa [%l1] CFG_REG_ASI, %g1
    
    /* Enable ExecD with mask set by sync method */
    or %g1, ED_ENABLE_MASK, %g1
    stxa %g1, [%l1] CFG_REG_ASI

	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_enable_execd)



/* Disable mask */
#define ED_DISABLE_MASK              0x0

    ENTRY_NP(hcall_cpu_disable_execd)

    /* Set the offset for the ED0 config reg */
    mov ED0_CFG_OFFSET, %l1

    /* Load ED0 configuration register default value */
    ldxa [%l1] CFG_REG_ASI, %g1
    
    /* Enable ExecD with mask set by sync method */
    or %g1, ED_DISABLE_MASK, %g1
    stxa %g1, [%l1] CFG_REG_ASI

    HCALL_RET(EOK)
    SET_SIZE(hcall_cpu_disable_execd)


/* check whether execd register is enable or not */

    ENTRY_NP(hcall_cpu_check_execd_register)

    /* Set the offset for the ED0 config reg */
    mov ED0_CFG_OFFSET, %l1

    /* Load ED0 configuration register value */
    ldxa [%l1] CFG_REG_ASI, %o1

    HCALL_RET(EOK)
    SET_SIZE(hcall_cpu_check_execd_register)














