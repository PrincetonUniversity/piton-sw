// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: rstzip3.C
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
/* rz3.C
 * the RZ3 compressor/decompressor
 *
 * Copyright (C) 2003 Sun Microsystems, Inc.
 * All Rights Reserved
 */


#ident "@(#)1.4 06/28/04 SMI rstzip3.C"


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <strings.h>
#include <unistd.h>
#include <ctype.h>

#include "zlib.h"

#include "rstf/rstf.h"

#include "rstzip3.h"

#include "rz3_section.h"


rz3_bitarray_descr rstzip3::bitarray_descr[] = {

  {"rtype_key_array               ", 2, rz3_bufsize_default},
  {"rtype_array                   ", 8, rz3_bufsize_default >>4},

  {"cpuid_pred_array              ", 1, rz3_bufsize_default},
  {"raw_cpuid_array               ", 10, (rz3_bufsize_default>>4)}, // was 6 in older versions

  {"instr_pred_all_array          ", 1, rz3_bufsize_default},
  {"instr_pred_raw_array          ", 8, rz3_bufsize_default>>4}, // was 7 in v3.19 and older

  {"raw_instr_array               ", 32, (rz3_bufsize_default>>4)},

  {"dcti_ea_va_pred_array         ", 1, rz3_bufsize_default>>4},

  {"value_iszero_array            ", 1, rz3_bufsize_default>>2},

  {"valuecache_level_array        ", 3, rz3_bufsize_default>>2},


  {"valuecache_data0_array        ", rz3_valuecache_idxbits0 + rz3_valuecache_lsbits0, rz3_bufsize_default>>2},
  {"valuecache_data1_array        ", rz3_valuecache_idxbits1 + rz3_valuecache_lsbits1, rz3_bufsize_default>>3},
  {"valuecache_data2_array        ", rz3_valuecache_idxbits2 + rz3_valuecache_lsbits2, rz3_bufsize_default>>4},
  {"valuecache_data3_array        ", rz3_valuecache_idxbits3 + rz3_valuecache_lsbits3, rz3_bufsize_default>>5},
  {"valuecache_data4_array        ", rz3_valuecache_idxbits4 + rz3_valuecache_lsbits4, rz3_bufsize_default>>6},
  {"valuecache_data5_array        ", rz3_valuecache_idxbits5 + rz3_valuecache_lsbits5, rz3_bufsize_default>>7},
  {"valuecache_data6_array        ", rz3_valuecache_idxbits6 + rz3_valuecache_lsbits6, rz3_bufsize_default>>8},

  {"raw_value64_array             ", 64, rz3_bufsize_default>>6},

  {"regval_postInstr_array        ", 1, (rz3_bufsize_default>>1)},
  {"regval_regtype_pred_array     ", 1, rz3_bufsize_default},
  {"regval_raw_regtype_array      ", 8, rz3_bufsize_default>>4},
  {"regval_regid_pred_array       ", 1, rz3_bufsize_default},
  {"regval_raw_regid_array        ", 8, rz3_bufsize_default>>4},

  {"memval_fields_array           ", 1, rz3_bufsize_default>>4},
  {"memval_size_array             ", 3, rz3_bufsize_default>>4},
  {"memval_addr36_43_array        ", 8, rz3_bufsize_default>>6},
  {"memval_addr04_35_array        ", 32, rz3_bufsize_default>>6},

  {"pavadiff_ictxt_pred_array     ", 1, rz3_bufsize_default>>2},
  {"pavadiff_raw_ictxt_array      ", 13, rz3_bufsize_default>>4},
  {"pavadiff_pc_pa_va_pred_array  ", 1, rz3_bufsize_default>>2},
  {"pavadiff_ea_valid_array       ", 1, rz3_bufsize_default>>2},
  {"pavadiff_dctxt_pred_array     ", 1, rz3_bufsize_default>>2},
  {"pavadiff_raw_dctxt_array      ", 13, rz3_bufsize_default>>4},
  {"pavadiff_ea_pa_va_pred_array  ", 1, rz3_bufsize_default>>2},
  {"pavadiff_lookahead_array      ", 1, rz3_bufsize_default>>8},

  {"tlb_info_array                ", 30, rz3_bufsize_default>>4}, // was 26bytes in v3.19 and older

  {"trap_info_array               ", 49, rz3_bufsize_default>>4},

  {"dma_iswrite_array             ", 1, rz3_bufsize_default>>6},
  {"dma_nbytes_array              ", 32, rz3_bufsize_default>>6},

  {"rfs_rtype_pred_array          ", 1, rz3_bufsize_default>>4},
  {"rfs_pc_pred_array             ", 1, rz3_bufsize_default>>4},
  {"rfs_instr_pred_array             ", 1, rz3_bufsize_default>>4},
  {"rfs_bt_pred_array             ", 1, rz3_bufsize_default>>4},
  {"rfs_cw_raw_reftype_array      ", 3, rz3_bufsize_default>>4},
  {"rfs_raw_cpuid_array           ", 10, rz3_bufsize_default>>4},
  {"rfs_cw_dma_size_array         ", 32, rz3_bufsize_default>>6},
  {"rfs_cw_asi_array              ", 8, rz3_bufsize_default>>4},
  {"rfs_cw_pf_fcn_array           ", 5, rz3_bufsize_default>>6},
  {"rfs_cw_va_valid_array         ", 1, rz3_bufsize_default>>4},
  {"rfs_cw_pa_pred_array          ", 1, rz3_bufsize_default>>4},

}; // struct rz3_bitarray_descr rstzip3::bitarray_descr[] 



// the rel field is a parameter relative to which to print stats
// (in addition to per record and per instr). eg raw-regvals per regval.
// ps_max => none
struct rz3_perf_stats_descr rstzip3::perf_stats_descr[] = {


  {"nrecords                  ", rstzip3::ps_MAX},
  {"instr_counts              ", rstzip3::ps_MAX},

  {"brpred_refs               ", rstzip3::ps_MAX},
  {"brpred_misses             ", rstzip3::ps_brpred_refs},

  {"an_misses                 ", rstzip3::ps_MAX},

  {"ras_refs                  ", rstzip3::ps_MAX},
  {"ras_misses                ", rstzip3::ps_ras_refs},

  {"ea_valid_misses           ", rstzip3::ps_MAX},
  {"ea_va_valuecache_refs     ", rstzip3::ps_MAX},
  {"ea_va_valuecache_misses   ", rstzip3::ps_ea_va_valuecache_refs},

  {"regval_records            ", rstzip3::ps_MAX},
  {"regval_raw_regtype_count  ", rstzip3::ps_regval_records},
  {"regval_raw_regid_count    ", rstzip3::ps_regval_records},
  {"regval_valuecache_refs    ", rstzip3::ps_regval_records},
  {"regval_valuecache_misses  ", rstzip3::ps_regval_valuecache_refs},

  {"pavadiff_count            ", rstzip3::ps_MAX},
  {"pavadiff_ictxt_misses     ", rstzip3::ps_pavadiff_count},
  {"pavadiff_raw_pc_pa        ", rstzip3::ps_pavadiff_count},
  {"pavadiff_ea_valid_count   ", rstzip3::ps_pavadiff_count},
  {"pavadiff_dctxt_misses     ", rstzip3::ps_pavadiff_count},
  {"pavadiff_raw_ea_pa_va     ", rstzip3::ps_pavadiff_count}

}; // struct rz3_perf_stats_descr rstzip3::perf_stats_descr = {}


rstzip3::rstzip3(const char * fname, const char * mode)
{
  rz3_error = false;

  verbose = false;
  stats = false;
  g0_nonzero_warn = true; // will be set to false after first instance unless verbose

  if ((mode == NULL) || (mode[0] == 0)) {
    fprintf(stderr, "ERROR: rz3: mode must be specified as \"r\" or \"w\"\n");
    rz3_error = true;
    return;
  } else if (strcmp(mode, "r") == 0) {
    c_nd = false;
  } else if (strcmp(mode, "w") == 0) {
    c_nd = true;
  } else {
    fprintf(stderr, "ERROR: rz3: mode must be specified as \"r\" or \"w\"\n");
    rz3_error = true;
    return;
  }

  header = new rz3_header;

  shdr = new rz3_section_header(this);

  if (c_nd) {

    rz3_bufsize = rz3_bufsize_default;

    if (fname != NULL) {
      gzf = gzopen(fname, "w");
      if (gzf == NULL) {
	fprintf(stderr, "ERROR: rz3: failed gzopen of output file "); perror(fname);
	rz3_error = true;
	return;
      }
    } else {
      gzf = gzdopen(STDOUT_FILENO, "w");
      if (gzf == NULL) {
	perror("ERROR: rz3: failed gzdopen of STDOUT");
	rz3_error = true;
	return;
      }
    }

    // write header
    strcpy(header->magic, rz3_hdr_magic);
    header->major_version = rstzip3_major_version;
    header->minor_version = rstzip3_minor_version;
    header->reserved16 = 0;
    header->reserved32 = 0;
    gzwrite(gzf, header, sizeof(rz3_header));

    strcpy(shdr->magic, rz3_shdr_magic);

    rstf_pre212 = false; // set to true if necessary upon reading rst header record

    pre320 = false;

    pre323 = false;

  } else /* decompress */ {
    if (fname != NULL) {
      gzf = gzopen(fname, "r");
      if (gzf == NULL) {
	fprintf(stderr, "ERROR: rz3: failed gzopen of input file "); perror(fname);
	rz3_error = true;
	return;
      }
    } else /* stdin */{
      gzf = gzdopen(STDIN_FILENO, "r");
      if (gzf == NULL) {
	perror("ERROR: rz3: failed gzdopen of STDIN");
	rz3_error = true;
	return;
      }
    }

    // read header
    int nbytes = gzread(gzf, header, sizeof(rz3_header));
    if (nbytes != sizeof(rz3_header)) {
      int errnum;
      fprintf(stderr, "ERROR: gzread rz3 header from input file: %s"); gzerror(gzf, &errnum);
      fprintf(stderr, "errnum %d\n", errnum);
      rz3_error = true;
      return;
    }

    // check header
    if ((header->magic[0] == 0) || strcmp(rz3_hdr_magic, header->magic)) {
      fprintf(stderr, "ERROR: rz3 header magic string mismatch\n");
      if (verbose) {
	fprintf(stderr, "  expected: %s\n", rz3_hdr_magic);
	fprintf(stderr, "  saw: ");
	int i;
	for (i=0; i<15; i++) {
	  if (isprint(header->magic[i])) fprintf(stderr, "%c", header->magic[i]); else fprintf(stderr, "\\%03o", (int) header->magic[i]);
	}
      }
      rz3_error = true;
      return;
    }

    // version must be >= 3.15. v3.14beta was the first beta version which is not supported
    if ((header->major_version == 3) && (header->minor_version == 14)) {
      fprintf(stderr, "ERROR: rstzip v3.14beta is an unsupported version.\n");
      fprintf(stderr, "Please decompress this file using the stand-alone rstzip v3.14beta binary,\n");
      fprintf(stderr, "and recompress using the latest rstzip3 compressor\n");
      rz3_error = true;
      return;
    }

    // check if our major/minor version is >= version number from file
    float f1 = rstzip3_major_version + rstzip3_minor_version/1000.0;
    float f2 = header->major_version + header->minor_version/1000.0;
    if (f2 > f1) {
      fprintf(stderr, "ERROR: version number of compressed file (%d.%03d) is greater than this build (%d.%03d)\n",
	      header->major_version, header->minor_version, rstzip3_major_version, rstzip3_minor_version);
      rz3_error = true;
      return;
    }

    if ((header->major_version == 3) && (header->minor_version <= 19)) {
      pre320 = true;
    } else {
      pre320 = false;
    }
    rstf_pre212 = false; // this variable is ignored during decompression

    if ((header->major_version == 3) && (header->minor_version <= 21)) {
      rz3_bufsize = rz3_bufsize_pre322;
    } else {
      rz3_bufsize = rz3_bufsize_default;
    }

    if ((header->major_version == 3) && (header->minor_version <= 22)) {
	pre323 = true;
    } else {
	pre323 = false;
    }
  } // compress/decompress?

  sdata = new rz3_section_data(shdr, pre320);

  clear(); // clear prediction-related state variables

  tdata = new rz3_percpu_data * [rz3_max_ncpus];

  int i;
  for (i=0; i<(rz3_max_ncpus); i++) {
    tdata[i] = NULL;
  }


  interface_buffer = new rstf_unionT[rz3_bufsize];
  interface_buffer_size = interface_buffer_count = 0;

  rfs_phase = false;
  rfs_cw_phase = false;
  rfs_bt_phase = false;

  nsections = 0;

  perf_stats = new int [ps_MAX];
  perf_stat_totals = new int64_t [ps_MAX];
  for (i=0; i<ps_MAX; i++) {
    perf_stat_totals[i] = 0;
  }
  raw_v64_count=0;
  if (!c_nd) {
    // testfp = fopen("/tmp/rz3tmp.rst", "w");
  } else {
    testfp = NULL;
  }
} // rstzip3::rstzip3(const char * fname, const char * mode)


rstzip3::~rstzip3()
{
  if (c_nd) {
    if (interface_buffer_count != 0) {
      compress_buffer(interface_buffer, interface_buffer_count);
      interface_buffer_count = 0;
    }
  } else {
    // caller did not wait to read all decompressed records. ignore
  }
  if (sdata != NULL) {
    if (verbose) sdata->print_totals();
    if (verbose) {
      int i;
      for (i=0; i<rz3_max_ncpus; i++) {
	if (tdata[i] != NULL) {
	  tdata[i]->valuecache->Report(stderr);
	}
      }
    }
    if (stats) print_stat_totals();
  }

  if (gzf != NULL) {
    gzclose(gzf); gzf = NULL;
  }

  delete shdr; shdr = NULL;
  delete sdata; sdata = NULL;

  int i;
  for (i=0; i<(rz3_max_ncpus); i++) {
    if (tdata[i] != NULL) {
      delete tdata[i]; tdata[i] = NULL;
    }
  }
  delete [] tdata; tdata = NULL;

  if (interface_buffer != NULL) {
    delete [] interface_buffer;
  }
} // rstzip3::~rstzip3()



int rstzip3::compress(rstf_unionT * buf, int nrec)
{
  // if interface buffer count is non-zero, copy in records to fill up buffer
  int done = 0;
  if (interface_buffer_count) {
    int n = (rz3_bufsize - interface_buffer_count);
    if (n > nrec) n = nrec;
    memcpy(interface_buffer+interface_buffer_count, buf, n*sizeof(rstf_unionT));
    interface_buffer_count += n;
    if (interface_buffer_count == rz3_bufsize) {
      compress_buffer(interface_buffer, rz3_bufsize);
      interface_buffer_count = 0;
    }
    done += n;
    if (done == nrec) {
      return done;
    }
  }

  // at this point, there are no records waiting to be compressed in the buffer
  while((nrec-done) >= rz3_bufsize) {
    compress_buffer(buf+done, rz3_bufsize);
    done += rz3_bufsize;
  }

  // at this point, the buffer is empty; there may be some records left to be
  // compressed, but not enough to fill the buffer
  if (done < nrec) {
    memcpy(interface_buffer, buf+done, (nrec-done)*sizeof(rstf_unionT));
    interface_buffer_count += (nrec-done);
  }
  return nrec;

} // int rstzip3::compress(rstf_unionT * buf, int nrec)


int rstzip3::decompress(rstf_unionT * buf, int nrec)
{
  // if there are some records ready to be
  // copied out, copy out as many as possible
  int done = 0;
  if (interface_buffer_count) {
    int n = interface_buffer_count;
    if (n > nrec) n = nrec;

    memcpy(buf+done, interface_buffer+(interface_buffer_size-interface_buffer_count), n*sizeof(rstf_unionT));
    interface_buffer_count -= n;
    done += n;
    if (done == nrec) return nrec;
  }

  // at this point, if we haven't returned, done < nrec and interface_buffer_count == 0
  // decompress the next section.
  while((nrec-done) >= rz3_bufsize) {
    int n = decompress_buffer(buf+done, rz3_bufsize); // returns the actual number of records decmopressed
    // this should be equal to rz3_bufsize unless we reached the end of file
    if (n == 0) return done;
    done += n;
  }

  // at this point, the number of records that can be copied to the caller is < rz3_bufsize.
  // to avoid buffer overflow, we use the interface buffer once again
  while(done < nrec) {
    interface_buffer_size = decompress_buffer(interface_buffer, rz3_bufsize);
    if (interface_buffer_size == 0) return done;

    interface_buffer_count = interface_buffer_size;

    // how many can we copy out?
    int n = interface_buffer_size;
    if (n > (nrec-done)) n = (nrec-done);

    // copy and update (decrement) buffer count
    memcpy(buf+done, interface_buffer+(interface_buffer_size-interface_buffer_count), n*sizeof(rstf_unionT));
    done += n;
    interface_buffer_count -= n;
  }
  // at this point done = nrec.
  return nrec;

} // rstzip3::decompress(rstf_unionT * buf, int nrec)


bool rstzip3::error() {
  return rz3_error;
} // bool rstzip3::error() {



void rstzip3::setverbose() {
  verbose = true;
} // rstzip3::setverbose()


void rstzip3::setstats() {
  stats = true;
} // void rstzip3::setstats() {



void rstzip3::clear()
{
  pred_cpuid = 0;
  last_instr_cpuid = 0;
  rfs_cw_phase = false;
  rfs_bt_phase = false;
  rfs_nrecords = 0;
  rfs_records_seen = 0;
  prev_rtype = 0;
} // void rstzip3::clear()

void rstzip3::clear_stats()
{
  // bzero(perf_stats, ps_MAX * sizeof(int));
  memset(perf_stats, 0, ps_MAX * sizeof(int));
} // void rstzip3::clear_stats()


void rstzip3::print_stats()
{
  int i;
  fprintf(stderr, "\nPerformance statistics for this section:\n");
  for (i=0; i<ps_MAX; i++) {
    fprintf(stderr, "%s \t%d \t%0.4f%%/rec \t%0.4f%%/instr", perf_stats_descr[i].name, perf_stats[i],
	   perf_stats[i]*100.0/perf_stats[ps_nrecords], perf_stats[i]*100.0/perf_stats[ps_instr_count]);

    if (perf_stats_descr[i].rel != ps_MAX) {
      int rel = perf_stats_descr[i].rel;
      fprintf(stderr, " \t%0.4f%%/%s", perf_stats[i]*100.0/perf_stats[rel], perf_stats_descr[rel].name);
    }
    fprintf(stderr, "\n");
  }
} // void rstzip3::print_stats()


void rstzip3::print_stat_totals()
{
  int i;
  fprintf(stderr, "\nOverall performance statistics:\n");
  for (i=0; i<ps_MAX; i++) {
    fprintf(stderr, "total %s \t%lld \t%0.4f%%/rec \t%0.4f%%/instr", perf_stats_descr[i].name, perf_stat_totals[i],
	   perf_stat_totals[i]*100.0/perf_stat_totals[ps_nrecords], perf_stat_totals[i]*100.0/perf_stat_totals[ps_instr_count]);

    if (perf_stats_descr[i].rel != ps_MAX) {
      int rel = perf_stats_descr[i].rel;
      fprintf(stderr, " \t%0.4f%%/%s", perf_stat_totals[i]*100.0/perf_stat_totals[rel], perf_stats_descr[rel].name);
    }
    fprintf(stderr, "\n");
  }
} // void rstzip3::print_stat_totals()



void rstzip3::update_stats()
{
  // update some stats using sdata array counts
  perf_stats[ps_nrecords] = shdr->nrecords;
  perf_stats[ps_instr_count] = shdr->rz3_bitarray_counts[instr_pred_all_array];
  // brpred_refs
  // brpred_misses
  // an_misses
  // ras_refs
  // ras_misses
  // ea_valid_misses
  // ea_lookup_table_misses
  perf_stats[ps_regval_records] = shdr->rz3_bitarray_counts[regval_postInstr_array];
  perf_stats[ps_regval_raw_regtype_count] = shdr->rz3_bitarray_counts[regval_raw_regtype_array];
  perf_stats[ps_regval_raw_regid_count] = shdr->rz3_bitarray_counts[regval_raw_regid_array];
  perf_stats[ps_pavadiff_count] = shdr->rz3_bitarray_counts[pavadiff_ictxt_pred_array];
  perf_stats[ps_pavadiff_ictxt_misses] = shdr->rz3_bitarray_counts[pavadiff_raw_ictxt_array];
  perf_stats[ps_pavadiff_ea_valid_count] = shdr->rz3_bitarray_counts[pavadiff_dctxt_pred_array];
  perf_stats[ps_pavadiff_dctxt_misses] = shdr->rz3_bitarray_counts[pavadiff_raw_dctxt_array];

  int i;
  for (i=0; i<ps_MAX; i++) {
    perf_stat_totals[i] += perf_stats[i];
  }
} // void rstzip3::update_stats()


