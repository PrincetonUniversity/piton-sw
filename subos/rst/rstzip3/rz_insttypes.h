/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rz_insttypes.h
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
/* rz_insttypes.h
 * lightweight spix-like calls to determine inst types and
 * extract information like effective addresses from sparcv9 insts
 *
 * Copyright (c) 2004 by Sun Microsystems, Inc.
 * All rights reserved.
 *
 */


#ifndef _rz_insttypes_h_
#define _rz_insttypes_h_


/* Notes
 *
 * rz_insttypes.h contains a set of macros and functions used to
 * decode and classify SPARC V9 instructions. It is meant as a
 * light-weight replacement for SPIX. All functions take the 32-bit
 * instr word as the sole argument
 *
 * Here is a list of the functions available, their spix equivalents,
 * and crucial differences between spix and this library:
 *
 * rz_is_dcti() -- equivalent to spix_sparc_iop_isdcti()
 *
 * rz_is_branch() -- equivalent to spix_sparc_iop_isbranch()
 *
 * rz_isubranch_always() -- equivalent to spix_sparc_iop_isubranch()
 *
 * rz_isubranch_never() -- true for BRANCH NEVER instructions
 *
 * rz_isubranch() -- unconditional branches (ALWAYS and NEVER)
 *    NOT equivalent to spix_sparc_iop_isubranch()
 *
 * rz_iscbranch() -- conditional branches (does not include BRANCH NEVER)
 *    NOT equivalent to spix_sparc_iop_iscbranch()
 *
 * rz_isbpr(), rz_isbpcc(), rz_isbicc(), rz_fbfcc(), rz_isfbpcc(),
 * rz_iscall(), rz_isreturn(), rz_isdone(), rz_isretry()
 *
 * rz_isprefetch() -- equivalent to spix_sparc_iop_isprefetch()
 *
 * rz_isload() -- true for loads but not load-store or prefetch insts
 *  NOT equivalent to spix_sparc_iop_isload()
 *
 * rz_is_load_store() -- conditional AND unconditional load-store insts
 *  rz_isustore() -- contains unconditional stores and unconditional load-stores
 *
 * rz_is_load_store_conditional() -- equivalent to spix_sparc_iop_iscstore()
*/



#define sign_ext_hi_bit(x, n) (((x) >> ((n)-1)) & 1)
#define sign_ext_1(x, n) (sign_ext_hi_bit(x, n) ? (~0ull)<<((n)-1) : 0ull)

#define sign_ext_lo_mask(n) ((1ull << (n)) - 1)
#define sign_ext_2(x, n) ((x) & sign_ext_lo_mask(n))

//#define sign_ext(x, n) (sign_ext_1((x), (n)) | sign_ext_2((x), (n)))
static inline int64_t sign_ext(int64_t imm, int sz) {
  int64_t rv = (imm << (64 - sz));
  rv = (rv >> (64-sz));
  return rv;
}



#define BPcc_OPCODE_MASK 0xc1c00000u
#define BPcc_OPCODE_BITS 0x00400000u
#define BPcc_DISP(_opc_) (sign_ext((_opc_ & 0x7ffff), 19) << 2)

static inline bool rz_is_bpcc(uint32_t instr)
{
  return ((instr & BPcc_OPCODE_MASK) == BPcc_OPCODE_BITS);
} // static inline bool rz_is_bpcc(uint32_t instr)


#define BPR_OPCODE_MASK 0xd1c00000u
#define BPR_OPCODE_BITS 0x00c00000u
#define BPR_DISP_d16hi(_opc_) (((_opc_) >> 20) & 0x3)
#define BPR_DISP_d16lo(_opc_) ((_opc_) & 0x3fff)
#define BPR_DISP_d16(_opc_) ((BPR_DISP_d16hi(_opc_) << 14) | BPR_DISP_d16lo(_opc_))
#define BPR_DISP(_opc_) (sign_ext(BPR_DISP_d16(_opc_), 16) << 2)

static inline bool rz_is_bpr(uint32_t instr) {
  if ((instr & BPR_OPCODE_MASK) == BPR_OPCODE_BITS) {
    uint32_t rcond = (instr >> 25) & 0x7;
    return ((rcond & 3) != 0);
  } else {
    return false;
  }
} // static inline bool rz_is_bpr(uint32_t instr) {

#define FBfcc_OPCODE_MASK 0xc1c00000u
#define FBfcc_OPCODE_BITS 0x01800000u
#define FBfcc_DISP(_opc_) (sign_ext((_opc_ & 0x3fffff), 22) << 2)

static inline bool rz_is_fbfcc(uint32_t instr)
{
  return ((instr & FBfcc_OPCODE_MASK) == FBfcc_OPCODE_BITS);
}


#define FBPfcc_OPCODE_MASK 0xc1c00000u
#define FBPfcc_OPCODE_BITS 0x01400000u
#define FBPfcc_DISP(_opc_) (sign_ext((_opc_ & 0x7ffff), 19) << 2)


static inline bool rz_is_fbpfcc(uint32_t instr)
{
  return ((instr & FBPfcc_OPCODE_MASK) == FBPfcc_OPCODE_BITS);
} // static inline bool rz_is_fbpfcc(uint32_t instr)


#define Bicc_OPCODE_MASK 0xc1c00000u
#define Bicc_OPCODE_BITS 0x00800000u
#define Bicc_DISP(_opc_) (sign_ext((_opc_ & 0x3fffff), 22) << 2)



static inline bool rz_is_bicc(uint32_t instr)
{
  return ((instr & Bicc_OPCODE_MASK) == Bicc_OPCODE_BITS);
} // static inline bool rz_is_bicc(uint32_t instr)



#define CALL_OPCODE_MASK 0xc0000000u
#define CALL_OPCODE_BITS 0x40000000u
#define CALL_DISP(_opc_) (sign_ext((_opc_ & 0x3fffffff), 30) << 2)



static inline bool rz_is_call(uint32_t instr)
{
  return ((instr & CALL_OPCODE_MASK) == CALL_OPCODE_BITS);
} // static inline bool rz_is_call(uint32_t instr)



#define UBRANCH_OPCODE_MASK 0xdfc00000u

#define FBA_OPCODE_BITS 0x11400000u
#define FBN_OPCODE_BITS 0x01400000u

#define FBPA_OPCODE_BITS 0x11400000u
#define FBPN_OPCODE_BITS 0x01400000u

#define BA_OPCODE_BITS 0x10400000u
#define BN_OPCODE_BITS 0x00400000u

#define BPA_OPCODE_BITS 0x10400000u
#define BPN_OPCODE_BITS 0x00400000u

#define RESTORE_OPCODE_MASK 0xc1f80000
#define RESTORE_OPCODE_BITS 0x81e80000

#define MOV_G1_G7_INSTR 0x9e100001


#define JMPL_OPCODE_MASK 0xc1f80000
#define JMPL_OPCODE_BITS 0x81c00000
static inline bool rz_is_jmpl(uint32_t instr)
{
  return ((instr & JMPL_OPCODE_MASK) == JMPL_OPCODE_BITS);
} // static inline bool rz_is_jmpl(uint32_t instr)


#define RETURN_OPCODE_MASK 0xc1f80000
#define RETURN_OPCODE_BITS 0x81c80000
static inline bool rz_is_return(uint32_t instr)
{
  return ((instr & RETURN_OPCODE_MASK) == RETURN_OPCODE_BITS);
} //static inline bool rz_is_return(uint32_t instr)


static inline bool rz_is_branch(uint32_t instr) {
  return rz_is_bpr(instr) || rz_is_fbfcc(instr) || rz_is_fbpfcc(instr) || rz_is_bicc(instr) || rz_is_bpcc(instr);
}

static inline bool rz_is_ubranch_always(uint32_t instr) {
  // op=0, (op2 =~ ?01 or op2 =~ ?10), cond == 8
  return ((instr & 0xdec00000) == 0x10800000) || ((instr & 0xdec00000) == 0x10400000);
}

static inline bool rz_is_ubranch_never(uint32_t instr) {
  // op=0, (op2 =~ ?01 or op2 =~ ?10), cond == 0
  return ((instr & 0xdec00000) == 0x00800000) || ((instr & 0xdec00000) == 0x00400000);
}

static inline bool rz_is_ubranch(uint32_t instr) {
  return rz_is_ubranch_always(instr) || rz_is_ubranch_never(instr);
}

// DIFFERENCE FROM SPIX: spix _iscbranch() includes branch_never. ours does NOT.
static inline bool rz_is_cbranch(uint32_t instr) {
  return (rz_is_branch(instr) && ! rz_is_ubranch(instr));
}

static inline bool rz_is_dcti(uint32_t instr)
{
  return rz_is_branch(instr) || rz_is_call(instr) || rz_is_jmpl(instr) || rz_is_return(instr);
} //  static inline bool rz_is_dcti(uint32_t instr)


static inline bool rz_is_pc_relative_cti(uint32_t instr)
{
  return rz_is_branch(instr) || rz_is_call(instr);
}

#define DONE_RETRY_OPCODE_MASK 0xfff80000
#define DONE_OPCODE_BITS 0x81f00000
#define RETRY_OPCODE_BITS 0x83f00000
static inline bool rz_is_done(uint32_t instr)
{
  return ((instr & DONE_RETRY_OPCODE_MASK) == DONE_OPCODE_BITS);
}


static inline bool rz_is_retry(uint32_t instr)
{
  return ((instr & DONE_RETRY_OPCODE_MASK) == RETRY_OPCODE_BITS);
} // static inline bool rz_is_retry(uint32_t instr)



static inline bool rz_is_ldstpf(uint32_t instr)
{
  return ((instr >> 30) == 0x3);
} // static inline bool rz_is_ldstpf(uint32_t instr)


// does *not* include load-store insts, unlike spix _isload()
// also does *not* include prefetches, unlike spix _isload()
static inline bool rz_is_load(uint32_t instr)
{
  // op3 =~ ?? ?0??
  return ((instr & 0xc0200000) == 0xc0000000);
}


// does *not* include load-store insts. spix _isstore() includes unconditional ldst insts
static inline bool rz_is_store(uint32_t instr)
{
  // op3 =~ ?? 01?? or op3 =~ 0? 1110
  return ((instr & 0xc0600000) == 0xc0200000) || ((instr & 0xc1780000) == 0xc0700000);
}

// load and cond store (CAS/CASA) - same as spix _iscstore()
static inline bool rz_is_load_store_conditional(uint32_t instr)
{
  // op=3, op3=11 11?0
  return ((instr & 0xc1e80000) == 0xc1e00000);
}


// ldstub, swap
static inline bool rz_is_load_store_unconditional(uint32_t instr)
{
  // op=3 op3=0? 11?1
  return ((instr & 0xc1680000) == 0xc0680000);
}


// include conditional as well as unconditional ldst insts (ldst + cas + swap)
static inline bool rz_is_load_store(uint32_t instr)
{
  return rz_is_load_store_conditional(instr) || rz_is_load_store_unconditional(instr);
}


static inline bool rz_is_prefetch(uint32_t instr)
{
  // op3 =~ 1? 1101
  return ((instr & 0xc1780000) == 0xc1680000);
}

static inline bool rz_is_sethi(uint32_t instr)
{
  // op==0 op2=100
  return ( ((instr & 0xc1c00000) == 0x01000000) && (instr & 0x3e000000) ); 
}

#endif // _rz_insttypes_h_
