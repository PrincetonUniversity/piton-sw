/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vdev_console.s
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

	.ident	"@(#)vdev_console.s	1.12	07/02/14 SMI"

	.file	"vdev_console.s"

/*
 * Virtual console device implementation
 */

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hprivregs.h>
#include <asi.h>
#include <fpga.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>
#include <sun4v/asi.h>
#include <sparcv9/asi.h>
#include <sun4v/queue.h>
#include <devices/pc16550.h>

#include <guest.h>
#include <offsets.h>
#include <util.h>
#include <svc.h>
#include <vdev_intr.h>
#include <abort.h>
#include <vdev_console.h>
#include <debug.h>
#include <vcpu.h>
#include <mmu.h>
#include <ldc.h>

/*
 * Virtual console guest interfaces (hcalls)
 */

/*
 * Service Channel implementation
 */


/*
 * cons_putchar
 *
 * arg0 char (%o0)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_cons_putchar)
#if 0 /* XXX check for invalid char -or- magic values (BREAK) */
	cmp	%o0, MAX_CHAR
	bgu,pn	%xcc, herr_inval
#endif

	VCPU_GUEST_STRUCT(%g4, %g3)
	! %g3 = guestp
	! %g4 = cpup

	! if not initialized, then just swallow the characters.
	! OK What type of console do we have.
	ldub	[%g3 + GUEST_CONSOLE + CONS_TYPE], %g5
	cmp	%g5, CONS_TYPE_UNCONFIG
	beq,pn	%xcc, hret_ok
	  nop
	cmp	%g5, CONS_TYPE_LDC
	beq,pt	%xcc, .use_ldc_put
	  nop
#ifdef CONFIG_CN_UART /* { */
	cmp	%g5, CONS_TYPE_UART
	beq,pt	%xcc, .use_uart_put
	  nop
#endif /* } */
	ba,pt	%xcc, herr_inval	! Return inval if console not configd
	  nop

	/*
	 * Console put char using a LDC channel as output
	 */
.use_ldc_put:

	setx	GUEST_CONSOLE, %g2, %g6
	add	%g6, %g3, %g6

	ldub	[%g6 + CONS_STATUS], %g2	! chk if ready
	andcc	%g2, LDC_CONS_READY, %g2
	bz,pn	%xcc, herr_wouldblock
	  nop

	ldx	[%g6 + CONS_ENDPT], %g1

	! %g1 = channel 
	! %g3 = guest struct

	mulx	%g1, LDC_ENDPOINT_SIZE, %g1
	set	GUEST_LDC_ENDPOINT, %g2
	add	%g1, %g2, %g1
	add	%g1, %g3, %g2

	! %g2 = our endpoint
	! %g3 = guest struct

	! Since the SRAM LDC is a bottleneck (for performance)
	! we have to try and buffer up more than one char per LDC
	! packet.
	ldub	[ %g2 + LDC_TARGET_TYPE ], %g5
	cmp	%g5, LDC_SP_ENDPOINT
	bne	%xcc, 1f
	  nop

	! SRAM LDC
	!
	! Since any code which pulls data out of our TX queue and into
	! the SRAM will have to obtain the SP_LDC_TX_LOCK, we can go
	! ahead and grab that lock now and try to "pack" the console
	! LDC packets a little better so that we are not simply sending
	! one character per packet in all cases.

	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_SP_LDCS], %g1
	ldx	[%g2 + LDC_TARGET_CHANNEL], %g4
	mulx	%g4, SP_LDC_ENDPOINT_SIZE, %g4
	add	%g1, %g4, %g1			! target endpoint

	add	%g1, SP_LDC_TX_LOCK, %g4
	SPINLOCK_ENTER(%g4, %g5, %g6)

	lduw	[ %g2 + LDC_TX_QHEAD ], %g6
	lduw	[ %g2 + LDC_TX_QTAIL ], %g4

	cmp	%g4, %g6			! Is the TX queue empty?
	be	%xcc, .putchar_release_sp_lk	! If so, nothing to compact
	  nop					! so proceed as normal.

	ldx	[ %g2 + LDC_TX_QSIZE ], %g6	! "tail" points to next
	dec	Q_EL_SIZE, %g6			! available packet, so we
	dec	Q_EL_SIZE, %g4			! actually want the previous
	and	%g4, %g6, %g4			! packet.

	ldx	[ %g2 + LDC_TX_QBASE_PA ], %g6
	add	%g4, %g6, %g4			! Find the last packet

	ldub	[%g4 + LDC_CONS_SIZE], 	%g5	! read current size (#chars)

	cmp	%g5, LDC_CONS_PAYLOAD_SZ	! is packet already full?
	bgeu,a	%xcc, .putchar_release_sp_lk	! if so, just start the next
	  nop					! packet as usual (unpacked)

	add	%g4, %g5, %g6			! offset of this char.
	stb	%o0, [%g6 + LDC_CONS_PAYLOAD]	! store char in payload.

	inc	%g5				! # chars in payload now.
	stb	%g5, [%g4 + LDC_CONS_SIZE]	! store new payload size.

	add	%g1, SP_LDC_TX_LOCK, %g4
	SPINLOCK_EXIT(%g4)

	! Queue was not empty, so no need to send notification.
	HCALL_RET(EOK)

.putchar_release_sp_lk:

	add	%g1, SP_LDC_TX_LOCK, %g4
	SPINLOCK_EXIT(%g4)

	ba,a	.send_pkt

1:
	! target is a guest endpoint
	! if it has no receive queue configured drop the
	! console char and return back
	ldx	[ %g2 + LDC_TARGET_GUEST ], %g6
	ldx	[ %g2 + LDC_TARGET_CHANNEL ], %g4
	mulx	%g4, LDC_ENDPOINT_SIZE, %g4
	set	GUEST_LDC_ENDPOINT, %g5
	add	%g6, %g5, %g6
	add	%g6, %g4, %g6			! g6 is the target endpoint
	ldx	[ %g6 + LDC_RX_QSIZE ], %g4	! check if queue is configured
	brnz,a,pn %g4, .send_pkt
	  nop
	HCALL_RET(EOK)

.send_pkt:
	! %g2 = our endpoint
	! %g3 = guest struct

	lduw	[ %g2 + LDC_TX_QHEAD ], %g6
	lduw	[ %g2 + LDC_TX_QTAIL ], %g4

	ldx	[ %g2 + LDC_TX_QSIZE ], %g5
	dec	Q_EL_SIZE, %g5
	add	%g4, Q_EL_SIZE, %g1
	and	%g1, %g5, %g1

	cmp	%g1, %g6			! Does TX queue have room?
	bne,pt	%xcc, 2f			! If so, continue.
	  nop

	! TX queue is full. Have we already marked it as such?
	ldub	[ %g2 + LDC_TXQ_FULL ], %g5
	set	1, %g6
	brz,a	%g5, 1b				! If not, mark it and try one
	   stb	%g6, [ %g2 + LDC_TXQ_FULL ]	! last time to avoid lost intr.

	ba	herr_wouldblock
	  nop
2:
	! %g1 = new tail value
	! %g2 = our endpoint
	! %g3 = guest struct
	! %g4 = old tail

	ldx	[ %g2 + LDC_TX_QBASE_PA ], %g3
	add	%g4, %g3, %g4

	! %g1 = new tail value
	! %g2 = sender's endpoint
	! %g4 = pointer to outgoing queue entry

	stx	%g0, [%g4]
	stx	%g0, [%g4 + 0x08]
	stx	%g0, [%g4 + 0x10]
	stx	%g0, [%g4 + 0x18]
	stx	%g0, [%g4 + 0x20]
	stx	%g0, [%g4 + 0x28]
	stx	%g0, [%g4 + 0x30]
	stx	%g0, [%g4 + 0x38]

	set	LDC_CONSOLE_DATA, %g5
	stb	%g5, [%g4 + LDC_CONS_TYPE]
	mov	1, %g5				! size=1, one char is
	stb	%g5, [%g4 + LDC_CONS_SIZE]	!  being sent
	stb	%o0, [%g4 + LDC_CONS_PAYLOAD]

	ldub	[ %g2 + LDC_TARGET_TYPE ], %g5
	cmp	%g5, LDC_GUEST_ENDPOINT
	be	%xcc, 3f
	  nop

	! %g1 = new tail value
	! %g2 = sender's endpoint

	HVCALL(guest_to_sp_tx_set_tail)		! clobbers all %g1,%g3-%g7
	ba	4f
	  nop
3:

	HVCALL(guest_to_guest_tx_set_tail)	! clobbers all %g1,%g3-%g7
4:
	! %g2 = sender's endpoint
	
	HCALL_RET(EOK)

	/*
	 * Console put char using a service channel as output
	 */


#ifdef	CONFIG_CN_UART	/* { */
.use_uart_put:
	ldx	[%g3 + GUEST_CONSOLE + CONS_UARTBASE], %g1
	! %g1 = uartp
0:
	ldub	[%g1 + LSR_ADDR], %g4
	btst	LSR_THRE, %g4
	bz,pn	%xcc, herr_wouldblock
	  nop
	stb	%o0, [%g1]
	HCALL_RET(EOK)

#endif /* } */

	SET_SIZE(hcall_cons_putchar)


/*
 * cons_getchar
 *
 * no arguments
 * --
 * ret0 status (%o0)
 * ret1 char (%o1)
 */
	ENTRY_NP(hcall_cons_getchar)

	GUEST_STRUCT(%g1)
	! %g1 = guestp

	! if not initialized, then return EWOULDBLOCK.
	! OK What type of console do we have.
	ldub	[%g1 + GUEST_CONSOLE + CONS_TYPE], %g5
	cmp	%g5, CONS_TYPE_UNCONFIG
	beq,pn	%xcc, herr_wouldblock
	  nop
	cmp	%g5, CONS_TYPE_LDC
	beq,pt	%xcc, .use_ldc_get
	  nop
#ifdef	CONFIG_CN_UART /* { */
	cmp	%g5, CONS_TYPE_UART
	beq,pt	%xcc, .use_uart_get
	  nop
#endif /* } */
	ba,pt	%xcc, herr_inval	! Return inval if console not configd
	  nop

#ifdef CONFIG_CN_UART /* { */

.use_uart_get:
	ldx	[%g1 + GUEST_CONSOLE + CONS_UARTBASE], %g2

	! %g2 = uartp
	ldub	[%g2 + LSR_ADDR], %g3 ! line status register
	btst	LSR_BINT, %g3	! BREAK?
	bz,pt	%xcc, 1f
	nop

	! BREAK
	andn	%g3, LSR_BINT, %g3
	stb	%g3, [%g2 + LSR_ADDR] 	! XXX clear BREAK? need w1c
	mov	CONS_BREAK, %o1
	HCALL_RET(EOK)

1:	btst	LSR_DRDY, %g3	! character ready?
	bz,pt	%xcc, herr_wouldblock
	nop

	ldub	[%g2], %o1	! input data register
	HCALL_RET(EOK)

#endif /* } CONFIG_CN_UART */

	! read character from LDC internal buffer
	!
.use_ldc_get:
	
	! %g1 = guestp

	mov	%g1, %g4

	! LDC based console processing	
	setx	GUEST_CONSOLE, %g2, %g3
	add	%g1, %g3, %g1

	ldx	[%g1 + CONS_ENDPT], %g2

	mulx	%g2, LDC_ENDPOINT_SIZE, %g2
	set	GUEST_LDC_ENDPOINT, %g3
	add	%g2, %g3, %g2
	add	%g2, %g4, %g2

	! %g2 = our endpoint

	ldub	[ %g2 + LDC_TARGET_TYPE ], %g3
	cmp	%g3, LDC_SP_ENDPOINT
	be	%xcc, 1f
	  nop

	HVCALL(guest_to_guest_pull_data)	! clobbers all %g1,%g3-%g7
	ba	2f
	  nop
1:
	HVCALL(sp_to_guest_pull_data)		! clobbers all %g1,%g3-%g7
2:
	! %g2 = our endpoint

	lduw	[%g2 + LDC_RX_QHEAD], %g3	! check if there is any data
	lduw	[%g2 + LDC_RX_QTAIL], %g4	! in our RX queue.
	cmp	%g3, %g4
	be	%xcc, 1f

	CPU_PUSH(%g2, %g4, %g5, %g6)		! save off endpoint struct
	CPU_PUSH(%g3, %g4, %g5, %g6)		! save off head pointer

	! There is data in the RX queue, so process the next console packet.
	ldx	[%g2 + LDC_RX_QBASE_PA], %g4
	add	%g3, %g4, %g2

	GUEST_STRUCT(%g1)

	HVCALL(cons_ldc_callback)

	CPU_POP(%g3, %g4, %g5, %g6)		! restore head pointer
	CPU_POP(%g2, %g4, %g5, %g6)		! restore endpoint struct

	! Now we have to incriment the head pointer
	ldx	[%g2 + LDC_RX_QSIZE], %g5
	dec	Q_EL_SIZE, %g5
	add	%g3, Q_EL_SIZE, %g3
	and	%g3, %g5, %g5
	stw	%g5, [%g2 + LDC_RX_QHEAD]

1:
	GUEST_STRUCT(%g1)

	! LDC based console processing	
	setx	GUEST_CONSOLE, %g2, %g3
	add	%g1, %g3, %g1

	! %g1 = guest console

	ldub	[%g1 + CONS_STATUS], %g2	! chk if ready
	andcc	%g2, LDC_CONS_READY, %g0
	bz,pn	%xcc, herr_wouldblock
	  nop

	andcc	%g2, LDC_CONS_BREAK, %g0
	bz,pt	%xcc, 2f
	  nop
	mov	LDC_CONS_READY, %g2
	stb	%g2, [%g1 + CONS_STATUS]	! clear break
	mov	CONS_BREAK, %o1
	HCALL_RET(EOK)
2:
	andcc	%g2, LDC_CONS_HUP, %g0
	bz,pt	%xcc, 3f
	  nop
	mov	LDC_CONS_READY, %g2
	stb	%g2, [%g1 + CONS_STATUS]	! clear break
	mov	CONS_HUP, %o1
	HCALL_RET(EOK)
		
3:	! LDC Console data	
	ldx	[%g1 + CONS_INHEAD], %g2	! chk if head=tail 
	ldx	[%g1 + CONS_INTAIL], %g3
	cmp	%g2, %g3
	beq,pt	%xcc, herr_wouldblock
  	  nop

	add	%g1, CONS_INBUF, %g3		! get inbuf addr
	add	%g3, %g2, %g3

	ldub	[%g3], %o1	! input data register

	inc	%g2				! inc the head
	and	%g2, (CONS_INBUF_SIZE - 1), %g2
	stx	%g2, [%g1 + CONS_INHEAD]

	HCALL_RET(EOK)
	SET_SIZE(hcall_cons_getchar)


/*
 * cons_read - read characters from the console
 *
 * Read arg1 characters from the console and place into buffer at arg0.
 * If arg1 is zero the call immediately returns success, no data
 * is consumed.
 * On success ret1 contains either a magic character (CONS_BREAK, CONS_HUP)
 * or the number of characters placed into the buffer.
 *
 * arg0 buffer RA (%o0)
 * arg1 length (%o1)
 * --
 * ret0 status (%o0)
 * ret1 length completed (%o1)
 */
	ENTRY_NP(hcall_cons_read)
	/*
	 * read buffer size is 0, return success
	 */
	brz,pn	%o1, hret_ok
	nop

	GUEST_STRUCT(%g1)

	ldub	[%g1 + GUEST_CONSOLE + CONS_TYPE], %g5
	cmp	%g5, CONS_TYPE_UNCONFIG
	beq,pn	%xcc, herr_wouldblock
	  nop
	cmp	%g5, CONS_TYPE_LDC
	beq,pt	%xcc, .use_ldc_read
	  nop
#ifdef	CONFIG_CN_UART /* { */
	cmp	%g5, CONS_TYPE_UART
	beq,pt	%xcc, .use_uart_read
	  nop
#endif /* } */
	ba,pt	%xcc, herr_inval	! Return inval if console not configd
	  nop

#ifdef	CONFIG_CN_UART /* { */

.use_uart_read:
	ldx	[%g1 + GUEST_CONSOLE + CONS_UARTBASE], %g2
	! %g2 = uartp

	ldub	[%g2 + LSR_ADDR], %g3 ! line status register
	btst	LSR_BINT, %g3	! BREAK?
	bz,pt	%xcc, 1f
	nop

	! BREAK
	andn	%g3, LSR_BINT, %g3
	stb	%g3, [%g2 + LSR_ADDR] 	! XXX clear BREAK? need w1c
	mov	CONS_BREAK, %o1
	HCALL_RET(EOK)

1:	btst	LSR_DRDY, %g3	! character ready?
	bz,pt	%xcc, herr_wouldblock
	nop

	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o0, %o1, herr_noraddr, %g5, %g6)
	mov	%g6, %o0
	! %o0 buf PA

	ldub	[%g2], %g3	! input data register
	stb	%g3, [%o0]
	mov	1, %o1		! Always one character
	HCALL_RET(EOK)

#endif	/* } CONFIG_CN_UART */

.use_ldc_read:
	! LDC based console processing	
	setx	GUEST_CONSOLE, %g2, %g3
	add	%g1, %g3, %g6

	ldx	[%g6 + CONS_ENDPT], %g2

	mulx	%g2, LDC_ENDPOINT_SIZE, %g2
	set	GUEST_LDC_ENDPOINT, %g3
	add	%g2, %g3, %g2
	add	%g2, %g1, %g2

	! %g2 = our endpoint

	ldub	[ %g2 + LDC_TARGET_TYPE ], %g3
	cmp	%g3, LDC_SP_ENDPOINT
	be	%xcc, 1f
	  nop

	HVCALL(guest_to_guest_pull_data)	! clobbers all %g1,%g3-%g7
	ba	2f
	  nop
1:
	HVCALL(sp_to_guest_pull_data)		! clobbers all %g1,%g3-%g7
2:
	! %g2 = our endpoint

	lduw	[%g2 + LDC_RX_QHEAD], %g3	! check if there is any data
	lduw	[%g2 + LDC_RX_QTAIL], %g4	! in our RX queue.
	cmp	%g3, %g4
	be	%xcc, 1f

	CPU_PUSH(%g2, %g4, %g5, %g6)		! save off endpoint struct
	CPU_PUSH(%g3, %g4, %g5, %g6)		! save off head pointer

	! There is data in the RX queue, so process the next console packet.
	ldx	[%g2 + LDC_RX_QBASE_PA], %g4
	add	%g3, %g4, %g2

	GUEST_STRUCT(%g1)

	HVCALL(cons_ldc_callback)

	CPU_POP(%g3, %g4, %g5, %g6)		! restore head pointer
	CPU_POP(%g2, %g4, %g5, %g6)		! restore endpoint struct

	! Now we have to incriment the head pointer
	ldx	[%g2 + LDC_RX_QSIZE], %g5
	dec	Q_EL_SIZE, %g5
	add	%g3, Q_EL_SIZE, %g3
	and	%g3, %g5, %g5
	stw	%g5, [%g2 + LDC_RX_QHEAD]

1:
	GUEST_STRUCT(%g6)

	! LDC based console processing	
	setx	GUEST_CONSOLE, %g2, %g3
	add	%g6, %g3, %g6

	! %g6 = guest console struct
	ldub	[%g6 + CONS_STATUS], %g2	! chk if ready
	andcc	%g2, LDC_CONS_READY, %g0
	bz,pn	%xcc, herr_wouldblock
	  nop

	andcc	%g2, LDC_CONS_BREAK, %g0
	bz,pt	%xcc, 2f
	  nop
	mov	LDC_CONS_READY, %g2
	stb	%g2, [%g6 + CONS_STATUS]	! clear break
	mov	CONS_BREAK, %o1
	HCALL_RET(EOK)
2:
	andcc	%g2, LDC_CONS_HUP, %g0
	bz,pt	%xcc, 3f
	  nop
	mov	LDC_CONS_READY, %g2
	stb	%g2, [%g6 + CONS_STATUS]	! clear hup
	mov	CONS_HUP, %o1
	HCALL_RET(EOK)
3:
	! LDC Console data	
	ldx	[%g6 + CONS_INHEAD], %g2	! chk if head=tail 
	ldx	[%g6 + CONS_INTAIL], %g3
	cmp	%g2, %g3
	beq,pt	%xcc, herr_wouldblock
  	  nop

	GUEST_STRUCT(%g1)

	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o0, %o1, herr_noraddr, %g5, %g4)
	mov	%g4, %o0
	! %o0 buf PA


	add	%g6, CONS_INBUF, %g3		! get inbuf addr
	mov	%g0, %g4

	! g2 = cons buf head idx
	! g3 = cons buf ptr
	! g4 = count of chars read
	! g5 = current buf tail idx

4:
	ldub	[%g3 + %g2], %g5
	stb	%g5, [%o0 + %g4]
	inc	%g4				! inc count
	inc	%g2				! inc the head
	and	%g2, (CONS_INBUF_SIZE - 1), %g2
	stx	%g2, [%g6 + CONS_INHEAD]
	
	cmp	%g4, %o1
	bgeu,pt	%xcc, 5f
	  nop
	ldx	[%g6 + CONS_INTAIL], %g5
	cmp	%g2, %g5
	beq,pt	%xcc, 5f
	  nop
	ba	4b			! next char
	 nop
5:
	mov	%g4, %o1			! characters read
	HCALL_RET(EOK)
	
	SET_SIZE(hcall_cons_read)


/*
 * cons_write - write characters to the console
 *
 * Writes arg1 characters from the buffer at arg0 to the console.
 * If arg1 is zero the call immediately returns success, no data
 * is consumed.
 * On success ret1 contains the actual number of characters consumed
 * from the buffer.
 *
 * arg0 buffer RA (%o0)
 * arg1 length (%o1)
 * --
 * ret0 status (%o0)
 * ret1 length completed (%o1)
 */
	ENTRY_NP(hcall_cons_write)
	brz,pn	%o1, hret_ok
	nop
	VCPU_GUEST_STRUCT(%g4, %g3)

	! %g3 = guestp
	! %g4 = cpup
	RA2PA_RANGE_CONV_UNK_SIZE(%g3, %o0, %o1, herr_noraddr, %g5, %g2)
	mov	%g2, %o0
	! %o0 buf PA

	ldub	[%g3 + GUEST_CONSOLE + CONS_TYPE], %g5
	cmp	%g5, CONS_TYPE_UNCONFIG
	beq,pn	%xcc, hret_ok
	  nop
	cmp	%g5, CONS_TYPE_LDC
	beq,pt	%xcc, .use_ldc_write
	  nop
#ifdef	CONFIG_CN_UART /* { */
	cmp	%g5, CONS_TYPE_UART
	beq,pt	%xcc, .use_uart_write
	  nop
#endif /* } */
	ba,pt	%xcc, herr_inval	! Return inval if console not configd
	  nop

#ifdef CONFIG_CN_UART	/* { */

.use_uart_write:
	ldx	[%g3 + GUEST_CONSOLE + CONS_UARTBASE], %g1
	! %g1 = uartp

	ldub	[%g1 + LSR_ADDR], %g4
	btst	LSR_THRE, %g4
	bz,pn	%xcc, herr_wouldblock
	nop

	mov	0, %g2
	! %g2 count of characters written
1:
	ldub	[%o0 + %g2], %g3
	stb	%g3, [%g1]
	inc	%g2
	cmp	%g2, %o1
	bgeu,pn	%xcc, 2f
	nop
	ldub	[%g1 + LSR_ADDR], %g4
	btst	LSR_THRE, %g4
	bnz,pt	%xcc, 1b
	nop

2:
	mov	%g2, %o1
	HCALL_RET(EOK)

#endif 	/* } CONFIG_CN_UART */

.use_ldc_write:
	setx	GUEST_CONSOLE, %g2, %g6
	add	%g6, %g3, %g6

	ldub	[%g6 + CONS_STATUS], %g2	! chk if ready
	andcc	%g2, LDC_CONS_READY, %g2
	bz,pn	%xcc, herr_wouldblock
	  nop

	ldx	[%g6 + CONS_ENDPT], %g1

	! %g1 = channel 
	! %g3 = guest struct

	mulx	%g1, LDC_ENDPOINT_SIZE, %g1
	set	GUEST_LDC_ENDPOINT, %g2
	add	%g1, %g2, %g1
	add	%g1, %g3, %g2

	! target is a guest endpoint
	! if it has no receive queue configured drop the
	! console char and return back
	ldub	[ %g2 + LDC_TARGET_TYPE ], %g5
	cmp	%g5, LDC_GUEST_ENDPOINT
	bne	%xcc, 1f
	  nop
	
	ldx	[ %g2 + LDC_TARGET_GUEST ], %g6
	ldx	[ %g2 + LDC_TARGET_CHANNEL ], %g4
	mulx	%g4, LDC_ENDPOINT_SIZE, %g4
	set	GUEST_LDC_ENDPOINT, %g5
	add	%g6, %g5, %g6
	add	%g6, %g4, %g6			! g6 is the target endpoint
	ldx	[ %g6 + LDC_RX_QSIZE ], %g4	! check if queue is configured
	brnz,a,pn %g4, 1f
	  nop
	HCALL_RET(EOK)

	! %g2 = our endpoint
	! %g3 = guest struct
1:
	lduw	[ %g2 + LDC_TX_QHEAD ], %g6
	lduw	[ %g2 + LDC_TX_QTAIL ], %g4

	ldx	[ %g2 + LDC_TX_QSIZE ], %g5
	dec	Q_EL_SIZE, %g5
	add	%g4, Q_EL_SIZE, %g1
	and	%g1, %g5, %g1

	cmp	%g1, %g6			! Does TX queue have room?
	bne,pt	%xcc, 2f			! If so, continue.
	  nop

	! TX queue is full. Have we already marked it as such?
	ldub	[ %g2 + LDC_TXQ_FULL ], %g5
	set	1, %g6
	brz,a	%g5, 1b				! If not, mark it and try one
	   stb	%g6, [ %g2 + LDC_TXQ_FULL ]	! last time to avoid lost intr.

	ba	herr_wouldblock
	  nop
2:
	! %g2 = our endpoint
	! %g3 = guest struct

	ldx	[ %g2 + LDC_TX_QBASE_PA ], %g3
	add	%g4, %g3, %g4

	! %g1 = new tail value
	! %g2 = sender's endpoint
	! %g4 = pointer to outgoing queue entry

	set	LDC_CONSOLE_DATA, %g5
	stb	%g5, [%g4 + LDC_CONS_TYPE]
	mov	%g0, %g6
	add	%g4, LDC_CONS_PAYLOAD, %g3	! payload buffer
3:
	ldub	[%o0 + %g6], %g5
	stb	%g5, [%g3 + %g6]
	inc	%g6
	cmp	%g6, %o1			! copied all chars ?
	bgeu,pn	%xcc, 4f
	  nop
	cmp	%g6, LDC_CONS_PAYLOAD_SZ	! payload buf full ?
	bgeu,pn	%xcc, 4f
	  nop
	ba	3b				! store next char in pkt
	  nop	
4:
	mov	%g6, %o1			! return / store chars copied
	stb	%g6, [%g4 + LDC_CONS_SIZE]

	ldub	[ %g2 + LDC_TARGET_TYPE ], %g5
	cmp	%g5, LDC_GUEST_ENDPOINT
	be	%xcc, 3f
	  nop

	! %g1 = new tail value
	! %g2 = sender's endpoint

	HVCALL(guest_to_sp_tx_set_tail)		! clobbers all %g1,%g3-%g7
	ba	4f
	  nop
3:
	HVCALL(guest_to_guest_tx_set_tail)	! clobbers all %g1,%g3-%g7
4:
	! %g2 = sender's endpoint

	HCALL_RET(EOK)

	SET_SIZE(hcall_cons_write)


