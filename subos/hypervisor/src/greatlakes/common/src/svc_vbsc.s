/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: svc_vbsc.s
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

	.ident	"@(#)svc_vbsc.s	1.28	07/05/29 SMI"

	.file	"svc_vbsc.s"

#if defined(CONFIG_SVC) && defined(CONFIG_VBSC_SVC)

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <asi.h>
#include <mmu.h>
#include <fpga.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/errs_defs.h>

#include <config.h>
#include <guest.h>
#include <strand.h>
#include <offsets.h>
#include <svc.h>
#include <svc_vbsc.h>
#include <errs_common.h>
#include <util.h>
#include <abort.h>
#include <debug.h>

/*
 * vbsc_send_polled - send a command to vbsc using polled I/O
 *
 * If VBSC does not accept the packet then 
 *
 * %g1 - cmd[0]
 * %g2 - cmd[1]
 * %g3 - cmd[2]
 * %g7 - return address
 */
	ENTRY_NP(vbsc_send_polled)
.vbsc_send_polled_resend:
	setx	FPGA_Q3OUT_BASE, %g4, %g5
	setx	FPGA_BASE + FPGA_SRAM_BASE, %g4, %g6

	lduh	[%g5 + FPGA_Q_BASE], %g4
	add	%g4, %g6, %g6
	!! %g6 = sram buffer words

	stx	%g3, [%g6 + (2 * 8)]
	stx	%g2, [%g6 + (1 * 8)]
	stx	%g1, [%g6 + (0 * 8)]
	mov	1, %g4
	stb	%g4, [%g5 + FPGA_Q_SEND]

	/*
	 * Wait for a non-zero status.  If we get an ACK then we're done.
	 * Otherwise re-send the packet.  Failure is not an option, even
	 * to hv_abort we need to send a message to vbsc.  So keep trying.
	 */
.vbsc_send_polled_wait_for_ack:
	ldub	[%g5 + FPGA_Q_STATUS], %g4
	andcc	%g4, (QINTR_ACK | QINTR_NACK | QINTR_BUSY | QINTR_ABORT), %g4
	bz,pn	%xcc, .vbsc_send_polled_wait_for_ack
	nop
	btst	QINTR_ACK, %g4
	bz,pt	%xcc, .vbsc_send_polled_resend
	nop

	stb	%g4, [%g5 + FPGA_Q_STATUS] ! clear status bits
	HVRET
	SET_SIZE(vbsc_send_polled)


/*
 * vbsc_hv_start - notify VBSC that the hypervisor has started
 *
 * %g7 return address
 *
 * Called from setup environment
 */
	ENTRY_NP(vbsc_hv_start)
	mov	%g7, %o3

	setx	VBSC_HV_START, %g2, %g1
	mov	0, %g2
	mov	0, %g3
	HVCALL(vbsc_send_polled)

	mov	%o3, %g7
	HVRET
	SET_SIZE(vbsc_hv_start)


/*
 * vbsc_hv_abort - notify VBSC that hv has aborted
 *
 * %g1 contains reason for the abort
 * %g7 return address
 */
	ENTRY_NP(vbsc_hv_abort)
	mov	%g1, %g2
	setx	VBSC_HV_ABORT, %g3, %g1
	mov	0, %g3
	HVCALL(vbsc_send_polled)

	/* spin until the vbsc powers us down */
	ba	.
	nop
	SET_SIZE(vbsc_hv_abort)


/*
 * vbsc_hv_plxreset - notify VBSC that the hypervisor has requested
 * a special reset due to PLX link training problems.  VBSC knows to
 * do this quietly and prevent it from looping forever.
 *
 * %g1 plx link failure bitmask
 * %g7 return address
 *
 * Called from setup environment
 */
	ENTRY_NP(vbsc_hv_plxreset)
	mov	%g7, %o3

	mov	%g1, %g2
	setx	VBSC_HV_PLXRESET, %g3, %g1
	mov	0, %g3
	HVCALL(vbsc_send_polled)

	mov	%o3, %g7
	HVRET
	SET_SIZE(vbsc_hv_plxreset)


/*
 * vbsc_guest_start - notify VBSC that a guest has started
 *
 * %g7 return address
 */
	ENTRY_NP(vbsc_guest_start)
	mov	%g7, %o3
	
	setx	VBSC_GUEST_ON, %g2, %g1
	GUEST_STRUCT(%o2)
	set	GUEST_GID, %o4
	ldx	[%o2 + %o4], %g2
	add	%g2, XPID_GUESTBASE, %g2
	mov	0, %g3
	HVCALL(vbsc_send_polled)

	mov	%o3, %g7
	HVRET
	SET_SIZE(vbsc_guest_start)


/*
 * vbsc_guest_exit - notify VBSC that a guest has exited
 *
 * arg0 exit code (%o0)
 * --
 * does not return
 */
	ENTRY_NP(vbsc_guest_exit)
	setx	VBSC_GUEST_OFF, %g2, %g1
	GUEST_STRUCT(%o2)
	set	GUEST_GID, %o4
	ldx	[%o2 + %o4], %g2
	add	%g2, XPID_GUESTBASE, %g2
	ldx	[%o2 + GUEST_TOD_OFFSET], %g3
	HVCALL(vbsc_send_polled)

	/* spin until the vbsc powers us down */
	ba	.
	nop
	SET_SIZE(vbsc_guest_exit)


/*
 * vbsc_guest_sir - notify vbsc that a guest requested a reset
 *
 * --
 * does not return
 */
	ENTRY_NP(vbsc_guest_sir)
	setx	VBSC_GUEST_RESET, %g2, %g1
	GUEST_STRUCT(%o2)
	set	GUEST_GID, %o4
	ldx	[%o2 + %o4], %g2
	add	%g2, XPID_GUESTBASE, %g2
	ldx	[%o2 + GUEST_TOD_OFFSET], %g3
	HVCALL(vbsc_send_polled)

	/* spin until the vbsc powers us down */
	ba	.
	nop
	SET_SIZE(vbsc_guest_sir)

/*
 * vbsc_guest_wdexpire - notify vbsc that a guest's watchdog timer expired
 * Service Processor policy dictates what happens next.
 *
 * %g1: guestp
 * %g7: return address
 * --
 */
	ENTRY_NP(vbsc_guest_wdexpire)
	mov	%g1, %g6
	setx	VBSC_GUEST_WDEXPIRE, %g2, %g1
	set	GUEST_GID, %g5
	ldx	[%g6 + %g5], %g2
	add	%g2, XPID_GUESTBASE, %g2
	ldx	[%g6 + GUEST_TOD_OFFSET], %g3
	ba,a	vbsc_send_polled ! tail call, returns to caller
	SET_SIZE(vbsc_guest_wdexpire)


/*
 * vbsc_guest_tod_offset - notify VBSC of a guest's TOD offset
 * We don't retry here, failures are ignored.
 *
 * %g1 guestp
 * %g7 return address
 *
 * Clobbers %g1-6
 * Called from guest hcall environment
 */

/* FIXME: Use a better buffer to send from ... */
/* Better yet this function / operation goes away entirely for LDoms */

	ENTRY_NP(vbsc_guest_tod_offset)
	VCPU_STRUCT(%g2)
	inc	CPU_SCR0, %g2

	set	GUEST_GID, %g3
	ldx	[%g1 + %g3], %g3
	add	%g3, XPID_GUESTBASE, %g3
	stx	%g3, [%g2 + 0x8]

	ldx	[%g1 + GUEST_TOD_OFFSET], %g3
	stx	%g3, [%g2 + 0x10]

	setx	VBSC_GUEST_TODOFFSET, %g4, %g3
	stx	%g3, [%g2 + 0x0]

	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_VBSC_SVCH], %g1

	mov	8 * 3, %g3

	!! %g1 svch
	!! %g2 buf
	!! %g3 length
	ba,pt	%xcc, svc_internal_send	! tail call, returns to caller
	nop
	SET_SIZE(vbsc_guest_tod_offset)



#define	SIM_IRU_DIAG_ERPT(erpt_vbsc, reg1, reg2)			\
	set	ERPT_TYPE_CPU, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_REPORT_TYPE]			;\
	setx	0x10000000000001, reg2, reg1				;\
	stx	reg1, [erpt_vbsc + EVBSC_EHDL]				;\
	setx	0x002a372a4, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_STICK]				;\
	setx	0x3e002310000607, reg2, reg1				;\
	stx	reg1, [erpt_vbsc + EVBSC_CPUVER]			;\
	setx	0x000000000, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_CPUSERIAL]			;\
	setx	0x000010000, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_SPARC_AFSR]			;\
	setx	0x000830550, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_SPARC_AFAR]			;\
	setx	0x400000402, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_TSTATE]			;\
	setx	0x000000800, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_HTSTATE]			;\
	setx	0x000800610, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_TPC]				;\
	set	0x0, reg1						;\
	stuh	reg1, [erpt_vbsc + EVBSC_CPUID]				;\
	set	0x63, reg1						;\
	stuh	reg1, [erpt_vbsc + EVBSC_TT]				;\
	set	0x1, reg1						;\
	stub	reg1, [erpt_vbsc + EVBSC_TL]				;\
	set	0x3, reg1						;\
	stub	reg1, [erpt_vbsc + EVBSC_ERREN]

#define	SIM_IRC_DIAG_ERPT(erpt_vbsc, reg1, reg2)			\
	set	ERPT_TYPE_CPU, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_REPORT_TYPE]			;\
	setx	0x10000000000002, reg2, reg1				;\
	stx	reg1, [erpt_vbsc + EVBSC_EHDL]				;\
	setx	0x002a372a4, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_STICK]				;\
	setx	0x3e002310000607, reg2, reg1				;\
	stx	reg1, [erpt_vbsc + EVBSC_CPUVER]			;\
	setx	0x000000000, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_CPUSERIAL]			;\
	setx	0x000020000, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_SPARC_AFSR]			;\
	setx	0x000830550, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_SPARC_AFAR]			;\
	setx	0x400000402, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_TSTATE]			;\
	setx	0x000000800, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_HTSTATE]			;\
	setx	0x000800610, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_TPC]				;\
	set	0x0, reg1						;\
	stuh	reg1, [erpt_vbsc + EVBSC_CPUID]				;\
	set	0x63, reg1						;\
	stuh	reg1, [erpt_vbsc + EVBSC_TT]				;\
	set	0x1, reg1						;\
	stub	reg1, [erpt_vbsc + EVBSC_TL]				;\
	set	0x3, reg1						;\
	stub	reg1, [erpt_vbsc + EVBSC_ERREN]


/*
 * vbsc_rx
 *
 * %g1 callback cookie (guest struct?XXX)
 * %g2 svc pointer
 * %g7 return address
 */
	ENTRY(vbsc_rx)
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_VBSC_SVCH], %g1

	mov	%g7, %g6
	PRINT("vbsc_rx: "); PRINTX(%g1); PRINT("\r\n"); 
	mov	%g6, %g7

	/*
	 * We don't defer packets so clear the recv pending flag.
	 * This is called on the cpu handling the interrupts so
	 * the contents of the buffer will not get clobbered until
	 * we return.
	 */
	ld	[%g2 + SVC_CTRL_STATE], %g3
	andn	%g3, SVC_FLAGS_RI, %g3
	st	%g3, [%g2 + SVC_CTRL_STATE]	! clear RECV pending

	ldx	[%g2 + SVC_CTRL_RECV + SVC_LINK_PA], %g2
	inc	SVC_PKT_SIZE, %g2 ! skip the header

	/*
	 * Dispatch command
	 */
	ldub	[%g2 + 6], %g4
	cmp	%g4, VBSC_CMD_GUEST_STATE
	be,pn	%xcc, gueststatecmd
	cmp	%g4, VBSC_CMD_HV
	be,pn	%xcc, hvcmd
	cmp	%g4, VBSC_CMD_READMEM
	be,pn	%xcc, dbgrd
	cmp	%g4, VBSC_CMD_WRITEMEM
	be,pn	%xcc, dbgwr
	cmp	%g4, VBSC_CMD_SENDERR
	be,pn	%xcc, dbg_send_error
	nop
vbsc_rx_finished:
	HVRET


/*
 * hvcmd - Hypervisor Command
 */
hvcmd:
	ldub	[%g2 + 7], %g4
	cmp     %g4, 'I'
	be,pn	%xcc, hvcmd_ping
	nop
	ba,a	vbsc_rx_finished

	/*
	 * hvcmd_ping - nop, just respond
	 */
hvcmd_ping:
		/* FIXME: find better scratch buffer */
	VCPU_STRUCT(%g2)
	inc	CPU_SCR0, %g2
	setx	VBSC_ACK(VBSC_CMD_HV, 'I'), %g4, %g3
	stx	%g3, [%g2 + 0x0]
	rdpr	%tpc, %g3
	st	%g3, [%g2 + 0xc]
	srlx	%g3, 32, %g3
	st	%g3, [%g2 + 0x8]
	ba,pt	%xcc, svc_internal_send	! returns to caller!!!!
	mov	16, %g3		! len

/*
 * gueststatecmd - Request from VBSC to change guest state
 */
gueststatecmd:
	!! %g2 = incoming packet

	ldub	[%g2 + 7], %g4
	cmp	%g4, GUEST_STATE_CMD_SHUTREQ
	be,pn	%xcc, 1f
	cmp	%g4, GUEST_STATE_CMD_DCOREREQ
	be,pn	%xcc, 1f
	nop
	ba,a	vbsc_rx_finished

1:
	/*
	 * The use of XID is deprecated. The target of
	 * the request is always the control domain.
	 */
	CTRL_DOMAIN(%g1, %g3, %g4)
	cmp	%g1, 0
	be,pn	%xcc, vbsc_rx_finished
	nop

	/*
	 * Check if the current vcpu is in the control
	 * domain and running. If so, the state command
	 * can be executed on the local strand.
	 */
	VCPU_STRUCT(%g3)

	!! %g1 = control domain guestp
	!! %g2 = incoming packet
	!! %g3 = current vcpup

	ldx	[%g3 + CPU_GUEST], %g4
	cmp	%g1, %g4
	bne,pn	%xcc, reroutecmd
	nop

	ldx	[%g3 + CPU_STATUS], %g4
	cmp	%g4, CPU_STATE_RUNNING
	bne,pn	%xcc, reroutecmd
	nop

	ba,a	executecmd

reroutecmd:

	!! %g1 = control domain guestp
	!! %g2 = incoming packet

	/*
	 * Loop through the vcpus in the control domain
	 * until one is found that is running. If none
	 * are found, the domain is not in an appropriate
	 * state for the request so the request is dropped.
	 */

	mov	0, %g4
	!! %g4 = current index
1:
	cmp	%g4, (NVCPUS - 1)
	bgu,pn	%xcc, vbsc_rx_finished	! no appropriate vcpu, ignore request
	nop
	sllx	%g4, GUEST_VCPUS_SHIFT, %g3
	add	%g1, %g3, %g3
	add	%g3, GUEST_VCPUS, %g3
	ldx	[%g3], %g3
	brz,a	%g3, 1b			! skip any empty entries
	  inc	%g4
	!! %g3 = current vcpup

	! check the vcpu state
	ldx	[%g3 + CPU_STATUS], %g5
	cmp	%g5, CPU_STATE_RUNNING
	bne,a	%xcc, 1b
	  inc	%g4

executecmd:

	!! %g2 = incoming packet
	!! %g3 = target vcpup

	VCPU2STRAND_STRUCT(%g3, %g4)
	!! %g4 = target strandp

	ldub	[%g2 + 7], %g5
	cmp	%g5, GUEST_STATE_CMD_SHUTREQ
	be,pn	%xcc, hvcmd_guest_shutdown_request
	cmp	%g5, GUEST_STATE_CMD_DCOREREQ
	be,pn	%xcc, hvcmd_guest_dcore_request
	nop
	ba,a	vbsc_rx_finished

hvcmd_guest_shutdown_request:

	!! %g2 = incoming packet
	!! %g3 = target vcpup
	!! %g4 = target strandp

#ifdef DEBUG
	mov	%g7, %g5
	PRINT("Control Domain shutdown request, target strand=0x")
	ldub	[%g4 + STRAND_ID], %g6
	PRINTX(%g6)
	PRINT("\r\n")
	mov	%g5, %g7
#endif /* DEBUG */

	! retrieve the command argument from the packet
	ldx	[%g2 + 0x10], %g2
	!! %g2 = command argument (grace period in seconds)
	
	/*
	 * Perform the action locally if the current
	 * strand is the specified target.
	 */

	STRAND_STRUCT(%g5)
	cmp	%g4, %g5
	be,a,pt	%xcc, guest_shutdown	! tail call, does not return here
	  mov	%g2, %g1		! the required argument

	/*
	 * Send a mondo to the specified strand to
	 * perform the action.
	 */

	add	%g4, STRAND_HV_TXMONDO, %g5
	!! %g5 = strand mondop

	! setup mondo structure
	mov	HXCMD_GUEST_SHUTDOWN, %g6
	stx	%g6, [%g5 + HVM_CMD]
	STRAND_STRUCT(%g6)
	stx	%g6, [%g5 + HVM_FROM_STRANDP]
	stx	%g3, [%g5 + HVM_ARGS + HVM_GUESTCMD_VCPUP]
	stx	%g2, [%g5 + HVM_ARGS + HVM_GUESTCMD_ARG]

	! send the mondo
	mov	%g4, %g1	! arg1 = target strandp
	mov	%g5, %g2	! arg2 = strand mondop
	STRAND_PUSH(%g7, %g3, %g4)
	HVCALL(hvmondo_send)
	STRAND_POP(%g7, %g3)

	ba,a	vbsc_rx_finished

hvcmd_guest_dcore_request:

	!! %g2 = incoming packet
	!! %g3 = target vcpup
	!! %g4 = target strandp

#ifdef DEBUG
	mov	%g7, %g5
	PRINT("Control Domain panic request, target strand=0x")
	ldub	[%g4 + STRAND_ID], %g6
	PRINTX(%g6)
	PRINT("\r\n")
	mov	%g5, %g7
#endif /* DEBUG */

	/*
	 * Perform the action locally if the current
	 * strand is the specified target.
	 */

	STRAND_STRUCT(%g5)
	cmp	%g4, %g5
	be,a,pt	%xcc, guest_panic	! tail call, does not return here
	  nop

	/*
	 * Send a mondo to the specified strand to
	 * perform the action.
	 */

	add	%g4, STRAND_HV_TXMONDO, %g5
	!! %g5 = strand mondop

	! setup mondo structure
	mov	HXCMD_GUEST_PANIC, %g6
	stx	%g6, [%g5 + HVM_CMD]
	STRAND_STRUCT(%g6)
	stx	%g6, [%g5 + HVM_FROM_STRANDP]
	stx	%g3, [%g5 + HVM_ARGS + HVM_GUESTCMD_VCPUP]

	! send the mondo
	mov	%g4, %g1	! arg1 = target strandp
	mov	%g5, %g2	! arg2 = strand mondop
	STRAND_PUSH(%g7, %g3, %g4)
	HVCALL(hvmondo_send)
	STRAND_POP(%g7, %g3)

	ba,a	vbsc_rx_finished

	/*
	 * dbgrd - perform read transaction on behalf of vbsc
	 */
dbgrd:
	ldx	[%g2 + 8], %g3		! ADDR
	ldub	[%g2 + 7], %g6		! size
	sub	%g6, '0', %g6
	ldub	[%g2 + 5], %g4		! asi?
	cmp	%g4, 'A'
	bne,pt	%xcc, 1f
	sllx	%g6, 2, %g6			! offset
	add	%g6, 4*4, %g6			! offset of ASIs
	srlx	%g3, 56, %g4
	and	%g4, 0xff, %g4
	wr	%g4, %asi
	sllx	%g3, 8, %g3
	srlx	%g3, 8, %g3			! bits 0-56
1:	ba	1f
	rd	%pc, %g4
	ldub	[%g3], %g6
	lduh	[%g3], %g6
	ld	[%g3], %g6
	ldx	[%g3], %g6
	lduba	[%g3] %asi, %g6
	lduha	[%g3] %asi, %g6
	lda	[%g3] %asi, %g6
	ldxa	[%g3] %asi, %g6
1:      add	%g4, 4, %g4
	jmp	%g4 + %g6			! CTI COUPLE!!
	ba	1f				! CTI COUPLE!!
	nop					! NEVER EXECUTED!! DONT DELETE
1:	ba	1f
	rd	%pc, %g2
.word	0			! data buffer - upper 32 bits
.word	0			! data buffer - lower 32 bits
1:	add	%g2, 4, %g2	! buf
	st	%g6, [%g2 + 4]	! low bits
	srlx	%g6, 32, %g6
	st	%g6, [%g2 + 0]  ! upper bits
	ba	svc_internal_send  ! returns to caller!!!!
	mov	8, %g3		! len

	/*
	 * dbgwr - perform write transaction on behalf of vbsc
	 */
dbgwr:
	ldx	[%g2 + 0x10], %g3 ! ADDR
	ldub	[%g2 + 7], %g6	! size
	sub	%g6, '0', %g6
	ldub	[%g2 + 5], %g1	! asi?
	cmp	%g1, 'A'
	bne,pt	%xcc, 1f
	sllx	%g6, 2, %g6                     ! offset
	add	%g6, 4*4, %g6                   ! offset of ASIs
	srlx	%g3, 56, %g4
	and	%g4, 0xff, %g4
	wr	%g4, %asi
	sllx	%g3, 8, %g3
	srlx    %g3, 8, %g3                     ! bits0-56
1:	ba	1f
	rd	%pc, %g4
	stb	%g1, [%g3]
	sth	%g1, [%g3]
	st	%g1, [%g3]
	stx	%g1, [%g3]
	stba	%g1, [%g3] %asi
	stha	%g1, [%g3] %asi
	sta	%g1, [%g3] %asi
	stxa	%g1, [%g3] %asi
1:	add	%g4, 4, %g4
	ldx	[%g2 + 8], %g1                  ! get data
	jmp	%g4 + %g6                       ! CTI COUPLE!!
	jmp	%g7 + 4                         ! All done.
	nop					! NEVER EXECUTED!!!

	/*
	 * dbg_send_error - send a fake error transaction back to vbsc
	 */
dbg_send_error:
#if 0
#ifdef DEBUG
	/*
	 * Fill the error reports with valid information to
	 * help test interaction with the FERG on the vbsc
	 */
	mov	%g7, %g6
	STRAND_STRUCT(%g3)
	add	%g3, STRAND_CE_RPT + STRAND_VBSC_ERPT, %g4
	SIM_IRC_DIAG_ERPT(%g4, %g5, %g7)
	add	%g3, STRAND_UE_RPT + STRAND_VBSC_ERPT, %g4
	SIM_IRU_DIAG_ERPT(%g4, %g5, %g7)
	PRINT("\r\n")
	mov	%g6, %g7
#endif

	CPU_PUSH(%g7, %g1, %g2, %g3)
	STRAND_STRUCT(%g1)
	add	%g1, STRAND_CE_RPT + STRAND_UNSENT_PKT, %g2
	ldx	[%g1 + STRAND_CONFIGP], %g6 	

#ifdef DEBUG
	/*
	 * Send one error and mark another buffer to be
	 * sent
	 */
	mov	1, %g7
	stx	%g7, [%g6 + CONFIG_ERRS_TO_SEND]
	set	STRAND_UE_RPT + STRAND_UNSENT_PKT, %g3
	add	%g1, %g3, %g3
	stx	%g7, [%g3]
#endif
	add	%g1, STRAND_CE_RPT + STRAND_VBSC_ERPT, %g1
	mov	EVBSC_SIZE, %g3
	HVCALL(send_diag_erpt)
	CPU_POP(%g7, %g1, %g2, %g3)
#endif
	HVRET
	SET_SIZE(vbsc_rx)

/*
 * vbsc_tx
 *
 * %g1 callback cookie
 * %g2 packet 
 * %g7 return address
 */
	ENTRY(vbsc_tx)
	mov 	%g7, %g6
	PRINT("vbsc_tx: ")
	PRINTX(%g1)
	PRINT("\r\n")
	mov	%g6, %g7

	HVRET
	SET_SIZE(vbsc_tx)

 


/*
 * vbsc_puts - print string on hypervisor console
 *
 * %g1 string pointer
 * %g7 return address
 */
	ENTRY_NP(vbsc_puts)

        CPU_PUSH(%g7, %g2, %g3, %g4)
        CPU_PUSH(%g6, %g2, %g3, %g4)
        CPU_PUSH(%g5, %g2, %g3, %g4)
        CPU_PUSH(%l0, %g2, %g3, %g4)

        mov     %g1, %l0
        !! %l0 = string pointer

1:      mov     8, %g5
        mov     0, %g2
        !! %g5 = loop count
        !! %g2 = debug-puthex arg1

2:      ldub    [%l0], %g3
        brz,pn  %g3, .sendndone
          nop
        sllx    %g2, 8, %g2
        or      %g2, %g3, %g2   ! arg1 = (arg1 << 8) | char
        deccc   %g5
        bnz,pt  %xcc, 2b
          inc     %l0

3:
        setx    VBSC_HV_PUTCHARS, %g3, %g1
        HVCALL(vbsc_send_polled)

        ba,pt   %xcc, 1b
          nop

.sendndone:
        setx    VBSC_HV_PUTCHARS, %g3, %g1
        HVCALL(vbsc_send_polled)

        CPU_POP(%l0, %g1, %g2, %g3)
        CPU_POP(%g5, %g1, %g2, %g3)
        CPU_POP(%g6, %g1, %g2, %g3)
        CPU_POP(%g7, %g1, %g2, %g3)

	HVRET
	SET_SIZE(vbsc_puts)


/*
 * vbsc_putx - print hex number on hypervisor console
 *
 * %g1 number
 * %g7 return address
 */
	ENTRY_NP(vbsc_putx)
	mov	%g1, %g2
	setx	VBSC_HV_PUTHEX, %g3, %g1
	ba,a	vbsc_send_polled
	/* tail call, returns directly to caller */
	SET_SIZE(vbsc_putx)

#endif /* CONFIG_SVC && CONFIG_VBSC_SVC  */
