/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: util.h
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

#ifndef _UTIL_H
#define	_UTIL_H

#pragma ident	"@(#)util.h	1.22	07/09/11 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <vcpu.h>
#include <abort.h>
#include <strand.h>
#include <platform/util.h>

/*
 * Size generation constants
 */
#define	KB	* 1024
#define	MB	* 1024LL KB
#define	GB	* 1024LL MB

/*
 * Time constants
 */
#define	MHZ		* 1000000
#define	NS_PER_S	1000000000
#define	MS_PER_NS	1000000

/*
 * L2$ line state
 */
#define	L2_LINE_CLEAN		0
#define	L2_LINE_DIRTY		1
#define	L2_LINE_INVALID		2
#define	L2_LINE_NOT_FOUND	3

/*
 * prefetch function to invalidate an L2$ line
 */
#define	INVALIDATE_CACHE_LINE	0x18

/* BEGIN CSTYLED */

/*
 * VCPU2GUEST_STRUCT - get the current guestp from a vcpup
 *
 * Delay Slot: safe in a delay slot
 * Register overlap: vcpu and root may be the same register
 */
#define	VCPU2GUEST_STRUCT(vcpu, guest)		\
	ldx	[vcpu + CPU_GUEST], guest


/* FIXME: do we ever use the following? */
/*
 * VCPU2ROOT_STRUCT - get the rootp from a vcpup
 *
 * Delay Slot: safe in a delay slot if vcpup is valid
 * Register overlap: vcpu and root may be the same register
 */
#define	VCPU2ROOT_STRUCT(vcpu, root)		\
	ldx	[vcpu + CPU_ROOT], root


/*
 * VCPU2STRAND_STRUCT - get the current strandp from a vcpup
 *
 * Delay Slot: safe in a delay slot
 * Register overlap: vcpu and strand may be the same register
 */
#define	VCPU2STRAND_STRUCT(vcpu, strand)	\
	ldx	[vcpu + CPU_STRAND], strand


#define	HSCRATCH_STRAND_STRUCT	HSCRATCH0
#define	HSCRATCH_VCPU_STRUCT	HSCRATCH1
#define	SCRATCHPAD_MEMBAR	/* nothing for niagara */

/*
 * VCPU_STRUCT - get the current vcpup from scratch
 *
 * Delay Slot: not safe in a delay slot
 */
#define	VCPU_STRUCT(vcpu)			\
	mov	HSCRATCH_VCPU_STRUCT, vcpu	;\
	ldxa	[vcpu]ASI_HSCRATCHPAD, vcpu

/*
 * SET_VCPU_STRUCT - set the vcpup into scratch
 */
#define	SET_VCPU_STRUCT(vcpu, scr1)		\
	mov	HSCRATCH_VCPU_STRUCT, scr1	;\
	stxa	vcpu, [scr1]ASI_HSCRATCHPAD	;\
	SCRATCHPAD_MEMBAR

/*
 * STRAND_STRUCT - get the current strandp from scratch
 *
 * Delay Slot: not safe in a delay slot
 */
#define	STRAND_STRUCT(strand)			\
	mov	HSCRATCH_STRAND_STRUCT, strand	;\
	ldxa	[strand]ASI_HSCRATCHPAD, strand

/*
 * SET_STRAND_STRUCT - set the strandp into scratch
 */
#define	SET_STRAND_STRUCT(strand, scr1)		\
	mov	HSCRATCH_STRAND_STRUCT, scr1	;\
	stxa	strand, [scr1]ASI_HSCRATCHPAD	;\
	SCRATCHPAD_MEMBAR

/*
 * STRAND2CONFIG_STRUCT - get the current configp from strandp
 */
#define	STRAND2CONFIG_STRUCT(strand, configp)	\
	ldx	[strand + STRAND_CONFIGP], configp

/*
 * CONFIG_STRUCT - get the current configp from scratch
 *
 * Delay Slot: safe in a delay slot
 */
#define	CONFIG_STRUCT(configp)			\
	STRAND_STRUCT(configp)			;\
	STRAND2CONFIG_STRUCT(configp, configp)

	/* For the moment alias */
#define	ROOT_STRUCT(configp)	CONFIG_STRUCT(configp)

/*
 * LOCK_ADDR - get the lock address from scratch
 *
 * Delay Slot: not safe in a delay slot
 */
#define	LOCK_ADDR(LOCK, addr)			\
	CONFIG_STRUCT(addr)			;\
	inc	LOCK, addr


/*
 * VCPU_GUEST_STRUCT - get both the current vcpup and guestp from scratch
 *
 * Delay Slot: not safe in a delay slot
 * Register overlap: if vcpu and guest are the same then only the guest
 *     is returned, see GUEST_STRUCT
 */
#define	VCPU_GUEST_STRUCT(vcpu, guest)		\
	VCPU_STRUCT(vcpu)			;\
	VCPU2GUEST_STRUCT(vcpu, guest)


/*
 * GUEST_STRUCT - get the current guestp from scratch
 *
 * Delay Slot: safe in a delay slot
 */
#define	GUEST_STRUCT(guest)			\
	VCPU_GUEST_STRUCT(guest, guest)


/*
 * CTRL_DOMAIN - returns the service domain guest structure ptr
 *
 * Delay Slot: Safe in a delay slot
 */
#define	CTRL_DOMAIN(guestp, scr1, scr2)	\
	CONFIG_STRUCT(scr1)					;\
	ldx	[scr1 + CONFIG_HVCTL_LDC], scr2			;\
	mulx    scr2, LDC_ENDPOINT_SIZE, scr2			;\
	ldx	[scr1 + CONFIG_HV_LDCS], guestp			;\
	add	guestp, scr2, guestp				;\
	ldx	[guestp + LDC_TARGET_GUEST], guestp 		

/*
 * PID2CPUP - convert physical cpu number to a pointer to the vcpu
 * cpu structure thats currently running on it.
 * FIXME: This needs removing .. including all uses
 * because it's just rubbish!
 */
#define	PID2VCPUP(pid, cpup, scr1, scr2)		\
	.pushlocals					;\
	mov	%g0, scr2				;\
1:							;\
	cmp	scr2, (NVCPUS - 1)			;\
	bg,a	2f					;\
	  mov	%g0, cpup				;\
	set	VCPU_SIZE, scr1				;\
	mulx	scr2, scr1, cpup			;\
	CONFIG_STRUCT(scr1)				;\
	ldx	[scr1 + CONFIG_VCPUS], scr1		;\
	add	scr1, cpup, cpup			;\
	VCPU2STRAND_STRUCT(cpup, scr1)			;\
	ldub	[scr1 + STRAND_ID], scr1		;\
	cmp	scr1, pid				;\
	bne,a	%icc, 1b				;\
	  inc	scr2					;\
2:							;\
	.poplocals


/* the VCPUID2CPUP macro below assumes the array step is 8 */
#if GUEST_VCPUS_INCR != 8
#error "GUEST_VCPUS_INCR is not 8"
#endif

#define	GUEST_VCPUS_SHIFT	3

/*
 * VCPUID2CPUP - convert a guest virtual cpu number to a pointer
 * to the corresponding virtual cpu struct
 *
 * Register overlap: vcpuid and cpup may be the same register
 * Delay Slot: safe in a delay slot
 */
#define	VCPUID2CPUP(guestp, vcpuid, cpup, fail_label, scr1)	\
	cmp	vcpuid, NVCPUS				;\
	bgeu,pn	%xcc, fail_label			;\
	sllx	vcpuid, GUEST_VCPUS_SHIFT, cpup		;\
	set	GUEST_VCPUS, scr1			;\
	add	cpup, scr1, cpup			;\
	ldx	[guestp + cpup], cpup			;\
	brz,pn	cpup, fail_label			;\
	nop


/*
 * PCPUID2COREID - derive core id from physical cpu id
 *
 * Register overlap: pid and coreid may be the same register
 * Delay slot: safe and complete in a delay slot
 */
#define	PCPUID2COREID(pid, coreid) \
	srlx	pid, CPUID_2_COREID_SHIFT, coreid


/*
 * Standard return-from-hcall with status "errno"
 */
#define	HCALL_RET(errno)			\
	mov	errno, %o0			;\
	done

/*
 * HVCALL - make a subroutine call
 * HVJMP - jmp to subroutine in reg
 * HVRET - return from a subroutine call
 *
 * This hypervisor has a convention of using %g7 as the the
 * return address.
 */
#define	HVCALL(x)				\
	ba,pt	%xcc, x				;\
	rd	%pc, %g7

#define	HVJMP(reg, pc)				\
	jmpl	reg, pc				;\
	nop

#define	HVRET					\
	jmp	%g7 + SZ_INSTR			;\
	nop

/*
 * Strand stack operations
 *
 * These macros are deprecated, but aliased for back compatibility
 *	CPU_PUSH - push a val into the stack
 *	CPU_POP - pop val from the stack
 * These macros temporarily push and pop values that need storing
 *	STRAND_PUSH - push a val into the stack
 *	STRAND_POP - pop val from the stack
 *
 */

#define CPU_PUSH(val, scr1, scr2, scr3)					\
	STRAND_PUSH(val, scr1, scr2)

#define	CPU_POP(val, scr1, scr2, scr3)					\
	STRAND_POP(val, scr1)

	/* Stack is empty if ptr = 0 */

#define STRAND_PUSH(val, scr1, scr2)					\
	STRAND_STRUCT(scr1)						;\
	add	scr1, STRAND_MINI_STACK, scr1				;\
	ldx	[scr1 + MINI_STACK_PTR], scr2	/* get stack ptr */	;\
	cmp	scr2, MINI_STACK_VAL_INCR*MINI_STACK_DEPTH		;\
	bge,a,pn %xcc, hvabort						;\
	  rd	%pc, %g1						;\
	add	scr2, MINI_STACK_VAL_INCR, scr2	/* next element */	;\
	stx	scr2, [scr1 + MINI_STACK_PTR]				;\
	add	scr2, scr1, scr2					;\
		/* store at previous ptr value */			;\
	stx	val, [scr2 + MINI_STACK_VAL - MINI_STACK_VAL_INCR]
	

#define	STRAND_POP(val, scr1)						\
	STRAND_STRUCT(scr1)						;\
	add	scr1, STRAND_MINI_STACK, scr1				;\
	ldx	[scr1 + MINI_STACK_PTR], val				;\
	brlez,a,pn val, hvabort						;\
	  rd	%pc, %g1						;\
	sub	val, MINI_STACK_VAL_INCR, val				;\
	stx	val, [scr1 + MINI_STACK_PTR]				;\
	add	scr1, val, scr1						;\
	ldx	[scr1 + MINI_STACK_VAL], val


/*
 * ATOMIC_OR_64 - atomically logical-or a value in a memory location
 */
#define	ATOMIC_OR_64(addr, value, scr1, scr2)	\
	.pushlocals				;\
	ldx	[addr], scr1			;\
0:	or	scr1, value, scr2		;\
	casx	[addr], scr1, scr2		;\
	cmp	scr1, scr2			;\
	bne,a,pn %xcc, 0b			;\
	mov	 scr2, scr1			;\
	.poplocals

/*
 * ATOMIC_ANDN_64 - atomically logical-andn a value in a memory location
 * Returns oldvalue 
 */
#define	ATOMIC_ANDN_64(addr, value, oldvalue, scr2) \
	.pushlocals				;\
	ldx	[addr], oldvalue		;\
0:	andn	oldvalue, value, scr2		;\
	casx	[addr], oldvalue, scr2		;\
	cmp	oldvalue, scr2			;\
	bne,a,pn %xcc, 0b			;\
	mov	 scr2, oldvalue			;\
	.poplocals

/*
 * ATOMIC_SWAP_64 - swaps the value at addr with newvalue, returns
 * the previous contents of addr as oldvalue
 */
#define	ATOMIC_SWAP_64(addr, newvalue, oldvalue, scr2)	\
	.pushlocals				;\
	ldx	[addr], scr2			;\
0:	mov	newvalue, oldvalue		;\
	casx	[addr], scr2, oldvalue		;\
	cmp	scr2, oldvalue			;\
	bne,a,pn %xcc, 0b			;\
	  mov	 oldvalue, scr2			;\
	.poplocals

/*
 * ATOMIC_ADD_64 - atomically add to a value stored in memory
 */
#define	ATOMIC_ADD_64(addr, value, newvalue, scr2)	\
	.pushlocals				;\
	ldx	[addr], newvalue		;\
0:	add	newvalue, value, scr2		;\
	casx	[addr], newvalue, scr2		;\
	cmp	newvalue, scr2			;\
	bne,a,pn %xcc, 0b			;\
	  mov	 scr2, newvalue			;\
	add	 newvalue, value, newvalue	;\
	.poplocals


/*
 * Locking primitives
 */
#define	MEMBAR_ENTER \
	/* membar #StoreLoad|#StoreStore not necessary on Niagara */
#define	MEMBAR_EXIT \
	/* membar #LoadStore|#StoreStore not necessary on Niagara */

/*
 * SPINLOCK_ENTER - claim lock by setting it to cpu#+1 spinning until it is
 *	free
 */
#define	SPINLOCK_ENTER(lock, scr1, scr2)				\
	.pushlocals							;\
	STRAND_STRUCT(scr1)						;\
	ldub	[scr1 + STRAND_ID], scr2	/* my ID */		;\
	inc	scr2			/* lockID = cpuid + 1 */ 	;\
	mov	0, scr1							;\
1:									;\
	brz,pn	scr1, 2f						;\
	nop								;\
									;\
	be,a	%xcc, hvabort						;\
	  rd	%pc, %g1						;\
2:									;\
	mov	scr2, scr1						;\
	casx	[lock], %g0, scr1	/* if zero, write my lockID */	;\
	brnz,a,pn scr1, 1b						;\
	  cmp	scr2, scr1						;\
	MEMBAR_ENTER							;\
	.poplocals

/*
 * SPINLOCK_EXIT - release lock
 */
#define	SPINLOCK_EXIT(lock)						;\
	MEMBAR_EXIT					       		;\
	stx	%g0, [lock]

#define	IS_CPU_IN_ERROR(cpup, scr1)					\
	ldx	[cpup + CPU_STATUS], scr1				;\
	cmp	scr1, CPU_STATE_ERROR

/*
 * LABEL_ADDRESS(label, reg)
 *
 * Args:
 *      label - assembler label
 *      reg - will hold the address of the label
 *
 * Calculate the (relocated) address of the target label.  Only
 * works if the target label is no more than 4092 bytes away from
 * the current assembly origin.  Also requires that the label be
 * in the same source file, and in the same section as the macro
 * invokation.
 */
#define LABEL_ADDRESS(label, reg)		\
	.pushlocals				;\
0:	rd	%pc, reg			;\
	add	reg, (label) - 0b, reg		;\
	.poplocals


/*
 * RELOC_OFFSET(scr, reg)
 *
 * Args:
 *      scr - scratch register, different from "reg"
 *      reg - will hold the value of the relocation offset
 *
 * Calculates the offset of the current image relative to the
 * address assigned by the linker.  The returned offset value can be
 * subtracted from labels calcuated with "setx" to obtain the actual
 * address after relocation.
 */
#define RELOC_OFFSET(scr, reg)					\
	.pushlocals						;\
	setx	0f, scr, reg		/* reg = linker */	;\
0:	rd	%pc, scr		/* scr = actual */	;\
	sub	reg, scr, reg		/* reg = l - a */	;\
	.poplocals

#define	DELAY_SECS(scr1, scr2, SECS) 				\
	CPU_STRUCT(scr1)					;\
	CPU2ROOT_STRUCT(scr1, scr2)				;\
	ldx	[scr2 + CONFIG_STICKFREQUENCY], scr2		;\
	mulx	scr2, SECS, scr2				;\
	rd	STICK, scr1					;\
	add	scr1, scr2, scr1				;\
0:								;\
	rd	STICK, scr2					;\
	cmp	scr2, scr1					;\
	blu	%xcc, 0b					;\
	nop

/*
 * SMALL_COPY_MACRO - byte-wise copy a small region of memory.
 *
 * Args:
 *      src - starting address
 *      len - length of region to copy
 *	dest - destination address
 *	scr - scratch
 *
 * All arguments are clobbered.
 */
#define	SMALL_COPY_MACRO(src, len, dest, scr) \
	.pushlocals		;\
1:	ldub	[src], scr	;\
	inc	src		;\
	deccc	len		;\
	stb	scr, [dest]	;\
	bnz,pt	%xcc, 1b	;\
	inc	dest		;\
	.poplocals

/*
 * SMALL_ZERO_MACRO - byte-wise zero a small region of memory.
 *
 * Args:
 *      addr - starting address
 *      len - length of region to copy
 *
 * All arguments are clobbered.
 */
#define	SMALL_ZERO_MACRO(addr, len) \
	.pushlocals		;\
	brz,pn	len, 2f		;\
	nop			;\
1:	stb	%g0, [addr]	;\
	deccc	len		;\
	bnz,pt	%xcc, 1b	;\
	inc	addr		;\
2:				;\
	.poplocals

/*
 * Cstyle macro for minimum
 */
#define	MIN(x, y) 			\
        ((x) < (y) ? (x) : (y))		\

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _UTIL_H */
