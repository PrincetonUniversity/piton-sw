/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall.s
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

	.ident	"@(#)hcall.s	1.99	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <asi.h>
#include <guest.h>
#include <offsets.h>
#include <util.h>
#include <debug.h>
#include <hcall.h>

/*
 * hcall_core - Entry point for CORE_TRAP hcalls
 *
 * These calls are unversioned, and universal to all guests.  They
 * represent key functionality that a guest must have available
 * even if API versions have not been negotiated.
 *
 * Calling conventions are identical to the FAST_TRAP conventions
 * described for hcall, below.
 */
	ENTRY_NP(hcall_core)
	cmp	%o5, (.core_end - .core_table) / 4	! in table?
	bgeu,pn	%xcc, herr_badtrap			! no, error
	sllx	%o5, 2, %g2				! scaled index
	LABEL_ADDRESS(.core_table, %g1)			! &core_table
	jmp	%g1 + %g2				! ... and go!
	nop

.core_table:
	ba,a,pt	%xcc, hcall_api_set_version		! 0x00
	ba,a,pt	%xcc, hcall_cons_putchar		! 0x01
	ba,a,pt	%xcc, hcall_mach_exit			! 0x02
	ba,a,pt	%xcc, hcall_api_get_version		! 0x03
.core_end:
	SET_SIZE(hcall_core)


/*
 * hcall - Entry point for FAST_TRAP hcalls
 *
 * function# (%o5) - number of the specific API function to be invoked
 * arg0-arg4 (%o0-%o4) arguments to the function
 * --
 * ret0 (%o0) status (EOK, or an error code)
 * ret1-ret5 (%o1-%o5) return values
 *
 * This code has access to fresh g-registers for scratch.  %o5 is
 * also legal for scratch, but the calling conventions require all
 * other o-registers to be preserved unless the specific call uses
 * the register either as an input or output argument.
 */
	ENTRY_NP(hcall)
	GUEST_STRUCT(%g2)
	ldx	[%g2 + GUEST_HCALL_TABLE], %g2

	cmp	%o5, MAX_FAST_TRAP_VALUE
	bleu,pt	%xcc, 0f
	sllx	%o5, API_ENTRY_SIZE_SHIFT, %g1

	sub	%o5, MAX_FAST_TRAP_VALUE, %g1
	sllx	%g1, API_ENTRY_SIZE_SHIFT, %g1
0:
	ldx     [%g2 + %g1], %g2
	jmp	%g2
	nop
	SET_SIZE(hcall)

/*
 * api_set_version - select API version
 *
 * arg0 (%o0) api_group
 * arg1 (%o1) major_version
 * arg2 (%o2) minor_version
 * --
 * ret0 (%o0) status
 * ret1 (%o1) actual_minor
 */
	ENTRY_NP(hcall_api_set_version)
	GUEST_STRUCT(%g2)
	add	%g2, GUEST_API_GROUPS, %g2	! %g2 = &guest->api_groups

	/*
	 * API_GROUP_SUN4V is special.  There are no API calls
	 * associated with this group.  Instead, each major version
	 * in the api_group corresponds to a set of known CPU errata
	 * that the guest must work around.  The meaning of minor
	 * numbers other than zero isn't defined; we're explicitly
	 * ignoring the passed in minor version.
	 *
	 * Note we store the major and minor numbers for
	 * API_GROUP_SUN4V for the api_get_version call, same as for
	 * any other API group.  The index is the first entry in the
	 * guest's local info table.
	 */
	cmp	%o0, API_GROUP_SUN4V		! check for the special group
	bne,pt	%xcc, 0f			! not special, skip it
	cmp	%o1, SUN4V_VERSION_INITIAL	! check if supported
	bne,pt	%xcc, herr_notsupported		! unknown major
	nop

	ba,pt	%xcc, .storeversion		! return success
	mov	0, %o2				! ... with minor number 0

0:

	/*
	 * Look up the table entry for the guest's requested
	 * api_group.
	 *
	 * We're calculating addresses in two tables:
	 * hcall_api_group_map (store in %g1), and the api_groups
	 * table in the guest structure (store in %g2).
	 */
	setx	hcall_api_group_map, %g3, %g1	! %g1 = api mapping table
	ROOT_STRUCT(%g3)			! address of config struct
	ldx	[%g3 + CONFIG_RELOC], %g3	! ... for relocation offset
	sub	%g1, %g3, %g1			! relocated table address

0:
	lduw	[%g1+4], %g4			! offset to next group entry
	lduw	[%g1], %g3			! api group number
	inc	VERSION_SIZE, %g2		! next api_groups entry
	brz	%g4, herr_inval			! EINVAL if end of table
	cmp	%g3, %o0			! is this the one?
	bne,a,pt %xcc, 0b			! ... no, keep looking
	  add	%g1, %g4, %g1			! next API group entry


	/*
	 * Register usage at this point:
	 *   %o0-%o2 - HCALL arguments
	 *   %g1 - pointer to the api_group entry in the mapping
	 *         table
	 *   %g2 - pointer to the entry in guest->api_groups
	 *
	 * We have the information for the requested api_group.  Our
	 * next step is to scan this api_group's entry to see if the
	 * requested major version is supported.  If it is, check
	 * the maximum minor version we can handle, and if necessary
	 * adjust the guest's request.
	 *
	 * As a special case, if the requested major_version is 0,
	 * we disable the entire API group.  There are checks here
	 * and in other places below.  The checks aren't optional,
	 * because the VERSION_PTR for the API group isn't valid in
	 * this case.  It's a bit hairy, so stay sharp out there.
	 */
	brnz,pt	%o1, .findmajor		! must search if major_version != 0
	inc	8, %g1			! advance to version info

	! major_version == 0 means disable the api_group
	mov	0, %g1			! ... to be stored in guest struct
	ba,pt	%xcc, .check_disable
	mov	0, %o2			! ... to be stored in guest struct
					! (and returned to guest)


0:
	brz,pn	%g3, herr_notsupported		! not found, ENOTSUPPORTED
	inc	3, %g4				! version plus first two xwords
	sllx	%g4, 3, %g4			! scale index
	add	%g1, %g4, %g1			! skip over minor version data
.findmajor:
	lduw	[%g1 + MAJOR_OFF], %g3		! get major number from table
	cmp	%g3, %o1			! is it a match?
	bne,pt	%xcc, 0b			! no, keep looking
	lduw	[%g1 + MINOR_OFF], %g4		! get minor number from table


	! Found the requested major number; check the requested
	! minor number
	cmp	%g4, %o2		! minor number supported?
	movlu	%xcc, %g4, %o2		! no, downgrade the request
	inc	8, %g1			! advance to minor version list


	/*
	 * Register usage at this point:
	 *   %o0-%o2 - HCALL arguments
	 *   %g1 - pointer to the list of minor version table
	 *         addresses
	 *   %g2 - pointer to the entry in guest->api_groups
	 *
	 * We've found the info for the major number being requested
	 * by the guest.
	 *
	 * Next big step, figure out if the guest's request is going
	 * to disable or enable any API functions.
	 *
	 * A picture to help explain the ubiquitous +1 found in all
	 * the index calculations below:
	 *           +--------------------------------------------+
	 * 1.0 ->    |        ... 1.0 entries here ...            |
	 *           +--------------------------------------------+
	 *           |       ... post 1.0 entries here ...        |
	 *           +--------------------------------------------+
	 * 1.old->   |   ... 1.old entries here are in use ...    |
	 *           +--------------------------------------------+
	 * 1.old+1-> |    ... from here on must be enabled ...    |
	 *           +--------------------------------------------+
	 *           |     ... after 1.old, before 1.new ...      |
	 *           +--------------------------------------------+
	 * 1.new->   | ... 1.new entries here must be enabled ... |
	 *           +--------------------------------------------+
	 * 1.new+1-> |     ... stop enabling from here on ...     |
	 *           +--------------------------------------------+
	 *
	 * This picture applies to the case where the major number
	 * isn't changing, and the minor number is increasing.
	 *
	 * Similar pictures apply to the other cases; drawing them
	 * is left as an exercise for the reader.
	 */
.check_disable:
	lduw	[%g2 + VERSION_MAJOR], %g3	! old major number
	cmp	%g3, %o1			! changing major numbers?
	be,pt	%xcc, .check_minor		! no, next check
	lduw	[%g2 + VERSION_MINOR], %g5	! guest's old minor number

	! We're changing major numbers, disable everything in the
	! old group
	brz,pt	%g3, .check_enable		! nothing to disable if was 0.0
	ldx	[%g2 + VERSION_PTR], %g4	! guest's old table entry
	ldx	[%g4], %g3			! disable start addr
	inc	%g5				! old_minor+1
	sllx	%g5, 3, %g5			! ... scaled
	ba,pt	%xcc, .do_disable
	ldx	[%g4 + %g5], %g4		! disable end addr

.check_minor:
	! We're not changing the major number; if the major
	! number was zero, we're done.
	brz	%g3, .storeversion
	! Otherwise, check whether the guest is changing its minor
	! number (delay slot)
	cmp	%g5, %o2			! changing?

	be,pn	%xcc, .storeversion		! no, we're done
	inc	%g5				! old_minor+1
	add	%o2, 1, %g6			! new_minor+1
	sllx	%g5, 3, %g5
	bgu,pn	%xcc, 0f			! old > new, downgrading
	sllx	%g6, 3, %g6

	! We're upgrading from a lower minor number to a higher one.
	ldx	[%g1 + %g5], %g3		! enable from old_minor+1
	ba,pt	%xcc, .do_enable
	ldx	[%g1 + %g6], %g4		! ... to new_minor+1

0:
	! We're downgrading from a higher minor number to a lower
	ldx	[%g1 + %g6], %g3		! disable from new_minor+1
	ldx	[%g1 + %g5], %g4		! ... to old_minor+1


	/*
	 * Register usage at this point:
	 *   %o0-%o2 - HCALL arguments
	 *   %g1 - pointer to the list of minor version table
	 *         addresses
	 *   %g2 - pointer to the entry in guest->api_groups
	 *   %g3 - starting address of list of hcall functions to be
	 *         disabled (unrelocated)
	 *   %g4 - ending address of list of hcall functions to be
	 *         disabled (unrelocated)
	 *
	 * Disable the entries indicated by the starting and ending
	 * addresses in %g3 and %g4.
	 */
.do_disable:
	dec	HCALL_ENTRY_SIZE - HCALL_ENTRY_INDEX, %g4
	sub	%g3, %g4, %g3			! adjust for loop check
	LABEL_ADDRESS(herr_badtrap, %g5)
	GUEST_STRUCT(%g7)
	ldx	[%g7 + GUEST_HCALL_TABLE], %g7	! hcall table address
	ROOT_STRUCT(%g6)
	ldx	[%g6 + CONFIG_RELOC], %g6
	sub	%g4, %g6, %g4			! relocate end address

0:
	ldx	[%g3 + %g4], %g6		! function index
			!   tbl, fn,  tgt
	UPDATE_HCALL_TARGET(%g7, %g6, %g5)
	brlz,pt	%g3, 0b
	inc	HCALL_ENTRY_SIZE, %g3


	/*
	 * Register usage at this point:
	 *   %o0-%o2 - HCALL arguments
	 *   %g1 - pointer to the list of minor version table
	 *         addresses
	 *   %g2 - pointer to the entry in guest->api_groups
	 *
	 * We've finished disabling any calls that won't be
	 * available.  If the new major version is 0, then we're done.
	 */
	brz,pn	%o1, .storeversion		! done if major_version==0
	.empty
.check_enable:
	add	%o2, 1, %g5
	sllx	%g5, 3, %g5			! (minor_version+1)*8
	ldx	[%g1], %g3			! enable start addr
	ldx	[%g1 + %g5], %g4		! enable end addr


	/*
	 * Register usage at this point:
	 *   %o0-%o2 - HCALL arguments
	 *   %g1 - pointer to the list of minor version table
	 *         addresses
	 *   %g2 - pointer to the entry in guest->api_groups
	 *   %g3 - starting address of list of hcall functions to be
	 *         enabled (unrelocated)
	 *   %g4 - ending address of list of hcall functions to be
	 *         enabled (unrelocated)
	 *
	 * Enable the entries indicated by the starting and ending
	 * addresses in %g3 and %g4.
	 */
.do_enable:
	dec	HCALL_ENTRY_SIZE - HCALL_ENTRY_INDEX, %g4
	GUEST_STRUCT(%g7)
	ldx	[%g7 + GUEST_HCALL_TABLE], %g7	! hcall table address
	ROOT_STRUCT(%g6)
	ldx	[%g6 + CONFIG_RELOC], %g6
	sub	%g3, %g6, %g3			! relocate start address
	sub	%g4, %g6, %g4			! relocate end address

0:
	ldx	[%g3 + HCALL_ENTRY_INDEX], %g6	! function index
	ldx	[%g3 + HCALL_ENTRY_LABEL], %g5	! target address
	ROOT_STRUCT(%o0)
	ldx	[%o0 + CONFIG_RELOC], %o0
	sub	%g5, %o0, %g5			! relocated target
	UPDATE_HCALL_TARGET(%g7, %g6, %g5)
	cmp	%g3, %g4
	bne,pt	%xcc, 0b
	inc	HCALL_ENTRY_SIZE, %g3

.storeversion:
	sllx	%o1, MAJOR_SHIFT, %g3
	or	%o2, %g3, %g3
	stx	%g3, [%g2 + VERSION_NUM]
	stx	%g1, [%g2 + VERSION_PTR]
	mov	%o2, %o1
	HCALL_RET(EOK)

	SET_SIZE(hcall_api_set_version)


/*
 * api_get_version - select API version
 *
 * arg0 (%o0) api_group
 * --
 * ret0 (%o0) status
 * reg1 (%o1) major_version
 * reg2 (%o2) minor_version
 */
	ENTRY_NP(hcall_api_get_version)
	GUEST_STRUCT(%g2)
	add	%g2, GUEST_API_GROUPS, %g2	! %g2 = guest's local table

	/*
	 * Check for API_GROUP_SUN4V.  This API group number isn't
	 * in the mapping table; the version info for this API group
	 * is the first entry in the guest's local info table.
	 */
	cmp	%o0, API_GROUP_SUN4V		! check for the special group
	be,pn	%xcc, .getversion		! special, we have the address
	nop

	/*
	 * Look up the table entry for the guest's requested
	 * api_group.
	 *
	 * There are two tables: the global table that maps API
	 * groups onto available API functions, and the guest's
	 * local table that indicates what version the guest has
	 * selected for each API group.
	 */
	setx	hcall_api_group_map, %g3, %g1	! %g1 = api mapping table
	ROOT_STRUCT(%g3)			! address of config struct
	ldx	[%g3 + CONFIG_RELOC], %g3	! ... for relocation offset
	sub	%g1, %g3, %g1			! relocated table address

0:
	lduw	[%g1+4], %g4			! offset to next group entry
	lduw	[%g1], %g3			! api group number
	inc	VERSION_SIZE, %g2		! next api_groups entry
	brz	%g4, herr_inval			! EINVAL if end of table
	cmp	%g3, %o0			! is this the one?
	bne,a,pt %xcc, 0b			! ... no, keep looking
	  add	%g1, %g4, %g1			! next API group entry


.getversion:
	ldx	[%g2 + VERSION_NUM], %g3
	srlx	%g3, MAJOR_SHIFT, %o1
	sllx	%g3, 64-MAJOR_SHIFT, %g3
	srlx	%g3, 64-MAJOR_SHIFT, %o2
	HCALL_RET(EOK)

	SET_SIZE(hcall_api_get_version)


/*
 * Common error escapes so errors can be implemented by
 * cmp, branch.
 */
	ENTRY(hret_ok)
	HCALL_RET(EOK)
	SET_SIZE(hret_ok)

	ENTRY(herr_nocpu)
	HCALL_RET(ENOCPU)
	SET_SIZE(herr_nocpu)

	ENTRY(herr_noraddr)
	HCALL_RET(ENORADDR)
	SET_SIZE(herr_noraddr)

	ENTRY(herr_nointr)
	HCALL_RET(ENOINTR)
	SET_SIZE(herr_nointr)

	ENTRY(herr_badpgsz)
	HCALL_RET(EBADPGSZ)
	SET_SIZE(herr_badpgsz)

	ENTRY(herr_badtsb)
	HCALL_RET(EBADTSB)
	SET_SIZE(herr_badtsb)

	ENTRY(herr_inval)
	HCALL_RET(EINVAL)
	SET_SIZE(herr_inval)

	ENTRY(herr_badtrap)
	HCALL_RET(EBADTRAP)
	SET_SIZE(herr_badtrap)

	ENTRY(herr_badalign)
	HCALL_RET(EBADALIGN)
	SET_SIZE(herr_badalign)

	ENTRY(herr_wouldblock)
	HCALL_RET(EWOULDBLOCK)
	SET_SIZE(herr_wouldblock)

	ENTRY(herr_noaccess)
	HCALL_RET(ENOACCESS)
	SET_SIZE(herr_noaccess)

	ENTRY(herr_ioerror)
	HCALL_RET(EIO)
	SET_SIZE(herr_ioerror)

	ENTRY(herr_cpuerror)
	HCALL_RET(ECPUERROR)
	SET_SIZE(herr_cpuerror)

	ENTRY(herr_toomany)
	HCALL_RET(ETOOMANY)
	SET_SIZE(herr_toomany)

	ENTRY(herr_nomap)
	HCALL_RET(ENOMAP)
	SET_SIZE(herr_nomap)

	ENTRY(herr_notsupported)
	HCALL_RET(ENOTSUPPORTED)
	SET_SIZE(herr_notsupported)

	ENTRY(herr_invalchan)
	HCALL_RET(ECHANNEL)
	SET_SIZE(herr_invalchan)

#ifdef CONFIG_VERSION_TEST
	/*
	 * Test API calls to go with test API group 0x400 above.
	 */

/****
    \ Cut and paste this at ok prompt if you want to test

    hex
    2 3 0 7f hypercall: api-set-version
    3 1 3 7f hypercall: api-get-version
    1 0 4 7f hypercall: bad-core4
    1 0 -1 7f hypercall: bad-core-1
    2 0 e0 0 hypercall: version-e0
    2 0 e1 0 hypercall: version-e1
    2 0 e2 0 hypercall: version-e2
    2 0 e3 0 hypercall: version-e3

    : test-api ( mjr mnr -- )
	swap 400 api-set-version ." set-version: " . . cr
	400 api-get-version ." get-version: " . . . cr
	version-e0 ." e0: " . . cr
	version-e1 ." e1: " . . cr
	version-e2 ." e2: " . . cr
	version-e3 ." e3: " . . cr
    ;
****/

	ENTRY(hcall_version_test_1_0)
	mov	0x10, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_version_test_1_0)

	ENTRY(hcall_version_test_1_1)
	mov	0x11, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_version_test_1_1)

	ENTRY(hcall_version_test_1_2)
	mov	0x12, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_version_test_1_2)

	ENTRY(hcall_version_test_2_0)
	mov	0x20, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_version_test_2_0)

	ENTRY(hcall_version_test_2_1)
	mov	0x21, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_version_test_2_1)

	ENTRY(hcall_version_test_2_2)
	mov	0x22, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_version_test_2_2)

	ENTRY(hcall_version_test_3_0)
	mov	0x30, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_version_test_3_0)
#endif
