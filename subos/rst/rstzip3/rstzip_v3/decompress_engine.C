// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: decompress_engine.C
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
/* decompress_engine.C */

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



int rstzip3::decompress_buffer(rstf_unionT * rstbuf, int rstbufsize)
{
  if (verbose) fprintf(stderr, "Section %d\n", nsections);

  // read section header
  if (!shdr->read(gzf)) {
    return 0;
  }

  if (rstbufsize < shdr->nrecords) {
    fprintf(stderr, "ERROR: rstzip3::decompress_buffer: caller buffer size (%d) smaller than section size (%d)\n", rstbufsize, shdr->nrecords);
    return 0;
  }

  sdata->clear(); // clear all bitarrays

  // FIXME: do not bzero rstbuf (cut corners) if fast decompression specified.
  bzero(rstbuf, rstbufsize*sizeof(rstf_unionT));

  // clear predictor tables in tdata if shdr->clearflag

  if (!sdata->read(gzf)) {
    perror("ERROR: rstzip3::decompress_buffer(): could not read section data from input file\n");
    return 0;
  }

  int i;
  uint64_t v;
  for (i=0; i<shdr->nrecords; i++) {
    if (rfs_phase) {
      if (rfs_cw_phase) {
	sdata->bitarrays[rfs_rtype_pred_array]->GetNext(v);
	if (v) {
	  rstbuf[i].proto.rtype = RFS_CW_T;
	  rfs_records_seen++;
	  if (rfs_records_seen == rfs_nrecords) {
	    rfs_phase = rfs_cw_phase = false;
	  }
	} else /* rfs cw rtype misprediction */ {
	  sdata->bitarrays[rtype_array]->GetNext(v);
	  rstbuf[i].proto.rtype = v;
	  rfs_phase = rfs_cw_phase = false;
	} // rfs cw rtype pred
      } else if (rfs_bt_phase) {
	sdata->bitarrays[rfs_rtype_pred_array]->GetNext(v);
	if (v) {
	  rstbuf[i].proto.rtype = RFS_BT_T;
	  rfs_records_seen++;
	  if (rfs_records_seen == rfs_nrecords) {
	    rfs_phase = rfs_bt_phase = false;
	  }
	} else /* rfs cw rtype misprediction */ {
	  sdata->bitarrays[rtype_array]->GetNext(v);
	  rstbuf[i].proto.rtype = v;
	  rfs_phase = rfs_bt_phase = false;
	} // rfs bt rtype pred
      } // which rfs phase?
    } else /* regular rst phase */ {
      sdata->bitarrays[rtype_key_array]->GetNext(v);
      switch(v) {
      case rtype_key_INSTR:
	rstbuf[i].proto.rtype = INSTR_T;
	break;
      case rtype_key_REGVAL:
	rstbuf[i].proto.rtype = REGVAL_T;
	break;
      case rtype_key_PAVADIFF:
	rstbuf[i].proto.rtype = PAVADIFF_T;
	break;
      default:
	sdata->bitarrays[rtype_array]->GetNext(v);
	rstbuf[i].proto.rtype = v;
      }
    }


    switch(rstbuf[i].proto.rtype) {
    case INSTR_T:
      decompress_inst(rstbuf, i);
      break;
    case PAVADIFF_T:
      decompress_pavadiff(rstbuf, i);
      break;
    case REGVAL_T:
      decompress_regval(rstbuf, i);
      break;
    case MEMVAL_T:
      decompress_memval(rstbuf, i);
      break;
    case TRAP_T:
      decompress_trap(rstbuf, i);
      break;
    case TLB_T:
      decompress_tlb(rstbuf, i);
      break;
    case PREG_T:
      decompress_preg(rstbuf, i);
      break;
    case DMA_T:
      decompress_dma(rstbuf, i);
      break;
    case RFS_CW_T:
      if ((rfs_records_seen == 0) && ! rfs_cw_phase) {
	// in case there was no rfs preamble, section header etc.
	rfs_phase = rfs_cw_phase = true;
	rfs_nrecords = rfs_unknown_nrecords;
	rfs_records_seen = 1;
      }
      decompress_rfs_cw(rstbuf, i);
      break;
    case RFS_BT_T:
      if ((rfs_records_seen == 0) && ! rfs_bt_phase) {
	// in case there was no rfs preamble, section header etc.
	rfs_phase = rfs_bt_phase = true;
	rfs_nrecords = rfs_unknown_nrecords;
	rfs_records_seen = 1;
      }
      decompress_rfs_bt(rstbuf, i);
      break;

    default:
      sdata->bitarrays[raw_value64_array]->GetNext(rstbuf[i].arr64.arr64[0]);
      sdata->bitarrays[raw_value64_array]->GetNext(rstbuf[i].arr64.arr64[1]);
      sdata->bitarrays[raw_value64_array]->GetNext(rstbuf[i].arr64.arr64[2]);

#if defined(ARCH_AMD64)
      // turns into BE layout
      rstbuf[i].arr64.arr64[0] = byteswap64(rstbuf[i].arr64.arr64[0]);
      rstbuf[i].arr64.arr64[1] = byteswap64(rstbuf[i].arr64.arr64[1]);
      rstbuf[i].arr64.arr64[2] = byteswap64(rstbuf[i].arr64.arr64[2]);
#endif

      if (rstbuf[i].proto.rtype == RFS_SECTION_HEADER_T) {
	if (rstbuf[i].rfs_section_header.section_type == RFS_CW_T) {
	  rfs_phase = rfs_cw_phase = true;
	  rfs_nrecords = rstbuf[i].rfs_section_header.n_records;
#if defined(ARCH_AMD64)
	  rfs_nrecords = byteswap64(rfs_nrecords);
#endif
	  rfs_records_seen = 0;
	} else if (rstbuf[i].rfs_section_header.section_type == RFS_BT_T) {
	  rfs_phase = rfs_bt_phase = true;
	  rfs_nrecords = rstbuf[i].rfs_section_header.n_records;
#if defined(ARCH_AMD64)
	  rfs_nrecords = byteswap64(rfs_nrecords);
#endif
	  rfs_records_seen = 0;
	} // else - do nothing
      } // if rfs section header

      // fwrite(rstbuf+i, sizeof(rstf_unionT), 1, testfp); fflush(testfp);

      break;
    } // what rtype?

    prev_rtype = rstbuf[i].proto.rtype;
  } // for each record

  nsections++;


  return shdr->nrecords;
} // int rstzip3::decompress_buffer(rstf_unionT * rstbuf, int nrec)




void rstzip3::decompress_inst(rstf_unionT * rstbuf, int idx)
{
  uint64_t v;

  rstf_instrT * ir = &(rstbuf[idx].instr);

  // cpuid pred
  uint16_t cpuid;
  sdata->bitarrays[cpuid_pred_array]->GetNext(v);
  if (v) {
    cpuid = pred_cpuid;
  } else {
    sdata->bitarrays[raw_cpuid_array]->GetNext(v);
    cpuid = v;
  }

  rstf_instrT_set_cpuid(ir, cpuid);

  // predict cpuid. assume round robin FIXME: for now, assump uP traces
  if (tdata[cpuid+1] == NULL) {
    pred_cpuid = 0;
  } else {
    pred_cpuid = cpuid+1;
  }
  last_instr_cpuid = cpuid;

  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  // instr pred bits
  sdata->bitarrays[instr_pred_all_array]->GetNext(v);
  if (v) {
    instr_preds = instr_pred_all;
  } else {
    sdata->bitarrays[instr_pred_raw_array]->GetNext(v);
    instr_preds = v;
  }

  // amask bit: if amask is 0, all 64-bits of pred_pc are used. if not, only the lower 32-bits are used
  // we check and set the amask bit on a pc misprediction. if the misprediction leaves the lower 32-bits unchanged
  // but differs in the upper 32-bits, we set/clear amask accordingly
  // check pc
  uint64_t pc;
  if (instr_preds & instr_pred_pc) {
    ir->pc_va = tdata[cpuid]->pred_pc;
    pc = tdata[cpuid]->pred_pc;
  } else /* pc mispredicted */ {
    sdata->bitarrays[raw_value64_array]->GetNext(v);
    pc = v;
    ir->pc_va = pc;

    uint64_t pred_pc = tdata[cpuid]->pred_pc;

    // is our amask to blame?
    if ((pc & rz3_amask_mask) == (pred_pc & rz3_amask_mask)) {
      // lower 32 bits match
      if ((pc >> 32) != 0) {
	// if amask was 1, it should be 0. if it was already zero, amask is not to blame, but set it to 0 anyway
	tdata[cpuid]->pred_amask = 0;
      } else {
	// if amask was 0, it should be 1. if it was already 1, we shouldn't be here.
	if (0 && tdata[cpuid]->pred_amask) {
	  fprintf(stderr, "rz3: decompress_inst: amask was set but predicted pc was > 32 bits: pred_pc %llx actual %llx\n", pred_pc, pc);
	}
	tdata[cpuid]->pred_amask = 1;
      }
    }

    // we mispredicted the PC of the current instr
    tdata[cpuid]->pred_npc = pc+4;
  }

  // pc, npc
  tdata[cpuid]->pred_pc = tdata[cpuid]->pred_npc;
  tdata[cpuid]->pred_npc += 4; // this may be modified later, in case of dctis

  tdata[cpuid]->prev_pc = pc;

  // annul bit
  ir->an = (instr_preds & instr_pred_an) ? tdata[cpuid]->pred_an : !tdata[cpuid]->pred_an;

  // instr
  rz3iu_icache_data * icdata = tdata[cpuid]->icache->get(pc);
  if (instr_preds & instr_pred_instr) {
    ir->instr = icdata->instr;
  } else {
    sdata->bitarrays[raw_instr_array]->GetNext(v);
    ir->instr = v;
    icdata = tdata[cpuid]->icache->set(pc, ir->instr, header->major_version, header->minor_version);

    if ((!ir->an) && (icdata->dinfo.flags.isdcti)) {
      icdata->gen_target(pc);
    }
  }
  uint32_t instr = ir->instr;

  if (tdata[cpuid]->call_delay_slot) {
    if ( ((instr & RESTORE_OPCODE_MASK) == RESTORE_OPCODE_BITS) || (instr == MOV_G1_G7_INSTR) ) {
      tdata[cpuid]->ras->pop();
    }
    tdata[cpuid]->call_delay_slot = false;
  }


  // tr and pr bits. we predict tr=0 and pr=prev_pr
  // predict and set tr BEFORE decompress_ea_va because ea_valid prediction depends on the tr bit
  ir->tr = (instr_preds & instr_pred_tr) ? 0 : 1;

  if (instr_preds & instr_pred_pr) {
    ir->pr = tdata[cpuid]->pred_pr;
  } else {
    ir->pr = tdata[cpuid]->pred_pr ? 0 : 1;
    tdata[cpuid]->pred_pr = ir->pr;
  }

  if (!pre320) {
    if (instr_preds & instr_pred_hpriv) {
      ir->hpriv = tdata[cpuid]->pred_hpriv;
    } else {
      ir->hpriv = tdata[cpuid]->pred_hpriv ? 0 : 1;
      tdata[cpuid]->pred_hpriv = ir->hpriv;
    }
    if (ir->hpriv) {
      tdata[cpuid]->pred_pr = 0;
    }
  } // else if pre320 = do nothing

  // predict ea_valid, ea_va, bt, NEXT-instr an
  if (!ir->an) {
    if (icdata->dinfo.flags.isdcti) {

      decompress_dcti(rstbuf, idx, icdata);

    } else /* not dcti */ {

      // bt: prediction is 0 unless done_retry. resolution: ir->bt = (v == is_done_retry)
      if (instr_preds & instr_pred_bt) {
	ir->bt = icdata->dinfo.flags.is_done_retry;
      } else {
	ir->bt = ! icdata->dinfo.flags.is_done_retry;
      }

      // ea_valid
      bool ea_valid_pred = (instr_preds & instr_pred_ea_valid);
      if (icdata->is_ldstpf) {
	ir->ea_valid = ea_valid_pred; // predict ea_valid=1
      } else if (icdata->dinfo.flags.is_done_retry) {
	ir->ea_valid = ea_valid_pred; // predict ea_valid=1
      } else if (ir->tr) {
	ir->ea_valid = ea_valid_pred; // predict ea_valid = 1
      } else {
	ir->ea_valid = !ea_valid_pred; // predict ea_valid = 0;
      }

      if (ir->ea_valid) {
	decompress_ea_va(rstbuf, idx);
      }

      tdata[cpuid]->pred_an = 0;

    }
  } // if not annulled

  // pavadiff: pass 2
  if (tdata[cpuid]->pending_pavadiff_idx != -1) {
    decompress_pavadiff_pass2(rstbuf, idx); // pass the index of the instrution to the pavadiff decompressor
  }

  // fwrite(rstbuf+idx, sizeof(rstf_unionT), 1, testfp); fflush(testfp);

#if defined(ARCH_AMD64)
  rstf_convertT::l2b((rstf_uint8T*)&rstbuf[idx]);
#endif
} // void rstzip3::decompress_inst(rstf_unionT * rstbuf, int idx)


void rstzip3::decompress_pavadiff(rstf_unionT * rstbuf, int idx)
{
  if (0 && idx == 102577) {
    printf("debug: decompress_pavadiff idx %d\n", idx);
  }

  uint64_t v;

  rstf_pavadiffT * dr = &(rstbuf[idx].pavadiff);

  // cpuid
  int cpuid;
  sdata->bitarrays[cpuid_pred_array]->GetNext(v);
  if (v) {
    rstf_pavadiffT_set_cpuid(dr, pred_cpuid); // dr->cpuid = pred_cpuid;
    cpuid = pred_cpuid;
  } else {
    sdata->bitarrays[raw_cpuid_array]->GetNext(v);
    rstf_pavadiffT_set_cpuid(dr, v); // dr->cpuid = v;
    cpuid = v;
  }
  pred_cpuid = cpuid; // for next instr

  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }


  // icontext
  sdata->bitarrays[pavadiff_ictxt_pred_array]->GetNext(v);
  if (v) {
    dr->icontext = tdata[cpuid]->pred_icontext;
  } else {
    sdata->bitarrays[pavadiff_raw_ictxt_array]->GetNext(v);
    dr->icontext = v;
    tdata[cpuid]->pred_icontext = dr->icontext;
  }

  // dcontext
 
  sdata->bitarrays[pavadiff_dctxt_pred_array]->GetNext(v);
  if (v) {
    dr->dcontext = tdata[cpuid]->pred_dcontext;
  } else {
    sdata->bitarrays[pavadiff_raw_dctxt_array]->GetNext(v);
    dr->dcontext = v;
    tdata[cpuid]->pred_dcontext = dr->dcontext;
  }


  // ea_valid
  sdata->bitarrays[pavadiff_ea_valid_array]->GetNext(v);
  dr->ea_valid = v;

  // to predict pc_pa_va and ea_pa_va, we need the NEXT instr from this cpuid
  // if the prediction was successful. Otherwise, we read those values from
  // the raw arrays
  sdata->bitarrays[pavadiff_pc_pa_va_pred_array]->GetNext(v);
  int pc_pa_va_hit = v;
  if (pc_pa_va_hit) {
    tdata[cpuid]->pending_pavadiff_pc_pa_va_pred = 1;
  } else {
    sdata->bitarrays[raw_value64_array]->GetNext(v);
    dr->pc_pa_va = v;
  }

  int ea_pa_va_hit = 0;
  if (dr->ea_valid) {
    sdata->bitarrays[pavadiff_ea_pa_va_pred_array]->GetNext(v);
    ea_pa_va_hit = v;
    if (ea_pa_va_hit) {
      tdata[cpuid]->pending_pavadiff_ea_pa_va_pred = 1;
    } else {
      sdata->bitarrays[raw_value64_array]->GetNext(v);
      dr->ea_pa_va = v;
    }
  }

  if (tdata[cpuid]->pending_pavadiff_pc_pa_va_pred || tdata[cpuid]->pending_pavadiff_ea_pa_va_pred) {
    tdata[cpuid]->pending_pavadiff_idx = idx;
  } else /* neither pc_pa_va no ea_pa_va could be predicted */ {
    // is there a next instr for this cpuid (do we need to update itlb and dtlb?
    sdata->bitarrays[pavadiff_lookahead_array]->GetNext(v);
    if (v) {
      tdata[cpuid]->pending_pavadiff_idx = idx;
    } else {
      tdata[cpuid]->pending_pavadiff_idx = -1;
      // fwrite(rstbuf+idx, sizeof(rstf_unionT), 1, testfp); fflush(testfp);
    }
  }


#if defined(ARCH_AMD64)
  rstf_convertT::l2b((rstf_uint8T*)&rstbuf[idx]);
#endif
} // rstzip3::decompress_pavadiff()


void rstzip3::decompress_pavadiff_pass2(rstf_unionT * rstbuf, int instr_idx)
{
  if (header->minor_version <= 15) {
    decompress_pavadiff_pass2_v315(rstbuf, instr_idx);
    return;
  }

  rstf_instrT * ir = &(rstbuf[instr_idx].instr);

  int cpuid = rstf_instrT_get_cpuid(ir);

  int idx = tdata[cpuid]->pending_pavadiff_idx;
  rstf_pavadiffT * dr = &(rstbuf[idx].pavadiff);

  if (tdata[cpuid]->pending_pavadiff_pc_pa_va_pred) {
    dr->pc_pa_va = tdata[cpuid]->itlb->get(ir->pc_va >> 13) << 13;
    tdata[cpuid]->pending_pavadiff_pc_pa_va_pred = false;
  } else /* there was an itlb miss */ {
    if (0) printf("%d: cpu%d itlb update: %llx => %llx\n", idx, cpuid, ir->pc_va, dr->pc_pa_va);
    tdata[cpuid]->itlb->set(ir->pc_va >> 13, dr->pc_pa_va >> 13);
  }

  if (tdata[cpuid]->pending_pavadiff_ea_pa_va_pred) {
    dr->ea_pa_va = tdata[cpuid]->dtlb->get(ir->ea_va >> 13) << 13;
    tdata[cpuid]->pending_pavadiff_ea_pa_va_pred = false;
  } else if (ir->ea_valid && dr->ea_valid) /* there was a dtlb miss */ {
    if (0) printf("%d: cpu%d dtlb update: %llx => %llx\n", idx, cpuid, ir->ea_va, dr->ea_pa_va);
    tdata[cpuid]->dtlb->set(ir->ea_va >> 13, dr->ea_pa_va >> 13);
  } // else - ea_valid = 0. do nothing

  tdata[cpuid]->pending_pavadiff_idx = -1;

  // fwrite(rstbuf+idx, sizeof(rstf_unionT), 1, testfp); fflush(testfp);

}

void rstzip3::decompress_pavadiff_pass2_v315(rstf_unionT * rstbuf, int instr_idx)
{
  rstf_instrT * ir = &(rstbuf[instr_idx].instr);

  int cpuid = rstf_instrT_get_cpuid(ir);

  int idx = tdata[cpuid]->pending_pavadiff_idx;
  rstf_pavadiffT * dr = &(rstbuf[idx].pavadiff);

  if (tdata[cpuid]->pending_pavadiff_pc_pa_va_pred) {
    dr->pc_pa_va = tdata[cpuid]->itlb->get(ir->pc_va >> 13) << 13;
    tdata[cpuid]->pending_pavadiff_pc_pa_va_pred = false;
  } else /* there was an itlb miss */ {
    if (ir->pc_va != 0x0) {
      tdata[cpuid]->itlb->set(ir->pc_va >> 13, dr->pc_pa_va >> 13);
    }
  }

  if (tdata[cpuid]->pending_pavadiff_ea_pa_va_pred) {
    if (ir->ea_va == 0) {
      dr->ea_pa_va = 42ull << 13;
    } else {
      dr->ea_pa_va = tdata[cpuid]->dtlb->get(ir->ea_va >> 13) << 13;
    }
    tdata[cpuid]->pending_pavadiff_ea_pa_va_pred = false;
  } else if (dr->ea_valid) /* there was a dtlb miss */ {
    if (ir->ea_va != 0x0) {
      tdata[cpuid]->dtlb->set(ir->ea_va >> 13, dr->ea_pa_va >> 13);
    }
  } // else - ea_valid = 0. do nothing

  tdata[cpuid]->pending_pavadiff_idx = -1;

  // fwrite(rstbuf+idx, sizeof(rstf_unionT), 1, testfp); fflush(testfp);

} // void decompress_pavadiff_pass2_v315(rstf_unionT * outbuf, int instr_idx)


// predict bt, ea_valid, ea_va, NEXT-instr an for a dcti instr. also set pred_npc
void rstzip3::decompress_dcti(rstf_unionT * rstbuf, int idx, rz3iu_icache_data * icdata)
{
  uint64_t v;

  rstf_instrT * ir = &(rstbuf[idx].instr);
  int cpuid = rstf_instrT_get_cpuid(ir);
  uint64_t pc = ir->pc_va;

  int bt_pred_hit = (instr_preds & instr_pred_bt) ? 1 : 0;

  // ea_valid pred: predict ea_valid is true
  ir->ea_valid = (instr_preds & instr_pred_ea_valid) ? 1 : 0;
  if (!ir->ea_valid) {
    perf_stats[ps_ea_valid_misses]++;
  }

  sdata->bitarrays[dcti_ea_va_pred_array]->GetNext(v);
  int ea_pred_hit = v;
  if (!ea_pred_hit) {
    sdata->bitarrays[raw_value64_array]->GetNext(v);
    ir->ea_va = v;
  }

  if (icdata->dinfo.flags.iscbranch) {

    // use branch predictor
    // pred_bt = tdata[cpuid]->bp->predict(pc, ir->bt);
    ir->bt = tdata[cpuid]->bp->actual_outcome(pc, bt_pred_hit);

    perf_stats[ps_brpred_refs]++;
    if (!bt_pred_hit) {
      perf_stats[ps_brpred_misses]++;
    }

    if (ir->bt) {
      tdata[cpuid]->pred_npc = icdata->target;
      if (tdata[cpuid]->pred_amask) {
	tdata[cpuid]->pred_npc &= rz3_amask_mask;
      }
    } // else - pred_npc is already set to pc+4

  } else if (icdata->dinfo.flags.isubranch && ! icdata->dinfo.flags.isubranch_nottaken) {

    // pred_npc is branch target
    ir->bt = bt_pred_hit; // pred_bt = 1;
    tdata[cpuid]->pred_npc = icdata->target;
    if (tdata[cpuid]->pred_amask) {
      tdata[cpuid]->pred_npc &= rz3_amask_mask;
    }
  } else if (icdata->dinfo.flags.iscall) {

    ir->bt = bt_pred_hit; // pred_bt = 1;
    tdata[cpuid]->pred_npc = icdata->target;
    if (tdata[cpuid]->pred_amask) {
      tdata[cpuid]->pred_npc &= rz3_amask_mask;
    }
    // push pc to ras unless following (delay slot) instr is restore
    tdata[cpuid]->ras->push(pc);
    tdata[cpuid]->call_delay_slot = true;

  } else if (icdata->dinfo.flags.isindirect) {

    ir->bt = bt_pred_hit; // pred_bt = 1;
    // if jmpl, use prediction table
    // if ret/retl, use RAS
    if (icdata->dinfo.flags.is_ret|icdata->dinfo.flags.is_retl) {

      perf_stats[ps_ras_refs]++;
      tdata[cpuid]->pred_npc = tdata[cpuid]->ras->pop() + 8;
      if (tdata[cpuid]->pred_amask) {
	tdata[cpuid]->pred_npc &= rz3_amask_mask;
      }
      if (ea_pred_hit) { // if (tdata[cpuid]->pred_npc == ir->ea_va) {
      } else {
	tdata[cpuid]->ras->clear();
	// sdata->ras_miss_count++;
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
      if (! ea_pred_hit) { // if (tdata[cpuid]->pred_npc != ir->ea_va) {
	// ea_va misprediction (pred_ea_va is set to pred_npc for dctis)
	tdata[cpuid]->jmpl_table->set(pc>>2, ir->ea_va);
      }
     } // is this a ret/retl or indirect call?

    /* else do nothing */
  } else {
    ir->bt = ! bt_pred_hit;
  } // what type of dcti?

  // ea_va: predict pred_npc is ea_va
  if (ea_pred_hit) {
    ir->ea_va = tdata[cpuid]->pred_npc;
  } else {
    // we got ea_va from the raw_value64_array
    tdata[cpuid]->pred_npc = ir->ea_va;
  }

  // annul flag for *next* instr
  if (icdata->dinfo.flags.annul_flag) {
    if ((icdata->dinfo.flags.iscbranch && !ir->bt) || icdata->dinfo.flags.isubranch) {
      tdata[cpuid]->pred_an = 1;
    }
  }

} // rstzip3::compress_dcti()


void rstzip3::decompress_ea_va(rstf_unionT * rstbuf, int idx)
{
  uint64_t v;
  rstf_instrT * ir = &(rstbuf[idx].instr);
  int cpuid = rstf_instrT_get_cpuid(ir);

  decompress_value(cpuid, v);
  ir->ea_va = v;
} // void rstzip3::decompress_ea_va(rstf_unionT * rstbuf, int idx)




void rstzip3::decompress_regval(rstf_unionT * rstbuf, int idx)
{
  uint64_t v;

  rstf_regvalT * vr = &(rstbuf[idx].regval);

  // cpuid
  int cpuid;
  sdata->bitarrays[cpuid_pred_array]->GetNext(v);
  if (v) {
    cpuid =  last_instr_cpuid;
  } else {
    sdata->bitarrays[raw_cpuid_array]->GetNext(v);
    cpuid = v;
  }
  rstf_regvalT_set_cpuid(vr, cpuid);

  // tdata
  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  // postInstr
  sdata->bitarrays[regval_postInstr_array]->GetNext(v);
  vr->postInstr = v;

  // regtype, regid
  uint64_t prev_pc = tdata[cpuid]->prev_pc;
  int regtype_tbl_idx = (prev_pc >> 2) & (rz3_percpu_data::rz3_tdata_regval_regtype_tbl_size-1);
  int regid_tbl_idx = (prev_pc >> 2) & (rz3_percpu_data::rz3_tdata_regval_regid_tbl_size-1);

  int k;
  for (k=0; k<2; k++) {

    // predict regtype: use prev_instr
    uint8_t pred_regtype = tdata[cpuid]->regval_regtype_tbl[k][regtype_tbl_idx];

    sdata->bitarrays[regval_regtype_pred_array]->GetNext(v);
    if (v) {
      vr->regtype[k] = pred_regtype;
    } else {
      sdata->bitarrays[regval_raw_regtype_array]->GetNext(v);
      vr->regtype[k] = v;
      tdata[cpuid]->regval_regtype_tbl[k][regtype_tbl_idx] = vr->regtype[k];
    }

    if (vr->regtype[k] != RSTREG_UNUSED_RT) {

      // regid
      uint8_t pred_regid = tdata[cpuid]->regval_regid_tbl[k][regid_tbl_idx];
      if (prev_rtype == REGVAL_T) { // probably in save/restore code: predict regid = prev_regid+2
	pred_regid += 2;
      }
      sdata->bitarrays[regval_regid_pred_array]->GetNext(v);
      if (v) {
	vr->regid[k] = pred_regid;
      } else {
	sdata->bitarrays[regval_raw_regid_array]->GetNext(v);
	vr->regid[k] = v;
      }

      // we always update update the table.
      // even if our prediction is correct, the predicted value is different from the value read from the table in case of save/restore
      tdata[cpuid]->regval_regid_tbl[k][regid_tbl_idx] = vr->regid[k];

      // is this reg %g0 ? if so, set value to zero
      if ((vr->regtype[k] == RSTREG_INT_RT) && (vr->regid[k] == 0)) {
	vr->reg64[k] = 0x0;
      }

      // reg64
      sdata->bitarrays[value_iszero_array]->GetNext(v);
      if (v) {
	vr->reg64[k] = 0;
      } else {
	decompress_value(cpuid, v);
	vr->reg64[k] = v;
      }
    } // if regtype != UNUSED
  } // for reg field = 0,1

  // fwrite(rstbuf+idx, sizeof(rstf_unionT), 1, testfp); fflush(testfp);

#if defined(ARCH_AMD64)
  rstf_convertT::l2b((rstf_uint8T*)&rstbuf[idx]);
#endif
} // void rstzip3::decompress_regval(rstf_unionT * rstbuf, int idx)


void rstzip3::decompress_memval(rstf_unionT * rstbuf, int idx)
{
  uint64_t v;

  rstf_memval64T * m64 = & (rstbuf[idx].memval64);
  rstf_memval128T * m128 = & (rstbuf[idx].memval128);

  sdata->bitarrays[memval_fields_array]->GetNext(v);
  m128->ismemval128 = v;

  sdata->bitarrays[memval_fields_array]->GetNext(v);
  m128->addrisVA = ! v;

  // cpuid
  int cpuid;
  sdata->bitarrays[cpuid_pred_array]->GetNext(v);
  if (v) {
    cpuid = pred_cpuid;
  } else {
    sdata->bitarrays[raw_cpuid_array]->GetNext(v);
    cpuid = v;
  }
  rstf_memval128T_set_cpuid(m128, cpuid);
  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  if (m128->ismemval128) {
    sdata->bitarrays[memval_fields_array]->GetNext(v);
    m128->isContRec = v;
    if (! m128->isContRec) {
      sdata->bitarrays[memval_addr36_43_array]->GetNext(v);
      m128->addr36_43 = v;
      sdata->bitarrays[memval_addr04_35_array]->GetNext(v);
      m128->addr04_35 = v;
    }

    // vals
    decompress_value(cpuid, v);
    m128->val[0] = v;
    decompress_value(cpuid, v);
    m128->val[1] = v;

  } else {

    // size
    sdata->bitarrays[memval_size_array]->GetNext(v);
    m64->size = v+1;

    decompress_value(cpuid, v);
    m64->addr = v;
    decompress_value(cpuid, v);
    m64->val = v;

  }
#if defined(ARCH_AMD64)
  rstf_convertT::l2b((rstf_uint8T*)&rstbuf[idx]);
#endif
} // void rstzip3::decompress_memval(rstf_unionT * rstbuf, int idx)

void rstzip3::decompress_trap(rstf_unionT * rstbuf, int idx)
{
  uint64_t v;
  rstf_trapT * tr = &(rstbuf[idx].trap);
  sdata->bitarrays[cpuid_pred_array]->GetNext(v);
  int cpuid;
  if (v) {
    cpuid = pred_cpuid;
  } else {
    sdata->bitarrays[raw_cpuid_array]->GetNext(v);
    cpuid = v;
  }
  rstf_trapT_set_cpuid(tr, cpuid);

  sdata->bitarrays[trap_info_array]->GetNext(v);
  tr->is_async = (v>>48) & 1;
  tr->tl = (v>>44) & 0xf;
  tr->ttype = (v>>34) & 0x3ff;
  tr->pstate = (v>>18) & 0xffff;
  tr->syscall = (v>>2) & 0xfff;
  uint64_t pred_npc;
  if ((v>>1) & 1) { // pred_pc = true
    tr->pc = tdata[cpuid]->pred_pc;
    pred_npc = tdata[cpuid]->pred_npc;
  } else {
    uint64_t pc;
    sdata->bitarrays[raw_value64_array]->GetNext(pc);
    tr->pc = pc;
    pred_npc = pc+4;
  }

  if (v & 1) {
    tr->npc = pred_npc;
  } else {
    uint64_t npc;
    sdata->bitarrays[raw_value64_array]->GetNext(npc);
    tr->npc = npc;
  }
#if defined(ARCH_AMD64)
  rstf_convertT::l2b((rstf_uint8T*)&rstbuf[idx]);
#endif
} // void rstzip3::decompress_trap(rstf_unionT * rstbuf, int idx)


void rstzip3::decompress_tlb(rstf_unionT * rstbuf, int idx)
{
  rstf_tlbT * tr = &(rstbuf[idx].tlb);
  uint64_t tlb_info;
  sdata->bitarrays[tlb_info_array]->GetNext(tlb_info);
  if ((header->major_version == 3) && (header->minor_version <= 19)) {
    tr->demap = (tlb_info>>25) & 0x1;
    tr->tlb_index = (tlb_info >> 9) & 0xffff;
    tr->tlb_type = (tlb_info >> 8) & 1;
    tr->tlb_no = (tlb_info >> 6) & 3;
    int cpuid = (tlb_info) & 0x3f;
    rstf_tlbT_set_cpuid(tr, cpuid);
  } else {
    tr->demap = (tlb_info>>29) & 0x1;
    tr->tlb_index = (tlb_info >> 13) & 0xffff;
    tr->tlb_type = (tlb_info >> 12) & 1;
    tr->tlb_no = (tlb_info >> 10) & 3;
    int cpuid = (tlb_info) & 0x3ff;
    rstf_tlbT_set_cpuid(tr, cpuid);
  }

  uint64_t v;
  sdata->bitarrays[raw_value64_array]->GetNext(v);
  tr->tte_tag = v;
  sdata->bitarrays[raw_value64_array]->GetNext(v);
  tr->tte_data = v;

#if defined(ARCH_AMD64)
  rstf_convertT::l2b((rstf_uint8T*)&rstbuf[idx]);
#endif
} // void rstzip3::decompress_tlb(rstf_unionT * rstbuf, int idx)


void rstzip3::decompress_preg(rstf_unionT * rstbuf, int idx)
{
  rstf_pregT * pr = &(rstbuf[idx].preg);

  uint64_t preg_info;
  sdata->bitarrays[raw_value64_array]->GetNext(preg_info);

  int cpuid;
  if ((preg_info>>61) & 1) {
    cpuid = pred_cpuid;
  } else {
    uint64_t v;
    sdata->bitarrays[raw_cpuid_array]->GetNext(v);
    cpuid = v;
  }
  rstf_pregT_set_cpuid(pr, cpuid);

  pr->primD = (preg_info >> 48) & 0x1fff;
  pr->primA = pr->primD;
  pr->secD = (preg_info >> 35) & 0x1fff;
  pr->secA = pr->secD;
  pr->asiReg = (preg_info >> 27) & 0xff;
  pr->traplevel = (preg_info >> 24) & 7;
  pr->traptype = (preg_info >> 16) & 0xff;
  pr->pstate = preg_info & 0xffff;

#if defined(ARCH_AMD64)
  rstf_convertT::l2b((rstf_uint8T*)&rstbuf[idx]);
#endif
} // void rstzip3::decompress_preg(rstf_unionT * rstbuf, int idx)


void rstzip3::decompress_dma(rstf_unionT * rstbuf, int idx)
{
  uint64_t v;
  rstf_dmaT * dr = &(rstbuf[idx].dma);

  sdata->bitarrays[dma_iswrite_array]->GetNext(v);
  dr->iswrite = v;

  sdata->bitarrays[dma_nbytes_array]->GetNext(v);
  dr->nbytes = v;

  sdata->bitarrays[raw_value64_array]->GetNext(v);
  dr->start_pa = v;

  if (!pre323) {
      sdata->bitarrays[raw_value64_array]->GetNext(v);
      dr->devid = v;
  }

#if defined(ARCH_AMD64)
  rstf_convertT::l2b((rstf_uint8T*)&rstbuf[idx]);
#endif
} // void rstzip3::decompress_dma(rstf_unionT * rstbuf, int idx)



void rstzip3::decompress_rfs_cw(rstf_unionT * rstbuf, int idx)
{
  uint64_t v;

  rstf_cachewarmingT *cw = &(rstbuf[idx].cachewarming);

  sdata->bitarrays[rfs_cw_raw_reftype_array]->GetNext(v);
  cw->reftype = v;

  sdata->bitarrays[rfs_raw_cpuid_array]->GetNext(v);
  int cpuid;
  if ((cw->reftype != cw_reftype_DMA_R) && (cw->reftype != cw_reftype_DMA_W)) {
    rstf_cachewarmingT_set_cpuid(cw, v);
    cpuid = v;
  } else {
    // cw cpuid is already 0 because we had cleared the memory
    cpuid = 0;
  }
  
  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  if ((cw->reftype == cw_reftype_DMA_R) || (cw->reftype == cw_reftype_DMA_W)) {
    sdata->bitarrays[raw_value64_array]->GetNext(v);
    cw->pa = v;
    sdata->bitarrays[rfs_cw_dma_size_array]->GetNext(v);
    cw->refinfo.dma_size = v;
  } else /* not DMA */ {
    // asi
    sdata->bitarrays[rfs_cw_asi_array]->GetNext(v); cw->refinfo.s.asi = v;

    // fcn
    if (cw->reftype == cw_reftype_PF_D) {
      sdata->bitarrays[rfs_cw_pf_fcn_array]->GetNext(v); cw->refinfo.s.fcn = v;
    }

    // va_valid
    sdata->bitarrays[rfs_cw_va_valid_array]->GetNext(v); cw->refinfo.s.va_valid = v;

    if (cw->refinfo.s.va_valid) {
      // va
      decompress_value(cpuid, v); cw->va = v;

      // tlb hit/miss
      sdata->bitarrays[rfs_cw_pa_pred_array]->GetNext(v);
      if (v) {
	uint64_t pred_pa;
	if (cw->reftype == cw_reftype_I) {
	  pred_pa =  tdata[cpuid]->itlb->get(cw->va>>13) << 13;
	} else {
	  if (header->minor_version <= 20) {
	    // backward compatibility: this was a bug in both compress & decompress fixed in 3.21
	    pred_pa = tdata[cpuid]->itlb->get(cw->va>>13) << 13;
	  } else {
	    pred_pa = tdata[cpuid]->dtlb->get(cw->va>>13) << 13;
	  }
	}
	pred_pa |= (cw->va & 0x1fffull);
	cw->pa = pred_pa;
      } else {
	sdata->bitarrays[raw_value64_array]->GetNext(v); cw->pa = v;
	if (cw->reftype == cw_reftype_I) {
	  tdata[cpuid]->itlb->set(cw->va>>13, cw->pa>>13);
	} else {
	  tdata[cpuid]->dtlb->set(cw->va>>13, cw->pa>>13);
	}
      }
      
    } else {
      sdata->bitarrays[raw_value64_array]->GetNext(v); cw->pa = v;
    }
  } // DMA?

#if defined(ARCH_AMD64)
  rstf_convertT::l2b((rstf_uint8T*)&rstbuf[idx]);
#endif
} // void rstzip3::decompress_rfs_cw(rstf_unionT * rstbuf, int idx)




void rstzip3::decompress_rfs_bt(rstf_unionT * rstbuf, int idx)
{
  uint64_t v;

  rstf_bpwarmingT * bt = &(rstbuf[idx].bpwarming);

  // cpuid
  sdata->bitarrays[rfs_raw_cpuid_array]->GetNext(v);
  int cpuid = v;
  rstf_bpwarmingT_set_cpuid(bt, cpuid);
  if (tdata[cpuid] == NULL) {
    tdata[cpuid] = new rz3_percpu_data(cpuid);
  }

  // pc
  sdata->bitarrays[rfs_pc_pred_array]->GetNext(v);
  if (v) {
    bt->pc_va = tdata[cpuid]->rfs_pc_pred_table->get(tdata[cpuid]->rfs_prev_npc);
  } else {
    sdata->bitarrays[raw_value64_array]->GetNext(v); bt->pc_va = v;
    tdata[cpuid]->rfs_pc_pred_table->set(tdata[cpuid]->rfs_prev_npc, bt->pc_va);
  }

  // instr: use icache
  sdata->bitarrays[rfs_instr_pred_array]->GetNext(v);
  rz3iu_icache_data * icdata;
  if (v) {
    icdata = tdata[cpuid]->icache->get(bt->pc_va);
    bt->instr = icdata->instr;
  } else {
    sdata->bitarrays[raw_instr_array]->GetNext(v);
    bt->instr = v;
    icdata = tdata[cpuid]->icache->set(bt->pc_va, bt->instr, header->major_version, header->minor_version);
    icdata->gen_target(bt->pc_va);
  }

  // bt
  sdata->bitarrays[rfs_bt_pred_array]->GetNext(v);
  int bt_pred_hit = v;
  if (icdata->dinfo.flags.iscbranch) {
    bt->taken = tdata[cpuid]->bp->actual_outcome(bt->pc_va, bt_pred_hit);
  } else if (icdata->dinfo.flags.isubranch && icdata->dinfo.flags.isubranch_nottaken) {
    bt->taken = ! bt_pred_hit;
  } else {
    bt->taken = bt_pred_hit;
  }

  // target
  sdata->bitarrays[dcti_ea_va_pred_array]->GetNext(v);
  if (v) {
    bt->npc_va = bt->taken ? icdata->target : (bt->pc_va+8);
  } else {
    sdata->bitarrays[raw_value64_array]->GetNext(v); bt->npc_va = v;
  }

  tdata[cpuid]->rfs_prev_npc = bt->npc_va;

  tdata[cpuid]->pred_pc = tdata[cpuid]->rfs_pc_pred_table->get(bt->npc_va);

#if defined(ARCH_AMD64)
  rstf_convertT::l2b((rstf_uint8T*)&rstbuf[idx]);
#endif
} // void rstzip3::decompress_rfs_bt(rstf_unionT * rstbuf, int idx)


bool rstzip3::decompress_value(int cpuid, uint64_t & v64)
{
  uint64_t key;
  uint64_t level;
  sdata->bitarrays[valuecache_level_array]->GetNext(level);
  sdata->bitarrays[valuecache_data0_array+level]->GetNext(key);
  return tdata[cpuid]->valuecache->Retrieve(level, key, v64);
}
