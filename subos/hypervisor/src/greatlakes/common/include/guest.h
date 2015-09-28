/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: guest.h
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

#ifndef _GUEST_H
#define	_GUEST_H

#pragma ident	"@(#)guest.h	1.58	07/06/04 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <hypervisor.h>
#include <sys/htypes.h>
#include <vdev_console.h>
#ifdef CONFIG_DISK
#include <vdev_simdisk.h>
#endif /* CONFIG_DISK */

#ifdef T1_FPGA_SNET
#include <vdev_snet.h>
#endif

#include <ldc.h>
#include <hvctl.h>
#include <platform/guest.h>

/*
 * This file contains definitions of the state structures for guests
 * and physical processors.
 */

/*
 * Value of MAX_LDC_CHANNELS arbitrary number for now, but must
 * kept in sync with Zeus PRI
 */
#define	MAX_LDC_CHANNELS	256

/*
 * Value of MAX_LDC_INOS arbitrary number for now, but must
 * kept in sync with Zeus PRI
 */
#define	MAX_LDC_INOS	(2 * MAX_LDC_CHANNELS)

/*
 * Various constants associated with the guest's API version
 * configuration.
 *
 * The guest's hcall table is an array of branch instructions.
 * Most of the API calls in the table are indexed by the FAST_TRAP
 * function number associated with the call.  The last five
 * calls are indexed by unique indexes.  Here's the overall
 * layout:
 *      +-----------------------+ --
 *      | FAST_TRAP function #0 |   \
 *      +-----------------------+    \
 *      | FAST_TRAP function #1 |     \
 *      +-----------------------+     |
 *      |          ...          |     |
 *      +-----------------------+     |
 *      |  MAX_FAST_TRAP_VALUE  |     |
 *      +-----------------------+      \
 *      |    DIAG_RA2PA_IDX     |       - NUM_API_CALLS
 *      +-----------------------+      /
 *      |    DIAG_HEXEC_IDX     |     |
 *      +-----------------------+     |
 *      |   MMU_MAP_ADDR_IDX    |     |
 *      +-----------------------+     |
 *      |  MMU_UNMAP_ADDR_IDX   |     /
 *      +-----------------------+    /
 *      |  TTRACE_ADDENTRY_IDX  |   /
 *      +-----------------------+ --
 *
 * Other important constants:
 *
 * NUM_API_GROUPS - The size of the "api_versions" table in the
 *     guest structure.  One more than the number of entries in the
 *     table in hcall.s, to account for API_GROUP_SUN4V.
 *     (defined in <platform/guest.h> )
 *
 * API_ENTRY_SIZE_SHIFT -
 * API_ENTRY_SIZE - Size of one entry in the API table.  Entries are
 *     unconditional branch instructions, so they occupy 4 bytes.
 *
 * HCALL_TABLE_SIZE - Total size in bytes of the hcall table for one
 *     guest.  The size is rounded up to align to the L2$ line size.
 */

#define	MAX_FAST_TRAP_VALUE	0x201
#define	MMU_MAP_ADDR_IDX	(MAX_FAST_TRAP_VALUE+1)
#define	MMU_UNMAP_ADDR_IDX	(MAX_FAST_TRAP_VALUE+2)
#define	TTRACE_ADDENTRY_IDX	(MAX_FAST_TRAP_VALUE+3)
#define	NUM_API_CALLS		(MAX_FAST_TRAP_VALUE+4)

#define	API_ENTRY_SIZE_SHIFT	SHIFT_LONG
#define	API_ENTRY_SIZE		(1 << API_ENTRY_SIZE_SHIFT)

/*
 * ROUNDUP - round "n" up to the next value for which
 * "(n & (align-1))" is zero.  Only works if "align" is a power of
 * two.
 */
#define	ROUNDUP(n, align)	(((n) + (align) - 1) & ~((align)-1))

#define	HCALL_TABLE_SIZE	\
	ROUNDUP(NUM_API_CALLS * API_ENTRY_SIZE, L2_LINE_SIZE)


/*
 * Constants relating to the internal representation of version
 * numbers.
 */
#define	MAJOR_OFF		0
#define	MINOR_OFF		4
#define	MAJOR_SHIFT		32
#define	MAKE_VERSION(maj, min)	(((maj)<<MAJOR_SHIFT)+(min))


#define	NVCPU_XWORDS	((NVCPUS + 63) / 64) /* Num words for bit mask */
#define	MAPPING_XWORD_SHIFT	6
#define	MAPPING_XWORD_BYTE_SHIFT_BITS				\
	(MAPPING_XWORD_SHIFT-3)	/* shift for num bytes in each XWORD */
#define	MAPPING_XWORD_SIZE					\
	(1<<MAPPING_XWORD_BYTE_SHIFT_BITS)	/* num bytes in each XWORD */
#define	MAPPING_XWORD_MASK					\
	((1<<MAPPING_XWORD_SHIFT)-1)	/* Mask for bit index in XWORD */

/*
 * Internal guest states.
 */
#define	GUEST_STATE_STOPPED		0x0	/* dead pending restart */
#define	GUEST_STATE_RESETTING		0x1	/* in process of resetting */
#define	GUEST_STATE_NORMAL		0x2	/* running normally */
#define	GUEST_STATE_SUSPENDED		0x3	/* suspended pending migr. */
#define	GUEST_STATE_EXITING		0x4	/* in process of exiting */
#define	GUEST_STATE_UNCONFIGURED	0xff	/* unused */


/*
 * Reasons for guest exit.
 */
#define	GUEST_EXIT_STOP		0x1
#define	GUEST_EXIT_MACH_EXIT	0x2
#define	GUEST_EXIT_MACH_SIR	0x3

#ifndef _ASM

typedef struct guest guest_t;

/*
 * API group version information
 */
struct version {
	uint64_t	version_num;
	void 		*verptr;
};


struct guest_watchdog {
	uint64_t	ticks;	/* ticks of our heartbeat timer, not ms */
};


/*
 * Permanent mapping state
 */
struct mapping {
	union map_entry_aligned {
		/*
		 * Force 16-byte alignment as VA and TTE are accessed via
		 * quad load.
		 */
		struct map_data {
			uint64_t va;
			uint64_t tte;
		} _map_data;
		long double ld;
	} _map_entry_aligned;
	uint64_t	icpuset[NVCPU_XWORDS];
	uint64_t	dcpuset[NVCPU_XWORDS];
};


/*
 * Utilisation statistics for the guest
 */
typedef struct  guest_util {
	uint64_t	stick_last;
	uint64_t	stopped_cycles;
} guest_util_t;


struct guest {
	uint64_t	guestid;
		/* FIXME: this configp is hardly used - remove it */
	void		*configp; /* global hv configuration */

	uint32_t	state;
	volatile uint64_t state_lock;		/* protects guest state */

	uint8_t		soft_state;
	uint8_t		soft_state_str[SOFT_STATE_SIZE];

	volatile uint64_t soft_state_lock; 	/* protects soft state */

	uint64_t	real_base;		/* base of real addr range */
	/*
	 * (N.B. limit/offset are required for MMU HWTW)
	 */
	uint64_t	real_limit;		/* limit real address range */
	uint64_t	mem_offset;		/* real address range offset */

	/*
	 * ra2pa segments
	 */
	struct ra2pa_segment	ra2pa_segment[NUM_RA2PA_SEGMENTS];

	/*
	 * mapin region - part of address space
	 */
	uint64_t		ldc_mapin_basera;
	uint64_t		ldc_mapin_size;

	/*
	 * Permanent mappings
	 */
	uint64_t	perm_mappings_lock;
	struct mapping	perm_mappings[NPERMMAPPINGS];
#if PERMMAP_STATS
	uint64_t	perm_mappings_count;
#endif

	/*
	 * Per-guest virtualized console state
	 */
	struct console	console;

	/*
	 * Misc. Guest state
	 */
	uint64_t	tod_offset;
	uint64_t	ttrace_freeze;

	/*
	 * Static configuration data
	 */
	vcpu_t		*vcpus[NVCPUS]; /* virtual cpu# index */
#ifdef CONFIG_CRYPTO
	mau_t		*maus[NMAUS];
	struct cwq	*cwqs[NCWQS];
#endif /* CONFIG_CRYPTO */

	/*
	 * API version management information
	 */
	struct version	api_groups[NUM_API_GROUPS];
	uint64_t	hcall_table;

	/*
	 * Virtual devices
	 */
	uint8_t		dev2inst[NDEVIDS];
	struct vino2inst vino2inst;
	struct vdev_state vdev_state;

	/*
	 * Partition description
	 */
	uint64_t	md_pa;
	uint64_t	md_size;

	/*
	 * Debug
	 */
	uint64_t	dumpbuf_pa;
	uint64_t	dumpbuf_ra;
	uint64_t	dumpbuf_size;

	/*
	 * Startup configuration
	 */
	uint64_t	entry;
	uint64_t	rom_base;
	uint64_t	rom_size;

	/*
	 * Policy settings from Zeus
	 */
	uint64_t	perfreg_accessible;
	uint64_t	diagpriv;
	uint64_t	reset_reason;
	uint64_t	perfreght_accessible;
	uint64_t	rng_ctl_accessible;

	/*
	 * Watchdog configuration
	 */
	struct guest_watchdog watchdog;

#ifdef CONFIG_DISK
	/*
	 * Simulated disk
	 */
	struct hvdisk	disk;
#endif

#ifdef T1_FPGA_SNET
	/*
	 * Simulated/Simple network
	 */
	struct snet_info   snet;
#endif

	/*
	 * LDC
	 */
	uint64_t	ldc_max_channel_idx; /* legit LDC nos are this value */
	uint64_t	ldc_mapin_free_idx;

	struct ldc_endpoint	ldc_endpoint[MAX_LDC_CHANNELS];

	struct ldc_mapin	ldc_mapin[LDC_NUM_MAPINS];
	struct ldc_ino2endpoint	ldc_ino2endpoint[MAX_LDC_INOS];

	guest_parse_info_t	pip;

	/*
	 * Asycnhronous messaging
	 */
	uint8_t		async_busy[HVctl_info_guest_max];
	volatile uint64_t async_lock[HVctl_info_guest_max];
	uint64_t	async_buf[HVCTL_BUF_SIZE];

	/*
	 * Utilisation statistics
	 */
	uint64_t	start_stick;
	guest_util_t	util;

	/*
	 * Device Management.
	 */
	uint64_t	vdev_cfghandle;
	uint64_t	cdev_cfghandle;

	struct machguest guest_m;
};


extern guest_t guests[];

extern void init_guest(int);
extern bool_t	guest_ignition(guest_t *guestp);

extern void reset_guest_perm_mappings(guest_t *guestp);
extern void reset_api_hcall_table(guest_t *guestp);
extern void reset_guest_ldc_mapins(guest_t *guestp);

extern void init_ra2pa_segment(ra2pa_segment_t *rsp);
extern void assign_ra2pa_segments(guest_t *guestp, uint64_t real_base,
		uint64_t size, uint64_t ra2pa_offset, uint8_t flags);
extern void clear_ra2pa_segments(guest_t *guestp, uint64_t real_base,
		uint64_t size);

extern void config_guest_md(guest_t *guestp);


extern void config_a_guest_device_vino(guest_t *guestp, int ino, uint8_t type);
extern void unconfig_a_guest_device_vino(guest_t *guestp, int ino,
		uint8_t type);
extern void config_guest_virtual_device(guest_t *guestp, uint64_t cfg_handle);
extern void unconfig_guest_virtual_device(guest_t *guestp);
extern void config_guest_channel_device(guest_t *guestp, uint64_t cfg_handle);
extern void unconfig_guest_channel_device(guest_t *guestp);

#endif /* !_ASM */

#define	INVALID_GID	(-1)

#define	INVALID_CFGHANDLE	0xdeadbeef

#ifdef __cplusplus
}
#endif

#endif /* _GUEST_H */
