/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mau_api.h
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

#ifndef _MAU_API_H
#define	_MAU_API_H

#pragma ident	"@(#)mau_api.h	1.1	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASM
/* Forward typedefs */
typedef union ma_ctl		ma_ctl_t;
typedef union ma_mpa		ma_mpa_t;
typedef union ma_ma		ma_ma_t;
typedef uint64_t		ma_np_t;

/*
 * Modulare Arithmetic Unit (MA) control register definition.
 */
union ma_ctl {
	uint64_t	value;
	struct {
		uint64_t	reserved1:50;
		uint64_t	invert_parity:1;
		uint64_t	thread:2;
		uint64_t	busy:1;
		uint64_t	interrupt:1;
		uint64_t	operation:3;
		uint64_t	length:6;
	} bits;
};
#endif	/* _ASM */

/* Values for ma_ctl operation field */
#define	MA_OP_LOAD		0x0
#define	MA_OP_STORE		0x1
#define	MA_OP_MULTIPLY		0x2
#define	MA_OP_REDUCE		0x3
#define	MA_OP_EXPONENTIATE	0x4

#define	MA_WORDS2BYTES_SHIFT	3	/* log2(sizeof(uint64_t)) */

/* The MA memory is 1280 bytes (160 8 byte words) */
#define	MA_SIZE		1280

/* We can only load 64 8 byte words at a time */
#define	MA_LOAD_MAX	64

#ifndef _ASM
union ma_mpa {
	uint64_t	value;
	struct {
		uint64_t	reserved0:24;
		uint64_t	address:37;
		uint64_t	reserved1:3;
	} bits;
};

union ma_ma {
	uint64_t	value;
	struct {
		uint64_t	reserved0:16;
		uint64_t	address5:8;
		uint64_t	address4:8;
		uint64_t	address3:8;
		uint64_t	address2:8;
		uint64_t	address1:8;
		uint64_t	address0:8;
	} bits;
};

#endif	/* _ASM */

#ifdef __cplusplus
}
#endif

#endif /* _MAU_API_H */
