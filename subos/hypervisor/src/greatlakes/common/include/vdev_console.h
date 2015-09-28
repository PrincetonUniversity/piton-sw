/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vdev_console.h
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

#ifndef _VDEV_CONSOLE_H
#define	_VDEV_CONSOLE_H

#pragma ident	"@(#)vdev_console.h	1.7	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	CONS_TYPE_UNCONFIG	0x0
#define	CONS_TYPE_LDC		0x1
#ifdef CONFIG_CN_UART
#define	CONS_TYPE_UART		0x2
#endif

/*
 * LDC based console status values
 *   The status field is a bit field where each bit
 *   corresponds to a state
 */
#define	LDC_CONS_READY		0x1
#define	LDC_CONS_BREAK		0x2
#define	LDC_CONS_HUP		0x4

#define	CONS_INBUF_ENTRIES	64
#define	CONS_INBUF_SIZE		(CONS_INBUF_ENTRIES*8)

/*
 * LDC console pkt format
 *
 *             6                      3             1 1
 *             3                      2             6 5      8 7     0
 *            +------------------------+-------------+--------+-------+
 *  word 0:   |        ctrl_msg        |    unused   |  size  | type  |
 *            +------------------------+-------------+--------+-------+
 *  word 1-6: |                    payload                            |
 *            +-------------------------------------------------------+
 */

/*
 * LDC Console msg type
 */
#define	LDC_CONSOLE_CONTROL	0x1
#define	LDC_CONSOLE_DATA	0x2

#define	LDC_CONS_PAYLOAD_SZ	56

#ifndef _ASM
struct ldc_conspkt {
	uint8_t		type;		/* packet type */
	uint8_t		size;		/* num chars in payload */
	uint16_t	rsvd;
	uint32_t	ctrl_msg;	/* control message */
	uint8_t		payload[LDC_CONS_PAYLOAD_SZ];
};


/*
 * Info to help with (re)configuration
 */

typedef struct {
	resource_t	res;
	uint8_t		type;
	uint8_t		ino;	/* virtual device ino */
	int		ldc_channel;
#ifdef CONFIG_CN_UART
	uint64_t	uartbase;
#endif
} console_parse_info_t;


/*
 * Guest console structure
 */
struct console {
	uint8_t		type;		/* type of console */

	console_parse_info_t	pip;
#ifdef CONFIG_CN_UART
	/*
	 * UART based console (primarily for Legion at this point)
	 */
	uint64_t	uartbase;		/* console base address */
#endif
	/*
	 * LDC based console
	 */
	uint8_t		status;				/* Console status */
	uint64_t	endpt;				/* HV LDC Endpt */
	uint64_t	in_head;			/* Incoming buf head */
	uint64_t	in_tail;			/* Incoming buf tail */
	vdev_mapreg_t	*vintr_mapreg;			/* for guest intr */
	uint64_t	in_buf[CONS_INBUF_ENTRIES];	/* Incoming buffer */
};

	/*
	 * Support functions for console resource
	 */

extern void init_consoles();

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _VDEV_CONSOLE_H */
