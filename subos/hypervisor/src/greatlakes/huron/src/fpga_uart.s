/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: fpga_uart.s
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

#pragma ident	"@(#)fpga_uart.s	1.2	07/06/13 SMI"

#include <sys/htypes.h>
#include <sys/asm_linkage.h>
#include <asi.h>
#include <offsets.h>
#include <util.h>
#include <fpga.h>
#include <ldc.h>
#include <intr.h>
#include <vdev_ops.h>
#include <devices/pc16550.h>

#if defined(CONFIG_FPGA) && defined(CONFIG_PIU) && defined(CONFIG_FPGA_UART)

#define	FPGA_INT(n)	(1 << FPGA_INT_/**/n/**/_BIT)
#define	UART_SYSINO	((PIU_AID << PIU_DEVINO_SHIFT) | 0x13)

/*
 * fpga_uart_intr_getvalid
 *
 * %g1 FPGA Uart Cookie Pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 intr valid state (%o1)
 */
	ENTRY_NP(fpga_uart_intr_getvalid)
	!! %g1 pointer to FPGA_UART_COOKIE
	ldub	[%g1 + FPGA_UART_COOKIE_VALID], %o1
	HCALL_RET(EOK)
	SET_SIZE(fpga_uart_intr_getvalid)

/*
 * fpga_uart_intr_setvalid
 *
 * %g1 FPGA Uart Cookie Pointer
 * arg0 Virtual INO (%o0)
 * arg1 intr valid state (%o1) 1: Valid 0: Invalid
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fpga_uart_intr_setvalid)
	!! %g1 pointer to FPGA_UART_COOKIE
	cmp	%o1, INTR_ENABLED
	bgu,pn	%xcc, herr_inval
	mov	FPGA_INT(UART), %g5
	stb	%o1, [%g1 + FPGA_UART_COOKIE_VALID]	! save state
	ldx	[%g1 + FPGA_UART_COOKIE_ENABLE], %g3
	ldx	[%g1 + FPGA_UART_COOKIE_DISABLE], %g4
	movrz	%o1, %g4, %g6
	movrnz	%o1, %g3, %g6
	stb	%g5, [%g6]
	HCALL_RET(EOK)
	SET_SIZE(fpga_uart_intr_setvalid)

/*
 * fpga_uart_intr_getstate
 *
 * %g1 FPGA Uart Cookie Pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 (%o1) 2: Delivered 1: Received  0: Idle
 */
	ENTRY_NP(fpga_uart_intr_getstate)
	!! %g1 pointer to FPGA_UART_COOKIE
	ldub	[%g1 + FPGA_UART_COOKIE_STATE], %o1
	HCALL_RET(EOK)
	SET_SIZE(fpga_uart_intr_getstate)

/*
 * fpga_uart_intr_setstate
 *
 * %g1 FPGA Uart Cookie Pointer
 * arg0 Virtual INO (%o0)
 * arg1 (%o1) 2: Delivered, 1: Received, 0: Idle
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fpga_uart_intr_setstate)
	!! %g1 pointer to FPGA_UART_COOKIE
	cmp	%o1, INTR_DELIVERED
	bgu,pn	%xcc, herr_inval
	mov	FPGA_INT(UART), %g5
	stb	%o1, [%g1 + FPGA_UART_COOKIE_STATE]	! save state
	ldx	[%g1 + FPGA_UART_COOKIE_ENABLE], %g3
	ldx	[%g1 + FPGA_UART_COOKIE_DISABLE], %g4
	movrz	%o1, %g3, %g6
	movrnz	%o1, %g4, %g6
	stb	%g5, [%g6]
	HCALL_RET(EOK)
	SET_SIZE(fpga_uart_intr_setstate)

/*
 * fpga_uart_intr_gettarget
 *
 * %g1 FPGA Uart Cookie Pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 cpuid (%o1)
 */
	ENTRY_NP(fpga_uart_intr_gettarget)
	!! %g1 pointer to FPGA_UART_COOKIE
	ldub	[%g1 + FPGA_UART_COOKIE_TARGET], %g4
	!! %g4 = Physical CPU number
	PID2VCPUP(%g4, %g3, %g5, %g6)
	!! %g3 = CPU struct
	ldub	[%g3 + CPU_VID], %o1
	HCALL_RET(EOK)
	SET_SIZE(fpga_uart_intr_gettarget)

/*
 * fpga_uart_intr_settarget
 *
 * %g1 FPGA Uart Cookie Pointer
 * arg0 Virtual INO (%o0)
 * arg1 cpuid (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fpga_uart_intr_settarget)
	!! %g1 pointer to FPGA_UART_COOKIE
	GUEST_STRUCT(%g2)
	VCPUID2CPUP(%g2, %o1, %g3, herr_nocpu, %g6)
	!! %g3 = target cpup
	IS_CPU_IN_ERROR(%g3, %g6)
	be,pn	%xcc, herr_cpuerror
	VCPU2STRAND_STRUCT(%g3, %g6)
	ldub	[%g6 + STRAND_ID], %g6
	!! %g6 = Physical Target CPU number
	stb	%g6, [%g1 + FPGA_UART_COOKIE_TARGET]
	HCALL_RET(EOK)
	SET_SIZE(fpga_uart_intr_settarget)


/*
 * fpga_uart_mondo_receive
 *
 * Since the ssi interrupt is shared amoung many sources, a few tests must be made
 * before it is determined that this mondo is to be sent.
 *
 * 1) test the pending bit for the uart, if set then
 * 2) test the state for IDLE, if IDLE then
 * 3) test the interrupt enable bit for the UART, if set then send mondo
 * If any condition above  fails, then return, this ssi int was not meant
 * for a UART interrupt to be sent to the guest.
 *
 * %g1 - FPGA Uart Cookie Pointer
 */
	ENTRY_NP(fpga_uart_mondo_receive)
	!! %g1 pointer to FPGA_UART_COOKIE
	mov	FPGA_INT(UART), %g5
	ldx	[%g1 + FPGA_UART_COOKIE_STATUS], %g3
	ldub	[%g3], %g4
	!! %g4 = Pending FPGA interrupts
	!! %g5 = UART interrupt bit
	btst	%g5, %g4
	bz	%xcc, 1f			! is pending set?
	ldub	[%g1 + FPGA_UART_COOKIE_STATE], %g3
	cmp	%g3, INTR_IDLE			! is state idle?
	bne,pt	%xcc, 1f
	ldx	[%g1 + FPGA_UART_COOKIE_ENABLE], %g3
	ldub	[%g3], %g3
	btst	%g5, %g3			! is int enabled?
	mov	UART_SYSINO, %g2
	bnz	%xcc, send_guest_uart_interrupt
	nop
1:	HVRET

send_guest_uart_interrupt:
	!! Deliver interrupt locally if current cpu is the same as target.
	!! %g1 pointer to FPGA_UART_COOKIE
	ldx	[%g1 + FPGA_UART_COOKIE_DISABLE], %g3
	stb	%g5, [%g3]			! disable

	ldub	[%g1 + FPGA_UART_COOKIE_VALID], %g6
	mov	INTR_RECEIVED, %g3
	movrnz	%g6, INTR_DELIVERED, %g3
	stb	%g3, [%g1 + FPGA_UART_COOKIE_STATE]	! update state
	brz	%g6, 3f
	nop

	mov	%g1, %g4
	ldub	[%g4 + FPGA_UART_COOKIE_TARGET], %g1
	PID2VCPUP(%g1, %g5, %g6, %g3)
	mov	%g5, %g1			! %g1 = vcpup
	mov	%g2, %g3			! %g3 = mondo
	mov	1, %g2				! %g2 = flag, 1 = mondo
	ba,a	send_dev_mondo
	nop

3:	HVRET
	SET_SIZE(fpga_uart_mondo_receive)

/*
 * fpga_uart_intr_redistribute
 *
 * %g1 this strand
 * %g2 target strand
 */
	ENTRY_NP(fpga_uart_intr_redistribute)
	!! 
	mov	DEVOPS_FPGA, %g3
	GUEST_STRUCT(%g4)
	DEVINST2COOKIE(%g4, %g3, %g3, %g5, uart_fail)
	ldub	[%g3 + FPGA_UART_COOKIE_TARGET], %g4
	cmp	%g1, %g4
	be,pt	%xcc, 1f
	nop
	HVRET
1:
	stb	%g2, [%g3 + FPGA_UART_COOKIE_TARGET]
	HVRET
	SET_SIZE(fpga_uart_intr_redistribute)

! When DEBUG is defined badtrap is too far away for
! "DEVINST2COOKIE()", branch here instead
uart_fail:
	nop
	ba,a	badtrap

#endif /* CONFIG_FPGA && CONFIG_PIU && CONFIG_FPGA_UART */
