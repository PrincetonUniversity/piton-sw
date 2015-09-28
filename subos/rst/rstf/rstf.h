/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rstf.h
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
#ifndef _rstf_h
#define _rstf_h

#ident "@(#)  rstf.h  1.41: 12/08/03 13:03:59 @(#)"

/* 
 * WARNING: The Java RST jrst package relies upon the existing comment style
 *   to pick off the rtype value in each record.  The Perl script
 *   that "parses" this .h file is jrst/c2java.pl
 *   I apologize in advance for this hackery.  -R Quong  5/2002
 * 
 * File contents (you can search this file using on the terms below)
 * 0) Associated header files and #defines
 * 1) Overview of RST format
 *    History
 * 2) Version info and checking
 *    If you use the RST version check code, you must link with rstf/rstf.o
 * 3) struct definitions
 * 4) Useful functions
 *    If you use any functions in (3), you must link with rstf/rstf.o
 */

/*
 * ================ 0) Associated header file and #defines ===========
 * Choose *ONE* of the following to include:
 * 
 *  rstf.h               // most people should just include this file
 *  rstf_bustrace.h      // bustrace implementation specifics + rstf.h
 *
 * To use deprecated RSTF values, include rstf_deprecated.h *FIRST*   Ex:
 * 
 * #include "rstf/rstf_deprecated.h"
 * #include "rstf/rstf.h"
 *
 */

/* 
 * ================ 1) Overview of RST format ================
 * RST (trace) format or just RST for short.  
 *   Russell's Simplified Trace format
 *   Really    Simple     Trace format
 * 
 * RST format handles "unified architectural" trace data.
 * There are different kinds of records corresponding to
 *   - instructions
 *   - events (traps, interrupts)
 *   - MMU state (TLB entry changes)
 *   - internal processor state (register dumps)
 *   - high-level evnts (process/context switch, thread switch)
 *   - markers (timestamp, current CPU) 
 *   - state (cache/memory state)
 * 
 * For simplicity of reading data, all records are the same size (24 bytes)
 * making it easy if you want to skip certain records.
 * The first byte in each record, the rtype, denotes the record type.
 * 
 *    +==============+
 *    | byte: header |  The first record must be of type rstf_headerT
 *    | maj,minor,%  |  Use   init_rstf_header(rstf_headerT * hp)
 *    |   header     |
 *    |   marker     |
 *    +==============+
 *    | byte: rtype  |
 *    |              |
 *    | 23 bytes of  |
 *    |    data      |
 *    +==============+
 *    | byte: rtype  |
 *    |              |
 *    | 23 bytes of  |
 *    |    data      |
 *    +==============+
 *    | byte: rtype  |
 *    |              |
 *    | 23 bytes of  |
 *    |    data      |
 *    +==============+
 * 
 * We have different records type, so that future record types
 * can be added in the future.
 * 
 * One easy way to read or write an RST trace is to define a 
 * buffer of type rstf_unionT, which is a union of all known rec types.
 * You can access the record type of your choice directly w/o typecasts.
 * 
 *    rstf_unionT rstbuff [1024];
 *    ... read or write into rstbuff ...
 *    rstf_instrT * instrPtr = & rstbuff[3].instr;  // good = NO TYPE CASTING
 *    rstf_instrT * instrPtr = (rstf_instrT*) &rstbuff[3];  // avoid, bad, ugly
 *    int pc = instrPtr->pc_va;
 *    int iContext = rstbuff[89].pavadiff.icontext;
 *    rstf_tlbT * tlb = & rstbuff[234].tlb;	// no type casting (!!)
 * 
 * HISTORY: 
 * This was format was originally known as unatrace (Version 1) in 1999.
 *
 * In 10/99, I (R Quong) developed a new definition for 
 * the unatrace version 2 (now known as unawrap) format, 
 * to be a general trace wrapper.
 * Rather than call the original format unatrace version 1, which
 * became way rather confusing, I renamed it as RST.
 * As of 4/2001, nothing is called unatrace.
 */

#include <stdio.h>		// FILE*
#include <sys/types.h>		// uid_t

#ifdef  __cplusplus
extern "C" {
#endif
#if 0
}
#endif

#if defined(RSTF_USE_DEPRECATED)
#include "rstf/rstf_deprecated.h"
#endif

// if compiling with cc, use '-xCC' to handle C++ comments.

// emacs commands for me (RQ)
// (query-replace-regexp "int\\([0-9]+\\)" "int\\1_t" nil)

#ifndef MIN
  #define MIN(a,b) (((a)>(b))?(b):(a))
#endif

/*
 * 2) Version info and checking
 */

#define RSTF_MAGIC "RST Header"
#define RSTF_MAJOR_VERSION  2
#define RSTF_MINOR_VERSION  13

#define RSTF_VERSION_STR    "2.13"

  // Mandatory version checking info: 
  // See vercheck.h for return codes:
  //   0 = version match
  //   2 = semi compatible versions
  //   4 = version mismatch
int rstf_version_check_fn (const char* compile_time_version);

  // Convenience macro for version checking
#define RSTF_CHECK_VERSION()   rstf_version_check_fn(RSTF_VERSION_STR)

  // Do a compile-time vs run-time check on a record from a trace
#define RSTF_CHECK_TRACEVER(rstheader_ptr) \
   rstf_checkheader(RSTF_VERSION_STR, rstheader_ptr)

static const char* rstf_version_str = "\n\
 2.13 07/25/2005 [VP] Added TRAPPED_INSTR_T record type\n\
 2.12 09/29/2004 [VP] extended cpuid fields to 10 bits; added accessor funcs\n\
 2.10 09/17/2003 Merged in rfs.h file, which defines record for RFS traces\n\
 2.09 08/28/2003 defined is_data one bit field in tsb_access record\n\
 2.08 06/16/2003 define tsb_access record\n\
 2.07 10/18/2002 define snoopT record\n\
 2.06 03/XX/2002 regvalT:tpc is array; clean up comments for MM (trap::pstate, trapexit::tpc, tlb::line_idx)\n\
 2.05 02/07/2002 augment STATUS_T w/ more analyzer-commands\n\
 2.05 10/19/2001 augment STATUS_T w/ analyzer-commands, e.g. for MPCachesim\n\
 2.05 10/04/2001 add bustrace::tdiff, renamed CONTEXT_T to PREG_T, add rstf_deprecated.h, expand hwinfo\n\
 2.04  8/16/2001 revisions to bus trace spec\n\
 2.03  8/06/2001 compile-vs-runtime version checking, openRST() supports rstzip\n\
 2.02  7/20/2001 revise memval64/128 recs, add bus trace record type\n\
 2.01  6/20/2001 add recs memval64 and memval128 records \n\
 2.00  6/19/2001 rev 1.10 to 2.00 (no other changes)\n\
 1.10  5/23/2001 cleanup openRST(), closeRST\n\
 1.10  4/26/2001 add cpuid to INSTR_T +TRAP_T, add TRACEINFO_T,\n\
 	deprecate ASI_T, modified REGVAL_T \n\
  1.9  4/20/2001 In CONTEXT_T: add cpuid, rename 'asi' to 'asiReg'\n\
  1.8  3/27/2001 unixcommand(), rstf_snprintf(), stdized rstf_headerT,magic\n\
  1.7  3/26/2001 Add RECNUM_T for rst-snapper\n\
  1.6  3/15/2001 Add support for MP (cpuid to PAVADIFF, cpuid/tlbnum TLB)\n\
  1.5  9/18/2000 Fixed Shade V6 record types (thanks Kelvin)\n\
  1.4  9/9/2000  Added icontext and dcontext to PAVADIFF_T rec\n\
  1.4  9/?/2000  Added major, minor numbers to HEADER_T rec\n\
  1.3  8/25/2000 Added PATCH_T type.\n\
  1.2  8/22/2000 Added STATUS_T type.\n\
";

/* The rtypes in RST */
enum {
    // values for the rtype field in the following traces.
    // we start at 3 not 0, to catch the common uninitialized case.

    // enum::rtypes  Do not remove THIS comment, c2java.pl needs this
    RST_ZERO_T = 0,	// should not see this
    RST_ONE_T = 1,	// reserved, not used 5/2000.
    RSTHEADER_T = 2,	// [REQUIRED]   header type (mostly for marking)
    INSTR_T = 3,	// instruction

    TRACEINFO_T = 4,	// [REQUIRED] additional header info

    TLB_T = 5,		// change in a TLB line 
    THREAD_T = 6,	// thread info
    TRAP_T = 7,		// trap event
    TRAPEXIT_T = 8,	// exit a trap
    REGVAL_T = 9,	// short register dump (1 or 2 regs)
    TIMESTAMP_T = 11,	// current cycle
    CPU_T = 11,		// current CPU
    PROCESS_T = 12,	// change in process, uses Unix PID ... rarely used.
    DMA_T = 13,		// DMA event
    STRDESC_T = 14,	// record is a N-char null-terminated (!) string (N<22)
    LEFTDELIM_T = 15,	// multi-record data must be delimited by
    RIGHTDELIM_T = 16,	// matching LEFTDELIM, RIGHTDELIM records
    PREG_T = 17,	// priv regs (traplev, pstate, asiReg)
    PHYSADDR_T = 18,	// physical addr of PC and EA; prefer PAVADIFF instead
    PAVADIFF_T = 19,	// (PA-VA) values of PC and EA 
    NULLREC_T = 20,	// null record, which should be ignored 
			// E.g. change the rtype to NULLREC_T to ignore it
    STRCONT_T = 21,	// string that is *NOT* null-terminated 
			// Multi-record str=>[STRCONT_T...STRCONT_T STRDESC_T]
    FILEMARKER_T = 22, 	// indicate where we are in a file
    RECNUM_T = 22,	// set rec num counters (indicates a skip in the trace)
    STATUS_T = 23, 	// some sort of status (error, EOF, etc).
    PATCH_T = 24, 	// patch instructions (application specific)
    HWINFO_T = 25,	// # cpu's, speed, memory, etc
    MEMVAL_T = 26,	// value from ld/st from/to memory
    BUSTRACE_T = 27,	// data from a bus trace
    SNOOP_T = 28,       // a snoop event
    TSB_ACCESS_T = 29,  // TSB access address during tlb fill
    RFS_SECTION_HEADER_T = 30,	// The section header for RFS trace sub-type.
    RFS_CW_T = 31,	// cache-warming data
    RFS_BT_T = 32,	// branch-predict hardware warming
    // RFS_RST_T is only used to identify the section type in the
    // section header no actual rst records of that rtype are actually created
    RFS_RST_T = 33,

    TRAPPING_INSTR_T = 34,

    TIMESYNC_T = 35,    // emitted periodically with a common sequence number
		        // to align per-cpu traces

    DEVIDSTR_T = 36, // displays like a string record. in addition, maps device ids to names


    LAST_T = 37

};

/* 
 * Multi-record types.  
 * These types values are used in a LEFTDELIM_T record in the WHAT field.
 */
enum {
    STRING_MRT = 257,
    REGDUMP_MRT = 258,
    LAST_MRT = 300
};

  // These are all 32 bit values representing invalid or bad addresses
  // I'll choose odd values of the form 0x3141592y  where y=odd
#define RSTF_BADADDR_BASE 0x31415900 // fictitious data EA, unknown reason
#define RSTF_NO_EA        0x31415921 // fictitious data EA, unknown reason
#define RSTF_NO_PC        0x31415923 // fictitious PC     , unknown reason
#define RSTF_ATRACE_NO_PC 0x31415927 // fictitious PC when no atrace I-rec
#define RSTF_ATRACE_NO_EA 0x3141592f // fictitious data EA when no atrace D-rec

  // D-addr address is invalid, officially removed in 2.05
// #define RSTF_NOADDR       0x00314159  // (!!) Deprecated as of v 1.5 (!!) 

#define RSTF_IS_BADADDR(addr) \
  ((((addr) & 01) != 0) && (((addr >> 8) == (RSTF_BADADDR_BASE >> 8))))

//
// Here are definitions of the individual RST record types.
// There are some convenience types at the end, to let you view
// an RST record as an array of 8, 16, 32, or 64 bit values
//    and
// a union type

typedef struct {		/* not done yet */
    uint8_t     rtype;		/* value = ZERO_T */
    uint8_t     notused8;
    uint16_t    notused16;
    uint32_t    notused32;
    uint64_t    notused64;
    uint64_t    notused64a;
} rstf_protoT;
typedef rstf_protoT rstf_xxxT;

/* 
 * 3) struct definitions
 */

    // view rsttrace record as an array of bytes, shorts, ints and long longs
typedef struct {
    uint8_t     arr8[ sizeof(rstf_protoT)/sizeof(uint8_t) ];
} rstf_uint8T;

typedef struct {
    uint16_t     arr16[ sizeof(rstf_protoT)/sizeof(uint16_t) ];
} rstf_uint16T;

typedef struct {
    uint32_t     arr32[ sizeof(rstf_protoT)/sizeof(uint32_t) ];
} rstf_uint32T;

typedef struct {
    uint64_t     arr64[ sizeof(rstf_protoT)/sizeof(uint64_t) ];
} rstf_uint64T;

    // All RST traces must begin with an rstf_headerT record.
    // 
    // Initialize via    init_rstf_header (rstf_headerT * headerp);
typedef struct {
    uint8_t     rtype;		/* value = RSTHEADER_T */
    uint8_t     majorVer;	/* major version  Ex: 2   (binary value) */
    uint8_t     minorVer;	/* minor version  Ex: 23  (binary value) */
    uint8_t     percent;	/* must be '%' to be compliant */

	// header_str MUST start with RSTF_MAGIC
	// Expect it to look like:  "RST Header v1.9"
    char        header_str[ sizeof(rstf_uint8T) - sizeof( uint32_t ) ];
} rstf_headerT;

#define MAX_INSTR_CPUID 48
typedef struct {
  uint8_t     rtype;		/* value = INSTR_T */
  unsigned  notused : 1;	/* not used */
  unsigned  ea_valid : 1;	/* ea_va field is valid, for ld/st only */
  unsigned  tr : 1;		/* trap occured 1=yes */
  unsigned  hpriv : 1;		/* hpriv: hpstate.hpriv==1. It is recommended */
				/* that pr be set to 0 when hpriv==1 */
  unsigned  pr : 1;		/* priviledged or user  1=priv */
  unsigned  bt : 1;		/* br/trap taken, cond-move/st done */
  unsigned  an : 1;		/* 1=annulled (instr was not executed) */
  unsigned  reservedCompress : 1;  /* was used by rstzipv2 compressor */

  unsigned  cpuid : 6;	/* do not access the cpuid field directly. Instead, use the
			   set/get_cpuid functions defined below */
  unsigned cpuid9_6 : 4;

  unsigned notused3 : 6;	/* must be zero in this version of RST */

  uint32_t    instr;		/* instruction word (opcode, src, dest) */
  uint64_t    pc_va;		/* VA */
  uint64_t    ea_va;		/* VA: Eff addr of ld/st; Eff targ of CTI */
} rstf_instrT;
static void rstf_instrT_set_cpuid(rstf_instrT * tr, int cpuid) { tr->cpuid = cpuid & 0x3f; tr->cpuid9_6 = ((cpuid>>6) & 0xf); }
static int rstf_instrT_get_cpuid(const rstf_instrT * tr) { return (tr->cpuid9_6<<6)|tr->cpuid; }

typedef struct {
  uint8_t     rtype;		/* value = PAVADIFF_T */
  unsigned    ea_valid : 1;	/* does ea_pa contain a valid address */
  unsigned    cpuid    : 7;
  unsigned    cpuid9_7 : 3;
  unsigned    notused13: 13;	/* must be zero */
  uint16_t    icontext;	/* I-context used for these diffs */
  uint16_t    dcontext;	/* only valid if ea_valid is true (!) */
  uint64_t    pc_pa_va;	/* (PA-VA) of PC */
  uint64_t    ea_pa_va;	/* (PA-VA) of EA for ld/st (not branches), if ea_valid is true */
} rstf_pavadiffT;
static void rstf_pavadiffT_set_cpuid(rstf_pavadiffT * tr, int cpuid) { tr->cpuid = cpuid & 0x7f; tr->cpuid9_7 = (cpuid>>7)&0x7; }
static int rstf_pavadiffT_get_cpuid(const rstf_pavadiffT * tr) { return (tr->cpuid9_7 << 7)|tr->cpuid; }

    // subtypes for records with a rtype2 field
enum {
    RSTT2_ZERO_T = 0,	    RSTT2_ONE = 1,   // reserved
    RSTT2_NLEVEL_T = 2,		// 
    RSTT2_CPUINFO_T = 3,
    RSTT2_CPUIDINFO_T = 4,
    RSTT2_LAST_T = 5		// 
};

// Trace information:

// Each RST trace starts with a header record, followed by a series of tracinfo records

// The first traceinfo record should indicate the trace level (incremented with each update)

// The next traceinfo record specifies the number of cpus and the min/max cpuid in the trace

// The following traceinfo records list the cpuids specified in the trace, up to 10 per record

// This is followed by a series of string records containing more detail about the trace



    // Initialize these records with init_rstf_traceinfo_level().
    // 
    // Each program that generates/processes/modifies the trace is a level.
    // Level 0 = program that generated the trace
    // Level 1 = first "filter" run on the trace that modifies the trace.
    // To be compliant w/ RST v2.06, the second record in the trace
    // must be a traceinfo_levelT.
    // Thus a filter can read the second record, bump the level
    // and rewrite the modified record
typedef struct {		/* not done yet */
    uint8_t     rtype;		/* value = TRACEINFO_T */
    uint8_t     rtype2;		/* RSTT2_NLEVEL_T */
    uint16_t    level;		/* number of levels, must be >= 1 */
    uint32_t    val32;
    uint64_t    time64;		/* value returned by time(2) */
    uint64_t    notused64a;
} rstf_traceinfo_levelT;

typedef struct {
  uint8_t rtype;		/* value=TRACEINFO_T */
  uint8_t rtype2;		/* value = RSTT2_CPUINFO_T */
  int16_t numcpus;		/* number of cpus in trace */
  int16_t min_cpu_id;
  int16_t max_cpu_id;
  int64_t reserved1;		/* must be zero in this version */
  int64_t reserved2;		/* must be zero in this version */
} rstf_cpuinfoT;

/* The cpuidinfo records list the cpuids that occur in the trace.
 * It is needed because cpuids are not necessarily 0..ncpus-1.
 * More than one cpuidinfo record can appear following a cpuinfo record,
 * each contains up to 10 cpuids that appear in the trace.
 * For example, there will be 3 cpuidinfo records for ncpus=24.
 * Unused cpuid's must be set to 0
 */

typedef struct {
  uint8_t rtype;		/* value=TRACEINFO_T */
  uint8_t rtype2;		/* value=RSTT2_CPUIDINFO_T */
  uint16_t reserved1;		/* must be zero in this version */
  uint16_t cpuids[10];		/* unused fields must be zero */
} rstf_cpuidinfoT;

  // placemarker, as will split off more variants of 
typedef struct {		/* not done yet */
    uint8_t     rtype;		/* value = TRACEINFO_T */
    uint8_t     rtype2;		/* subtype: RSTT2_NLEVEL_T */
    uint16_t    val16;		
    uint32_t    val32;
    uint64_t    val64;		
    uint64_t    val64a;
} rstf_traceinfoT;



typedef struct {
  uint8_t     rtype;		/* value = TLB_T */
  unsigned    demap : 1; 	/* 0 = add/replace entry ; 1=invalidate */
  unsigned    tlb_type : 1;	/* 0 = INSTR, 1 = DATA */
  unsigned    notused : 6;	/* not used */

  // Each TLB implementor can number the lines in the TLB arbitrarily
  // For direct-mapped TLBs, the line index is obvious
  // For a K-way TLB, we recommend having idx={0,1,..,K-1}=first set
  uint16_t    tlb_index;	/* TLB line index, specific to each TLB impl */

  unsigned    tlb_no : 2 ; 	/* which I or D TLB ? (eg. Ch+ has 3 D TLBS) */
  unsigned    cpuid : 6 ; 	/* changed in v1.6 */
  unsigned	cpuid9_6 : 4;
  unsigned    unused : 4 ;    /* */

  uint16_t    unused16;	/* */

  // The blaze RSTracer collects the following information
  // tte_tag[63:13] = VA[63:13]    tte_tag[12:0] = context
  // (!) This format is different from that used in the US-I hardware
  uint64_t    tte_tag;		/* tag for a TTE */

  // See the struct rstf_tte_dataT at the end of this file 
  // for an example of how the tte_data might be organized.
  //    rstf_tte_dataT * xp = (rst_tte_data_T *) & tlbp->tte_data;
  uint64_t    tte_data;		/* data for a TTE */
} rstf_tlbT;
static void rstf_tlbT_set_cpuid(rstf_tlbT * tr, int cpuid) { tr->cpuid = cpuid & 0x3f; tr->cpuid9_6 = (cpuid>>6)&0xf; }
static int rstf_tlbT_get_cpuid(const rstf_tlbT * tr) { return (tr->cpuid9_6<<6)|tr->cpuid; }

typedef struct {		/* not done yet */
    uint8_t     rtype;		/* value = THREAD_T */
    uint8_t     notused8;
    uint16_t    icontext;	/* I-context */
    uint32_t    notused32;
    uint64_t    tid;		/* Thread ID or %g7=ptr to OS thread */
    uint64_t    notused64;
} rstf_threadT;

typedef struct {
    uint8_t     rtype;            /* value = PROCESS_T */
    uint8_t     notused8;         
    uint16_t    notused16;
    uint32_t    notused32;

    uint32_t    oldpid;		/* previous process id 0=no info */
    uint32_t    newpid;		/* current process id  0=no info */

    uint32_t    oldcontext;
    uint32_t    newcontext;
} rstf_processT;

typedef struct {
  uint8_t     rtype;		/* value = PREG_T */
  uint8_t     asiReg;		/* ASI register */
  uint16_t    unused_lastcontext; /* DEPRECATED */

  uint8_t     traplevel;
  uint8_t     traptype;	/* traptype[traplevel] register */
  uint16_t    pstate;		/* pstate */

  uint8_t     cpuid;		/* cpu 0, 1, 2, ... */
  uint8_t	cpuid9_8 : 2;
  uint8_t     notused4 : 6;	/* */
  uint16_t    notused16;	/* */
  uint32_t    notused32;	/* */

  // DO NOT USE THESE FOR GETTING THE CURRENT CONTEXT
  // Use the PAVADIFF_T icontext and dcontext, instead
  // These are MMU reg values, which may or may not be used by the instr
  uint16_t    primA;		/* primary IMMU context, must be equal to primD */
  uint16_t    secA;		/* secondary IMMU context, not used */
  uint16_t    primD;		/* primary DMMU context register */
  uint16_t    secD;		/* secondary DMMU context register */
} rstf_pregT;
static void rstf_pregT_set_cpuid(rstf_pregT * tr, int cpuid) { tr->cpuid = cpuid & 0xff; tr->cpuid9_8 = (cpuid>>8) & 3; }
static int rstf_pregT_get_cpuid(const rstf_pregT * tr) { return (tr->cpuid9_8<<8)|tr->cpuid; }

typedef struct {
  uint8_t     rtype;		/* value = TRAP_T */
  unsigned    is_async : 1 ;	/* asynchronous trap ? */
  unsigned    unused : 3 ;	/* unused */
  unsigned    tl : 4 ;	/* trap level at the time trap occurred */

  unsigned    cpuid : 6 ;	/* cpu id */
  unsigned    ttype : 10;	/* trap type for V9, only 9 bits matter */

  uint16_t    pstate;		/* Pstate register in the trap */
  uint16_t cpuid9_6 : 4;
  
  uint16_t    syscall : 12;	/* If a system call, the syscall # */

  uint64_t    pc;		/* PC before the trap (= post-trap TPC[TL]) */
  uint64_t    npc;		/* NPC before   trap (= post-trap TNPC[TL]) */
} rstf_trapT;
static void rstf_trapT_set_cpuid(rstf_trapT * tr, int cpuid) { tr->cpuid = cpuid & 0x3f; tr->cpuid9_6 = (cpuid>>6) & 0xf; }
static int rstf_trapT_get_cpuid(const rstf_trapT * tr) { return (tr->cpuid9_6 << 6) | tr->cpuid; }

typedef struct {
  uint8_t     rtype;		/* value = TRAPEXIT_T */
  uint8_t     tl;		/* trap level , after done/retry */
  unsigned    cpuid : 6 ;	/* 10-bit cpu id */
  unsigned    cpuid9_6 : 4;
  unsigned    notused10 : 6;
  uint32_t    tstate;		/* bottom 32 bits of tstate */

  uint64_t    unused64;		/* used to be pc */
  uint64_t    unused64b;	/* used to be npc */
} rstf_trapexitT;
static void rstf_trapexitT_set_cpuid(rstf_trapexitT * tr, int cpuid) { tr->cpuid = cpuid & 0x3f; tr->cpuid9_6 = (cpuid>>6) & 0xf; }
static int rstf_trapexitT_get_cpuid(const rstf_trapexitT * tr) { return (tr->cpuid9_6 << 6) | tr->cpuid; }


typedef struct {
    uint8_t     rtype;		/* value = CPU_T */
    uint8_t     notused8;
    uint16_t    notused16;
    uint16_t    notused16b;
    uint16_t    cpu;		/* CPU ID = 0, 1, etc */
    uint64_t    notused64;
    uint64_t    timestamp;		
} rstf_cpuT;

typedef struct {
    uint8_t     rtype;		/* value = DMA_T */
    unsigned    unused : 7;	/* unused */
    unsigned    iswrite : 1;	/* 1=write to memory, 0=read from memory */
    uint16_t    notused16;
    uint32_t    nbytes;		/* # of bytes transfered in the DMA */
    uint64_t    start_pa;       /* starting address for the DMA */
    uint32_t	devid;		/* id of device that performed the dma */
    uint32_t    notused32;
} rstf_dmaT;

typedef struct {
  uint8_t     rtype;		/* value = TSB_ACCESS_T */
  unsigned    unused : 7;
  unsigned    isdata : 1;     /* 1=data access, 0=instruction access */
  uint16_t    unused2 : 6;
  uint16_t    cpuid : 10;          /* CPU ID = 0, 1, etc */
  uint32_t    notused32;
  uint64_t    pa;       	/* physical address of TSB access */
  uint64_t    va;       	/* virtual address of TSB access */
} rstf_tsb_accessT;
static void rstf_tsb_accessT_set_cpuid(rstf_tsb_accessT * tr, int cpuid) { tr->cpuid = cpuid; }
static int rstf_tsb_accessT_get_cpuid(const rstf_tsb_accessT * tr) { return tr->cpuid; }


/* A rstf_trapping_instrT record is output before a synchronous trap record to provide
 * additional information about the cause of the trap. It is also output before an async trap
 * with information about the instruction that would have executed if the trap hadn't been taken
 *
 * The trap record will typically be followed by an rstf_instrT record with the tr flag set.
 */
typedef struct {
  uint8_t rtype;		/* value = TRAPPING_INSTR_T */

  /* values of hpstate.hpriv and pstate.priv when the trapping instr was initiated */
  uint8_t hpriv: 1;
  uint8_t priv : 1;

  uint8_t iftrap : 1; // if true, only cpuid and ea_va are valid

  uint8_t ea_va_valid : 1; // valid only if iftrap == 0
  uint8_t ea_pa_valid : 1; // do not translate ea_va unless true
  uint8_t unused3: 3;

  uint16_t cpuid: 10;
  uint16_t unused6: 6;

  uint32_t instr; // valid only if iftrap == 0

  uint64_t pc_va; // always valid

  uint64_t ea_va; // only if ea_va_valid

} rstf_trapping_instrT;
static void rstf_trapping_instrT_set_cpuid(rstf_trapping_instrT * tr, int cpuid) { tr->cpuid = cpuid; }
static int rstf_trapping_instrT_get_cpuid(const rstf_trapping_instrT * tr) { return tr->cpuid; }

  //
  // RST Bus trace format philosophy.
  // (i) convert a minimal set of "common" data into a standard form
  //   which is sufficient for any generic-bus-trace analyzer
  // (ii) to leave the bus-trace implementation specific data bits as-is,
  //    in a bus-trace specific set of 64-96 bits.
  // 
  //  There are major differences between different bus trace implementations
  // (system, bus, logic analyzer) even only looking at the
  // HPLA/Firetruck versus Tektronix/E10K traces.  
  //  In particular, the transaction types alone are different.  
  // And as we collect more bus traces from different/new setups, this
  // problem will only get worse.
  // 
  // See rstf_bustrace.h for bus-trace implementation specific details.
  // To access bus trace implementations specific fields use:
  //     #include <rstf/rstf_bustrace.h>
  // 
  // Or, if you just need common fields (e.g. a cache simulator), use
  //     #include <rstf/rstf.h>  
  // 
  // Again, The bustrace record (here) in rstf.h only describes fields
  // common to all bus trace records.  These fields are those suitable
  // for cache simulators and should be values present in all bus
  // traces.


#ifndef _rstf_bustrace_h

enum {
    // TX types must know so a cache simulator can do the right thing
    // 07/26/2001

    RST_BTTX_BADVAL  = 0x0,     // Make common unitialized value an error

    // UPA
    RST_BTTX_RTS    = 0x10,     // Read to Share
    RST_BTTX_RTSA   = 1,        // Read to Share Always (I access)
    RST_BTTX_RTO    = 2,        // Read to Own
    RST_BTTX_RTD    = 3,        // Read to Discard
    RST_BTTX_CGSS   = 4,        // CopybackGotoSState
    RST_BTTX_NCR    = 5,        // NonCachedRead
    RST_BTTX_NCBR   = 6,        // NonCachedBlockRead
    RST_BTTX_NCBW   = 7,        // NonCachedBlockWrite
    RST_BTTX_WB     = 8,        // Writeback
    RST_BTTX_WI     = 9,        // WriteInvalidate
    RST_BTTX_INV    = 10,        // Invalidate
    RST_BTTX_CB     = 11,        // Copyback
    RST_BTTX_CBI    = 12,        // CopybackInvalidate
    RST_BTTX_CBD    = 13,        // CopybackToDiscard
    RST_BTTX_NCW    = 14,        // NonCachedWrite
    RST_BTTX_INT    = 15,        // Interrupt

    // Additional Tx types in the firetruck bus
    RST_BTTX_IDLE   = 0x11,        // Idle
    RST_BTTX_ADMIN  = 0x12,        // Admin
    RST_BTTX_RTSF   = 0x13,        // ReadToShareFork
    RST_BTTX_RS     = 0x14,        // ReadStream

    RST_BTTX_RSTADMIN = 0x18,      // an administrative record (reserved)
    RST_BTTX_LAST   = 0x18	   // any value greater than this is an error
};

  // In rstf_bustrace.h,  u_btimpl64_t   is defined as a union of structs
  // but if we did not see rstf_bustrace.h, define it as an long long.
  // 
typedef uint64_t u_btimpl64_t;		

#endif  /* _rstf_bustrace_h */

    // The common bus trace info if the user just includes <rstf/rstf.h>
typedef struct {
    uint8_t   rtype;		/* value = BUSTRACE_T */

    unsigned    dirtyvictim : 1; // this access create dirty victim?
    unsigned    shared : 1;     // FT: anybody claim share this line?  E10K:N/A
    unsigned    owned : 1;      // FT: owned line asserted        E10K: N/A
    unsigned    memcancel : 1;	// E10=abort bit, FT=data cancel
    unsigned    bt_type : 4;	/* type of bus trace, see rstf_bustrace.h */

    unsigned    txType : 6;     // Transaction type
    unsigned    agentid : 10;   // cpu/board/agent/module ID

    unsigned    tdiff :  1 ;    // 1=timestamp is differental from prev rec, 
    unsigned    nsScale : 1 ;   // 1=timestamp is in nS; 0=timestamp in 100nS
    unsigned    timestamp : 20; // absolute=unsigned, time delta=signed

    
    u_btimpl64_t btimpl64;	// specific to a given bustrace
    uint64_t    addr_pa;	// PA, bottom 6 bits may be unused
} rstf_bustraceT;


enum {
  // ================
  // register types
  // 
    RSTREG_INT_RT = 1,
    RSTREG_FLOAT_RT = 2,
    RSTREG_PRIV_RT = 3,
    RSTREG_OTHER_RT = 4,	//
    RSTREG_UNUSED_RT = 5,	// register value bits are unused

      // regtype[i]=RSTREG_CC_RT => regid[i] field holds icc+xcc values
      // regid[i] bits 0:3 hold icc    regid[i] bits 4:7 hold xcc  
      //   XCC: n z v c  ICC: n z v c 
      // Bits   7 6 5 4       3 2 1 0
    RSTREG_CC_RT = 6,		        

      // regtype[i]=RSTREG_CC_RT => regid[i] field holds icc+xcc values
      // regid[i] bits 0:3 hold icc    regid[i] bits 4:7 hold xcc  
      //   XCC: n z v c  ICC: n z v c 
      // Bits   7 6 5 4       3 2 1 0
    RSTREG_FCC_RT = 7,		        

      // regtype[i]=RSTREG_WININT_RT => regid[i] field holds winptr+regnum
      // regid[i] bits 7:5 holds window pointer (0-8), for integer regs
      //                         or global type (RSTREG_USER_GLOBAL thru
      //                         RSTREG_ALTERNATE_GLOBAL) and global level
      //                         for Millennium-type architectures
      // Examples:
      //   %l5 of window 3 = 0x75 = 8b'011-10101 (l5 = 21 = 0x15)
      //   %l3 of window 7 = 0xf3 = 8b'111-10011 (l3 = 19 = 0x13)
      //   %ag3 = 0x63 = 8b'011-00011 
      // Transformation Functions:
      //   regid = (wp << 5) + regnum;
      //   wp = (regid >> 5); regnum = (regid & 0x1f);
    RSTREG_WININT_RT = 8,                        

    RSTREG_MMU_RT = 9,		// MMU specific

    RSTREG_HPRIV_RT = 10,

    RSTREG_LAST_RT = 11,

  // ================
  // register ID's
  // 

    // int registers, %g0=0,%g7=7,%o0=8,%o7=15,%l0=16,%l7=23,%i0=24,%i7=31
    RSTREG_iGLOBAL_R = 0,    
    RSTREG_iOUT_R = 8,    
    RSTREG_iLOCAL_R = 16,    
    RSTREG_iIN_R = 24,    
    RSTREG_iTHREAD_R = RSTREG_iGLOBAL_R+7,   // %g7 = & kernel thread struct
    RSTREG_iSP_R = RSTREG_iOUT_R+6,
    RSTREG_iFP_R = RSTREG_iIN_R+6,

    // float registers, SingleP=0..31, DoubleP=32..63, QuadP=64..95
    //  - A quad float occupies regval[0..1] and must be regtype[0].
    //    And, regtype[1] must be RSTREG_CC_RT or RSTREG_UNUSED_RT.

    // priv registers (same encoding as in the RDPR instr)
    // used when regtype=RSTREG_PRIV_RT
    RSTREG_TPC_R     = 0,
    RSTREG_TNPC_R    = 1, 
    RSTREG_TSTATE_R  = 2, 
    RSTREG_TT_R      = 3, 
    RSTREG_TICK_R    = 4,
    RSTREG_TBA_R     = 5, 
    RSTREG_PSTATE_R  = 6, 
    RSTREG_TL_R      = 7, 
    RSTREG_PIL_R     = 8, 
    RSTREG_CWP_R     = 9, 
    RSTREG_CANSAVE_R = 10, 
    RSTREG_CANRESTORE_R = 11, 
    RSTREG_CLEANWIN_R = 12,
    RSTREG_OTHERWIN_R = 13,
    RSTREG_WSTATE_R  = 14, 
    RSTREG_FQ_R      = 15,
    RSTREG_VERSION_R = 31,

    // There is an instance of the following registers for each trap level
    // We allocate enough space for 8 trap levels (as of 2001, MAXTL=4)
    // Thus for TPC[ TL=3 ], use regid=RSTREG_TPC_RBASE+3
    RSTREG_TPC_RBASE    = 64,
    RSTREG_TNPC_RBASE   = 72,
    RSTREG_TSTATE_RBASE = 80,
    RSTREG_TT_RBASE     = 88,

    // other registers (same encoding as in the RDSTATE instr)
    // used when regtype=RSTREG_OTHER_RT
    RSTREG_Y_R = 0,
    RSTREG_CC_R = 2, 
    RSTREG_ASI_R = 3, 
    // RSTREG_TICK_R = 4, (duplicated from above)
    RSTREG_PC_R = 5, 
    RSTREG_FPRS_R = 6, 
    RSTREG_ASR_R = 7, // not used
    RSTREG_OLDFSR_R = 8, // not used
    RSTREG_ASR_PCR_R = 16,
    RSTREG_ASR_PIC_R = 17,
    RSTREG_ASR_IEU_CTRL_R = 18,
    RSTREG_ASR_GSR_R = 19,
    RSTREG_ASR_INTR_SET_R = 20,
    RSTREG_ASR_INTR_CLR_R = 21,
    RSTREG_ASR_INTR_WRITE_R = 22,
    RSTREG_ASR_TICK_CMPR_R = 23,
    RSTREG_ASR_STICK_REG_R = 24,
    RSTREG_ASR_STICK_CMPR_R = 25,
    RSTREG_ASR_STICK_THR_STR_R = 26,
    RSTREG_ASR_NPC_R = 32,
    RSTREG_ASR_FSR_R = 33,

    // register id's for regtype RSTREG_HPRIV_RT.
    // Values correspond to rd/wr hpr instruction operand encodings
    RSTREG_HPR_HPSTATE = 0x0,
    RSTREG_HPR_HTSTATE = 0x1,
    RSTREG_HPR_HINTP = 0x3,
    RSTREG_HPR_HTBA = 0x5,
    RSTREG_HPR_HVER = 0x6,
    RSTREG_HPR_HSTICK_CMPR = 0x1f,

    // global types (used for global registers in regtype=RSTREG_WININT_RT)
    RSTREG_USER_GLOBAL = 0,		// %g0-g7
    RSTREG_INTERRUPT_GLOBAL = 1,	// %ig0-ig7
    RSTREG_MMU_GLOBAL = 2,		// %mg0-mg7
    RSTREG_ALTERNATE_GLOBAL = 3,	// %ag0-ag7

    // mmu reg types. use encodings from ASI 0x58
    RSTREG_MMU_PCONTEXT=0x8,
    RSTREG_MMU_SCONTEXT=0x10,

    RSTREG_LAST_MARKER = 15
};

/*
 * This structure contains one or two register values
 */
typedef struct {
  uint8_t     rtype;		/* value = REGVAL_T */
  unsigned    postInstr : 1;	/* 0=values before instr, 1=values AFTER */
  unsigned    cpuid : 7;	/* CPU */

  uint8_t     regtype[2];	/* type: Ex: regtype[0]=RSTREG_INT_RT */
  uint8_t     regid[2];	/* register Ex regid[0]=14 (%o6=%sp) */

  uint16_t	cpuid9_7 : 3;
  uint16_t    notused13 : 13;

  uint64_t    reg64[2];	/* reg64[i] described by regtype[i]/regid[i]*/
} rstf_regvalT;
static void rstf_regvalT_set_cpuid(rstf_regvalT * tr, int cpuid) { tr->cpuid = cpuid & 0x7f; tr->cpuid9_7 = (cpuid>>7) & 0x7; }
static int rstf_regvalT_get_cpuid(const rstf_regvalT * tr) { return (tr->cpuid9_7 << 7) | tr->cpuid; }


// Memory values
// An RST trace is associated with a direct-mapped memory cache
// of geometry 128Bytes x 32K lines. Every ifetch/load/store/prefetch
// with a valid memory PA accesses the cache. Memory value records are
// emitted for each miss

#define RSTF_MEMVAL_CACHE_BLOCKSIZE 128
#define RSTF_MEMVAL_CACHE_LINES 32768


// A memory value record can be either a memval128T or memval64T
// memval128T = 128 bits of aligned data.
//   Only give bits 4:43 of address.  Must sign extend to get full addr
//   if isContRec==1, ignore addr bits and use address from previous rec
//   This is done because the record only has enough space for 43 bits
//   of address, so a 64 bit memval that precedes the 128 bit memval
//   provides the address.
//
typedef struct {
    uint8_t     rtype;		/* value = MEMVAL_T */
    unsigned    ismemval128 : 1; // type of memval?  1=memval128T  0=memval64T
    unsigned    addrisVA : 1;   // What type of addr?  1=VA   0=PA
    unsigned    isContRec : 1;  // continuation?  applies only to memval128T
    unsigned    zero3: 3;	// should be zero
    unsigned	cpuid9_8 : 2;
    unsigned    cpuid : 8 ;     // cpu id

    // contain 40 bits <04:43> which must be sign extended to get the full addr
    uint8_t     addr36_43;	// shift this value 36 bits to the right
    uint32_t    addr04_35;	// addr = (long long) (addr04_35 << 4);
    uint64_t    val[2];		// must be ALIGNED 128 bits=16 bytes data
} rstf_memval128T;
static void rstf_memval128T_set_cpuid(rstf_memval128T * tr, int cpuid) { tr->cpuid = cpuid & 0xff; tr->cpuid9_8 = (cpuid>>8) & 3; }
static int rstf_memval128T_get_cpuid(const rstf_memval128T * tr) { return (tr->cpuid9_8<<8)|tr->cpuid; }

static void rstf_memval128T_set_addr(rstf_memval128T * tr, uint64_t addr) {tr->addr36_43 = (addr>>36)&0xff; tr->addr04_35 = (addr>>4) & ~0u;}
static uint64_t rstf_memval128T_get_addr(rstf_memval128T * tr) { return (((uint64_t)tr->addr36_43) << 36) | (((uint64_t)tr->addr04_35) << 4); }

typedef struct {
    uint8_t     rtype;		/* value = MEMVAL_T */
    unsigned    ismemval128 : 1; // type of memval?  1=memval128T  0=memval64T
    unsigned    addrisVA : 1;   // What type of addr?  1=VA   0=PA
    unsigned    isContRec : 1;  // this bit does not apply to rstf_memval64T
    unsigned    zero3: 3;	// should be zero
    unsigned	cpuid9_8 : 2;
    unsigned    cpuid : 8 ;     // cpu id
    unsigned    unused4 : 4 ;   // 
    unsigned    size  : 4 ;     // # of valid bytes in val (1-8)

    uint32_t    notused32;	//
    uint64_t    addr;		// 64 bit address
    uint64_t    val;		// 64 bits = 8 bytes of data
} rstf_memval64T;
// cpuid accessor fns same as memval128
static void rstf_memval64T_set_cpuid(rstf_memval64T * tr, int cpuid) { tr->cpuid = cpuid & 0xff; tr->cpuid9_8 = (cpuid>>8) & 3; }
static int rstf_memval64T_get_cpuid(const rstf_memval64T * tr) { return (tr->cpuid9_8<<8)|tr->cpuid; }

typedef struct {
    uint8_t     rtype;		/* value = LEFTDELIM_T, RIGHTDELIM_T */
    uint8_t     id;		/* left and right delims must match */
    uint16_t    what;		/* type of data */
    uint32_t    length;		/* length of data (bytes) in following recs */
    uint64_t    notused64;
    uint64_t    notused64a;
} rstf_delimT;

  // PHYSADDR_T: this record type is rarely used as of 7/2001
typedef struct {
    uint8_t     rtype;		/* value = PHYSADDR_T */
    unsigned    ea_valid : 1;	/* does ea_pa contain a valid address */
    unsigned    cpuid    : 7;	
    uint16_t	cpuid9_7 : 3;
    uint16_t    notused13 : 13;
    uint32_t    notused32;
    uint64_t    pc_pa;
    uint64_t    ea_pa;
} rstf_physaddrT;
static void rstf_physaddrT_set_cpuid(rstf_physaddrT * tr, int cpuid) { tr->cpuid = cpuid & 0x7f; tr->cpuid9_7 = (cpuid>>7) & 0x7; }
static int rstf_physaddrT_get_cpuid(const rstf_physaddrT * tr) { return (tr->cpuid9_7 << 7) | tr->cpuid; }

   /* tell record #, before/after processing level LEV */
typedef struct {		
    uint8_t     rtype;		/* value = FILEMARKER_T == RECNUM_T */
    unsigned    recNum : 1 ;	/* 0 = filemark, 1 = recnum */
    unsigned    level : 7 ;	/* LEV=level of the processing, 0=orig data */
    uint8_t     recType;	/* rec type (e.g. INSTR_T) to set on count */
    uint8_t     cpuID;		/* 0 = first CPU */
    uint32_t	cpuid9_8 : 2;
    uint32_t    notused30 : 30;
    uint64_t    incount;	/* input record # */
    uint64_t    outcount;	/* output record # (not used in recnum_T) */
} rstf_filemarkerT;
static void rstf_filemarkerT_set_cpuid(rstf_filemarkerT * tr, int cpuid) { tr->cpuID = cpuid & 0xff; tr->cpuid9_8 = (cpuid>>8) & 3; }
static int rstf_filemarkerT_get_cpuid(const rstf_filemarkerT * tr) { return (tr->cpuid9_8<<8)|tr->cpuID; }


// reset record number counter.
typedef struct {		
    uint8_t     rtype;		/* value = FILEMARKER_T == RECNUM_T */
    unsigned    recNum : 1 ;	/* 0 = filemark, 1 = recnum */
    unsigned    level : 7 ;	/* not used  */
    uint8_t     recType;	/* type of record (e.g. INSTR_T) to set on count) */
    uint8_t     cpuID;		/* 0 = first CPU */
    uint32_t	cpuid9_8 : 2;
    uint32_t    notused30 : 30;
    uint64_t    incount;	/* new record #  */
    uint64_t    notused64;	/* not used */
} rstf_recnumT;
// accessor funcs same as filemarkerT

typedef struct {
    uint8_t     rtype;		/* value = STRDESC_T, STRCONT_T */
    char      string[23];	/* null terminated if STRDESC, no if STRCONT */
} rstf_stringT;

    // values in a STATUS_T record
enum {
    // values for the status field a STATUS_T record
    // we start at 2 not 0, to catch the common uninitialized case.
    RST_EOF = 2,
    RST_ERROR = 3,
    RST_ANALYZER_CMD = 4,
    // let me know what else you want...

    //	analyzer specs
    // Any/all analyzers are free to ignore these records
    RST_AN_ALL_ANALYZERS = 3,	/* request for all analyzers */
    RST_AN_CACHESIM = 4,	/* all cache simulators */
    RST_AN_MPCACHESIM = 5,
    RST_AN_CYCLESIM = 8,
    RST_AN_SIM_HONEY = 9,
    RST_AN_SIM_BB = 10,
    RST_AN_AZTECS = 11,
    RST_AN_MAYAS = 12,

    // command 
    RST_ACMD_RESET_COUNTERS = 3,
    RST_ACMD_DUMP_COUNTERS = 4,

    RST_STATUS_END = 255
};    

typedef struct {
    uint8_t     rtype;		/* value = STATUS_T */
    uint8_t     status;		/* enumerated value (e.g. RST_EOF) */
    uint8_t     analzyer;	/* analyzer for ANALYZER_CMD */
    uint8_t     command;	/* command  for ANALYZER_CMD */
    uint32_t    notused32;
    uint64_t    notused64;
    uint64_t    notused64a;
} rstf_statusT;

typedef struct {
    uint8_t     rtype;		/* value = PATCH_T */

    unsigned    unused : 7;	/* */	
    unsigned    isBegin : 1;	/* 1=begin of patch, 0=end of patch */

    uint8_t     rewindrecs;	/* # recs to rewind before applying patch */
    uint8_t     id;		/* id should match begin/end pairs */

    uint16_t    length;		/* # recs in patch, ignore beg/end patchT */
    				/* we count those beg/end of nested patches */

    uint16_t    notused32;

    char        descr[16];	/* may not be null-terminated */
} rstf_patchT;

    // Categories and infotypes for HWINFO_T
    // If there are multiple values (e.g. sizes of caches) 
    // use the INDEX field to differentiate.  
    // NUMENT indicates how many vals there
enum {
    HWCAT_TRSRC = 2,	// trace source
      HWINFO_RSTBLAZE = 2,      // 
      HWINFO_ATRACE = 3,     // 
      HWINFO_SHADE5 = 5,      // 
      HWINFO_SHADE6 = 6,      // 
      HWINFO_SIMICS = 7,     // 

    HWCAT_SIMHW = 6,	// a simulated hardware value
    HWCAT_HOSTHW = 7,	// real machine hardware value

      HWINFO_CPUTYPE = 2,    // 1 = US-1, 3=US-3, etc
      HWINFO_NUMPROC = 3,    // 
      HWINFO_MEMSIZE = 4,    // bytes
      HWINFO_CPUFREQ = 5,    // Hertz    [0]=cpufreq  [1]=stick freq
      HWINFO_TLBSIZE = 8,    // size of index-th TLB, val2=assoc
      HWINFO_CACHESPEC = 9, // size
      HWINFO_NUMNIC  = 10,    // number of NICS
      HWINFO_IPADDR  = 11,   // IP address
      HWINFO_DISKSIZE = 12,  // bytes
      HWINFO_DISKDELAY = 14,  // cpufreq cycles  [0]=read delay [1]=write delay
      HWINFO_NREGWIN = 15,   // Number of register windows

    HWCAT_DUMMY = -1
};    

enum {
    SNOOP_RTO = 1,
    SNOOP_RTS = 2
};

enum {
    DEVICE_CPU = 1
};


typedef struct {                
    uint8_t     rtype;          /* value = SNOOP_T */
    uint8_t     snoopreq;	/* type of snoop request, values */	
    uint16_t    device_id;	/* agent ID initiating the request */
    uint32_t    size;		/* size in bytes of snoop */
    uint64_t    addr_pa;
    uint16_t	device_type;	/* What type of device */
    uint16_t    notused16;	/* reserved */
    uint32_t    notused32;	/* reserved */
} rstf_snoopT;

typedef struct {
    uint8_t     rtype;		/* value = HWINFO_T */
    unsigned    sim : 1;		
    unsigned    unused : 7;
    uint8_t     category;	/* category of info  Ex: sim HW value */
    uint8_t     infotype;	/* type of   value Ex: CPU freq or mem size */
    uint16_t    entindex;	/* if multiple entries (e.g. cache sizes) */
    uint16_t    nument;	        /* total number of entries 0=> only 1 entry */
    uint64_t    val;		/* value */
    uint64_t    val2;
} rstf_hwinfoT;


enum rstf_timesyncT_subtype_e {
    rstf_timesyncT_nil=0,
    rstf_timesyncT_local=1,
    rstf_timesyncT_global=2
    // 3..255: available for other events (eg serial sync)
};

typedef struct {
    uint8_t rtype; // equal to TIMESYNC_T
    uint8_t subtype; // valid values in enum rstf_timesyncT_subtype_e;
    uint16_t zero1; // reserved1

    uint16_t zero2; // reserved2
    uint16_t cpuid;

    uint64_t data; // not used for barrier sync
    uint64_t sequence_number; // use for ordering events across traces
} rstf_timesyncT;
static void rstf_timesyncT_set_cpuid(rstf_timesyncT * tr, int cpuid) { tr->cpuid = cpuid; }
static int rstf_timesyncT_get_cpuid(const rstf_timesyncT * tr) { return tr->cpuid; }


static const uint32_t rstf_devidstr_continuation_id = ~0u;
typedef struct {
    uint8_t rtype; // equal to DEVIDSTR_T

    /* Trailing characters must all be zero.  If str[18] is not zero,
     * this record is followed by more devidstrT record(s) that
     * continue the string, until a zero character is found.  These
     * continuation records have an id of <rstf_devidstr_continuation_id>
     */
    char str[19];

    uint32_t id;
} rstf_devidstrT;


/************************ RFS SUB-TRACE STUFF ***************************/

/* Structure of an RST-Format Snap:
 *
 * ========
 * Header: 
 * ========
 * Descr: rstf_stringT record identifying the trace as rfs format
 *   The string should be the RFS descriptor 23-char string:
 *   "RFS vX.YY RST-FMT SNAP\0"
 *   X is rfs_major_version, YY is rfs_minor_version (version of the
 *   RFS format SPECIFICATION)
 * ========
 * One or more RFS sections
 * ========
 *
 * An RFS section consists of an RFS section header and section data
 * The section header is of type rstf_rfs_section_headerT (defined below)
 * The various section data types are also defined below; these may be extended
 * if necessary

 *
 * IMPORTANT: Since it is possible for the record-count for
 * the RST section to be unknown,
 * there can be only one RST section in a snap, and it MUST be the last section
 * FIXME: this constraint can be relaxed at the cost of slowing down
 * the compressor/analyzers etc
 */

static const int rfs_major_version = 1;
static const int rfs_minor_version = 0;

// all "reserved" fields in rfs structures should be initialized
// to 0 for consistency.


// a ridiculously large positive 64-bit number
static const int64_t rfs_unknown_nrecords = ((~0ull)>>1);


typedef struct {
  unsigned rtype	: 8; // RFS_SECTION_HEADER_T
  unsigned section_type	: 8; // same as the data rtype (eg RFS_CW_T
                             // or RFS_BP_T or RFS_RST_T)
  unsigned reserved1	: 16;

  uint32_t reserved2;

  // n_records == rfs_unknown_nrecords indicates unknown record count:
  // reader must determine count from the input stream
  // This feature is ONLY supported for an RST section,
  // of which there can be only one
  int64_t n_records; // NOT including section header record.

  uint64_t reserved3;

  // the reserved fields may be used for a checksum (eg md5sum) in the future
} rstf_rfs_section_headerT;



typedef struct {
  uint8_t rtype;	// value = RFS_BT_T
  unsigned	cpuid	: 10;
  unsigned	taken	: 1;
  unsigned	reserved: 13;
  unsigned	instr;	// instr word
  uint64_t	pc_va;	// branch pc
  uint64_t	npc_va;	// fall-through addr if branch not taken
} rstf_bpwarmingT;
static void rstf_bpwarmingT_set_cpuid(rstf_bpwarmingT * tr, int cpuid) { tr->cpuid = cpuid; }
static int rstf_bpwarmingT_get_cpuid(const rstf_bpwarmingT * tr) { return tr->cpuid; }

enum cw_reftype_e {
  cw_reftype_NIL = 0,
  cw_reftype_I = 1,
  cw_reftype_R = 2,
  cw_reftype_W = 3,
  cw_reftype_PF_D = 4,
  cw_reftype_PF_I = 5,
  cw_reftype_DMA_R = 6,
  cw_reftype_DMA_W = 7,

  cw_reftype_MAX
};


typedef struct {
  uint8_t	rtype;	// value = RFS_CW_T

  unsigned	cpuid	: 10; // must be ZERO for DMA_R and DMA_W reftypes
  unsigned	reftype	: 6;

  unsigned	reserved1: 8;

  union refinfo_u {
    uint32_t	dma_size;

    struct refinfo_s {
      unsigned	asi	: 8; // must be defined for ALL reference types
                             // except DMA. For DMA, the dma_size field
			     // overlaps with this struct
      unsigned	va_valid: 1;
      unsigned	fcn	: 5; // for prefetch refs only. For others,
                             // consider this as "reserved"
      unsigned	reserved: 18;
    } s;

    uint32_t l; // this is just to represent refinfo_s as a 32-bit
                // quantity that can be passed to functions

  } refinfo;

  // va must be ZERO for DMA_R or DMA_W. and if the refinfo.s.va_valid
  // bit is clear
  uint64_t	va;

  uint64_t	pa;
} rstf_cachewarmingT;
static void rstf_cachewarmingT_set_cpuid(rstf_cachewarmingT * tr, int cpuid) { tr->cpuid = cpuid; }
static int rstf_cachewarmingT_get_cpuid(const rstf_cachewarmingT * tr) { return tr->cpuid; }

/******************END OF RFS SUB-TRACE STUFF ***************************/


  // my template for use in emacs.  Ignore.
typedef struct {		/* not done yet */
    uint8_t     rtype;		/* value = PROTO_T */
    uint8_t     notused8;
    uint16_t    notused16;
    uint32_t    notused32;
    uint64_t    notused64;
    uint64_t    notused64a;
} rstf_whatT;

typedef union {
    rstf_headerT		header;
    rstf_instrT			instr;
    rstf_traceinfo_levelT	tlevel;
    rstf_cpuinfoT		cpuinfo;
    rstf_cpuidinfoT		cpuidinfo;
    rstf_tlbT			tlb;
    rstf_threadT		thread;
    rstf_pregT	        	preg;
    rstf_trapT			trap;
    rstf_trapexitT		trapexit;
    rstf_trapping_instrT	trapping_instr;
    rstf_cpuT			cpu;
    rstf_dmaT			dma;
    rstf_delimT			delim;
    rstf_physaddrT		physaddr;
    rstf_pavadiffT		pavadiff;
    rstf_filemarkerT		fmarker;
    rstf_hwinfoT		hwinfo;
    rstf_recnumT		recnum;
    rstf_stringT		string;
    rstf_statusT		status;
    rstf_patchT			patch;
    rstf_regvalT        	regval;
    rstf_memval64T      	memval64;
    rstf_memval128T     	memval128;
    rstf_bustraceT		bustrace;
    rstf_snoopT			snoop;
    rstf_tsb_accessT		tsb_access;
    rstf_rfs_section_headerT    rfs_section_header;
    rstf_bpwarmingT		bpwarming;
    rstf_cachewarmingT		cachewarming;

    // types for fields in the rst record
    rstf_protoT		proto;
    rstf_uint8T	        arr8;
    rstf_uint16T	arr16;
    rstf_uint32T	arr32;
    rstf_uint64T	arr64;

#if defined(RSTF_USE_DEPRECATED)
    rstf_contextT	context;
#endif

} rstf_unionT;

#define SIZEOF_RSTF (sizeof(rstf_unionT))

// ================ 4) Useful functions ================
//
// Some macros and functions for dealing with rstf
// 

  // Do a compile-time vs run-time check on a record from a trace
int rstf_checkheader (const char* compile_time_ver, rstf_headerT *rec);

  // Open a RST file for reading.
  // If the file is compressed (rstzip/rstzip2), automatically decompress
  //   We use popen() internally, if filename is a compressed file
  // Returns
  //   null on error and sets errno
  //   
FILE* openRST (const char* filename);
void closeRST (FILE* f);	// pclose(f); if compressed
int  isPipeRST (FILE* f);	// 1 if f is a pipe, as in from popen().

  // initialize a header record with the current RST major/minor number.
  // The string 
int init_rstf_header (rstf_headerT * headerp);

  // initialize a header record with the current RST major/minor number.
int init_rstf_traceinfo_level (rstf_traceinfo_levelT * ti, int level);

  // Initialize a single STR_DESC RST record STRP with the string STR
  // takes the last 22 chars if STR will not fully fit.
int init_rstf_string (rstf_stringT * strp, const char *str);

  // Note: In most cases, rstf_snprintf() is easier to use.
  // Initialize upto MAXREC records with the string STR, using
  // STRDESC_T and STRCONT_T records.  Handles strings of any length.
  // Returns the number of RST records used.
  // You must allocate the space to which STRP points.
  // 
  // Ex:
  //   rstf_unionT buff[128];
  //   int currIdx = 37 ;
  //   char charbuff [8192];
  //   sprintf(charbuff, "A long bunch of data %s %d ...", ... );
  //   rstf_sprintf( &buff[currIdx] , charbuff, 128-37-1 );
  // 
int init_rstf_strbuff (rstf_stringT * strp, const char *str, int maxrec);

  // Convenience fns:
  // rstf_sprintf():
  //  initialize a RST record STRP with the sprintf output
  //  if the resulting string is too long, the last 22 chars are used.
  // 
  // rstf_snprintf()
  //  initialize upto MAXREC RST records STRP with the sprintf output
  //  if the resulting string is too long, the last characters are dropped.
  //  Also, we use an 8K buffer, all chars beyond which are silently dropped.
  //  Returns the number of RST records actually used.
  // 
  // Ex:
  //   rstf_unionT buff[...];
  //   rstf_unionT * currRec = ... ;
  //   struct passwd * pp = getpwuid( getuid() );
  //   nr = rstf_sprintf( currRec, "Collected by user %s", pp->pw_name);
  //   nr = rstf_snprintf( currRec+1, 4, "Some big long string %s", stringval);
  // 
int rstf_sprintf (rstf_stringT * strp, const char* fmt, ...);
int rstf_snprintf (rstf_stringT * strp, int maxrec, const char* fmt, ...);

  // Given a multi-record string, read it.
  // STRP points to the first of NREC consecutive (in an array) RST records.
  //   These need not all be string, but must know how many recs we can read.
  // Returns the string in a static buffer.
  // If NRREAD != NULL, we return the number of RST records we skipped over.
  // Internally we use a 2048 char buffer.
const char* get_rstf_longstr (const rstf_stringT * strp, int nrec, int *nrread);

  // 1) Return the result of running command COMMAND
  // The result is returned in a static buffer of size at least 4K.
  // 
  // 2) Store the exit status at *EXIT_STATUS, if this addr is non-NULL
  // 3) Get at most MAXLINE lines of output from the COMMAND.
  // 
char* unixcommand (const char * command, int MAXLINE, int* exit_status);

  // returns a pointer to a statically allocated buffer
  // Ex: rstf_btTxtype2str (RST_BTTX_RTSA) ==> "RTSA"
const char* rstf_btTxtype2str (int txType);


  // the set cpuid function must be called *after* initializing the rtype field
  // the get cpuid function returns 0xffff if the cpuid field is not present in
  // the record type being queried.
static void rstf_set_cpuid(rstf_unionT * rec, int cpuid) {
  switch(rec->proto.rtype) {
  case INSTR_T:
    rstf_instrT_set_cpuid(&rec->instr, cpuid);
    break;
  case PAVADIFF_T:
    rstf_pavadiffT_set_cpuid(&rec->pavadiff, cpuid);
    break;
  case TLB_T:
    rstf_tlbT_set_cpuid(&rec->tlb, cpuid);
    break;
  case PREG_T:
    rstf_pregT_set_cpuid(&rec->preg, cpuid);
    break;
  case TRAP_T:
    rstf_trapT_set_cpuid(&rec->trap, cpuid);
    break;
  case TRAPEXIT_T:
    rstf_trapexitT_set_cpuid(&rec->trapexit, cpuid);
    break;
  case TSB_ACCESS_T:
    rstf_tsb_accessT_set_cpuid(&rec->tsb_access, cpuid);
    break;
  case TRAPPING_INSTR_T:
    rstf_trapping_instrT_set_cpuid(&rec->trapping_instr, cpuid);
    break;
  case REGVAL_T:
    rstf_regvalT_set_cpuid(&rec->regval, cpuid);
    break;
  case MEMVAL_T:
    rstf_memval128T_set_cpuid(&rec->memval128, cpuid);
    break;
  case PHYSADDR_T:
    rstf_physaddrT_set_cpuid(&rec->physaddr, cpuid);
    break;
  case FILEMARKER_T:
    rstf_filemarkerT_set_cpuid(&rec->fmarker, cpuid);
    break;
  case RFS_BT_T:
    rstf_bpwarmingT_set_cpuid(&rec->bpwarming, cpuid);
    break;
  case RFS_CW_T:
    rstf_cachewarmingT_set_cpuid(&rec->cachewarming, cpuid);
    break;
  default:
    break;
    // fprintf(stderr, "rstf.h: warning: set_cpuid meaningless for rtype=%d\n", rec->proto.rtype);
  } // swithc(rtype)
}

static int16_t rstf_get_cpuid(const rstf_unionT * rec)
{
  switch(rec->proto.rtype) {
  case INSTR_T:
    return rstf_instrT_get_cpuid(&rec->instr);
    break;
  case PAVADIFF_T:
    return rstf_pavadiffT_get_cpuid(&rec->pavadiff);
    break;
  case TLB_T:
    return rstf_tlbT_get_cpuid(&rec->tlb);
    break;
  case PREG_T:
    return rstf_pregT_get_cpuid(&rec->preg);
    break;
  case TRAP_T:
    return rstf_trapT_get_cpuid(&rec->trap);
    break;
  case TRAPEXIT_T:
    return rstf_trapexitT_get_cpuid(&rec->trapexit);
    break;
  case TSB_ACCESS_T:
    return rstf_tsb_accessT_get_cpuid(&rec->tsb_access);
  case TRAPPING_INSTR_T:
    return rstf_trapping_instrT_get_cpuid(&rec->trapping_instr);
  case REGVAL_T:
    return rstf_regvalT_get_cpuid(&rec->regval);
    break;
  case MEMVAL_T:
    return rstf_memval128T_get_cpuid(&rec->memval128);
    break;
  case PHYSADDR_T:
    return rstf_physaddrT_get_cpuid(&rec->physaddr);
    break;
  case FILEMARKER_T:
    return rstf_filemarkerT_get_cpuid(&rec->fmarker);
    break;
  case RFS_BT_T:
    return rstf_bpwarmingT_get_cpuid(&rec->bpwarming);
    break;
  case RFS_CW_T:
    return rstf_cachewarmingT_get_cpuid(&rec->cachewarming);
    break;
  default:
    // fprintf(stderr, "rstf.h: warning: get_cpuid meaningless for rtype=%d\n", rec->proto.rtype);
    return -1;
  } // swithc(rtype)
} // static int16_T rstf_get_cpuid()



  // Initialize the RST record pointed ty by RST_PTR, with the rtype RTYPE_VAL
  // Fill the rest of the record with zero data.
  // This macro code is as efficient as I (RQ) could make it.
  // Ex:
  //    rstf_unionT array[256];
  //    ...
  // 	INIT_RST_REC( &array[k], INSTR_T);
  //    rstf_instrT * p = & ( array[k].instr );
  // 
#define INIT_RST_REC(rstf_x_ptr,rtype_val) \
    do { \
	rstf_uint64T * p_x_rst = (rstf_uint64T*) (rstf_x_ptr); \
	p_x_rst->arr64[0] = (rtype_val); \
	p_x_rst->arr64[0] <<= (64-8); \
	p_x_rst->arr64[1] = 0; \
	p_x_rst->arr64[2] = 0; \
    } while (0==1)

#define ZERO_RST_REC(rstf_x_ptr) \
    do { \
	rstf_uint64T * p_x_rst = (rstf_uint64T*) (rstf_x_ptr); \
	p_x_rst->arr64[0] = 0; \
	p_x_rst->arr64[1] = 0; \
	p_x_rst->arr64[2] = 0; \
    } while (0==1)

  // The tte_data that blaze v2.40-v3.60 uses to mimic the US-III.
  // This type is now an official type in rstf.h
  // 
struct rstf_tte_dataT {
    unsigned          valid           : 1;    /* valid bit */
    unsigned          size            : 2;    /* page size */
    unsigned          nfo             : 1;    /* no-fault only */
    unsigned          ie              : 1;    /* invert endianness */
    unsigned          soft2           : 9;    /* forced to zero */
    unsigned          subpg           : 2;
    unsigned          sn              : 1;    /* snoop bit */
    unsigned          diag_reserved   : 2;
    unsigned          diag_used       : 1;
    unsigned          io              : 1;
    unsigned          pa_tag_hi       : 11;   /* PA bits <42:32> hi+lo give 43 bit PA */
    unsigned          pa_tag_lo       : 19;   /* PA bits <31:13> (use for 32-bit addr) */
    unsigned          soft            : 6;    /* forced to zero */
    unsigned          lock            : 1;    /* lock bit */
    unsigned          cp              : 1;    /* cacheable physical */
    unsigned          cv              : 1;    /* cacheable virtual */
    unsigned          e               : 1;    /* side-effect */
    unsigned          priv            : 1;    /* priviledged */
    unsigned          writable        : 1;    /* writeable */
    unsigned          global          : 1;    /* global (same as tag.g) */
};

#ifdef  __cplusplus
}
#endif

#endif  /* _rstf_h */
