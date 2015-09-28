/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rstzip3.h
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
/* rstzip3.h
 * rz3 compressor/decompressor metadata structures
 *
 * Copyright (C) 2003 Sun Microsystems, Inc.
 * All Rights Reserved
 */

#ifndef _rstzip3_h_
#define _rstzip3_h_

#ident "@(#)1.6 06/28/04 SMI rstzip3.h"

#include <sys/types.h>
#include "zlib.h"

#include "rstf/rstf.h"


static const int rstzip3_major_version = 3;
static const int rstzip3_minor_version = 23;
static const char rstzip3_version_str[] = "rstzip v3.23";

static const int rz3_bufsize_default = 32<<10;

// In rstzip3 v3.22 the buffer size was reduced to 32k to reduce
// the memory foot-print of the java trace reader. This constant
// is used for decompressing traces older than rstzip3 v3.22
static const int rz3_bufsize_pre322 = 128 << 10;

/* we use a 16-character magic string to identify an rz3 compressed trace
 * starting with "RZ3 " and ending with a $ and the null-terminator (\0).
 * The remainder (16-4-2) is a 10-digit random integer
 */
#define rz3_hdr_magic "RZ3 5948486328$"

struct rz3_header {
  char magic[16];

  /* *internal* version numbers for rz3. The global rstzip version number is, obviously, 3 */
  uint8_t major_version;
  uint8_t minor_version;

  uint16_t reserved16;
  uint32_t reserved32;
}; // struct rz3_header


static const int rz3_max_ncpus = 1<<10;

static const uint64_t rz3_amask_mask = ((1ull<<32)-1);

class rstzip3 {
 public:
  rstzip3(const char * fname, const char * mode);

  ~rstzip3();

  int getMajorVersion() {
    return rstzip3_major_version;
  }

  int getMinorVersion() {
    return rstzip3_minor_version;
  }

  const char * getVersionStr() {
    return rstzip3_version_str;
  }

  int compress(rstf_unionT * buf, int nrec);

  int decompress(rstf_unionT * buf, int nrec);

  bool error();

  void setverbose();
  void setstats();

  int rz3_bufsize;

private:
  int compress_buffer(rstf_unionT * rstbuf, int rstbufsize);
  void compress_inst(rstf_unionT * rstbuf, int idx);
  void compress_dcti(rstf_unionT * rstbuf, int idx, struct rz3iu_icache_data * icdata);
  void compress_pavadiff(rstf_unionT * rstbuf, int idx);
  void compress_tlb(rstf_unionT * rstbuf, int idx);
  void compress_preg(rstf_unionT * rstbuf, int idx);
  void compress_trap(rstf_unionT * rstbuf, int idx);
  void compress_dma(rstf_unionT * rstbuf, int idx);
  void compress_regval(rstf_unionT * rstbuf, int idx);
  void compress_memval(rstf_unionT * rstbuf, int idx);
  void compress_ea_va(rstf_unionT * rstbuf, int idx);
  void compress_rfs_cw(rstf_unionT * rstbuf, int idx);
  void compress_rfs_bt(rstf_unionT * rstbuf, int idx);

  bool compress_value(int cpuid, uint64_t v64);

  bool regen_value(rstf_regvalT *vr, int idx);

  int decompress_buffer(rstf_unionT * rstbuf, int rstbufsize);
  void decompress_inst(rstf_unionT * rstbuf, int idx);
  void decompress_dcti(rstf_unionT * rstbuf, int idx, struct rz3iu_icache_data * icdata);
  void decompress_pavadiff(rstf_unionT * rstbuf, int idx);
  void decompress_pavadiff_pass2(rstf_unionT * rstbuf, int instr_idx);
  void decompress_tlb(rstf_unionT * rstbuf, int idx);
  void decompress_preg(rstf_unionT * rstbuf, int idx);
  void decompress_trap(rstf_unionT * rstbuf, int idx);
  void decompress_dma(rstf_unionT * rstbuf, int idx);
  void decompress_regval(rstf_unionT * rstbuf, int idx);
  void decompress_memval(rstf_unionT * rstbuf, int idx);
  void decompress_ea_va(rstf_unionT * rstbuf, int idx);
  void decompress_rfs_cw(rstf_unionT * rstbuf, int idx);
  void decompress_rfs_bt(rstf_unionT * rstbuf, int idx);

  bool decompress_value(int cpuid, uint64_t & v64);

  // backward compatibility support
  void decompress_pavadiff_pass2_v315(rstf_unionT * rstbuf, int instr_idx);

 public:
  bool c_nd; // compress, not decompress
  bool verbose;
  bool stats;

  int64_t raw_v64_count;

 private:

  bool rstf_pre212; // input rst trace is older than v2.12 (during compression) - doesn't matter during decompression

  bool pre320; // rstzip version is v3.19 or older (during decompression)

  bool pre323; // rstzip version is v3.22 or older (during decompression)

  bool g0_nonzero_warn;

  struct rz3_header * header;
  struct rz3_section_header * shdr;
  struct rz3_section_data * sdata;

  gzFile gzf;

  bool rz3_error;

  int nsections; // incremented every time a section is completed and written out, or read in and decompressed

  // int n_cpuids;

  // state variables used in prediction (other than per-cpu)
  uint16_t last_instr_cpuid; // cpuid of the prev instr seen. we need this for records corresponding to this cpuid that occur after the instr record (eg regval)
  uint16_t pred_cpuid; // cpuid predicted for the next instr/pavadiff etc
  uint8_t instr_preds; // some prediction bits (pc, instr, tr, pr, bt, an, ea_valid) which are aggregated for each instr
  bool rfs_phase;
  bool rfs_cw_phase;
  bool rfs_bt_phase;
  uint64_t rfs_nrecords;
  uint64_t rfs_records_seen;
  uint8_t prev_rtype;

  // these state variables are cleared in clear()

  struct rz3_percpu_data ** tdata;

  // buffer used to store records in case the number of records requested
  // is not optimal
  rstf_unionT * interface_buffer; // size is rz3_bufsize

  // size of the interface buffer. when compressing, this is rz3_bufsize
  // when decompressing, we get this size from the section header
  int interface_buffer_size;

  int interface_buffer_count;
  // count of records in the buffer waiting to be compressed/copied out
  // we try to keep this buffer empty as far as possible. When empty,
  // we try to compress/decompress directly using the caller's buffer.
  // if not empty or if the caller's buffer is not large enough, we
  // use the interface buffer.

 public:

  // rtypes we compress
  enum rtype_key_e {
    rtype_key_INSTR = 0,
    rtype_key_REGVAL,
    rtype_key_PAVADIFF,
    rtype_key_RAW
  }; // enum rtype_key_e

  enum instr_pred_bits {
    instr_pred_pc = 0x1,
    instr_mispred_pc = 0xfe,
    instr_pred_instr = 0x2,
    instr_mispred_instr = 0xfd,
    instr_pred_bt = 0x4,
    instr_mispred_bt = 0xfb,
    instr_pred_an = 0x8,
    instr_mispred_an = 0xf7,
    instr_pred_tr = 0x10,
    instr_mispred_tr = 0xef,
    instr_pred_pr = 0x20,
    instr_mispred_pr = 0xdf,
    instr_pred_ea_valid = 0x40,
    instr_mispred_ea_valid = 0xbf,
    instr_pred_hpriv = 0x80,
    instr_mispred_hpriv = 0x7f,

    instr_pred_all = 0xff,
    instr_mispred_none = 0xff
  }; // enum instr_pred_bits

  // enumerated type for various compressed bitarray sections
  enum bitarrays_e {

    rtype_key_array=0,
    rtype_array,

    cpuid_pred_array,
    raw_cpuid_array,

    instr_pred_all_array,
    instr_pred_raw_array,

    raw_instr_array,

    dcti_ea_va_pred_array,

    value_iszero_array,

    valuecache_level_array,

    // important: the valuecache data array names MUST be in the following order and must be followed by raw_value64_array
    valuecache_data0_array,
    valuecache_data1_array,
    valuecache_data2_array,
    valuecache_data3_array,
    valuecache_data4_array,
    valuecache_data5_array,
    valuecache_data6_array,

    raw_value64_array, // IMPORTANT: raw_value64_array MUST immediately follow the valuecache data arrays

    regval_postInstr_array,
    regval_regtype_pred_array,
    regval_raw_regtype_array,
    regval_regid_pred_array,
    regval_raw_regid_array,

    memval_fields_array,
    memval_size_array,
    memval_addr36_43_array,
    memval_addr04_35_array,

    pavadiff_ictxt_pred_array,
    pavadiff_raw_ictxt_array,
    pavadiff_pc_pa_va_pred_array,
    pavadiff_ea_valid_array,
    pavadiff_dctxt_pred_array,
    pavadiff_raw_dctxt_array,
    pavadiff_ea_pa_va_pred_array,
    pavadiff_lookahead_array,

    tlb_info_array,

    trap_info_array,

    dma_iswrite_array,
    dma_nbytes_array,

    rfs_rtype_pred_array,
    rfs_pc_pred_array,
    rfs_instr_pred_array,
    rfs_bt_pred_array,
    rfs_cw_raw_reftype_array,
    rfs_raw_cpuid_array,
    rfs_cw_dma_size_array,
    rfs_cw_asi_array,
    rfs_cw_pf_fcn_array,
    rfs_cw_va_valid_array,
    rfs_cw_pa_pred_array,

    bitarray_count
  }; // enum bitarrays_e

  static struct rz3_bitarray_descr bitarray_descr[]; // initialized in rstzip3.C

// performance statistics are reported as per record, per instr and optionally relative to another parameter
  enum perf_stats_e {

    ps_nrecords=0,
    ps_instr_count,

    ps_brpred_refs,
    ps_brpred_misses,

    ps_an_misses,

    ps_ras_refs,
    ps_ras_misses,

    ps_ea_valid_misses,
    ps_ea_va_valuecache_refs,
    ps_ea_va_valuecache_misses,

    ps_regval_records,
    ps_regval_raw_regtype_count,
    ps_regval_raw_regid_count,
    ps_regval_valuecache_refs,
    ps_regval_valuecache_misses,

    ps_pavadiff_count,
    ps_pavadiff_ictxt_misses,
    ps_pavadiff_raw_pc_pa_va,
    ps_pavadiff_ea_valid_count,
    ps_pavadiff_dctxt_misses,
    ps_pavadiff_raw_ea_pa_va,

    ps_MAX

  }; // enum perf_stats_e

  int * perf_stats;
  int64_t * perf_stat_totals;

  static struct rz3_perf_stats_descr perf_stats_descr [];

  void clear(); // clear prediction-related fields - 
  void clear_stats();
  void update_stats();
  void print_stats();
  void print_stat_totals();

  FILE * testfp; // write records to testfp as soon as they are decompressed; so they can be compared with the orig file
}; // struct rz3


/* rz3 compressed data is organized as a series of array dumps (rz3_bitarray and rz3_rst_array)
 * all but one array is a "bitarray" (elements <= 64 bits in size).
 * We allocate a list of bitarrays, and identify each bitarray by a name (enum list)
 * The following structure is used to describe properties of each array
 */
struct rz3_bitarray_descr {
  const char *name;
  int nbits;
  int size_hint;
}; // struct rz3_bitarray_descr


struct rz3_perf_stats_descr {
  const char * name;
  enum rstzip3::perf_stats_e rel; // print stats relative to this parameters. ps_MAX => none
}; // struct rz3_perf_stats_descr


#endif // _rstzip3_h_

