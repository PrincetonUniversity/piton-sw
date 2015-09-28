// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: rz3iu.C
// Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
// DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
// 
// The above named program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
// 
// The above named program is distributed in the hope that it will be 
// useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
// 
// You should have received a copy of the GNU General Public
// License along with this work; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
// 
// ========== Copyright Header End ============================================
/* rz3iu.C
 */

#include <sys/types.h>

#include "rz3iu.h"

#include "rz_insttypes.h"

// #include "spix_sparc.h"

// union dcti_info_u gen_dcti_info(uint32_t instr, spix_sparc_iop_t iop)

// fixed in v3.18 - better classification of branch_never insts
union dcti_info_u gen_dcti_info(uint32_t instr)
{
  union dcti_info_u dinfo;
  dinfo.u32 = 0x0;

  // if (spix_sparc_iop_isdcti(iop)) {
  if (rz_is_dcti(instr)) {
    dinfo.flags.isdcti = true;
    // if (spix_sparc_iop_isbranch(iop)) {
    if (rz_is_branch(instr)) {
      dinfo.flags.isbranch = true;
      // if (spix_sparc_iop_iscbranch(iop)) {
      if (rz_is_cbranch(instr)) {
	dinfo.flags.iscbranch = true;
      } else /* not cbranch */ {
	dinfo.flags.isubranch = true;
	// uint32_t b = (instr & UBRANCH_OPCODE_MASK);
	// if ((b == FBN_OPCODE_BITS) || (b == BN_OPCODE_BITS)) {
	if (rz_is_ubranch_never(instr)) {
	  dinfo.flags.isubranch_nottaken = true;
	}
      } /* cbranch? */

      dinfo.flags.annul_flag = (instr >> 29) & 1;

      // specific branch type and disp
      // if ((instr & BPcc_OPCODE_MASK) == BPcc_OPCODE_BITS) {
      if (rz_is_bpcc(instr)) {
	dinfo.flags.isBPcc = 1;
	// } else if ((instr & BPR_OPCODE_MASK) == BPR_OPCODE_BITS) {
      } else if (rz_is_bpr(instr)) {
	dinfo.flags.isBPR = 1;
	// } else if ((instr & FBfcc_OPCODE_MASK) == FBfcc_OPCODE_BITS) {
      } else if (rz_is_fbfcc(instr)) {
	dinfo.flags.isFBfcc = 1;
	// } else if ((instr & FBPfcc_OPCODE_MASK) == FBPfcc_OPCODE_BITS) {
      } else if (rz_is_fbpfcc(instr)) {
	dinfo.flags.isFBPfcc = 1;
	// } else if ((instr & Bicc_OPCODE_MASK) == Bicc_OPCODE_BITS) {
      } else if (rz_is_bicc(instr)) {
	dinfo.flags.isBicc = 1;
      } else {
	/* other branch instr? */
	fprintf(stderr, "ERROR: rz3iu: gen_dcti_info: invalid branch instr %08x\n", instr);
	dinfo.u32 = 0;
	return dinfo;
      }

    } else /* not branch */ {
      // if ((instr & CALL_OPCODE_MASK) == CALL_OPCODE_BITS) {
      if (rz_is_call(instr)) {
	dinfo.flags.iscall = 1;
      } else {
	dinfo.flags.isindirect = 1;
	// is ret if rd=0, rs1=31, imm=8
	// is retl if rd=0, rs1=15, imm=8
	// is "call indirect" otherwise if rd is 15
	int rs1 = (instr >> 14) & 0x1f;
	int rd = (instr >> 25) & 0x1f;
	uint32_t simm13 = instr & 0x1fff;
	if ((rd == 0) && (simm13 == 0x8)){
	  if (rs1 == 15) {
	    dinfo.flags.is_retl = 1;
	  } else if (rs1 == 31) {
	    dinfo.flags.is_ret = 1;
	  } else {
	    // do nothing
	  }
	} // else - do nothing
      }
    } // branch?
    // } else if ((iop == SPIX_SPARC_IOP_DONE)||(iop == SPIX_SPARC_IOP_RETRY)) {
  } else if (rz_is_done(instr) || rz_is_retry(instr)) {
    dinfo.flags.is_done_retry = 1;
  } else {
    // do nothing
  } // instr type?

  return dinfo;
} // gen_dcti_info


// BUG: in versions 3.17 and older, branch_never insts were counted
// as conditional branches and iscbranch was set, because of the
// way spix classifies these insts. this leads to an incorrect value
// of iscbranch/isubranch/isubranch_nottaken for branch_never insts.
// This causes the compressor to use the branch predictor for these
// branches, which affects the compression efficiency.
union dcti_info_u gen_dcti_info_v317(uint32_t instr)
{
  union dcti_info_u dinfo;
  dinfo.u32 = 0x0;

  // if (spix_sparc_iop_isdcti(iop)) {
  if (rz_is_dcti(instr)) {
    dinfo.flags.isdcti = true;
    // if (spix_sparc_iop_isbranch(iop)) {
    if (rz_is_branch(instr)) {
      dinfo.flags.isbranch = true;
      // if (spix_sparc_iop_iscbranch(iop)) {
      if (rz_is_cbranch(instr) || rz_is_ubranch_never(instr)) {
	dinfo.flags.iscbranch = true;
      } else /* not cbranch */ {
	dinfo.flags.isubranch = true;
	uint32_t b = (instr & UBRANCH_OPCODE_MASK);
	if ((b == FBN_OPCODE_BITS) || (b == BN_OPCODE_BITS)) {
	  dinfo.flags.isubranch_nottaken = true;
	}
      } /* cbranch? */

      dinfo.flags.annul_flag = (instr >> 29) & 1;

      // specific branch type and disp
      // if ((instr & BPcc_OPCODE_MASK) == BPcc_OPCODE_BITS) {
      if (rz_is_bpcc(instr)) {
	dinfo.flags.isBPcc = 1;
	// } else if ((instr & BPR_OPCODE_MASK) == BPR_OPCODE_BITS) {
      } else if (rz_is_bpr(instr)) {
	dinfo.flags.isBPR = 1;
	// } else if ((instr & FBfcc_OPCODE_MASK) == FBfcc_OPCODE_BITS) {
      } else if (rz_is_fbfcc(instr)) {
	dinfo.flags.isFBfcc = 1;
	// } else if ((instr & FBPfcc_OPCODE_MASK) == FBPfcc_OPCODE_BITS) {
      } else if (rz_is_fbpfcc(instr)) {
	dinfo.flags.isFBPfcc = 1;
	// } else if ((instr & Bicc_OPCODE_MASK) == Bicc_OPCODE_BITS) {
      } else if (rz_is_bicc(instr)) {
	dinfo.flags.isBicc = 1;
      } else {
	/* other branch instr? */
	fprintf(stderr, "ERROR: rz3iu: gen_dcti_info: invalid branch instr %08x\n", instr);
	dinfo.u32 = 0;
	return dinfo;
      }

    } else /* not branch */ {
      // if ((instr & CALL_OPCODE_MASK) == CALL_OPCODE_BITS) {
      if (rz_is_call(instr)) {
	dinfo.flags.iscall = 1;
      } else {
	dinfo.flags.isindirect = 1;
	// is ret if rd=0, rs1=31, imm=8
	// is retl if rd=0, rs1=15, imm=8
	// is "call indirect" otherwise if rd is 15
	int rs1 = (instr >> 14) & 0x1f;
	int rd = (instr >> 25) & 0x1f;
	uint32_t simm13 = instr & 0x1fff;
	if ((rd == 0) && (simm13 == 0x8)){
	  if (rs1 == 15) {
	    dinfo.flags.is_retl = 1;
	  } else if (rs1 == 31) {
	    dinfo.flags.is_ret = 1;
	  } else {
	    // do nothing
	  }
	} // else - do nothing
      }
    } // branch?
    // } else if ((iop == SPIX_SPARC_IOP_DONE)||(iop == SPIX_SPARC_IOP_RETRY)) {
  } else if (rz_is_done(instr) || rz_is_retry(instr)) {
    dinfo.flags.is_done_retry = 1;
  } else {
    // do nothing
  } // instr type?

  return dinfo;
} // gen_dcti_info


void rz3iu_icache_data::gen_target(uint64_t pc)
{
  if (dinfo.flags.isbranch) {
    if (dinfo.flags.isBPcc) {
      target = pc + BPcc_DISP(instr);
    } else if (dinfo.flags.isBPR) {
      target = pc + BPR_DISP(instr);
    } else if (dinfo.flags.isFBfcc) {
      target = pc + FBfcc_DISP(instr);
    } else if (dinfo.flags.isFBPfcc) {
      target = pc + FBPfcc_DISP(instr);
    } else if (dinfo.flags.isBicc) {
      target = pc + Bicc_DISP(instr);
    } else {
      assert(0);
    }
  } else if (dinfo.flags.iscall) {
    target = pc + CALL_DISP(instr);
  }
} // gen_target()


