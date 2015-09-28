// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: compress_engine.C
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
/* compress_engine.C */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "rstf/rstf.h"

#if defined(ARCH_AMD64)
#include "rstf/rstf_convert.h"
#endif

#include "rstzip3.h"
#include "rz3_section.h"

#include "rz3iu.h"

/* debug stuff */
static const bool dbg_ras = false;
static const bool dbg_regid = false;


// rstbufsize <= rz3_bufsize
int rstzip3::compress_buffer(rstf_unionT * rstbuf, int rstbufsize)
{

  shdr->clear();
  sdata->clear();

  // set shdr->clearflag if records_since_prev_clear >= clear_interval
  // clear predictor tables in tdata if shdr->clearflag is set

  // if (verbose) clear_stats();
  clear_stats();

  // write record count to header
  shdr->nrecords = rstbufsize;

  int i;
  for (i=0; i<rstbufsize; i++) {
    if (rfs_phase) {
      if (rfs_cw_phase) {
	if (rstbuf[i].proto.rtype == RFS_CW_T) {
	  sdata->bitarrays[rfs_rtype_pred_array]->Push(1);
	  rfs_records_seen++;
	  if (rfs_records_seen == rfs_nrecords) {
	    rfs_phase = rfs_cw_phase = false;
	  }
	} else /* rfs cw rtype mispred */ {
	  sdata->bitarrays[rfs_rtype_pred_array]->Push(0);
	  sdata->bitarrays[rtype_array]->Push(rstbuf[i].proto.rtype);
	  rfs_phase = rfs_cw_phase = false;
	} // rfs cw rtype pred
      } else if (rfs_bt_phase) {
	if (rstbuf[i].proto.rtype == RFS_BT_T) {
	  sdata->bitarrays[rfs_rtype_pred_array]->Push(1);
	  rfs_records_seen++;
	  if (rfs_records_seen == rfs_nrecords) {
	    rfs_phase = rfs_bt_phase = false;
	  }
	} else /* rfs bt rtype mispred */ {
	  sdata->bitarrays[rfs_rtype_pred_array]->Push(0);
	  sdata->bitarrays[rtype_array]->Push(rstbuf[i].proto.rtype);
	  rfs_phase = rfs_bt_phase = false;
	} // rfs bt rtype pred
      } // which rfs phase? */
    } else /* regular rst phase */ {
      // rtype compression
      if (rstbuf[i].proto.rtype == INSTR_T) {
	sdata->bitarrays[rtype_key_array]->Push(rtype_key_INSTR);
      } else if (rstbuf[i].proto.rtype == REGVAL_T) {
	sdata->bitarrays[rtype_key_array]->Push(rtype_key_REGVAL);
      } else if (rstbuf[i].proto.rtype == PAVADIFF_T) {
	sdata->bitarrays[rtype_key_array]->Push(rtype_key_PAVADIFF);
      } else {
	sdata->bitarrays[rtype_key_array]->Push(rtype_key_RAW);
	sdata->bitarrays[rtype_array]->Push(rstbuf[i].proto.rtype);
      }
    } // phase: rfs cw, rfs bt or regular rst?

    switch(rstbuf[i].proto.rtype) {
    case INSTR_T:
      compress_inst(rstbuf, i);
      break;
    case REGVAL_T:
      compress_regval(rstbuf, i);
      break;
    case PAVADIFF_T:
      compress_pavadiff(rstbuf, i);
      break;
    case TLB_T:
      compress_tlb(rstbuf, i);
      break;
    case PREG_T:
      compress_preg(rstbuf, i);
      break;
    case TRAP_T:
      compress_trap(rstbuf, i);
      break;
    case DMA_T:
      compress_dma(rstbuf, i);
      break;
    case MEMVAL_T:
      compress_memval(rstbuf, i);
      break;
    case RFS_CW_T:
      if ((rfs_records_seen == 0) && ! rfs_cw_phase) {
	// in case there was no rfs preamble, section header etc.
	rfs_phase = rfs_cw_phase = true;
	rfs_nrecords = rfs_unknown_nrecords;
	rfs_records_seen = 1;
      }
      compress_rfs_cw(rstbuf, i);
      break;
    case RFS_BT_T:
      if ((rfs_records_seen == 0) && ! rfs_bt_phase) {
	// in case there was no rfs preamble, section header etc.
	rfs_phase = rfs_bt_phase = true;
	rfs_nrecords = rfs_unknown_nrecords;
	rfs_records_seen = 1;
      }
      compress_rfs_bt(rstbuf, i);
      break;

    case RSTHEADER_T:
      // write raw records to output
#if defined(ARCH_AMD64)
      {
	rstf_unionT temp;
	memcpy(&temp, &rstbuf[i], sizeof(rstf_unionT));
	rstf_convertT::l2b((rstf_uint8T*)&temp);
	sdata->bitarrays[raw_value64_array]->Push(byteswap64(temp.arr64.arr64[0]));
	sdata->bitarrays[raw_value64_array]->Push(byteswap64(temp.arr64.arr64[1]));
	sdata->bitarrays[raw_value64_array]->Push(byteswap64(temp.arr64.arr64[2]));
      }
#else
      sdata->bitarrays[raw_value64_array]->Push(rstbuf[i].arr64.arr64[0]);
      sdata->bitarrays[raw_value64_array]->Push(rstbuf[i].arr64.arr64[1]);
      sdata->bitarrays[raw_value64_array]->Push(rstbuf[i].arr64.arr64[2]);
#endif
      if (rstbuf[i].header.majorVer*1000+rstbuf[i].header.minorVer <= 2011) {
	rstf_pre212 = true;
      }

      break;

    default:
      // write raw records to output
#if defined(ARCH_AMD64)
      {
	rstf_unionT temp;
	memcpy(&temp, &rstbuf[i], sizeof(rstf_unionT));
	rstf_convertT::l2b((rstf_uint8T*)&temp);
	sdata->bitarrays[raw_value64_array]->Push(byteswap64(temp.arr64.arr64[0]));
	sdata->bitarrays[raw_value64_array]->Push(byteswap64(temp.arr64.arr64[1]));
	sdata->bitarrays[raw_value64_array]->Push(byteswap64(temp.arr64.arr64[2]));
      }
#else
      sdata->bitarrays[raw_value64_array]->Push(rstbuf[i].arr64.arr64[0]);
      sdata->bitarrays[raw_value64_array]->Push(rstbuf[i].arr64.arr64[1]);
      sdata->bitarrays[raw_value64_array]->Push(rstbuf[i].arr64.arr64[2]);
#endif

      if (rstbuf[i].proto.rtype == RFS_SECTION_HEADER_T) {
	if (rstbuf[i].rfs_section_header.section_type == RFS_CW_T) {
	  rfs_phase = rfs_cw_phase = true;
	  rfs_nrecords = rstbuf[i].rfs_section_header.n_records;
	  rfs_records_seen = 0;
	} else if (rstbuf[i].rfs_section_header.section_type == RFS_BT_T) {
	  rfs_phase = rfs_bt_phase = true;
	  rfs_nrecords = rstbuf[i].rfs_section_header.n_records;
	  rfs_records_seen = 0;
	} // else - do nothing
      } // if rfs section header

      break;
    } // what rtype? */

    prev_rtype = rstbuf[i].proto.rtype;
  } // for each record

  sdata->update_counts();

  if (stats) update_stats();

  if (! shdr->write(gzf)) {
    perror("ERROR: rstzip3::compress_Buffer(): could not write section header to output file\n");
    return 0;
  }

  if (! sdata->write(gzf)) {
    perror("ERROR: rstzip3::compress_buffer(): could not write section data to output file\n");
    return 0;
  }


  if (verbose) {
    fprintf(stderr, "Section %d\n", nsections);
    sdata->print();
  }

  if (stats) print_stats();

  nsections++;

  return rstbufsize;
} // rstzip3::compress_buffer


static bool ds_indicates_tail_call(uint32_t instr) {
  return (instr == MOV_G1_G7_INSTR) || ((instr & RESTORE_OPCODE_MASK) == RESTORE_OPCODE_BITS);
}

void rstzip3::compress_inst(rstf_unionT * rstbuf, int idx)
{

  rstf_instrT *ir = &(rstbuf[idx].instr);

  // check cpuid
  uint16_t cpuid = rstf_pre212 ? ir->cpuid : rstf_instrT_get_cpuid(ir);
  if (pred_cpuid == cpuid) {
    sdata->bitarrays[cpuid_pred_array]->Push(1);
  } else {
    sdata->bitarrays[cpuid_pred_array]->Push(0);
    sdata->bitarrays[raw_cpuid_array]->Push(cpuid);
  }

  // predict cpuid. assume round robin. FIXME: for now, assump uP traces
  if (tdata[cpuid+1] == NULL) {
    pred_cpuid = 0;
  } else {
    pred_cpuid = cpuid+1;
  }
  last_instr_cpuid = cpuid;

  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  instr_preds = instr_mispred_none;

  // amask bit: if amask is 0, all 64-bits of pred_pc are used. if not, only the lower 32-bits are used
  // we check and set the amask bit on a pc misprediction. if the misprediction leaves the lower 32-bits unchanged
  // but differs in the upper 32-bits, we set/clear amask accordingly
  // check pc
  uint64_t pc = ir->pc_va;
  uint64_t pred_pc = tdata[cpuid]->pred_pc;
  bool pc_pred = (pred_pc == ir->pc_va);
  if (!pc_pred) {
    instr_preds &= instr_mispred_pc;

    sdata->bitarrays[raw_value64_array]->Push(pc);

    // is our amask to blame?
    if ((pc & rz3_amask_mask) == (pred_pc & rz3_amask_mask)) {
      // lower 32 bits match
      if ((pc >> 32) != 0) {
	// if amask was 1, it should be 0. if it was already zero, amask is not to blame, but set it to 0 anyway
	tdata[cpuid]->pred_amask = 0;
      } else {
	// if amask was 0, it should be 1. if it was already 1, we shouldn't be here.
	if (0 && tdata[cpuid]->pred_amask) {
	  fprintf(stderr, "rz3: compress_inst: amask was set but predicted pc was > 32 bits: pred_pc %llx actual %llx\n", pred_pc, pc);
	}
	tdata[cpuid]->pred_amask = 1;
      }
    }

    tdata[cpuid]->pred_npc = pc+4;
  }

  // (pc, npc) <= (npc, npc+4)
  tdata[cpuid]->pred_pc = tdata[cpuid]->pred_npc;
  tdata[cpuid]->pred_npc += 4; // this may be updated later in case of CTIs

  tdata[cpuid]->prev_pc = pc;

  // check annul bit
  if (tdata[cpuid]->pred_an != ir->an) {
    instr_preds &= instr_mispred_an;
    perf_stats[ps_an_misses]++;
    // sdata->an_mispred_count++;
  }

  // predict and check instr
  rz3iu_icache_data * icdata = tdata[cpuid]->icache->get(pc);
  uint32_t instr = ir->instr;
  if ((icdata == NULL) || (icdata->instr != ir->instr)) {
    // ic miss
    instr_preds &= instr_mispred_instr;

    sdata->bitarrays[raw_instr_array]->Push(instr);

    icdata = tdata[cpuid]->icache->set(pc, instr, rstzip3_major_version, rstzip3_minor_version);

    if ((!ir->an) && icdata->dinfo.flags.isdcti) {
      icdata->gen_target(pc);
    }
  }
  tdata[cpuid]->last_instr = ir->an ? 0x0 : instr;

  // if this is a delay slot of a call instr, we need to pop ras if "restore" or mov_g1_g7 instr
  if (tdata[cpuid]->call_delay_slot) {
    if ( ((instr & RESTORE_OPCODE_MASK) == RESTORE_OPCODE_BITS) || (instr == MOV_G1_G7_INSTR) ) {
      tdata[cpuid]->ras->pop();
    }
    tdata[cpuid]->call_delay_slot = false;
  }


  // tr and pr bits.
  // predict and set tr BEFORE decompress_ea_va because ea_valid prediction depends on the tr bit
  // tr is usually 0. we follow the convention of
  // inserting all 1's where possible. so we *invert* the tr bit
  if (ir->tr) {
    instr_preds &= instr_mispred_tr;
  }

  // for the hpriv bit, we predict it based on the previous instr
  // this is new in v3.20 and up
  uint32_t hpriv = rstf_pre212 ? 0 : ir->hpriv;
  if (hpriv != tdata[cpuid]->pred_hpriv) {
    instr_preds &= instr_mispred_hpriv;
    tdata[cpuid]->pred_hpriv = hpriv;
    if (hpriv) {
      tdata[cpuid]->pred_pr = 0;
    }
  }

  // for the pr bit, we predict it based on the previous instr
  if (ir->pr != tdata[cpuid]->pred_pr) {
    instr_preds &= instr_mispred_pr;
    tdata[cpuid]->pred_pr = ir->pr;
  }

  // predict ea_valid, ea_va, bt, NEXT-instr an

  if (!ir->an) {
    if (icdata->dinfo.flags.isdcti) {

      compress_dcti(rstbuf, idx, icdata);

    } else /* not dcti */ {

      // predict bt == 0
      int pred_bt = icdata->dinfo.flags.is_done_retry;
      if (pred_bt != ir->bt) {
	instr_preds &= instr_mispred_bt;
      }

      // ea_valid=1 for ld/st/pf
      int pred_ea_valid;
      if (icdata->is_ldstpf) {
	// FIXME: make sure this is not an internal ASI
	pred_ea_valid = 1;
      } else if (icdata->dinfo.flags.is_done_retry) {
	pred_ea_valid = 1;
      } else if (ir->tr) {
	pred_ea_valid = 1;
      } else {
	pred_ea_valid = 0;
      }

      if (pred_ea_valid != ir->ea_valid) { 
	instr_preds &= instr_mispred_ea_valid;
	perf_stats[ps_ea_valid_misses]++;
      }

      if (ir->ea_valid) {
	compress_ea_va(rstbuf, idx);
      }

      tdata[cpuid]->pred_an = 0;
    } // dcti?
  } // if not annulled

  if (instr_preds == instr_mispred_none) {
    sdata->bitarrays[instr_pred_all_array]->Push(1);
  } else {
    sdata->bitarrays[instr_pred_all_array]->Push(0);
    sdata->bitarrays[instr_pred_raw_array]->Push(instr_preds);
  }

} // rstzip3::compress_inst()



void rstzip3::compress_ea_va(rstf_unionT * rstbuf, int idx)
{
  rstf_instrT * ir = &(rstbuf[idx].instr);
  uint16_t cpuid = rstf_pre212 ? ir->cpuid : rstf_instrT_get_cpuid(ir);

  // if value trace: predict ea using known reg values

  // predict ea using the rz3 value cache
  compress_value(cpuid, ir->ea_va);
} // rstzip3::compress_ea_va

void rstzip3::compress_pavadiff(rstf_unionT * rstbuf, int idx)
{
  if (0 && idx == 102577) {
    printf("debug: decompress_pavadiff idx %d\n", idx);
  }

  rstf_pavadiffT * dr = &(rstbuf[idx].pavadiff);
  int cpuid = rstf_pre212 ? dr->cpuid : rstf_pavadiffT_get_cpuid(dr);

  // check and predict cpuid
  if (pred_cpuid == cpuid) {
    sdata->bitarrays[cpuid_pred_array]->Push(1);
  } else {
    sdata->bitarrays[cpuid_pred_array]->Push(0);
    sdata->bitarrays[raw_cpuid_array]->Push(cpuid);
  }
  pred_cpuid = cpuid;

  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  // predict icontext the same as prev icontext
  if (tdata[cpuid]->pred_icontext == dr->icontext) {
    sdata->bitarrays[pavadiff_ictxt_pred_array]->Push(1);
  } else {
    sdata->bitarrays[pavadiff_ictxt_pred_array]->Push(0);
    sdata->bitarrays[pavadiff_raw_ictxt_array]->Push(dr->icontext);
    tdata[cpuid]->pred_icontext = dr->icontext;
  }

  // dcontext - predict same as prev dcontext for this cpu
  if (tdata[cpuid]->pred_dcontext == dr->dcontext) {
    sdata->bitarrays[pavadiff_dctxt_pred_array]->Push(1);
  } else {
    sdata->bitarrays[pavadiff_dctxt_pred_array]->Push(0);
    sdata->bitarrays[pavadiff_raw_dctxt_array]->Push(dr->dcontext);
    tdata[cpuid]->pred_dcontext = dr->dcontext;
  }

  bool found_pc_va = false;
  uint64_t nextpc_va;
  bool found_ea_va = false;
  uint64_t nextea_va;

  int i;
  for (i=idx+1; i<shdr->nrecords; i++) {
    if (rstbuf[i].proto.rtype == INSTR_T) {
      rstf_instrT * ir = &(rstbuf[i].instr);
      uint16_t i_cpuid = rstf_pre212 ? ir->cpuid : rstf_instrT_get_cpuid(ir);

      if (i_cpuid == cpuid) {
	nextpc_va = ir->pc_va;
	found_pc_va = true;
	if (dr->ea_valid && ir->ea_valid) { // we only care about ea_va if dr->ea_valid
	  nextea_va = ir->ea_va;
	  found_ea_va = true;
	}
      } // if cpuid match
      break;
    } else if (rstbuf[i].proto.rtype == PAVADIFF_T) {
	rstf_pavadiffT * pd = &(rstbuf[i].pavadiff);
	uint16_t pd_cpuid = rstf_pre212 ? pd->cpuid : rstf_pavadiffT_get_cpuid(pd);
	if (pd_cpuid == cpuid) {
	    // We ran into a second pavadiff record before seeing an instr record.
	    // flag this as a no-pred (hence no lookahead).
	    // If we don't do this, the decompression algorithm will break
	    // because we only have a 1 item limit on the number of pending
	    // pavadiffs to patch, and patching this pavadiff will break the next one.
	    break;
	}
    } // if instr or pavadiff
  } // for each subsequent record

  // ea_valid
  sdata->bitarrays[pavadiff_ea_valid_array]->Push(dr->ea_valid);

  bool pc_pa_va_hit = false;
  bool ea_pa_va_hit = false;

  uint64_t pred_pa_va_diff;

  if (found_pc_va) {
    pred_pa_va_diff = tdata[cpuid]->itlb->get(nextpc_va >> 13);
    if (pred_pa_va_diff == (dr->pc_pa_va >> 13)) {
      pc_pa_va_hit = true;
    }
  }

  if (pc_pa_va_hit) {
    sdata->bitarrays[pavadiff_pc_pa_va_pred_array]->Push(1);
  } else {
    sdata->bitarrays[pavadiff_pc_pa_va_pred_array]->Push(0);
    sdata->bitarrays[raw_value64_array]->Push(dr->pc_pa_va);


    if (found_pc_va) {
      if (0) printf("%d: cpu%d itlb update: %llx => %llx\n", idx, cpuid, nextpc_va, dr->pc_pa_va);
      tdata[cpuid]->itlb->set(nextpc_va>>13, dr->pc_pa_va>>13);
    }
  }


  if (dr->ea_valid) {
    // ea_pa_va - use next instr (if available) and a tlb simulator
    if (found_ea_va) {
      // tlb lookup
      pred_pa_va_diff = tdata[cpuid]->dtlb->get(nextea_va >> 13);
      if (pred_pa_va_diff == (dr->ea_pa_va >> 13)) {
	ea_pa_va_hit = true;
      }
    }

    if (ea_pa_va_hit) {
      sdata->bitarrays[pavadiff_ea_pa_va_pred_array]->Push(1);
    } else {
      sdata->bitarrays[pavadiff_ea_pa_va_pred_array]->Push(0);
      sdata->bitarrays[raw_value64_array]->Push(dr->ea_pa_va);

      if (found_ea_va) {
	if (0) printf("%d: cpu%d dtlb update: %llx => %llx\n", idx, cpuid, nextea_va, dr->ea_pa_va);
	tdata[cpuid]->dtlb->set((nextea_va >> 13), (dr->ea_pa_va >> 13));
      }
    }
  }

  // the lookahead flag tells the decompressor to look for the next instr (to update the tlb)
  // if we predicted pc_pa_va and/or ea_pa_va correctly, the decompressor knows from the pred bit to lookahead.
  // we set the lookahead flag so that the decomprssor knows the difference between no prediction (could not find corresponding instr) and misprediction

  if ((found_pc_va && pc_pa_va_hit) || (dr->ea_valid && found_ea_va && ea_pa_va_hit)) {
    // dont need lookahead flag since the pc_pa_va_pred flag and/or the ea_pa_va_pred flag will indicate lookahead
  } else {
    // we need to indicate whether there was no prediction or misprediction(s)
    int lookahead_flag = (found_pc_va || found_ea_va);
    sdata->bitarrays[pavadiff_lookahead_array]->Push(lookahead_flag);
  }
} // void rstzip3::compress_pavadiff(rstf_unionT * rstbuf, int idx)


// predict bt, ea_valid, ea_va, NEXT-instr an for a dcti instr. also set pred_npc
void rstzip3::compress_dcti(rstf_unionT * rstbuf, int idx, rz3iu_icache_data * icdata)
{
  rstf_instrT * ir = &(rstbuf[idx].instr);
  uint16_t cpuid = rstf_pre212 ? ir->cpuid : rstf_instrT_get_cpuid(ir);
  uint64_t pc = ir->pc_va;

  int bt_pred_hit;

  if (icdata->dinfo.flags.iscbranch) {

    // use branch predictor
    bt_pred_hit = tdata[cpuid]->bp->pred_hit(pc, ir->bt);
    perf_stats[ps_brpred_refs]++;
    if (!bt_pred_hit) {
      perf_stats[ps_brpred_misses]++;
    }

    if (ir->bt) {
      tdata[cpuid]->pred_npc = icdata->target;
      if (tdata[cpuid]->pred_amask) {
	tdata[cpuid]->pred_npc &= rz3_amask_mask;
      }
    } // else - pred_npc is already set to pc+8

  } else if (icdata->dinfo.flags.isubranch && ! icdata->dinfo.flags.isubranch_nottaken) {

    // pred_npc is branch target
    bt_pred_hit = ir->bt; // we predict taken. if not taken, we mispredict
    tdata[cpuid]->pred_npc = icdata->target;
    if (tdata[cpuid]->pred_amask) {
      tdata[cpuid]->pred_npc &= rz3_amask_mask;
    }
  } else if (icdata->dinfo.flags.iscall) {

    bt_pred_hit = ir->bt;
    tdata[cpuid]->pred_npc = icdata->target;
    if (tdata[cpuid]->pred_amask) {
      tdata[cpuid]->pred_npc &= rz3_amask_mask;
    }
    // push pc to ras unless following (delay slot) instr is restore
    tdata[cpuid]->ras->push(pc);
    tdata[cpuid]->call_delay_slot = true;

  } else if (icdata->dinfo.flags.isindirect) {

    bt_pred_hit = ir->bt;
    // if jmpl, use prediction table
    // if ret/retl, use RAS
    if (icdata->dinfo.flags.is_ret|icdata->dinfo.flags.is_retl) {

      perf_stats[ps_ras_refs]++;
      tdata[cpuid]->pred_npc = tdata[cpuid]->ras->pop() + 8;

      if (tdata[cpuid]->pred_amask) {
	tdata[cpuid]->pred_npc &= rz3_amask_mask;
      }
      if (tdata[cpuid]->pred_npc == ir->ea_va) {
      } else {
	tdata[cpuid]->ras->clear();
	perf_stats[ps_ras_misses]++;
      }

    } else if ( ((ir->instr >> 25) & 0x1f) == 15 ) {

      // push unless following (delay-slot) instr is restore
      tdata[cpuid]->ras->push(pc);
      tdata[cpuid]->call_delay_slot = true;

      tdata[cpuid]->pred_npc = tdata[cpuid]->jmpl_table->get(pc >> 2);
      if (tdata[cpuid]->pred_amask) {
	tdata[cpuid]->pred_npc &= rz3_amask_mask;
      }
      if (tdata[cpuid]->pred_npc != ir->ea_va) { // we are going to see an ea_va misprediction (pred_ea_va is set to pred_npc for dctis)
	tdata[cpuid]->jmpl_table->set(pc>>2, ir->ea_va);
      }

    } // is this a ret/retl or indirect call?
    /* else do nothing */
  } else {
    bt_pred_hit = ! ir->bt;
  } // what type of dcti?

  // bt pred
  if (!bt_pred_hit) {
    instr_preds &= instr_mispred_bt;
  }

  // ea_valid pred: predict ea_valid is true
  if (!ir->ea_valid) {
    instr_preds &= instr_mispred_ea_valid;
    perf_stats[ps_ea_valid_misses]++;
  }

  // ea_va: predict pred_npc is ea_va
  if (tdata[cpuid]->pred_npc == ir->ea_va) {
    sdata->bitarrays[dcti_ea_va_pred_array]->Push(1);
  } else {
    sdata->bitarrays[dcti_ea_va_pred_array]->Push(0);
    sdata->bitarrays[raw_value64_array]->Push(ir->ea_va);

    // at this point we know the real ea_va. predict npc=ea_va
    tdata[cpuid]->pred_npc = ir->ea_va;
  }

  // annul flag for *next* instr
  if (icdata->dinfo.flags.annul_flag) {
    if ((icdata->dinfo.flags.iscbranch && !ir->bt) || icdata->dinfo.flags.isubranch) {
      tdata[cpuid]->pred_an = 1;
    }
  }

} // rstzip3::compress_dcti()


// theres not much room for architectural compression
// here, except in case of value traces. all we do here
// is not store rtype and unused fields.
void rstzip3::compress_tlb(rstf_unionT * rstbuf, int idx)
{
  rstf_tlbT *tr = &(rstbuf[idx].tlb);
  // pack demap(25), tlb_index(24:9), tlb_type(8), tlb_no(7:6), cpuid(5:0) into a single
  // 26-bit field. we thus save only 38 bits/tlb record.
  // pack demap(29), tlb_index(28:13), tlb_type(12), tlb_no(11:10), cpuid(9:0) into a single
  // 30-bit field. we thus save only 34 bits/tlb record.
  int cpuid = rstf_pre212 ? tr->cpuid : rstf_tlbT_get_cpuid(tr);

  uint32_t tlb_info = (tr->demap<<29) | (((uint32_t)tr->tlb_index) << 13) | (tr->tlb_type << 12)
    | (tr->tlb_no << 10) | cpuid;
  sdata->bitarrays[tlb_info_array]->Push(tlb_info);

  sdata->bitarrays[raw_value64_array]->Push(tr->tte_tag);
  sdata->bitarrays[raw_value64_array]->Push(tr->tte_data);


} // void rstzip3::compress_tlb(rstf_unionT * rstbuf, int idx)


// try to predict pc and npc.
// at the time of this writing, trap records occur *before* the
// instr record at the time the trap occurred.
// For future RST versions, we will change this assumption if necessary
void rstzip3::compress_trap(rstf_unionT * rstbuf, int idx)
{
  rstf_trapT * tr = &(rstbuf[idx].trap);

  // predict cpuid as the predicted cpuid of the next instr
  int cpuid = rstf_pre212 ? tr->cpuid : rstf_trapT_get_cpuid(tr);

  if (cpuid == pred_cpuid) {
    sdata->bitarrays[cpuid_pred_array]->Push(1);
  } else {
    sdata->bitarrays[cpuid_pred_array]->Push(0);
    sdata->bitarrays[raw_cpuid_array]->Push(cpuid);
  }

  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  // put is_async(48), tl(47:44), ttype(43:34), pstate(33:18), syscall(17:2), pc_pred(1), npc_pred(0)
  // in one 49-bit field
  uint64_t trap_info = (((uint64_t)tr->is_async) << 48) | (((uint64_t)tr->tl) << 44) | (((uint64_t)tr->ttype) << 34) |
    (((uint64_t)tr->pstate) << 18) | (((uint64_t)tr->syscall) << 2);

  uint64_t pred_pc = tdata[cpuid]->pred_pc;
  uint64_t pred_npc;
  if (tr->pc == pred_pc) {
    trap_info |= 2ull;
    pred_npc = tdata[cpuid]->pred_npc;
  } else {
    sdata->bitarrays[raw_value64_array]->Push(tr->pc);

    pred_npc = tr->pc + 4;
  }

  if (tr->npc == pred_npc) {
    trap_info |= 1ull;
  } else {
    sdata->bitarrays[raw_value64_array]->Push(tr->npc);

  }

  sdata->bitarrays[trap_info_array]->Push(trap_info);
} // void rstzip3::compress_trap(rstf_unionT * rstbuf, int idx)


void rstzip3::compress_preg(rstf_unionT * rstbuf, int idx)
{
  rstf_pregT * pr = &(rstbuf[idx].preg);

  // cpuid: predict same as previous instr cpuid
  int cpuid = rstf_pre212 ? pr->cpuid : rstf_pregT_get_cpuid(pr);
  int cpuid_pred = (cpuid==pred_cpuid) ? 1 : 0;
  if (!cpuid_pred) {
    sdata->bitarrays[raw_cpuid_array]->Push(cpuid);
  }

  // pack cpuid_pred[61], primD[60:48], secD[47:35] asiReg{34:27], traplevel[26:24], traptype[23:16], pstate[15:0] in one 64-bit value
  uint64_t preg_info = (((uint64_t)cpuid_pred) << 61) | (((uint64_t)pr->primD) << 48) | (((uint64_t)pr->secD) << 35) |
    (((uint64_t)pr->asiReg) << 27) | (((uint64_t)pr->traplevel) << 24) | (((uint64_t)pr->traptype) << 16) | ((uint64_t)pr->pstate);
  sdata->bitarrays[raw_value64_array]->Push(preg_info);


  // primA and secA are not used - ignore
} // void rstzip3::compress_preg(rstf_unionT * rstbuf, int idx)

void rstzip3::compress_dma(rstf_unionT * rstbuf, int idx)
{
  rstf_dmaT * dr = &(rstbuf[idx].dma);
  sdata->bitarrays[dma_iswrite_array]->Push(dr->iswrite);
  sdata->bitarrays[dma_nbytes_array]->Push(dr->nbytes);
  sdata->bitarrays[raw_value64_array]->Push(dr->start_pa);
  sdata->bitarrays[raw_value64_array]->Push(dr->devid);
} // void rstzip3::compress_dma(rstf_unionT * rstbuf, int idx)

void rstzip3::compress_regval(rstf_unionT * rstbuf, int idx)
{
  // for now, try to compress the reg64 fields using the same mechanism as ea_va compression
  rstf_regvalT * vr = &(rstbuf[idx].regval);

  // cpuid
  int cpuid = rstf_pre212 ? vr->cpuid : rstf_regvalT_get_cpuid(vr);

  if (cpuid == last_instr_cpuid) {
    sdata->bitarrays[cpuid_pred_array]->Push(1);
  } else {
    sdata->bitarrays[cpuid_pred_array]->Push(0);
    sdata->bitarrays[raw_cpuid_array]->Push(cpuid);
  }

  // tdata
  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  // postInstr
  sdata->bitarrays[regval_postInstr_array]->Push(vr->postInstr);

#if 0
  // if prev instr can be emulated, regenerate values using emulation
  if (regen_value(vr, idx)) return; // FIXME: testing
  if (vr->regtype[0] == RSTREG_INT_RT) {
    tdata[cpuid]->regs[vr->regid[0]] = vr->reg64[0];
  }
  if (vr->regtype[1] == RSTREG_INT_RT) {
    tdata[cpuid]->regs[vr->regid[1]] = vr->reg64[1];
  }
#endif

  // regtype, regid
  uint64_t prev_pc = tdata[cpuid]->prev_pc;
  int regtype_tbl_idx = (prev_pc >> 2) & (rz3_percpu_data::rz3_tdata_regval_regtype_tbl_size-1);
  int regid_tbl_idx = (prev_pc >> 2) & (rz3_percpu_data::rz3_tdata_regval_regid_tbl_size-1);

  int k;
  for (k=0; k<2; k++) {

    // predict regtype: use prev_instr

    uint8_t pred_regtype = tdata[cpuid]->regval_regtype_tbl[k][regtype_tbl_idx];

    if (pred_regtype == vr->regtype[k]) {
      sdata->bitarrays[regval_regtype_pred_array]->Push(1);
    } else {
      sdata->bitarrays[regval_regtype_pred_array]->Push(0);
      sdata->bitarrays[regval_raw_regtype_array]->Push(vr->regtype[k]);
      tdata[cpuid]->regval_regtype_tbl[k][regtype_tbl_idx] = vr->regtype[k];
    }

    if (vr->regtype[k] != RSTREG_UNUSED_RT) {

      // regid
      uint8_t pred_regid = tdata[cpuid]->regval_regid_tbl[k][regid_tbl_idx];
      if (prev_rtype == REGVAL_T) { // probably in save/restore code: predict regid = prev_regid+2
	pred_regid += 2;
      }
      if (pred_regid == vr->regid[k]) {
	sdata->bitarrays[regval_regid_pred_array]->Push(1);
      } else {
	sdata->bitarrays[regval_regid_pred_array]->Push(0);
	sdata->bitarrays[regval_raw_regid_array]->Push(vr->regid[k]);
      }
      // we always update update the table.
      // even if our prediction is correct, the predicted value is different from the value read from the table in case of save/restore
      tdata[cpuid]->regval_regid_tbl[k][regid_tbl_idx] = vr->regid[k];

      // reg64
      uint64_t v64 = vr->reg64[k];

      if ((vr->regtype[k] == RSTREG_INT_RT) && (vr->regid[k] == 0)) {
	if (v64 != 0x0) {
	  if (g0_nonzero_warn) {
	    fprintf(stderr, "warning: rz3: compress_regval: int reg %%g0 has non-zero value %llx. will be ignored\n", v64);
	    if (!verbose) {
	      fprintf(stderr, "  (further %%g0!=0 warnings will be suppressed)\n");
	      g0_nonzero_warn = false;
	    }
	  }
	}
      }

      if (v64 == 0) {
	sdata->bitarrays[value_iszero_array]->Push(1);
      } else {
	static int regval_vc_refs = 0;
	static int regval_vc_hits = 0;
	sdata->bitarrays[value_iszero_array]->Push(0);
	regval_vc_refs++;
	if (compress_value(cpuid, v64)) {
	  regval_vc_hits++;
	} else {
	}

	if (regval_vc_refs % 1000 == 0) {
	  // printf("regval vc refs %d hits %d (%0.4f%%)\n", regval_vc_refs, regval_vc_hits, 100.0*regval_vc_hits/regval_vc_refs);
	}
      }

    } // if regtype != UNUSED
  } // for reg field = 0,1
} // rstzip3::compress_regval

void rstzip3::compress_memval(rstf_unionT * rstbuf, int idx)
{
  // rtype: in raw rtype array
  // ismemval128: raw

  // addrisVA: raw
  // isContRec: ignore for m64; raw for m128
  // cpuid: same as predicted cpuid for next instr

  // memval64.size: store raw size
  // memval64.addr: use valuecache
  // memval64.val: use valuecache

  // memval128.addr36_43: ignore if isContRec; raw otherwise
  // memval128.addr04_35: ignore if isContReg; raw otherwise

  // memval128.val[]: use valuecache

  rstf_memval64T * m64 = & (rstbuf[idx].memval64);
  rstf_memval128T * m128 = & (rstbuf[idx].memval128);

  sdata->bitarrays[memval_fields_array]->Push(m128->ismemval128);
  sdata->bitarrays[memval_fields_array]->Push(! m128->addrisVA);

  // cpuid
  int cpuid = rstf_pre212 ? m128->cpuid : rstf_memval128T_get_cpuid(m128);
  if (cpuid == pred_cpuid) {
    sdata->bitarrays[cpuid_pred_array]->Push(1);
  } else {
    sdata->bitarrays[cpuid_pred_array]->Push(0);
    sdata->bitarrays[raw_cpuid_array]->Push(cpuid);
  }

  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  if (m128->ismemval128) {
    sdata->bitarrays[memval_fields_array]->Push(m128->isContRec);
    if (! m128->isContRec) {
      sdata->bitarrays[memval_addr36_43_array]->Push(m128->addr36_43);
      sdata->bitarrays[memval_addr04_35_array]->Push(m128->addr04_35);
    }

    // vals
    
    compress_value(cpuid, m128->val[0]);

    compress_value(cpuid, m128->val[1]);

  } else /* memval64 */ {
    sdata->bitarrays[memval_size_array]->Push(m64->size-1);


    // predict addr using valuecache
    compress_value(cpuid, m64->addr);
    compress_value(cpuid, m64->val);

  }

} // compress_memval


void rstzip3::compress_rfs_cw(rstf_unionT * rstbuf, int idx)
{
  rstf_cachewarmingT *cw = &(rstbuf[idx].cachewarming);

  // there is no architectural method to predict reftype.
  sdata->bitarrays[rfs_cw_raw_reftype_array]->Push(cw->reftype);

  // dont predict cpuid
  
  int cpuid;

  if ((cw->reftype == cw_reftype_DMA_R) || (cw->reftype == cw_reftype_DMA_W)) {
    cpuid = 0;
  } else {
    cpuid = rstf_cachewarmingT_get_cpuid(cw);
  }

  if (tdata[cpuid] == NULL) {
    // fprintf(stderr, "compress_rfs_cw: new cpuid %d\n", cpuid);
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  sdata->bitarrays[rfs_raw_cpuid_array]->Push(cpuid);

  if ((cw->reftype == cw_reftype_DMA_R)|| (cw->reftype == cw_reftype_DMA_W)) {
    sdata->bitarrays[raw_value64_array]->Push(cw->pa);

    sdata->bitarrays[rfs_cw_dma_size_array]->Push(cw->refinfo.dma_size);
  } else {
    // asi
    sdata->bitarrays[rfs_cw_asi_array]->Push(cw->refinfo.s.asi);

    // fcn
    if (cw->reftype==cw_reftype_PF_D) {
      sdata->bitarrays[rfs_cw_pf_fcn_array]->Push(cw->refinfo.s.fcn);
    }

    // va_valid
    sdata->bitarrays[rfs_cw_va_valid_array]->Push(cw->refinfo.s.va_valid);

    if (cw->refinfo.s.va_valid) {

      compress_value(cpuid, cw->va);

      // tlb hit/miss
      uint64_t pred_pa;
      if (cw->reftype == cw_reftype_I) {
	pred_pa = tdata[cpuid]->itlb->get(cw->va>>13) << 13;
      } else {
	pred_pa = tdata[cpuid]->dtlb->get(cw->va>>13) << 13;
      }
      pred_pa |= (cw->va & 0x1fffull);
      if (pred_pa != cw->pa) {
	sdata->bitarrays[rfs_cw_pa_pred_array]->Push(0);
	sdata->bitarrays[raw_value64_array]->Push(cw->pa);

	if (cw->reftype == cw_reftype_I) {
	  tdata[cpuid]->itlb->set(cw->va>>13, cw->pa>>13);
	} else {
	  tdata[cpuid]->dtlb->set(cw->va>>13, cw->pa>>13);
	}
      } else {
	sdata->bitarrays[rfs_cw_pa_pred_array]->Push(1);
      }
    } else /* va invalid - no way to predict pa? */ {
      sdata->bitarrays[raw_value64_array]->Push(cw->pa);
    }
  }
} // rstzip3::compress_rfs_cw(rstf_unionT * rstbuf, int idx)


void rstzip3::compress_rfs_bt(rstf_unionT * rstbuf, int idx)
{
  rstf_bpwarmingT * bt = &(rstbuf[idx].bpwarming);

  // a bt record consists of cpuid, taken, instr, pc_va, npc_va

  // no easy way to compress cpuid: store raw
  int cpuid = rstf_bpwarmingT_get_cpuid(bt);
  sdata->bitarrays[rfs_raw_cpuid_array]->Push(cpuid);
  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  // pc
  uint64_t pred_pc = tdata[cpuid]->rfs_pc_pred_table->get(tdata[cpuid]->rfs_prev_npc);
  if (pred_pc == bt->pc_va) {
    sdata->bitarrays[rfs_pc_pred_array]->Push(1);
  } else {
    sdata->bitarrays[rfs_pc_pred_array]->Push(0);
    sdata->bitarrays[raw_value64_array]->Push(bt->pc_va>>2);

    tdata[cpuid]->rfs_pc_pred_table->set(tdata[cpuid]->rfs_prev_npc, bt->pc_va);
  }

  // instr: use icache
  rz3iu_icache_data * icdata = tdata[cpuid]->icache->get(bt->pc_va);
  uint32_t instr = bt->instr;
  if ((icdata == NULL) || (icdata->instr != instr)) {
    // ic miss
    sdata->bitarrays[rfs_instr_pred_array]->Push(0);
    sdata->bitarrays[raw_instr_array]->Push(instr);
    icdata = tdata[cpuid]->icache->set(bt->pc_va, instr, rstzip3_major_version, rstzip3_minor_version);
    icdata->gen_target(bt->pc_va);
  } else {
    sdata->bitarrays[rfs_instr_pred_array]->Push(1);
  }

  // bt
  int bt_pred_hit;
  if (icdata->dinfo.flags.iscbranch) {
    bt_pred_hit = tdata[cpuid]->bp->pred_hit(bt->pc_va, bt->taken);
    if (!bt_pred_hit) perf_stats[ps_brpred_misses]++;
  } else if (icdata->dinfo.flags.isubranch && icdata->dinfo.flags.isubranch_nottaken) {
    bt_pred_hit = ! bt->taken; // in other words, we predict uncond nt branches as not taken. if the taken bit is 0, then our prediction is correct (1) and vice versa
  } else {
    bt_pred_hit = bt->taken; // in other words, we predict all other branches as taken
  }

  sdata->bitarrays[rfs_bt_pred_array]->Push(bt_pred_hit);

  // target
  uint64_t pred_npc_va;
  if (bt->taken) {
    pred_npc_va = icdata->target;
  } else {
    pred_npc_va = bt->pc_va + 8;
  }
  if (pred_npc_va == bt->npc_va) {
    sdata->bitarrays[dcti_ea_va_pred_array]->Push(1);
  } else {
    sdata->bitarrays[dcti_ea_va_pred_array]->Push(0);
    sdata->bitarrays[raw_value64_array]->Push(bt->npc_va);
  }

  tdata[cpuid]->rfs_prev_npc = bt->npc_va;

  tdata[cpuid]->pred_pc = tdata[cpuid]->rfs_pc_pred_table->get(bt->npc_va);

} // rstzip3::compress_rstf_bt(rfs_unionT * rstbuf, int idx)



// return true if could compress using valuecache
bool rstzip3::compress_value(int cpuid, uint64_t v64)
{
  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  uint64_t key;
  int level = tdata[cpuid]->valuecache->Ref(v64, key);
  sdata->bitarrays[valuecache_level_array]->Push(level);
  sdata->bitarrays[valuecache_data0_array+level]->Push(key);

  return (level < 7);
}





#if 0 // leave this obsolete code in here. it is useful for making sense of the decompress_pavadiff_v315 code in decompress_engine.C
void rstzip3::compress_pavadiff_v315(rstf_unionT * rstbuf, int idx)
{
  rstf_pavadiffT * dr = &(rstbuf[idx].pavadiff);
  int cpuid = rstf_pavadiffT_get_cpuid(dr);

  // check and predict cpuid
  if (pred_cpuid == cpuid) {
    sdata->bitarrays[cpuid_pred_array]->Push(1);
  } else {
    sdata->bitarrays[cpuid_pred_array]->Push(0);
    sdata->bitarrays[raw_cpuid_array]->Push(cpuid);
  }
  pred_cpuid = cpuid;

  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  // predict icontext the same as prev icontext
  if (tdata[cpuid]->pred_icontext == dr->icontext) {
    sdata->bitarrays[pavadiff_ictxt_pred_array]->Push(1);
  } else {
    sdata->bitarrays[pavadiff_ictxt_pred_array]->Push(0);
    sdata->bitarrays[pavadiff_raw_ictxt_array]->Push(dr->icontext);
    tdata[cpuid]->pred_icontext = dr->icontext;
  }

  // dcontext - predict same as prev dcontext for this cpu
  if (tdata[cpuid]->pred_dcontext == dr->dcontext) {
    sdata->bitarrays[pavadiff_dctxt_pred_array]->Push(1);
  } else {
    sdata->bitarrays[pavadiff_dctxt_pred_array]->Push(0);
    sdata->bitarrays[pavadiff_raw_dctxt_array]->Push(dr->dcontext);
    tdata[cpuid]->pred_dcontext = dr->dcontext;
  }

  bool found_pc_va = false;
  uint64_t nextpc_va;
  bool found_ea_va = false;
  uint64_t nextea_va;

  int i;
  for (i=idx+1; i<shdr->nrecords; i++) {
    if (rstbuf[i].proto.rtype == INSTR_T) {
      if (rstf_instrT_get_cpuid(&rstbuf[i].instr) == cpuid) {
	nextpc_va = rstbuf[i].instr.pc_va;
	found_pc_va = (nextpc_va != 0x0);
	if (dr->ea_valid && rstbuf[i].instr.ea_valid) { // we only care about ea_va if dr->ea_valid
	  nextea_va = rstbuf[i].instr.ea_va;
	  found_ea_va = (nextea_va != 0x0);
	}
      } // if cpuid match
      break;
    } // if instr
  } // for each subsequent record

  // ea_valid
  sdata->bitarrays[pavadiff_ea_valid_array]->Push(dr->ea_valid);

  bool pc_pa_va_hit;
  bool ea_pa_va_hit;

  uint64_t pred_pa_va_diff;

  if (found_pc_va) {
    pred_pa_va_diff = tdata[cpuid]->itlb->get(nextpc_va >> 13);
  } else {
    pred_pa_va_diff = 42; // some nonsensical value
  }

  if (pred_pa_va_diff == (dr->pc_pa_va>>13)) {
    sdata->bitarrays[pavadiff_pc_pa_va_pred_array]->Push(1);
    pc_pa_va_hit = true;
  } else {
    sdata->bitarrays[pavadiff_pc_pa_va_pred_array]->Push(0);
    sdata->bitarrays[raw_value64_array]->Push(dr->pc_pa_va);

    if (found_pc_va) {
      tdata[cpuid]->itlb->set(nextpc_va>>13, dr->pc_pa_va>>13);
      pc_pa_va_hit = false;
    }
  }


  if (dr->ea_valid) {

    // ea_pa_va - use next instr (if available) and a tlb simulator
    if (found_ea_va) {
      // tlb lookup
      pred_pa_va_diff = tdata[cpuid]->dtlb->get(nextea_va >> 13);
    } else {
      pred_pa_va_diff = 42; // some nonsensical value
    }

    if (pred_pa_va_diff == (dr->ea_pa_va >> 13)) {
      sdata->bitarrays[pavadiff_ea_pa_va_pred_array]->Push(1);
      ea_pa_va_hit = true;
    } else {
      sdata->bitarrays[pavadiff_ea_pa_va_pred_array]->Push(0);
      sdata->bitarrays[raw_value64_array]->Push(dr->ea_pa_va);

      if (found_ea_va) {
	tdata[cpuid]->dtlb->set((nextea_va >> 13), (dr->ea_pa_va >> 13));
	ea_pa_va_hit = false;
      }
    }
  } else {
    ea_pa_va_hit = false;
  } // if ea_valid

  // the lookahead flag tells the decompressor to look for the next instr (to update the tlb)
  // if we predicted pc_pa_va and/or ea_pa_va correctly, the decompressor knows from the pred bit to lookahead.
  // we set the lookahead flag so that the decomprssor knows the difference between no prediction (could not find corresponding instr) and misprediction

  if ((found_pc_va && pc_pa_va_hit) || (dr->ea_valid && found_ea_va && ea_pa_va_hit)) {
    // dont need lookahead since the pc_pa_va_pred_array and/or the ea_pa_va_pred_array will indicate lookahead
  } else {
    // we need to indicate whether there was no prediction or misprediction(s)
    int lookahead_flag = (found_pc_va || found_ea_va);
    sdata->bitarrays[pavadiff_lookahead_array]->Push(lookahead_flag);
  }
} // rstzip3::compress_pavadiff()
#endif // #if 0  (obsolete code - left here as a reference for the corresponding decompress code



