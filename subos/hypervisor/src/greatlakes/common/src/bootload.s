/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: bootload.s
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

	.ident	"@(#)bootload.s	1.2	07/05/03 SMI"

	.file	"bootload.s"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <sys/stack.h>
#include <asi.h>
#include <debug.h>
#include <abort.h>
#include <offsets.h>
#include <util.h>
#include <sram.h>

#define BLOCK_SIZE	512
#define HDR_SIZE	32
#define HDR_ADDR	0
#define HDR_ACK		(HDR_ADDR+8)
#define HDR_SUM		(HDR_ACK+4)
#define HDR_TAG		(HDR_SUM+2)
#define HDR_DATA	(HDR_SIZE)
#define	BOOTLOAD_READY	1
#define	BOOTLOAD_DONE	-1

	! support the SC->memory loader protocol
	! to ACK a packet we write HDR_ACK = (TAG << 16 | SUM)
	! when HDR_ACK returns to 0 we have more data.
	! if HDR_ACK == -1 (32bits) then we are all finished
	! if HDR_ACK < 0 then abort.

#define r_tmp0	%o0
#define r_tmp1	%o1
#define r_tmp2	%o2
#define r_tdat	%o3
#define r_tmp4	%o4
#define r_sram	%l7
#define r_dram	%l6
#define r_dest	%l5
#define r_src	%l4
#define r_bytes	%l3
#define r_block	%l2
#define r_sum	%l1

	ENTRY(bootload)
	setx	SRAM_ADDR + SRAM_SHARED_OFFSET, r_tmp0, r_sram	! SRAM base
	set	SRAM_BOOTLOAD_PKT_OFFSET, r_tmp1 ! bootload packet offset 
	add	r_sram, r_tmp1, r_sram
	set	BOOTLOAD_READY, r_tmp0
	stuw	r_tmp0, [r_sram + HDR_ACK]
do_xfer:
	ldsw	[r_sram + HDR_ACK], r_tmp0
	cmp	r_tmp0, BOOTLOAD_DONE
	beq,pn	%xcc, xfer_done
	  mov	BLOCK_SIZE, r_bytes
	brz,pt	r_tmp0, begin_copy
	  ldx	[r_sram + HDR_ADDR], r_dest
	cmp	r_tmp0, 0
	bpos,pt %xcc, do_xfer
	  nop
	HVABORT(-1, "MD download aborted by SP")
begin_copy:
	mov	%g0, r_sum
	! accumulate header in checksum - only addr, tag and r_sum
	ldx	[r_sram + HDR_ADDR], r_tdat

	srlx	r_tdat, 48, r_tmp0
	add	r_tmp0, r_sum, r_sum
	sllx	r_tdat, 16, r_tmp0
	srlx	r_tmp0, 48, r_tmp0
	add	r_tmp0, r_sum, r_sum
	sllx	r_tdat, 32, r_tmp0
	srlx	r_tmp0, 48, r_tmp0
	add	r_tmp0, r_sum, r_sum
	sllx	r_tdat, 48, r_tmp0
	srlx	r_tmp0, 48, r_tmp0
	add	r_tmp0, r_sum, r_sum

	lduh	[r_sram + HDR_TAG], r_tmp0
	lduh	[r_sram + HDR_SUM], r_tmp1
	add	r_tmp0, r_sum, r_sum
	add	r_tmp1, r_sum, r_sum
	add	r_sram, HDR_DATA, r_src
do_copy:
	! copy data to ram and accumulate in checksum
	ldx	[r_src], r_tdat
	stx	r_tdat, [r_dest]

	srlx	r_tdat, 48, r_tmp0
	add	r_tmp0, r_sum, r_sum
	sllx	r_tdat, 16, r_tmp0
	srlx	r_tmp0, 48, r_tmp0
	add	r_tmp0, r_sum, r_sum
	sllx	r_tdat, 32, r_tmp0
	srlx	r_tmp0, 48, r_tmp0
	add	r_tmp0, r_sum, r_sum
	sllx	r_tdat, 48, r_tmp0
	srlx	r_tmp0, 48, r_tmp0
	add	r_tmp0, r_sum, r_sum

	add	r_dest, 8, r_dest
	subcc	r_bytes, 8, r_bytes
	bne,pt	%xcc, do_copy
	  add	r_src, 8, r_src
1:	srl	r_sum, 16, r_tmp0	! get upper 16 bits
	sll	r_sum, 16, r_sum
	srl	r_sum, 16, r_sum	! chuck upper 16 bits
	brnz,pt	r_tmp0, 1b
	  add	r_tmp0, r_sum, r_sum
	sub	%g0, 1, r_tmp1
	srl	r_tmp1, 16, r_tmp1	! 0xffff
	xor	r_sum, r_tmp1, r_sum 
	lduh	[r_sram + HDR_TAG], r_tmp2
	sllx	r_tmp2, 16, r_tmp2
	or	r_tmp2, r_sum, r_tmp2
	ba	do_xfer
	  st	r_tmp2, [r_sram + HDR_ACK]
xfer_done:
	HVRET
	SET_SIZE(bootload)

	/*
	 * Wrapper around bootload, so it can be called from C.
	 * SPARC ABI requries only that g2,g3,g4 are preserved across
	 * function calls.
	 *
	 * void c_bootload(void)
	 */

	ENTRY(c_bootload)

#ifndef CONFIG_FPGA
	retl
	nop
#else

	save	%sp, -SA(MINFRAME), %sp

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

	HVCALL(bootload)

	STRAND_POP(%g4, %g6)
	STRAND_POP(%g3, %g6)
	STRAND_POP(%g2, %g6)

	ret
	restore
#endif
	SET_SIZE(c_bootload)
