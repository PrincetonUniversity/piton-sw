/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rz3iu.h
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
/* rz3iu.h
 * rz3 instr unit data structures
 */

#ifndef _rz3iu_h_
#define _rz3iu_h_

#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

#include "rz3utils.h"

// #include "spix_sparc.h"

#include "rz_insttypes.h"

/* we use a simple fast branch predictor similar to the one on cheetah
 * the bpa is a 4k array of 2-bit up/down saturating counters
 * the bpa is indexed by a combination of the branch PC and global branch history
 */
struct rz3iu_brpred {

  rz3iu_brpred() {
    bpa = new uint8_t [1<<14];
    clear();
    int i;
    for (i=0; i<4; i++) {
      update_taken[i] = i+1;
      update_nottaken[i] = i-1;
    }
    // up-down counters saturate at strongly taken/not-taken
    update_taken[3] = 3;
    update_nottaken[0] = 0;
  }

  ~rz3iu_brpred() {
    delete [] bpa;
  }

  void clear() {
    int i;
    memset(bpa, 0, (1<<14));
    bhr = 0x0;
  }

  enum brpred_feedback_e { bp_feedback_INV=0, bp_no_feedback, bp_feedback_hit, bp_feedback_miss };

  // there are two operating modes of the predictor:
  // 1. we know the actual outcome of the branch. generate a prediction and return the *accuracy* of the prediction
  // 2. we know the *accuracy* of the prediction. generate the prediction and return the *actual outcome* of the branch

  int pred_hit(uint64_t pc, int actual_outcome)
  {
    int index = (int) (((pc>>2) & 0x3fff) ^ (bhr << 2));
    uint8_t countervalue = bpa[index];
    int pred = (countervalue >> 1);
    bpa[index] = actual_outcome ? update_taken[countervalue] : update_nottaken[countervalue];
    return (pred == actual_outcome);
  }

  int actual_outcome(uint64_t pc, int pred_hit)
  {
    int index = (int) (((pc>>2) & 0x3fff) ^ (bhr << 2));
    uint8_t countervalue = bpa[index];
    int pred = (countervalue >> 1);
    int actual_outcome = (pred == pred_hit);
    bpa[index] = actual_outcome ? update_taken[countervalue] : update_nottaken[countervalue];
    return actual_outcome;
  }

  uint8_t * bpa;
  uint16_t bhr; // 12-bit branch history
  uint8_t update_taken[4];
  uint8_t update_nottaken[4];
}; // struct rz3iu_brpred


union dcti_info_u {
  struct dcti_flags {
    unsigned isdcti : 1;
    unsigned isbranch : 1;
    unsigned iscbranch : 1;
    unsigned isubranch : 1;
    unsigned isubranch_nottaken : 1;
    unsigned annul_flag : 1;
    unsigned iscall : 1;
    unsigned isindirect : 1; // jmpl
    unsigned is_retl : 1;
    unsigned is_ret : 1;
    unsigned isBPcc : 1;
    unsigned isBPR : 1;
    unsigned isFBfcc : 1;
    unsigned isFBPfcc : 1;
    unsigned isBicc : 1;

    unsigned is_done_retry : 1;
  } flags;

  unsigned u32;
}; // union dcti_info_u




// union dcti_info_u gen_dcti_info(uint32_t instr, spix_sparc_iop_t iop);
union dcti_info_u gen_dcti_info(uint32_t instr);
union dcti_info_u gen_dcti_info_v317(uint32_t instr);

/* instructions that we emulate to regenerate value records:
 * AND, OR, ANDCC, ORCC, XOR
 * ADD, ADDCC, SUB, SUBCC
 * SETHI
 * SRLX, SLLX, SRA, SLL, SRA
 */

/* icache with predecode information for DCTIs */
struct rz3iu_icache_data {
  uint32_t instr;
  // spix_sparc_iop_t iop;
  union dcti_info_u dinfo;
  uint64_t target;

  bool is_ldstpf;

  void gen_target(uint64_t pc);
}; // struct rz3iu_icache_data




static const int rz3iu_icache_bshift = 0; // 8-instr block
static const uint64_t rz3iu_icache_bsize = 1<<rz3iu_icache_bshift;
static const uint64_t rz3iu_icache_size = 256<<10;
static const uint64_t rz3iu_icache_sets = rz3iu_icache_size >> 1+rz3iu_icache_bshift; // 2-way set-assoc
static const uint64_t rz3iu_icache_blocks = rz3iu_icache_size >> rz3iu_icache_bshift;

struct rz3iu_icache {
  uint64_t * tags;
  rz3iu_icache_data * data;
  uint8_t * lru;

  rz3iu_icache() {
    tags = new uint64_t [rz3iu_icache_blocks];
    data = new rz3iu_icache_data [rz3iu_icache_size];
    lru = new uint8_t [rz3iu_icache_sets];
    clear();
  }

  ~rz3iu_icache() {
    delete [] tags;
    delete [] data;
    delete [] lru;
  }

  void clear() {
    memset(tags, 0, rz3iu_icache_blocks*sizeof(uint64_t));
    memset(data, 0, rz3iu_icache_size * sizeof(rz3iu_icache_data));
    memset(lru, 0, rz3iu_icache_sets * sizeof(uint8_t));
  }

  rz3iu_icache_data * set(uint64_t pc, uint32_t instr, uint8_t rz3_major_version, uint8_t rz3_minor_version) {
    // replace lru
    uint64_t tag;
    int idx;
    int offset;
    tag_idx_ofs(pc, tag, idx, offset);
    int lruway;
    if (tags[idx] == tag) {
      lruway = 0;
      lru[idx] = 1;
    } else if (tags[idx+rz3iu_icache_sets] == tag) {
      lruway = 1;
      lru[idx] = 0;
    } else {
      lruway = lru[idx];
    }

    int w = idx + (lruway ? rz3iu_icache_sets : 0);

    tags[w] = tag;
    int loc = (w << rz3iu_icache_bshift) | offset;
    rz3iu_icache_data * icdata = &(data[loc]);
    icdata->instr = instr;
    // icdata->iop = spix_sparc_iop(SPIX_SPARC_V9, &(instr));
    // icdata->dinfo = gen_dcti_info(instr, icdata->iop);
    if (rz3_minor_version > 17) {
      icdata->dinfo = gen_dcti_info(instr);
    } else {
      icdata->dinfo = gen_dcti_info_v317(instr);
    }
    icdata->target = 0x0; // target of cti inst
    if (!icdata->dinfo.flags.isdcti && ! icdata->dinfo.flags.is_done_retry) {
      // icdata->is_ldstpf = (spix_sparc_iop_isload(icdata->iop) || spix_sparc_iop_isustore(icdata->iop) || spix_sparc_iop_iscstore(icdata->iop) || (icdata->iop == SPIX_SPARC_IOP_PREFETCH));
      icdata->is_ldstpf = rz_is_ldstpf(instr);
    } else {
      icdata->is_ldstpf = false;
    }
    return icdata;
  }

  struct rz3iu_icache_data * get(uint64_t pc) {
    uint64_t tag;
    int idx;
    int offset;
    tag_idx_ofs(pc, tag, idx, offset);
    if (tags[idx] == tag) {
      int loc = (idx << rz3iu_icache_bshift);
      loc |= offset;
      lru[idx] = 1;
      return &(data[loc]);
    } else if (tags[idx+rz3iu_icache_sets] == tag) {
      int loc = (idx+rz3iu_icache_sets) << rz3iu_icache_bshift;
      loc |= offset;
      lru[idx] = 0;
      return & (data[loc]);
    } else {
      return NULL;
    }
  }

  void tag_idx_ofs(uint64_t pc, uint64_t & tag, int & idx, int & ofs)
  {
    tag = (pc >> (2+rz3iu_icache_bshift));
    idx =  (int) (tag & (rz3iu_icache_sets - 1));
    ofs = (pc >> 2) & (rz3iu_icache_bsize - 1);
  }
}; // struct rz3iu_icache


struct rz3_ras {

  enum consts_e { ras_sz = 16 };
  uint64_t arr[ras_sz];
  int top;
  int n;

  rz3_ras() {
    clear();
  }

  void clear() {
    n = 0;
    top = 0;
  }

  void push(uint64_t pc) {
    int idx = (top+1) % ras_sz;
    arr[idx] = pc;
    top = idx;
    if (n<ras_sz) n++;
  }

  uint64_t pop() {
    if (n == 0) return 0x0;
    uint64_t rv = arr[top];
    if (top) {
      top--;
    } else {
      top = ras_sz-1;
    }
    n--;
    return rv;
  }
}; // rz3_ras

#endif // _rz3iu_util_h_

