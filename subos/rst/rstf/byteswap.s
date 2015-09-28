/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: byteswap.s
* Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
* DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
* 
* The above named program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License version 2 as published by the Free Software Foundation.
* 
* The above named program is distributed in the hope that it will be 
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
* 
* You should have received a copy of the GNU General Public
* License along with this work; if not, write to the Free Software
* Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
* 
* ========== Copyright Header End ============================================
*/
#if defined(ARCH_AMD64)

	.text
		
/*============================================================================*\
 * uint16_t byteswap16( uint16_t v )
\*============================================================================*/
	.align	16
	.globl	byteswap16
	.type	byteswap16, @function
byteswap16:
	movw	%di,%ax
	xchgb	%ah,%al
	ret
	.size	byteswap16, [.-byteswap16]
	
/*============================================================================*\
 * uint32_t byteswap32( uint32_t v )
\*============================================================================*/
	.align	16
	.globl	byteswap32

	.type	byteswap32, @function
byteswap32:
	movl	%edi,%eax
	bswapl	%eax
	ret
	.size	byteswap32, [.-byteswap32]
	
/*============================================================================*\
 * uint64_t byteswap64( uint64_t v )
\*============================================================================*/
	.align	16
	.globl	byteswap64
	.type	byteswap64, @function
byteswap64:
	movq	%rdi,%rax
	bswapq	%rax
	ret
	.size	byteswap64, [.-byteswap64]

#endif
