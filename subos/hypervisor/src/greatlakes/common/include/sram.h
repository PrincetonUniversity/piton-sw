/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: sram.h
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

#ifndef	_SRAM_H
#define	_SRAM_H

#pragma ident	"@(#)sram.h	1.3	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * SRAM definitions
 */

#define	SRAM_PROTOCOL_VERSION	1

#define	SSI_BASE		0xfff0000000

#ifdef FALLS_FPGA
#define	SRAM_ADDR		(SSI_BASE + 0x0000e00000)
#define	SRAM_BOOTLOAD_PKT_OFFSET	0x100
#define	SRAM_SHARED_OFFSET		0x4000
#else
#define	SRAM_ADDR		(SSI_BASE + 0x0000800000)
#define	SRAM_BOOTLOAD_PKT_OFFSET	0x1a20
#define	SRAM_SHARED_OFFSET		0x0
#endif

#define	SRAM_RESET_CTL_OFFSET		0x8
#define	SRAM_RESET_CTL_LEN		0xc
#define	SRAM_RESET_DATA_OFFSET		0x10
#define	SRAM_RESET_DATA_LEN		0x14
#define	SRAM_HOST_LOG_OFFSET		0x18
#define	SRAM_HOST_LOG_LEN		0x1c
#define	SRAM_HOST_LOG_INSERT		0x20
#define	SRAM_HOST_LOG_MUTEX		0x24

#define	SRAM_MEMBASE			0x28
#define	SRAM_MEMSIZE			0x30
#define	SRAM_PARTITION_DESC_OFFSET	0x38


/*
 * Format of SRAM LOG entries are:
 * byte 0 = cpu id
 * byte 1 = message len n
 * next n bytes = message
 */

#define	SRAM_LOG_HDR_SIZE		2
#define	SRAM_MIN_MSG_SIZE		(SRAM_LOG_HDR_SIZE + 1)

/*
 * Define reset_control bits
 * bit 31    ACK/GO
 * bit 30    Error
 * bit 24-29 unused
 * bit 16-23 offset into data_blk for data related to cmd (in 8 byte increments)
 * bit 0-15  cmd
 */
#define	RESET_CTL_ACK_GO	31
#define	RESET_CTL_ERROR		30
#define	RESET_CTL_DATA		16
#define	RESET_CTL_CMD		0
#define	RESET_CMD_MASK		0xffff

#define	RESET_CMD_NOP		  0
#define	RESET_STATE_MACHINE	  1	! debug cmd to start reset state machine
#define	RESET_CMD_SIGNON	  2
#define	RESET_CMD_READ		  3
#define	RESET_CMD_WRITE		  4
#define	RESET_CMD_READ_ASI	  5
#define	RESET_CMD_WRITE_ASI	  6
#define	RESET_CMD_BOOTLOAD	  7

#define	RESET_CMD_START_CPU	  8
#define	RESET_CMD_IDLE_CPU	  9
#define	RESET_CMD_RESUME_CPU	  10

#define	RESET_CMD_INIT_REGFILE	  11		! all threads
#define	RESET_CMD_INIT_CLOCK	  12		! boot core
#define	RESET_CMD_CHANGE_SPEED	  13
#define	RESET_CMD_DO_RESET	  14
#define	RESET_CMD_L1_BIST	  15		! per core
#define	RESET_CMD_L2_BIST	  16		! boot core
#define	RESET_CMD_INIT_TLB	  17		! per core
#define	RESET_CMD_INIT_DRAM_CTL0  18		! boot core
#define	RESET_CMD_INIT_DRAM_CTL1  19		! boot core
#define	RESET_CMD_INIT_DRAM_CTL2  20		! boot core
#define	RESET_CMD_INIT_DRAM_CTL3  21		! boot core
#define	RESET_CMD_INIT_LSU	  22		! per core
#define	RESET_CMD_INIT_JBUS_CFG	  23		! boot core
#define	RESET_CMD_INIT_L2_CTL_REG 24		! boot core
#define	RESET_CMD_INIT_IOBRIDGE	  25		! boot core
#define	RESET_CMD_INIT_IOB	  26		! boot core
#define	RESET_CMD_INIT_SSI	  27		! boot core
#define	RESET_CMD_INIT_JBI	  28		! boot core
#define	RESET_CMD_INIT_L2_ERR	  29		! boot core
#define	RESET_CMD_INIT_INTR_QUEUE 30		! all threads
#define	RESET_CMD_INIT_MEM	  31
#define	RESET_CMD_INIT_DRAM_RFR	  32

#define	RESET_CMD_INIT_ICACHE_TAG 33		! per core
#define	RESET_CMD_INIT_DCACHE_TAG 34		! per core

#define	RESET_CMD_INIT_ICACHE	  35		! per core
#define	RESET_CMD_INIT_DCACHE	  36		! per core
#define	RESET_CMD_INIT_L2CACHE	  37		! boot core
#define	RESET_CMD_INIT_UART	  38		! debug
#define	RESET_CMD_COPY_RESET	  39		! copy reset code
#define	RESET_CMD_RESET_JUMP	  40		! make sram poller jump

#define	RESET_CMD_START_MASTER	  50
#define	RESET_CMD_START_SLAVE	  51

#define	RESET_CMD_START_MASTER_ADDR	100	! debug - pass addr to jump to
#define	RESET_CMD_START_SLAVE_ADDR	101	! debug - pass addr to jump to

#define	RESET_CMD_ITLBFIXUP	102
#define	RESET_CMD_DTLBFIXUP	103

#define	RESET_CMD_COMPLETED	0xffff

#ifdef __cplusplus
}
#endif

#endif	/* _SRAM_H */
