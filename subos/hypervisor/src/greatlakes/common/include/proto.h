/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: proto.h
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

#ifndef _PROTO_H
#define	_PROTO_H

#pragma ident	"@(#)proto.h	1.6	07/05/04 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASM

void init_strand(int i);
void init_hv_internals(void);
void init_dummytsb(void);
void init_plat_hook(void);
void reloc_devinstances(void);
void reloc_plat_devops(void);
void reloc_devopsvec(devopsvec_t *);
void *reloc_ptr(void *ptr);

void config_basics(void);
void commit_reconfig(void);

void c_printf(char *strp, ...);
void c_putn(uint64_t val, int base);
void c_bzero(void *ptr, uint64_t size);

void c_bootload(void);
void c_start(void);
hvctl_status_t c_guest_exit(guest_t *guestp, int reason);

void guest_state_notify(guest_t *guestp);

void spinlock_enter(volatile uint64_t *lock);
void spinlock_exit(volatile uint64_t *lock);

void c_ldc_send_sp_intr(struct sp_ldc_endpoint *target, int reason);

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif	/* _PROTO_H */
