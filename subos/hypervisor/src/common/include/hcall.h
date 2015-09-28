/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall.h
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

#ifndef _HCALL_H
#define	_HCALL_H

#pragma ident	"@(#)hcall.h	1.2	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <guest.h>

/*
 * Macros for creating the table mapping api_group and version
 * numbers to specific sets of HV API calls.  The structure is meant
 * to be self-explanatory, but you might still do well to understand
 * hcall_api_set_version before you do anything beyond trivial to the
 * table.
 *
 * Rules for structuring the GROUP_* macros (this is a regular
 * language, if you really care about theory...):
 *
 *   GROUP_BEGIN -- start of one API group
 *     {
 *     GROUP_MAJOR_ENTRY -- one major number in the API group
 *       { GROUP_MINOR_ENTRY } + -- all the minor number call tables
 *       GROUP_MINOR_END -- end of minor number call tables
 *     } +
 *     GROUP_MAJOR_END -- end of the major number entries
 *
 *     {
 *       {
 *       GROUP_HCALL_TABLE -- one label for a minor number call table
 *         { GROUP_HCALL_ENTRY } + -- one call table entry
 *       } +
 *       GROUP_HCALL_END -- end of call table for this major number
 *     } +
 *   GROUP_END -- end of this API group
 */
/* BEGIN CSTYLED */

#define	GROUP_BEGIN(name, number)					\
hcall_api_group_/**/name:						;\
    	.word	number							;\
	.word	hcall_api_group_/**/name/**/_end - hcall_api_group_/**/name

#define	GROUP_END(name)							\
hcall_api_group_/**/name/**/_end:

#define	GROUP_MAJOR_ENTRY(name, major, max_minor)			\
	/* name not used in this case */				;\
	.xword	MAKE_VERSION(major, max_minor)

#define	GROUP_MAJOR_END(name)						\
	GROUP_MAJOR_ENTRY(name, 0, 0)

#define	GROUP_MINOR_ENTRY(name)						\
	.xword	hcall_table_/**/name

#define	GROUP_MINOR_END(name)						\
	.xword	hcall_table_/**/name

#define	GROUP_HCALL_TABLE(name)						\
hcall_table_/**/name:

#define	GROUP_HCALL_ENTRY(number, function)				\
	.xword	number, function

#define	GROUP_HCALL_END(name)						\
hcall_table_/**/name:

/* END CSTYLED */

/*
 * Constants below relate to the entries defined by
 * GROUP_HCALL_ENTRY.  Each entry contains a function number and an
 * unrelocated function label.
 *
 * HCALL_ENTRY_INDEX -
 *	Offset of the function number within the entry.
 *
 * HCALL_ENTRY_LABEL -
 *	Offset of the function address within the entry.
 *
 * HCALL_ENTRY_SIZE -
 *	Size of one function entry in bytes.
 */
#define	HCALL_ENTRY_INDEX	0
#define	HCALL_ENTRY_LABEL	8
#define	HCALL_ENTRY_SIZE	16

/*
 * UPDATE_HCALL_TARGET - update the branch target for an API call
 *
 * tbl - address of the fast_trap branch table in memory
 * fn - fast_trap function# (clobbered)
 * tgt - target address for the selected branch table entry
 */
/* BEGIN CSTYLED */

#define	UPDATE_HCALL_TARGET(tbl, fn, tgt)			\
	sllx	fn, API_ENTRY_SIZE_SHIFT, fn			;\
	stx	tgt, [tbl + fn]

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _HCALL_H */
