/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rstf_deprecated.h
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
#ifndef _rstf_deprecated_h
#define _rstf_deprecated_h

//
// Deprecated code from rstf.h
// 

#define RSTF_USE_DEPRECATED	// enable deprecated values in rstf.h

enum {
    ASI_T = 4,		// (DEPRECATED) change in ASI
    CONTEXT_T = 17,	// historic name CONTEXT_T (DEPRECATED), use PREG_T

    RSTF_DEPRECATED_LAST_T = 0	// dummy marker
};

typedef rstf_pregT	rstf_contextT;

/* ****************************************************************
 * ****************************************************************
 * ****************************************************************
 * ****************************************************************
 * Here are some older, common record formats.
 * We provide them for various tools such as tfmtconv 
 * which converts from the various formats.
 * 
 * I (RQ) personally do not use these types.
 * ****************************************************************
 * ****************************************************************
 * ****************************************************************
 * ****************************************************************
 * ****************************************************************
 */

  /* 
   * Special instruction format for "the" TPC-C Sybase DB trace.
   * This format is not used for anything else (!)
   * 
   * In particular, Blaze creates standard shade traces of 
   * type "struct Trace" defined in trace.h
   */
typedef struct {
	uint32_t tr_i;
	uint32_t tr_pc;
	uint32_t tr_ea;
        uint16_t tr_ih;
        uint16_t tr_misc;
} rtf99_trace_t;

  /* 
   * Minimal Shade V5 trace record.
   */
typedef struct {
        uint32_t  tr_pc;          /* instruction address */
        uint32_t  tr_i;           /* instruction text, Instr = uint32_t */
        uint8_t   tr_annulled;    /* instruction annulled? */
        uint8_t   tr_taken;       /* true if branch, trap taken, cond-move/st executed */
        uint16_t  tr_ih;          /* ihash() value (opcode) */

  // For DCTI: Target address (NOT the fall thru PC+8 for untaken branches).
  // for loads, stores, traps: rs1+(rs2 or simm13)
        uint32_t  tr_ea;          
} shadeV5_trace_t;

  /* 
   * Minimal Shade V6 32 bit trace record.
   */
typedef struct {
	unsigned		tr_ih	            : 16;
	unsigned		tr_shade_reserved0  : 5;
	unsigned		tr_annulled         : 1;
	unsigned		tr_taken            : 1;
	unsigned		tr_iwstart          : 1;
	unsigned		tr_shade_reserved1  : 8;
	unsigned		tr_tid;
	uint32_t		tr_pc;
	uint32_t		tr_ea;
	uint32_t		tr_i;
	unsigned		tr_reserved1;
} shadeV6_32bit_trace_t;

  /* 
   * Minimal Shade V6 64 bit trace record, V9 trace.
   */
typedef struct {
	unsigned		tr_ih	            : 16;
	unsigned		tr_shade_reserved0  : 5;
	unsigned		tr_annulled         : 1;
	unsigned		tr_taken            : 1;
	unsigned		tr_iwstart          : 1;
	unsigned		tr_shade_reserved1  : 8;
	unsigned		tr_tid;
	uint64_t		tr_pc;
	uint64_t		tr_ea;
	uint32_t		tr_i;
	unsigned		tr_reserved1;
} shadeV6_64bit_trace_t;

  /* 
   * Proposed master format.  All types of fields likely to be recorded.
   * Used for internal trace conversion.  (I do not use this)
   */
typedef struct {
    unsigned        tr_reserved0  : 8;	/* unused bits */
    unsigned        tr_userdefined : 1;	/* unused bits */
    unsigned        tr_va_valid   : 1;	/* got a trap */
    unsigned        tr_got_trap   : 1;	/* got a trap */
    unsigned        tr_asi_change : 1;	/* change to ASI reg */
    unsigned        tr_privmode   : 1;	/* priviledge mode */
    unsigned        tr_taken      : 1;	/* branch taken */
    unsigned        tr_annulled   : 1;  /* this instr is annulled */
    unsigned        tr_iwstart    : 1;  /* wide instruction */
    unsigned        tr_ih         : 16; /* ihash value */
    uint32_t     	    tr_i;          	/* instruction word */
    uint64_t          tr_pc_va;		/* VA */
    uint64_t          tr_ea_va;		/* VA */
    uint32_t          tr_tid;		/* thread id */
    unsigned        tr_reserved1;       /* not used */
    uint64_t          tr_pc_pa;		/* PA */
    uint64_t          tr_ea_pa;		/* PA */
    uint32_t          tr_context;	/* context/processid */
    uint8_t           tr_asi;		/* ASI */
    /* ... */
} master_64bit_trace_t;

typedef shadeV6_64bit_trace_t Tshade6x64;
typedef shadeV6_32bit_trace_t Tshade6x32;
typedef shadeV5_trace_t       Tshade5;
typedef rtf99_trace_t         Trtf99;
typedef master_64bit_trace_t  Tmaster64;

#endif  /* _rstf_deprecated_h */
