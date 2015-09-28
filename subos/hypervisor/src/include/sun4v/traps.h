/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: traps.h
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

#ifndef _SUN4V_TRAPS_H
#define	_SUN4V_TRAPS_H

#pragma ident	"@(#)traps.h	1.10	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	MAXPTL			2	/* Maximum privileged trap level */
#define	MAXPGL			2	/* Maximum privileged globals level */
#define	TT_OFFSET_SHIFT		5	/* tt to trap table offset shift */
#define	TRAPTABLE_ENTRY_SIZE	(8 * 4)	/* Eight Instructions */
#define	REAL_TRAPTABLE_SIZE	(8 * TRAPTABLE_ENTRY_SIZE)
#define	TRAPTABLE_SIZE		(1 << 14)

/*
 * sun4v definition of pstate
 */
#define	PSTATE_IE		0x00000002 /* interrupt enable */
#define	PSTATE_PRIV		0x00000004 /* privilege */
#define	PSTATE_AM		0x00000008 /* address mask */
#define	PSTATE_PEF		0x00000010 /* fpu enable */
#define	PSTATE_MM_MASK		0x000000c0 /* memory model */
#define	PSTATE_MM_SHIFT		0x00000006
#define	PSTATE_TLE		0x00000100 /* trap little-endian */
#define	PSTATE_CLE		0x00000200 /* current little-endian */
#define	PSTATE_TCT		0x00001000 /* trap on control transfer */

#define	PSTATE_MM_TSO		0x00
#define	PSTATE_MM_PSO		0x40
#define	PSTATE_MM_RMO		0x80

#define	TSTATE_CWP_SHIFT	0
#define	TSTATE_CWP_MASK		0x1f
#define	TSTATE_PSTATE_SHIFT	8
#define	TSTATE_ASI_SHIFT	24
#define	TSTATE_ASI_MASK		0xff
#define	TSTATE_CCR_SHIFT	32
#define	TSTATE_GL_SHIFT		40
#define	TSTATE_GL_MASK		0x3

#define	TSTATE_PSTATE_PRIV	(PSTATE_PRIV << TSTATE_PSTATE_SHIFT)

#define	TT_GUEST_WATCHDOG	0x2	/* guest watchdog */
#define	TT_IAX			0x8	/* instruction access exception */
#define	TT_IMMU_MISS		0x9	/* instruction access MMU miss */
#define	TT_ILLINST		0x10	/* illegal instruction */
#define	TT_PRIVOP		0x11	/* privileged opcode */
#define	TT_UNIMP_LDD		0x12	/* unimplemented LDD */
#define	TT_UNIMP_STD		0x13	/* unimplemented STD */
#define	TT_FP_DISABLED		0x20	/* fp disabled */
#define	TT_FP_IEEE754		0x21	/* fp exception IEEE 754 */
#define	TT_FP_OTHER		0x22	/* fp exception other */
#define	TT_TAGOVERFLOW		0x23	/* tag overflow */
#define	TT_CLEANWIN		0x24	/* cleanwin (BIG) */
#define	TT_DIV0			0x28	/* division by zero */
#define	TT_DAX			0x30	/* data access exception */
#define	TT_DMMU_MISS		0x31	/* data access MMU miss */
#define	TT_DAP			0x33	/* data access protection */
#define	TT_ALIGN		0x34	/* mem address not aligned */
#define	TT_LDDF_ALIGN		0x35	/* LDDF mem address not aligned */
#define	TT_STDF_ALIGN		0x36	/* STDF mem address not aligned */
#define	TT_PRIVACT		0x37	/* privileged action */
#define	TT_LDQF_ALIGN		0x38	/* LDQF mem address not aligned */
#define	TT_STQF_ALIGN		0x39	/* STQF mem address not aligned */
#define	TT_INTR_LEV1		0x41	/* interrupt level 1 */
#define	TT_INTR_LEV2		0x42	/* interrupt level 2 */
#define	TT_INTR_LEV3		0x43	/* interrupt level 3 */
#define	TT_INTR_LEV4		0x44	/* interrupt level 4 */
#define	TT_INTR_LEV5		0x45	/* interrupt level 5 */
#define	TT_INTR_LEV6		0x46	/* interrupt level 6 */
#define	TT_INTR_LEV7		0x47	/* interrupt level 7 */
#define	TT_INTR_LEV8		0x48	/* interrupt level 8 */
#define	TT_INTR_LEV9		0x49	/* interrupt level 9 */
#define	TT_INTR_LEVa		0x4a	/* interrupt level a */
#define	TT_INTR_LEVb		0x4b	/* interrupt level b */
#define	TT_INTR_LEVc		0x4c	/* interrupt level c */
#define	TT_INTR_LEVd		0x4d	/* interrupt level d */
#define	TT_INTR_LEVe		0x4e	/* interrupt level e */
#define	TT_INTR_LEVf		0x4f	/* interrupt level f */
#define	TT_RA_WATCH		0x61	/* real address watchpoint */
#define	TT_VA_WATCH		0x62	/* virtual address watchpoint */
#define	TT_FAST_IMMU_MISS	0x64	/* fast immu miss (BIG) */
#define	TT_FAST_DMMU_MISS	0x68	/* fast dmmu miss (BIG) */
#define	TT_FAST_DMMU_PROT	0x6c	/* fast dmmu protection (BIG) */
#define	TT_CTI_TAKEN		0x74	/* control transfer instruction */
#define	TT_CPU_MONDO		0x7c	/* cpu mondo */
#define	TT_DEV_MONDO		0x7d	/* dev mondo */
#define	TT_RESUMABLE_ERR	0x7e	/* resumable error */
#define	TT_NONRESUMABLE_ERR	0x7f	/* non-resumable error */
#define	TT_SPILL_0_NORMAL	0x80	/* spill 0 normal (BIG) */
#define	TT_SPILL_1_NORMAL	0x84	/* spill 1 normal (BIG) */
#define	TT_SPILL_2_NORMAL	0x88	/* spill 2 normal (BIG) */
#define	TT_SPILL_3_NORMAL	0x8c	/* spill 3 normal (BIG) */
#define	TT_SPILL_4_NORMAL	0x90	/* spill 4 normal (BIG) */
#define	TT_SPILL_5_NORMAL	0x94	/* spill 5 normal (BIG) */
#define	TT_SPILL_6_NORMAL	0x98	/* spill 6 normal (BIG) */
#define	TT_SPILL_7_NORMAL	0x9c	/* spill 7 normal (BIG) */
#define	TT_SPILL_0_OTHER 	0xa0	/* spill 0 other (BIG) */
#define	TT_SPILL_1_OTHER 	0xa4	/* spill 1 other (BIG) */
#define	TT_SPILL_2_OTHER 	0xa8	/* spill 2 other (BIG) */
#define	TT_SPILL_3_OTHER 	0xac	/* spill 3 other (BIG) */
#define	TT_SPILL_4_OTHER 	0xb0	/* spill 4 other (BIG) */
#define	TT_SPILL_5_OTHER 	0xb4	/* spill 5 other (BIG) */
#define	TT_SPILL_6_OTHER 	0xb8	/* spill 6 other (BIG) */
#define	TT_SPILL_7_OTHER 	0xbc	/* spill 7 other (BIG) */
#define	TT_FILL_0_NORMAL 	0xc0	/* fill 0 normal (BIG) */
#define	TT_FILL_1_NORMAL 	0xc4	/* fill 1 normal (BIG) */
#define	TT_FILL_2_NORMAL 	0xc8	/* fill 2 normal (BIG) */
#define	TT_FILL_3_NORMAL 	0xcc	/* fill 3 normal (BIG) */
#define	TT_FILL_4_NORMAL 	0xd0	/* fill 4 normal (BIG) */
#define	TT_FILL_5_NORMAL 	0xd4	/* fill 5 normal (BIG) */
#define	TT_FILL_6_NORMAL 	0xd8	/* fill 6 normal (BIG) */
#define	TT_FILL_7_NORMAL 	0xdc	/* fill 7 normal (BIG) */
#define	TT_FILL_0_OTHER  	0xe0	/* fill 0 other (BIG) */
#define	TT_FILL_1_OTHER  	0xe4	/* fill 1 other (BIG) */
#define	TT_FILL_2_OTHER  	0xe8	/* fill 2 other (BIG) */
#define	TT_FILL_3_OTHER  	0xec	/* fill 3 other (BIG) */
#define	TT_FILL_4_OTHER  	0xf0	/* fill 4 other (BIG) */
#define	TT_FILL_5_OTHER  	0xf4	/* fill 5 other (BIG) */
#define	TT_FILL_6_OTHER  	0xf8	/* fill 6 other (BIG) */
#define	TT_FILL_7_OTHER  	0xfc	/* fill 7 other (BIG) */
#define	TT_SWTRAP_BASE		0x100	/* trap instruction */

#ifdef __cplusplus
}
#endif

#endif /* _SUN4V_TRAPS_H */
