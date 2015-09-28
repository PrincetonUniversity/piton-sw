// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: rz3_section.C
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
/* rz3_section.C
 * rz3 section header, section data, per-cpu temporary data etc
 */

#include "rstzip3.h"
#include "rz3_section.h"
#include "rz3utils.h"

#if defined(ARCH_AMD64)
#include "rstf/byteswap.h"
#endif


void rz3_section_header::clear()
{
  nrecords = 0;

  bzero(rz3_bitarray_counts, sizeof(uint32_t) * rstzip3::bitarray_count);

} // rz3_section_header::clear()


bool rz3_section_header::write(gzFile gzf)
{
#if defined(ARCH_AMD64)
  flip_endianess();
#endif

  return (gzwrite(gzf, this, sizeof(rz3_section_header_file)) == sizeof(rz3_section_header_file));
} // bool rz3_section_header::write(gzFile gzf)


bool rz3_section_header::read(gzFile gzf)
{
  int bytes_read = gzread(gzf, this, sizeof(rz3_section_header_file));
  if (bytes_read == 0) {
    /* end of file */
    return false;
  }

  if (bytes_read != sizeof(rz3_section_header_file)) {
    int errnum;
    fprintf(stderr, "rz3_section_header::read() - gzread error (bytes read=%d, req = %d) %s\n",
	    bytes_read, sizeof(rz3_section_header_file), gzerror(gzf, &errnum));
    fprintf(stderr, "errnum %d\n", errnum);
    return false;
  }

#if defined(ARCH_AMD64)
  flip_endianess();
#endif

  // sanity checks

  return sanity_check();

} // bool rz3_section_header::read(gzFile gzf)


bool rz3_section_header::sanity_check() {
  // check magic number
  if ((magic[0] == 0) || strcmp(magic, rz3_shdr_magic)) {
    fprintf(stderr, "rz3 section_header magic mismatch\n");
    return false;
  }

  if ((nrecords <= 0) || (nrecords > rz3obj->rz3_bufsize)) {
    fprintf(stderr, "rz3 section header: invalid value of nrecords (%d not between 1 and %d)\n", nrecords, rz3obj->rz3_bufsize);
    return false;
  }

  return true;
}


#if defined(ARCH_AMD64)
void rz3_section_header::flip_endianess() {
  nrecords = byteswap32(nrecords);
  CompressedBufferSize = byteswap64(CompressedBufferSize);
  for (int i=0; i<rstzip3::bitarray_count; i++) {
    rz3_bitarray_counts[i] = byteswap32(rz3_bitarray_counts[i]);
  }
}
#endif



rz3_section_data::rz3_section_data(rz3_section_header * arg_shdr, bool pre320)
{
  shdr = arg_shdr;

  // raw_records_array = new rz3_rst_array(rz3_bufsize); // only allocates bufsize/512 pointers. array grows on demand

  int i;
  for (i=0; i<rstzip3::bitarray_count; i++) {
    int nbits = rstzip3::bitarray_descr[i].nbits;

    // this is a sub-optimal way of coding this, but we need to
    // special case things for version differences and backward
    // compatibility... (2004/12/23, 2005/01/11)
    if (pre320) {
      switch(i) {
      case rstzip3::raw_cpuid_array:
	nbits = 6;
	break;
      case rstzip3::instr_pred_raw_array:
	nbits = 7;
	break;
      case rstzip3::tlb_info_array:
	nbits = 26;
	break;
      default:
	break;
      } // switch i
    } // if pre320

    int size_hint = rstzip3::bitarray_descr[i].size_hint;
    bitarrays[i] = new rz3_bitarray(rstzip3::bitarray_descr[i].name, nbits, size_hint);
    total_rz3_bitarray_counts[i] = 0;
    total_rz3_bitarray_sums[i] = 0;
  }

  total_nrecords = 0;
  total_CompressedBufferSize = 0;

} // rz3_section_data::()


rz3_section_data::~rz3_section_data()
{

  // delete raw_records_array; raw_records_array = NULL;

  int i;
  for (i=0; i<rstzip3::bitarray_count; i++) {
    delete bitarrays[i]; bitarrays[i] = NULL;
  }

} // rz3_section_data::~()



void rz3_section_data::clear()
{
  int i;

  for (i=0; i<rstzip3::bitarray_count; i++) {
    bitarrays[i]->clear();
  }

  // raw_records_array->clear();

} // rz3_section_data::clear()


void rz3_section_data::print()
{

  fprintf(stderr, "\nSection array sizes:\n");
  fprintf(stderr, "nrecords = %d\n", shdr->nrecords);

  int instr_count = bitarrays[rstzip3::instr_pred_all_array]->Count();


  int i;
  for (i=0; i<rstzip3::bitarray_count; i++) {
    int count = shdr->rz3_bitarray_counts[i];
    fprintf(stderr, "# %s = %6d (%7.4f%%/instr, %7.4f%%/rec)  %7.4f bits/rec %7.4f%% of all bits",
	    rstzip3::bitarray_descr[i].name, count, count*100.0/instr_count, count*100.0/shdr->nrecords,
	    count*rstzip3::bitarray_descr[i].nbits*1.0/shdr->nrecords, count*rstzip3::bitarray_descr[i].nbits*100.0/(8*shdr->CompressedBufferSize));
    if (rstzip3::bitarray_descr[i].nbits == 1) {
      uint64_t sum = bitarrays[i]->GetSum();
      fprintf(stderr, " set-bit-count=%lld (%7.4f%%))\n", sum, sum*100.0/count);
    } else {
      fprintf(stderr, "\n");
    }
  }

  // int count = raw_records_array->Count();
  // fprintf(stderr, "# raw_records_array = %d (%3.4f%%/instr, \t%3.4f%%/rec)\n", count, count*100.0/instr_count, count*100.0/shdr->nrecords);

  fprintf(stderr, "Size of compressed buffer is %lld (%7.4f bytes/instr, %7.4f bytes/rec)\n",
	 shdr->CompressedBufferSize, shdr->CompressedBufferSize*1.0/instr_count, shdr->CompressedBufferSize*1.0/shdr->nrecords);

} // rz3_section_data::print()


void rz3_section_data::print_totals()
{

  fprintf(stderr, "\nTotal section array sizes:\n");
  fprintf(stderr, "nrecords = %d\n", total_nrecords);

  int instr_count = total_rz3_bitarray_counts[rstzip3::instr_pred_all_array];


  int i;
  for (i=0; i<rstzip3::bitarray_count; i++) {
    int count = total_rz3_bitarray_counts[i];
    fprintf(stderr, "# total %s = %6d (%7.4f%%/instr, %7.4f%%/rec)  %7.4f bits/rec %7.4f%% of all bits",
	    rstzip3::bitarray_descr[i].name, count, count*100.0/instr_count, count*100.0/total_nrecords,
	    count*rstzip3::bitarray_descr[i].nbits*1.0/total_nrecords, count*rstzip3::bitarray_descr[i].nbits*100.0/(8*total_CompressedBufferSize));
    if (rstzip3::bitarray_descr[i].nbits == 1) {
      uint64_t sum = total_rz3_bitarray_sums[i];
      fprintf(stderr, " set-bit-count=%lld (%7.4f%%))\n", sum, sum*100.0/count);
    } else {
      fprintf(stderr, "\n");
    }
  }

  // int count = raw_records_array->Count();
  // fprintf(stderr, "# raw_records_array = %d (%3.4f%%/instr, \t%3.4f%%/rec)\n", count, count*100.0/instr_count, count*100.0/shdr->nrecords);

  fprintf(stderr, "Total size of compressed buffer is %lld (%7.4f bytes/instr, %7.4f bytes/rec)\n",
	  total_CompressedBufferSize, total_CompressedBufferSize*1.0/instr_count, total_CompressedBufferSize*1.0/total_nrecords);

} // rz3_section_data::print()



void rz3_section_data::update_counts()
{
  shdr->CompressedBufferSize = sizeof(rz3_section_header);

  int i;
  for (i=0; i<rstzip3::bitarray_count; i++) {
    shdr->rz3_bitarray_counts[i] = bitarrays[i]->Count();
    total_rz3_bitarray_counts[i] += shdr->rz3_bitarray_counts[i];
    shdr->CompressedBufferSize += bitarrays[i]->GetMemBufSize();
    if (rstzip3::bitarray_descr[i].nbits == 1) {
      total_rz3_bitarray_sums[i] += bitarrays[i]->GetSum();
    }
  }
  total_nrecords += shdr->nrecords;
  total_CompressedBufferSize += shdr->CompressedBufferSize;

} // void rz3_section_data::update_counts()


// return false if error
bool rz3_section_data::write(gzFile gzf)
{
  uint64_t membufsz = shdr->rz3obj->rz3_bufsize;
  uint8_t * membuf = new uint8_t [membufsz];

  int i;
  for (i=0; i<rstzip3::bitarray_count; i++) {
    uint64_t sz = bitarrays[i]->GetMemBufSize();
    if (sz > membufsz) {
      membufsz = sz;
      delete [] membuf;
      membuf = new uint8_t [membufsz];
    }
    bitarrays[i]->CopyTo(membuf);
    if (gzwrite(gzf, membuf, sz) != sz) {
      return false;
    }
  } // for each array

  delete [] membuf;
  return true;
} // rz3_section_data::write()




bool rz3_section_data::read(gzFile gzf)
{
  uint64_t membufsz = shdr->rz3obj->rz3_bufsize;
  uint8_t * membuf = new uint8_t [membufsz];

  int i;
  for (i=0; i<rstzip3::bitarray_count; i++) {
    uint64_t sz = bitarrays[i]->ComputeMemBufSize(shdr->rz3_bitarray_counts[i]);
    if (sz > membufsz) {
      membufsz = sz;
      delete [] membuf;
      membuf = new uint8_t [membufsz];
    }
    if (gzread(gzf, membuf, sz) != sz) {
      return false;
    }
    int bytes_copied = (int) bitarrays[i]->CopyFrom(membuf, shdr->rz3_bitarray_counts[i]);
    if (bytes_copied != sz) {
      fprintf(stderr, "rz3_section_data: error reading %lld bytes into %s", sz, rstzip3::bitarray_descr[i]);
      return false;
    }
  } // for each array

  delete [] membuf;
  return true;
}




// return false if error
bool rz3_section_data::write(FILE * fp)
{
  uint64_t membufsz = shdr->rz3obj->rz3_bufsize;
  uint8_t * membuf = new uint8_t [membufsz];

  int i;
  for (i=0; i<rstzip3::bitarray_count; i++) {
    uint64_t sz = bitarrays[i]->GetMemBufSize();
    if (sz > membufsz) {
      membufsz = sz;
      delete [] membuf;
      membuf = new uint8_t [membufsz];
    }
    bitarrays[i]->CopyTo(membuf);
    if (fwrite(membuf, 1, sz, fp) != sz) {
      return false;
    }
  } // for each array

  delete [] membuf;
  return true;
} // rz3_section_data::write()




bool rz3_section_data::read(FILE * fp)
{
  uint64_t membufsz = shdr->rz3obj->rz3_bufsize;
  uint8_t * membuf = new uint8_t [membufsz];

  int i;
  for (i=0; i<rstzip3::bitarray_count; i++) {
    uint64_t sz = bitarrays[i]->ComputeMemBufSize(shdr->rz3_bitarray_counts[i]);
    if (sz > membufsz) {
      membufsz = sz;
      delete [] membuf;
      membuf = new uint8_t [membufsz];
    }
    if (fread(membuf, 1, sz, fp) != sz) {
      return false;
    }
    int bytes_copied = (int) bitarrays[i]->CopyFrom(membuf, shdr->rz3_bitarray_counts[i]);
    if (bytes_copied != sz) {
      fprintf(stderr, "rz3_section_data: error reading %lld bytes into %s", sz, rstzip3::bitarray_descr[i]);
      return false;
    }
  } // for each array

  delete [] membuf;
  return true;
}




rz3_percpu_data::rz3_percpu_data(int arg_cpuid)
{

  cpuid = arg_cpuid;

  icache = new rz3iu_icache;

  bp = new rz3iu_brpred;

  jmpl_table = new rz3_table<uint64_t>(rz3_tdata_jmpl_table_size);

  itlb = new rz3_table<uint64_t>(rz3_tdata_itlb_size);
  dtlb = new rz3_table<uint64_t>(rz3_tdata_dtlb_size);

  ras = new rz3_ras;

  char vcname[32];
  sprintf(vcname, "cpu%d", cpuid);
  valuecache = new rz3_valuecache(vcname);

  rfs_pc_pred_table = new rz3_table<uint64_t>(rz3_tdata_rfs_pc_pred_table_size);

  regval_regtype_tbl[0] = new uint8_t [rz3_tdata_regval_regtype_tbl_size];
  regval_regtype_tbl[1] = new uint8_t [rz3_tdata_regval_regtype_tbl_size];

  regval_regid_tbl[0] = new uint8_t [rz3_tdata_regval_regid_tbl_size];
  regval_regid_tbl[1] = new uint8_t [rz3_tdata_regval_regid_tbl_size];

  regs = new uint64_t [32];

  clear();
} // rz3_percpu_data::rz3_tmp_data()


void rz3_percpu_data::clear()
{
  pred_pc = 0x0;
  pred_npc = 0x0;
  pred_icontext = 0x0;
  pred_dcontext = 0x0;
  pred_amask = 0;
  pred_an = 0;
  pred_hpriv = 0;
  pred_pr = 0;
  call_delay_slot = false;
  pending_pavadiff_idx = -1;
  pending_pavadiff_pc_pa_va_pred = false;
  pending_pavadiff_ea_pa_va_pred = false;

  prev_pc = 0x0;

  rfs_prev_npc = 0x0;

  icache->clear();

  bp->clear();

  ras->clear();

  jmpl_table->clear();

  itlb->clear();
  dtlb->clear();

  valuecache->Clear();

  rfs_pc_pred_table->clear();

  bzero(regval_regtype_tbl[0], rz3_tdata_regval_regtype_tbl_size);
  bzero(regval_regtype_tbl[1], rz3_tdata_regval_regtype_tbl_size);
  bzero(regval_regid_tbl[0], rz3_tdata_regval_regid_tbl_size);
  bzero(regval_regid_tbl[1], rz3_tdata_regval_regid_tbl_size);

  last_instr = 0x0;
  bzero(regs, 32*sizeof(uint64_t));
  ccr = 0;
} // rz3_percpu_data::clear()


rz3_percpu_data::~rz3_percpu_data() {
  delete icache;
  delete bp;
  delete jmpl_table;
  delete itlb;
  delete dtlb;
  delete valuecache;
  delete rfs_pc_pred_table;
  delete regval_regtype_tbl[0];
  delete regval_regtype_tbl[1];
  delete regval_regid_tbl[0];
  delete regval_regid_tbl[1];

  delete [] regs;
} // rz3_percpu_data::~()
