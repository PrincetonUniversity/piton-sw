/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: l2subr.s
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

	.ident	"@(#)l2subr.s	1.11	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include "offsets.h"
#include "cpu_errs.h"
#include "util.h"


/*
 * L2_FLUSH_BASEADDR - get a 4MB-aligned DRAM address for l2$ flushing
 * The assumption is that %htba contains a valid dram address valid
 * for the current machine configuration.  Round it down to a 4MB
 * boundary to use as a base address for l2$ flushing.
 */
#define	L2_FLUSH_BASEADDR(addr, scr)			\
	rdhpr	%htba, addr				;\
	set	(4 MB) - 1, scr				;\
	andn	addr, scr, addr


	/*
	 * get_l2_vdbits_for_pa()()
	 * Read VD (Valid Dirty) bits of l2$ set for a given PA
	 * Arguments:
	 *	%g1 -> input - physical address (preserved)
	 *	%g2 -> output - VD bit array for 12 ways
	 *		---------------------------------------
	 *		|VPARITY| DPARITY||V11|..|V0|D11|..|D0|
	 *		---------------------------------------
	 *	Bits->	   25       24     23     12  11    0
	 *
	 *	%g3 -> scratch
	 *	%g4 - preserved
	 * 	%g5, %g6 - preserved
	 *	%g7 -> input - return address
	 */
	ENTRY_NP(get_l2_vdbits_for_pa)
	set	0xa6004000, %g2
	sllx	%g2, 8, %g2		! %g2 = L2_SELECT_A6 | L2_VDSEL
	and	%g1, 0xC0, %g3		! %g3 = paddr & L2_BANK_MASK
	or	%g2, %g3, %g2		! %g2 |= %g3
	set	0x3FF00, %g3		! %g3 = L2_SET_MASK
	and	%g1, %g3, %g3		! %g3 &= paddr
	or	%g2, %g3, %g2		! %g2 |= %g3
	jmp	%g7 + 4			! return
	ldx	[%g2], %g2 		! %g2 -> output
	SET_SIZE(get_l2_vdbits_for_pa)


	/*
	 * get_l2_vdbits_for_set()
	 * Read VD (Valid Dirty) bits of l2$ set specified by index and bank
	 * Arguments:
	 *	%g1 -> input - set index (preserved)
	 *	%g2 -> input - L2 bank number (preserved)
	 *	%g3 -> output - VD bit array for 12 ways
	 *		---------------------------------------
	 *		|VPARITY| DPARITY |V11 .. V0|D11 .. D0|
	 *		---------------------------------------
	 *	Bits->	   25       24     23     12  11    0
	 *
	 *	%g4 -> scratch
	 * 	%g5, %g6 - preserved
	 *	%g7 -> input - return address
	 */
	ENTRY_NP(get_l2_vdbits_for_set)
	set	0xa6004000, %g3
	sllx	%g3, 8, %g3		! %g3 = L2_SELECT_A6 | L2_VDSEL
	sllx	%g1, L2_SET_SHIFT, %g4	! %g4 = set << L2_SET_SHIFT
	or	%g3, %g4, %g3		! %g3 |= %g4
	sllx	%g2, L2_BANK_SHIFT, %g4	! %g4 = bank << L2_BANK_SHIFT
	or	%g3, %g4, %g3		! %g3 |= %g4
	jmp	%g7 + 4			! return
	ldx	[%g3], %g3 		! %g3 -> output
	SET_SIZE(get_l2_vdbits_for_set)

	/*
	 * get_l2_uabits_for_pa()()
	 * Read UA (Used Allocated) bits of l2$ set for a given PA
	 * Arguments:
	 *	%g1 -> input - physical address (preserved)
	 *	%g2 -> output - UA bit array for 12 ways
	 *		-------------------------------
	 *		| DPARITY |V11 .. V0|D11 .. D0|
	 *		-------------------------------
	 *	Bits->	    24     23     12  11    0
	 *
	 *	%g3 -> scratch
	 *	%g4 - preserved
	 * 	%g5, %g6 - preserved
	 *	%g7 -> input - return address
	 */
	ENTRY_NP(get_l2_uabits_for_pa)
	set	0xa6000000, %g2
	sllx	%g2, 8, %g2		! %g2 = L2_SELECT_A6
	and	%g1, 0xC0, %g3		! %g3 = paddr & L2_BANK_MASK
	or	%g2, %g3, %g2		! %g2 |= %g3
	set	0x3FF00, %g3		! %g3 = L2_SET_MASK
	and	%g1, %g3, %g3		! %g3 &= paddr
	or	%g2, %g3, %g2		! %g2 |= %g3
	jmp	%g7 + 4			! return
	ldx	[%g2], %g2 		! %g2 -> output
	SET_SIZE(get_l2_uabits_for_pa)

	/*
	 * get_l2_tag_for_line(int way, int set, int bank)
	 * Read L2$ tag for a given way, set, and bank.
	 * Arguments:
	 *	%g1 -> input - cache way
	 *	%g2 -> input - set index
	 *	%g3 -> input - bank number
	 *	%g4 -> output - L2$ tag
	 *		--------------------------
	 *		| TAG => PA<39:18> | ECC |
	 *		--------------------------
	 *	 	 27...............6 5...0
	 * 	%g5, %g6 - preserved
	 *	%g7 -> return address
	 */
	ENTRY_NP(get_l2_tag_for_line)
	set	0xa4000000, %g4		! %g4 = L2_SELECT_A4 >> 8
	or	%g4, %g2, %g4		! %g4 += set index
	sllx	%g4, L2_SET_SHIFT, %g4	! %g4 << L2_SET_SHIFT (8)
	sllx	%g1, L2_WAY_SHIFT, %g1	! %g1 = %g1 << L2_WAY_SHIFT
	or	%g4, %g1, %g4		! %g4 |= %g1
	srlx	%g1, L2_WAY_SHIFT, %g1	! %g1 = %g1 >> L2_WAY_SHIFT
	sllx	%g3, L2_BANK_SHIFT, %g3	! %g3 = %g3 << L2_BANK_SHIFT
	or	%g4, %g3, %g4		! %g4 |= %g3
	srlx	%g3, L2_BANK_SHIFT, %g3	! %g3 = %g3 >> L2_BANK_SHIFT
	jmp	%g7 + 4			! return
	ldx	[%g4], %g4		! %g4 -> output
	SET_SIZE(get_l2_tag_for_line)

	/*
	 * get_l2_tag_by_way(uint64_t pa, int way)
	 * Read L2$ tag for a given way and physical address
	 * Arguments:
	 *	%g1 -> input - physical address
	 *	%g2 -> input - way
	 *	%g3 -> output - L2$ tag
	 *		--------------------------
	 *		| TAG => PA<39:18> | ECC |
	 *		--------------------------
	 *	 	 27...............6 5...0
	 *	%g4 -> scratch
	 * 	%g5, %g6 - preserved
	 *	%g7 -> return address
	 */
	ENTRY_NP(get_l2_tag_by_way)
	set	0x3FFC0, %g4 		! %g4 = L2 SET|BANK MASK  <17:6>
	and	%g4, %g1, %g4		! %g4 &= %g1 (pa)
	sllx	%g2, L2_WAY_SHIFT, %g3	! %g3 = %g2 << L2_WAY_SHIFT
	or	%g4, %g3, %g4		! %g4 |= %g3
	set	0xA4, %g3
	sllx	%g3, 32, %g3		! %g3 = L2_SELECT_A4
	or	%g3, %g4, %g3		! %g3 |= %g4
	jmp	%g7 + 4			! return
	ldx	[%g3], %g3		! %g3 -> output
	SET_SIZE(get_l2_tag_by_way)

	/*
	 * set_l2_bank_dmmode(int bank)
	 * Set the L2 bank in direct-mapped displacement mode
	 * Arguments:
	 * 	%g1 - input ->  L2 bank number (preserved)
	 * 	%g2 - scratch 
	 * 	%g3 - scratch
	 * 	%g4, %g5, %g6 - preserved
	 * 	%g7 - input -> return address
	 */
	ENTRY_NP(set_l2_bank_dmmode)
	setx	L2_CONTROL_REG, %g3, %g2
	sllx	%g1, L2_BANK_SHIFT, %g3
	or	%g2, %g3, %g2		! or in L2 bank
	ldx	[%g2], %g3		! read L2_CONTROL[bank]
	or	%g3, L2_DMMODE, %g3	! %g3 |= L2_DMMODE
	jmp	%g7 + 4			! return
	stx	%g3, [%g2]		! L2_CONTROL[bank] = %g3
	SET_SIZE(set_l2_bank_dmmode)


	/*
	 * reset_l2_bank_dmmode(int bank)
	 * Reset the L2 bank to normal mode
	 * Arguments: 
	 * 	%g1 - input ->  L2 bank number (preserved)
	 * 	%g2 - scratch 
	 * 	%g3 - scratch
	 * 	%g4, %g5, %g6 - preserved
	 * 	%g7 - input -> return address
	 */
	ENTRY_NP(reset_l2_bank_dmmode)
	setx	L2_CONTROL_REG, %g3, %g2
	sllx	%g1, L2_BANK_SHIFT, %g3
	or	%g2, %g3, %g2		! or in L2 bank
	ldx	[%g2], %g3		! read L2_CONTROL[bank]
	bclr	L2_DMMODE, %g3		! %g3 &= ~L2_DMMODE
	jmp	%g7 + 4			! return
	stx	%g3, [%g2]		! L2_CONTROL[bank] = %g3
	SET_SIZE(reset_l2_bank_dmmode)


	/*
	 * set_all_banks_dmmode - set all l2 banks to direct-mapped mode
	 *
	 * NON-LEAF
	 * %g7 - return address
	 * clobbers %g6 along with the lowered-numbered registers
	 * clobbered by set_l2_bank_dmmode
	 */
	ENTRY_NP(set_all_banks_dmmode)
	mov	%g7, %g6		! save return

	mov	0, %g1			! bank 0
	HVCALL(set_l2_bank_dmmode)

	mov	1, %g1			! bank 1
	HVCALL(set_l2_bank_dmmode)

	mov	2, %g1			! bank 2
	HVCALL(set_l2_bank_dmmode)

	mov	3, %g1			! bank 3
	HVCALL(set_l2_bank_dmmode)

	mov	%g6, %g7		! restore return
	HVRET
	SET_SIZE(set_all_banks_dmmode)

	/*
	 * reset_all_banks_dmmode - set all l2 banks to normal mode
	 *
	 * NON-LEAF
	 * %g7 - return address
	 * clobbers %g6 along with the lowered-numbered registers
	 * clobbered by reset_set_l2_bank_dmmode
	 */
	ENTRY_NP(reset_all_banks_dmmode)
	mov	%g7, %g6		! save return

	mov	0, %g1
	HVCALL(reset_l2_bank_dmmode)

	mov	1, %g1			! bank 1
	HVCALL(reset_l2_bank_dmmode)

	mov	2, %g1			! bank 2
	HVCALL(reset_l2_bank_dmmode)

	mov	3, %g1			! bank 3
	HVCALL(reset_l2_bank_dmmode)

	mov	%g6, %g7		! restore return
	HVRET
	SET_SIZE(reset_all_banks_dmmode)

	/*
	 * l2_flush_cache(void)
	 * Flush the entire l2 cache
	 * clobbers %g1-%g6
	 * %g7 - return address
	 */
	ENTRY_NP(l2_flush_cache)
	mov	%g7, %g5		! set_all_banks_dmmode clobbers %g6

	HVCALL(set_all_banks_dmmode)

	/*
	 * read in from 0 to 3MB * 2. Experiments have shown that reading
	 * in 3 times the size of L2$ from 3 different 4MB-aligned addresses
	 * flushes the cache reliably.
	 */
	L2_FLUSH_BASEADDR(%g2, %g4)
	set	0x900000, %g1		! end
	add	%g2, %g1, %g1

1:
	ldx	[%g2], %g0	
	inc	L2_LINE_SIZE, %g2	! next cache line
	cmp	%g2, %g1
	blu,pt	%xcc, 1b		! not done, go to 1
	nop

	HVCALL(reset_all_banks_dmmode)

	mov	%g5, %g7
	HVRET
	SET_SIZE(l2_flush_cache)


	/*
	 * l2_flush_line(uint64_t pa)	[Non-leaf function]
	 * Flush the L2$ line corresponding to the physical address, pa
	 * Arguments:
	 *	%g1 - input - physical address
	 *	%g2-%g6 - scratch
	 *	%g7 - input - return address
	 */
	ENTRY_NP(l2_flush_line)
	mov	%g1, %g6	! save phys addr
	mov	%g7, %g5	! save return address
	and	%g1, 0xC0, %g1	! %g1 &= L2_BANK_MASK
	srlx	%g1, L2_BANK_SHIFT, %g1	! %g1 = L2 bank
	ba	set_l2_bank_dmmode	! set L2[bank] = DMMODE
	rd	%pc, %g7

	! do displacement flush
	set	0x3FFC0, %g1 		! %g1 = L2 SET|BANK MASK  <17:6>
	and	%g1, %g6, %g1		! %g1 = pa & L2_SET|BANK MASK

	L2_FLUSH_BASEADDR(%g3, %g4)

	add	%g3, %g1, %g3		! %g3 = flush addr for set, bank
	set	0x40000, %g2		! way increment
	set	0x2C0000, %g4
	mov	0, %g1			! current way
	! loop 12-way
1:
	ldx	[%g3 + %g1], %g0	! displacement flush read
	add	%g1, %g2, %g1		! way += 0x40000 (next way)
	cmp	%g1, %g4		! done?
	bleu	%xcc, 1b
	nop

	! reset dmmode bit
	and	%g6, 0xC0, %g1		! %g1 &= L2_BANK_MASK
	srlx	%g1, L2_BANK_SHIFT, %g1	! %g1 = L2 bank
	ba	reset_l2_bank_dmmode
	rd	%pc, %g7

	! return
	mov	%g6, %g1		! restore input args
	mov	%g5, %g7		! restore input args
	HVRET
	SET_SIZE(l2_flush_line)

	/*
	 * dump_l2_set_tag_data_ecc(uint64_t pa, void *dump_area) [Non-leaf]
	 * Dump the L2$ tag and data and ECC for the set corresponding to the
	 * given physical address, pa.
	 *
	 * The dump format is:
	 *	0x0  [VPARITY | DPARITY | VALID bits | DIRTY bits]
	 *	0x8  [APARITY | USED bits | ALLOC bits]
	 *	0x10 [way 0 tag + ECC]
	 *	0x18 [way 0 32-bit word 0 + ECC]
	 *	0x20 [way 0 32-bit word 1 + ECC]
	 *	0x28 [way 0 32-bit word 2 + ECC]
	 *	...
	 *	0x90 [way 0 32-bit word 15 + ECC]
	 *	0x98 [way 1 tag + ECC]
	 *	0xa0 way 1 data
	 *	...
	 *
	 * This function does not change L2$ enabled/disabled status.
	 *
	 * Arguments:
	 *	%g1 - input - physical address
	 *	%g2 - input - pointer to dump area
	 *	%g3-%g6 - scratch
	 *	%g7 - input - return address
	 */
	ENTRY_NP(dump_l2_set_tag_data_ecc)
	mov	%g2, %g5
	mov	%g7, %g6
	ba	get_l2_vdbits_for_pa
	rd	%pc, %g7

	stx	%g2, [%g5]		! store VD bits and parity
	add	%g5, 8, %g5

	ba	get_l2_uabits_for_pa
	rd	%pc, %g7

	stx	%g2, [%g5]		! save UA bits and parity
	add	%g5, 8, %g5

	mov	%g0, %g2		! set way = 0
	ba	get_l2_tag_by_way
	rd	%pc, %g7

	stx	%g3, [%g5]		! save tag_ECC[0]
	add	%g5, 8, %g5

	mov	%g6, %g7		! restore original return

	mov	%g0, %g2		! way number
1:
	set	0x3FFC0, %g4 		! %g4 = L2 SET|BANK MASK  <17:6>
	and	%g4, %g1, %g4		! %g4 &= %g1 (pa)
	or	%g4, %g2, %g4		! %g4 |= (way_num << L2_WAY_SHIFT)
	! way 0, word 0
	set	0xA1, %g3
	sllx	%g3, 32, %g3		! %g3 = L2_SELECT_A1 | EVEN
	or	%g4, %g3, %g4		! %g4 |= L2_SELECT_A1
	ldx	[%g4], %g6		! read even 32-bit
	stx	%g6, [%g5]		! store even 32-bit data
	add	%g5, 8, %g5		! increment pointer
	set	(1 << 22), %g3		! ODDEVEN = 1
	or	%g4, %g3, %g4		! select ODD
	ldx	[%g4], %g6		! read odd 32-bit
	stx	%g6, [%g5]		! store odd 32-bit data
	add	%g5, 8, %g5		! increment pointer
	! way 0, word 1
	add	%g4, 8, %g4		! next word
	andn	%g4, %g3, %g4		! EVEN
	ldx	[%g4], %g6		! read even 32-bit
	stx	%g6, [%g5]		! store even 32-bit data
	add	%g5, 8, %g5		! increment pointer
	set	(1 << 22), %g3		! ODDEVEN = 1
	or	%g4, %g3, %g4		! select ODD
	ldx	[%g4], %g6		! read odd 32-bit
	stx	%g6, [%g5]		! store odd 32-bit data
	add	%g5, 8, %g5		! increment pointer
	! way 0, word 2
	add	%g4, 8, %g4		! next word
	andn	%g4, %g3, %g4		! EVEN
	ldx	[%g4], %g6		! read even 32-bit
	stx	%g6, [%g5]		! store even 32-bit data
	add	%g5, 8, %g5		! increment pointer
	or	%g4, %g3, %g4		! select ODD
	ldx	[%g4], %g6		! read odd 32-bit
	stx	%g6, [%g5]		! store odd 32-bit data
	add	%g5, 8, %g5		! increment pointer
	! way 0, word 3
	add	%g4, 8, %g4		! next word
	andn	%g4, %g3, %g4		! EVEN
	ldx	[%g4], %g6		! read even 32-bit
	stx	%g6, [%g5]		! store even 32-bit data
	add	%g5, 8, %g5		! increment pointer
	or	%g4, %g3, %g4		! select ODD
	ldx	[%g4], %g6		! read odd 32-bit
	stx	%g6, [%g5]		! store odd 32-bit data
	add	%g5, 8, %g5		! increment pointer
	! way 0, word 4
	add	%g4, 8, %g4		! next word
	andn	%g4, %g3, %g4		! EVEN
	ldx	[%g4], %g6		! read even 32-bit
	stx	%g6, [%g5]		! store even 32-bit data
	add	%g5, 8, %g5		! increment pointer
	or	%g4, %g3, %g4		! select ODD
	ldx	[%g4], %g6		! read odd 32-bit
	stx	%g6, [%g5]		! store odd 32-bit data
	add	%g5, 8, %g5		! increment pointer
	! way 0, word 5
	add	%g4, 8, %g4		! next word
	andn	%g4, %g3, %g4		! EVEN
	ldx	[%g4], %g6		! read even 32-bit
	stx	%g6, [%g5]		! store even 32-bit data
	add	%g5, 8, %g5		! increment pointer
	or	%g4, %g3, %g4		! select ODD
	ldx	[%g4], %g6		! read odd 32-bit
	stx	%g6, [%g5]		! store odd 32-bit data
	add	%g5, 8, %g5		! increment pointer
	! way 0, word 6
	add	%g4, 8, %g4		! next word
	andn	%g4, %g3, %g4		! EVEN
	ldx	[%g4], %g6		! read even 32-bit
	stx	%g6, [%g5]		! store even 32-bit data
	add	%g5, 8, %g5		! increment pointer
	or	%g4, %g3, %g4		! select ODD
	ldx	[%g4], %g6		! read odd 32-bit
	stx	%g6, [%g5]		! store odd 32-bit data
	add	%g5, 8, %g5		! increment pointer
	! way 0, word 7
	add	%g4, 8, %g4		! next word
	andn	%g4, %g3, %g4		! EVEN
	ldx	[%g4], %g6		! read even 32-bit
	stx	%g6, [%g5]		! store even 32-bit data
	add	%g5, 8, %g5		! increment pointer
	or	%g4, %g3, %g4		! select ODD
	ldx	[%g4], %g6		! read odd 32-bit
	stx	%g6, [%g5]		! store odd 32-bit data
	add	%g5, 8, %g5		! increment pointer
	! next way
	srlx	%g2, L2_WAY_SHIFT, %g2	! current way
	add	%g2, 1, %g2		! next way
	cmp	%g2, L2_NUM_WAYS
	bz	2f			! read tag and loop back if not done
	nop

	! read tag
	mov	%g7, %g6		! save original return
	ba	get_l2_tag_by_way
	rd	%pc, %g7
	mov	%g6, %g7		! restore original return
	stx	%g3, [%g5]		! save tag_ECC[next]
	add	%g5, 8, %g5		! increment
	ba	1b
	sllx	%g2, L2_WAY_SHIFT, %g2	! shift to way field

2:
	! set %g2 back to original value based on %g5
	sub	%g5, 0x618, %g2		! restore %g2
	HVRET
	SET_SIZE(dump_l2_set_tag_data_ecc)

	/*
	 * check_l2_state(uint64_t pa)
	 * Checks L2$ line state for the given physical address
	 * and returns 0 for clean, 1 for dirty, 2 for invalid, 3 = not found
	 * Arguments:
	 *	%g1 - input - physical address
	 *	%g4 - output - clean, dirty or invalid state
	 *	%g7 - input - return address
	 */
	ENTRY_NP(check_l2_state)
	mov	%g7, %g6

	! get PA<39:18> from pa
	setx	L2_PA_TAG_MASK, %g2, %g5
	and	%g1, %g5, %g5		! %g5 has PA<39:18>
	srlx	%g5, L2_PA_TAG_SHIFT, %g5

	! read L2 tag
	set	0, %g2
2:
	ba	get_l2_tag_by_way	! returns tag in %g3
	rd	%pc, %g7
	setx	L2_TAG_MASK, %g7, %g4
	and	%g3, %g4, %g3
	srlx	%g3, L2_TAG_SHIFT, %g3	! %g3 has L2 TAG<27:6>
	cmp	%g3, %g5		! %g5 has the PA tag
	bz	1f
	add	%g2, 1, %g2
	cmp	%g2, 12			! 12th way?
	bnz	2b			! no, do next way
	mov	%g6, %g7
	! done, return not found
	jmp	%g7 + 4
	set	L2_LINE_NOT_FOUND, %g4	! return not found

	! tag match found
1:
	mov	%g2, %g5		! %g5 = %g2
	sub	%g5, 1, %g5		! %g5 has the way number
	ba	get_l2_vdbits_for_pa	! returns vdbits in %g2
	rd	%pc, %g7
	add	%g5, 12, %g5
	set	1, %g3
	sllx	%g3, %g5, %g3		! set valid[way]
	btst	%g3, %g2		! is valid?
	bz	0f
	mov	%g6, %g7

	! check dirty or clean
	srlx	%g3, 12, %g3		! set dirty[way]
	btst	%g3, %g2		! is dirty?
	bnz	2f			! yes, return dirty
	mov	%g6, %g7
	! return clean
	jmp	%g7 + 4
	set	L2_LINE_CLEAN, %g4			! return clean

	! return dirty
2:
	jmp	%g7 + 4
	set	L2_LINE_DIRTY, %g4			! return dirty

	! return invalid
0:
	jmp	%g7 + 4
	set	L2_LINE_INVALID, %g4			! return invalid
	SET_SIZE(check_l2_state)
