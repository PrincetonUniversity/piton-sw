/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: config.h
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

#ifndef _CONFIG_H
#define	_CONFIG_H

#pragma ident	"@(#)config.h	1.39	07/07/18 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <svc_vbsc.h>		/* dbgerror */
#include <platform/config.h>

#define	NGUESTS			NSTRANDS
#define	NVCPUS			NGUESTS		/* 1 per guest */

#define	DUMPBUF_MINSIZE	8192	/* smallest dump buffer allowed */
#define	HVCTL_BUF_SIZE	8	/* HVCTL ibuf and obuf size */

/*
 * cpu_pokedelay - the number of ticks between pokes to a target
 * cpu that has had a mondo outstanding.  The target's cpu queue
 * may have been full and it needs a poke to check it again.
 */
#define	CPU_POKEDELAY		2000	/* clock ticks */

/*
 * memscrub_max default - used as the default if the memscrub_max
 * was not specified in the hypervisor description or if the
 * setting does not correspond to an 8k-aligned byte count.
 */
#define	MEMSCRUB_MAX_DEFAULT	((4LL * 1024LL * 1024LL) >> L2_LINE_SHIFT)

/*
 * Dummy TSB to fake up real address space.
 */
#define	DUMMYTSB_ENTRIES	(DUMMYTSB_SIZE/16)
#define	DUMMYTSB_SIZE	0x2000
#define	DUMMYTSB_ALIGN	DUMMYTSB_SIZE

/*
 * Hypervisor MD content-version. We start with 1.0.
 * If the property is not present in the MD we assume pre 1.0.
 * Pre 1.0 MDs are  not supported by this hypervisor.
 * The hypervisor will support MDs in the same major version number.
 * Minor version numbers less than the version specified below require
 * the hypervisor to  be backward compatible. Minor versions above can be
 * ignored as the version is only incremented on content additions. Removing
 * content requires a Major version bump.
 */
#define	HV_MDCONT_VER_MAJOR	1
#define	HV_MDCONT_VER_MINOR	0

/*
 * Extract major and minor numbers. The property is encoded as an uint64_t.
 * Where:
 * Top 32 bits  = major version number
 * Bottom 32 bits  =  minor version number
 */
#define	MDCONT_VER_MAJOR(x)	(x >> 32)
#define	MDCONT_VER_MINOR(x)	((x << 32) >> 32)

#ifndef _ASM

struct nametable {
	uint64_t	hdname_root;
	uint64_t	hdname_fwd;
	uint64_t	hdname_back;
	uint64_t	hdname_id;
	uint64_t	hdname_cpus;
	uint64_t	hdname_cpu;
	uint64_t	hdname_devices;
	uint64_t	hdname_device;
	uint64_t	hdname_services;
	uint64_t	hdname_service;
	uint64_t	hdname_guests;
	uint64_t	hdname_guest;
#ifdef CONFIG_CRYPTO
	uint64_t	hdname_mau;
	uint64_t	hdname_maus;
	uint64_t	hdname_cwq;
	uint64_t	hdname_cwqs;
#endif /* CONFIG_CRYPTO */
	uint64_t	hdname_romsize;
	uint64_t	hdname_rombase;
	uint64_t	hdname_memory;
	uint64_t	hdname_mblock;
	uint64_t	hdname_unbind;
	uint64_t	hdname_mdpa;
	uint64_t	hdname_size;
	uint64_t	hdname_uartbase;
	uint64_t	hdname_base;
	uint64_t	hdname_link;
	uint64_t	hdname_inobitmap;
	uint64_t	hdname_tod;
	uint64_t	hdname_todfrequency;
	uint64_t	hdname_todoffset;
	uint64_t	hdname_vid;
	uint64_t	hdname_xid;
	uint64_t	hdname_pid;
	uint64_t	hdname_sid;
	uint64_t	hdname_gid;
	uint64_t	hdname_strandid;
	uint64_t	hdname_parttag;
	uint64_t	hdname_ign;
	uint64_t	hdname_ino;
	uint64_t	hdname_mtu;
	uint64_t	hdname_memoffset;
	uint64_t	hdname_memsize;
	uint64_t	hdname_membase;
	uint64_t	hdname_realbase;
	uint64_t	hdname_hypervisor;
	uint64_t	hdname_perfctraccess;
	uint64_t	hdname_perfctrhtaccess;
	uint64_t	hdname_rngctlaccessible;
	uint64_t	hdname_vpcidevice;
	uint64_t	hdname_pciregs;
	uint64_t	hdname_cfghandle;
	uint64_t	hdname_cfgbase;
	uint64_t	hdname_diskpa;
#ifdef T1_FPGA_SNET
	uint64_t	hdname_snet;
	uint64_t	hdname_snet_pa;
	uint64_t	hdname_snet_ino;
#endif
	uint64_t	hdname_diagpriv;
	uint64_t	hdname_debugprintflags;
	uint64_t	hdname_iobase;
	uint64_t	hdname_hvuart;
	uint64_t	hdname_flags;
	uint64_t	hdname_stickfrequency;
	uint64_t	hdname_ceblackoutsec;
	uint64_t	hdname_cepollsec;
	uint64_t	hdname_memscrubmax;
	uint64_t	hdname_erpt_pa;
	uint64_t	hdname_erpt_size;
	uint64_t	hdname_vdevs;
	uint64_t	hdname_reset_reason;
	uint64_t	hdname_ldc_endpoints;
	uint64_t	hdname_sp_ldc_endpoints;
	uint64_t	hdname_ldc_endpoint;
	uint64_t	hdname_channel;
	uint64_t	hdname_target_type;
	uint64_t	hdname_target_guest;
	uint64_t	hdname_target_channel;
	uint64_t	hdname_tx_ino;
	uint64_t	hdname_rx_ino;
	uint64_t	hdname_svc_id;
	uint64_t	hdname_svc_arg;
	uint64_t	hdname_svc_vino;
	uint64_t	hdname_private_svc;
	uint64_t	hdname_ldc_mapinrabase;
	uint64_t	hdname_ldc_mapinsize;
#ifdef CONFIG_SPLIT_SRAM /* { */
	uint64_t	hdname_sram_ptrs;
	uint64_t	hdname_inq_offset;
	uint64_t	hdname_inq_data_offset;
	uint64_t	hdname_inq_num_pkts;
	uint64_t	hdname_outq_offset;
	uint64_t	hdname_outq_data_offset;
	uint64_t	hdname_outq_num_pkts;
#endif /* { */
	uint64_t	hdname_idx;
	uint64_t	hdname_resource_id;
	uint64_t	hdname_consoles;
	uint64_t	hdname_console;
	uint64_t	hdname_virtual_devices;
	uint64_t	hdname_channel_devices;
	uint64_t	hdname_sys_hwtw_mode;
#ifdef CONFIG_PCIE
	uint64_t	hdname_pcie_bus;
	uint64_t	hdname_allow_bypass;
#endif
#ifdef STANDALONE_NET_DEVICES
	uint64_t	hdname_network_device;
#endif
#ifdef CONFIG_CLEANSER
	uint64_t	hdname_l2scrub_interval;
	uint64_t	hdname_l2scrub_entries;
#endif
#ifdef PLX_ERRATUM_LINK_HACK
	uint64_t	hdname_ignore_plx_link_hack;
#endif
	uint64_t	hdname_content_version;
};

struct erpt_svc_pkt {
	uint64_t	addr;
	uint64_t	size;
};


/*
 * Global configuration
 */

typedef struct config config_t;

struct config {
	uint64_t	membase; /* original membase value */
	uint64_t	memsize; /* original memsize value */

	/* HV state as reflected by a HV MD */
	void		*active_hvmd;	/* active hypervisor MD */
	void		*parse_hvmd;	/* hypervisor MD being parsed */

	uint64_t	reloc;		/* hv relocation offset */

	void		*guests;	/* pointer to base of guests array */
	void		*mblocks;	/* pointer to base of mblocks array */
	void		*vcpus;		/* pointer to base of vcpus array */
	void		*strands; 	/* pointer to base of strands array */
	void		*vstate;	/* pointer to base of vstate array */
#ifdef	CONFIG_LDC_BRIDGE
	uint64_t	ldcb_pa; 	/* Bridge base address */
#endif
#ifdef	CONFIG_PCIE
	void		*pcie_busses; 	/* pcie busses */
#endif
#ifdef STANDALONE_NET_DEVICES
	void		*network_devices; 	/* network devices */
#endif
	void		*hv_ldcs;	/* ptr to array of HV LDC endpoints */
	void		*sp_ldcs;	/* ptr to array of SP LDC endpoints */
	uint64_t	sp_ldc_max_cid;

	void		*dummytsbp; 	/* pointer to dummy tsb */

	/*
	 * lock to ensure that only one strand executes
	 */
	uint64_t	single_strand_lock;

	uint64_t	strand_startset;
	uint64_t	strand_present;	/* strand state information */
	uint64_t	strand_active;
	uint64_t	strand_idle;
	uint64_t	strand_halt;

	uint64_t	print_spinlock; /* print output serialization */

	uint64_t	heartbeat_cpu; /* physical cpu# of heartbeat handler */

	uint64_t	error_svch; /* hypervisor error service handle */

#ifdef CONFIG_VBSC_SVC
	uint64_t	vbsc_svch;
	struct dbgerror vbsc_dbgerror;
#endif

	struct hv_svc_data *svc;
	struct vintr_dev *vintr;

	uint64_t	hvuart_addr;
	uint64_t	tod;
	uint64_t	todfrequency;
	uint64_t	stickfrequency;

	uint64_t	sys_hwtw_mode;		/* MMU HWTW Mode */

	uint64_t	erpt_pa;		/* address of erpt buffer */
	uint64_t	erpt_size;		/* size */
	uint64_t	sram_erpt_buf_inuse;
	/*
	 * Cached hypervisor description nodes
	 */
	void		*root_dtnode;
	void		*devs_dtnode;
	void		*svcs_dtnode;
	void		*guests_dtnode;
	void		*cpus_dtnode;
	void		*hv_ldcs_dtnode;
	void		*sp_ldcs_dtnode;
#ifdef CONFIG_LDC_BRIDGE
	void		ldcb_dtnode;	/* FIXME: To go away */
#endif

	/*
	 * error log lock
	 */
	uint64_t	error_lock;

	/*
	 * Name to nameindex translation table for hypervisor description
	 */
	struct nametable hdnametable;

	uint64_t	intrtgt;	/* SSI interrupt targets */

	/*
	 * hcall memory scrub and sync limit
	 *
	 * It's a cacheline count, not byte count, and must correspond to
	 * a byte count multiple of 8k.
	 */
	uint64_t	memscrub_max;

	/* devinst */ void *devinstancesp;

	/*
	 * cyclic timers
	 */
	uint64_t	cyclic_maxd;		/* max delay in ticks */

	/*
	 * HVCTL (hypervisor control) messaging storage
	 */
	uint8_t		hvctl_state;
	uint16_t	hvctl_hv_seq;	/* HV's next seqn */
	uint16_t	hvctl_zeus_seq;	/* Zeus ' next seqn */
	uint16_t	hvctl_version_major;
	uint16_t	hvctl_version_minor;
	uint64_t	hvctl_rand_num;
	uint64_t	hvctl_ibuf[HVCTL_BUF_SIZE];
	uint64_t	hvctl_obuf[HVCTL_BUF_SIZE];

	/*
	 * HVCTL state
	 */
	uint64_t	hvctl_ip;
	uint64_t	hvctl_ldc;		/* HV LDC endpoint number */
	volatile uint64_t hvctl_ldc_lock;	/* serializes HV LDC sends */

	/*
	 * CE Storm Prevention
	 */
	uint64_t	ce_blackout;		/* ticks */
	uint64_t	ce_poll_time;		/* poll time in ticks */

	/*
	 * Error buffers still needed to be sent
	 */
	uint64_t	errs_to_send;

	uint64_t	physmemsize;	/* Total phys memory size */

	/*
	 * Delayed reconfiguration
	 */
	uint64_t	del_reconf_gid;	/* ID of delayed reconfig guest */
	volatile uint64_t del_reconf_lock; /* protects delayed reconfig */

	/*
	 * Scratch used at beginning of time for scrubbing.
	 * Could be overloaded with other fields.
	 */
	uint64_t	scrub_sync;
	uint64_t	fpga_status_lock;

#ifdef CONFIG_CLEANSER
	/*
	 * Interval (in seconds) for invoking the L2 Cache Cleanser
	 */
	uint64_t	l2scrub_interval;
	/*
	 * Number of L2 cache entries to be scrubbed on each invocation
	 * as a percentage of the total number of entries (64k)
	 */
	uint64_t	l2scrub_entries;
#endif /* CONFIG_CLEANSER */

#ifdef PLX_ERRATUM_LINK_HACK
	/*
	 * Global setting to ignore the PLX link training reset hack
	 * in case the system gets in an never-ending reset loop.
	 */
	uint64_t	ignore_plx_link_hack;
#endif /* PLX_ERRATUM_LINK_HACK */

	struct machconfig config_m;
};

extern config_t config;

#endif /* !_ASM */

/*
 * The intrtgt property is a byte array of physical cpuids for the SSI
 * interrupt targets (INT_MAN devices 1 and 2)
 */
#define	INTRTGT_CPUMASK	0xff	/* Mask for a single array element */
#define	INTRTGT_DEVSHIFT 8	/* #bits for each entry in array */

/*
 * The reset-reason property provided by VBSC
 */
#define	RESET_REASON_POR	0
#define	RESET_REASON_SIR	1

/*
 * Watchdog timeout limits
 */
#define	MSEC_PER_SEC	1000
#define	WATCHDOG_MAX_TIMEOUT	(365 * 24 * 60 * 60)  /* roughly a year */

#ifdef __cplusplus
}
#endif

#endif /* _CONFIG_H */
