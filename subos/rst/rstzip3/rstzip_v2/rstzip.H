/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rstzip.H
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
// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: rstzip.H
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
#ifndef _RSTZIP_H
#define _RSTZIP_H

// File: rstzip.H
//

#define DBGFP stdout

#include <ctype.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

#include "rz_insttypes.h"
#if 0
#include "spix6plus/IHASH.h"
#include "spix6plus/ITYPES.h"
#include "spix6plus/MISC.h"
#include "spix6plus/reguse.h"
#endif

#include "rstf/rstf.h"
#include "zlib.h"
#include "hash.H"
#include "pstate.H"
#include "VCache.h"


#ifdef COM_DEBUG
    #define comDebug( str ) fprintf( stderr, str )
    #define comDebugP( str, var )   fprintf( stderr, str, var )
#else
    #define comDebug( str )
    #define comDebugP( str, var )
#endif

#ifdef DEC_DEBUG
    #define decDebug( str ) fprintf( stderr, str )
    #define decDebugP( str, var )   fprintf( stderr, str, var )
#else
    #define  decDebug( str )
    #define  decDebugP( str, var )
#endif

#if 0 // removed - 20040210 (vp)
static int ih_ispcrelcti(int ih) {
  return (ih_isbranch(ih) || ih == IH_CALL);
}
#endif

// static int carry_ea(int ih, int ea_valid) { // changed - 20040210 (vp)
static int carry_ea(uint32_t iw, int ea_valid) {
  // return (ea_valid == 1 && ih_ispcrelcti(ih) == 0); // replaced - 20040210 (vp)
  return (ea_valid == 1 && !rz_is_pc_relative_cti(iw));
}


#define MAX(a, b) (((a) > (b)) ? (a) : (b))

enum {
  MAX_CHUNKSIZE     = 1000,
  CHECKSUM_FREQ     = 16,

  INSTR_FOLLOWS     = 0,
  NONINSTR_FOLLOWS  = 1,

  CHUNKSIZE_RES     = 10,

  NEW_RTYPES_START  = 160,
  NEW_RTYPES        = 13,

  RSTZIP_MAX_CONTEXTS = 8192
};

enum {
  z_HEADER_T = NEW_RTYPES_START,
  z_FOOTER_T,

  z_INSTR_T,      // compressed chunk
  zL_INSTR_T,     // compressed loop chunk

  z0_PAVADIFF_T,  // compresed pavadiff at cache index n
  z1_PAVADIFF_T,
  z2_PAVADIFF_T,
  z3_PAVADIFF_T,
  z4_PAVADIFF_T,
  z5_PAVADIFF_T,
  z6_PAVADIFF_T,
  z7_PAVADIFF_T,

  z_CCR_T,           // condition-code register
  z_REGID_T,         // register id
  z_REGVAL_8_T,      // 1-byte register value
  z_REGVAL_16_T,     // 2-byte register value
  z_REGVAL_32_T,     // 4-byte register value
  z_REGVAL_64_T,     // 8-byte register value
  z_REGIDX_T,        // 2-byte register index
  z_VALUE_MINUS1_T,  // These are the literal values -1 to 8
  z_VALUE_0_T,       
  z_VALUE_1_T,       
  z_VALUE_2_T,      
  z_VALUE_3_T,
  z_VALUE_4_T,
  z_VALUE_5_T,
  z_VALUE_6_T,
  z_VALUE_7_T,
  z_VALUE_8_T,
  z_REGPAIR_T,        // indicates that the next two register values should be
                      // merged into a single RST regval record.
  z_LAST_T
};

enum {
  OFFSET_8BITS_IDX          = 0,
  OFFSET_8BITS_RESERVED_IDX = 1,
  OFFSET_16BITS_IDX         = 2,
  OFFSET_32BITS_IDX         = 3,
  OFFSET_64BITS_IDX         = 4,

  RESERVED_OFFSET_8BITS     = -125,  // (0xffffff83)
  RESERVED_OFFSET_16BITS    = -123,  // (0xffffff85)
  RESERVED_OFFSET_32BITS    = 123,   // (0x7b)
  RESERVED_OFFSET_64BITS    = 125,   // (0x7d)

  NUM_RESERVED_OFFSETS      = 4,

  PADDING_SIZE0             = 2,
  FILENAME_STRING_SIZE      = 256,
  DATE_STRING_SIZE          = 32,
  HASH_FUNC_STRING_SIZE     = 64,
  PADDING_SIZE1             = 630
};

enum {
  NOTUSED      = 0x80,
  EA_VALID     = 0x40,
  TR           = 0x20,
  NOTUSED2     = 0x10,
  PR           = 0x08,
  BT           = 0x04,
  AN           = 0x02,
  RSRVD_CMPRSS = 0x01
};

typedef uint8_t flags_t;

class RstzipBase {
public:
  // Options
  bool compress;		// Set to 1 to compress, 0 to decompress
  uint8_t checksum_freq;	// Add checksum every n chunks (default=16)

  // stats
  uint32_t max_chunksize;
  uint64_t total_instr;
  uint64_t total_noninstr;
  uint64_t total_loop_chunk;
  uint64_t total_nonloop_chunk;
  uint64_t total_zpavadiff;
  uint64_t total_pavadiff;
  uint64_t zero_offset_count;
  uint64_t offset_count[OFFSET_64BITS_IDX + 1];
  uint64_t chunksize_count[CHUNKSIZE_RES];

  RstzipHash hash;
  RstzipPavadiffCache pava_cache;

  // Constructor (initialize file footer variables).
  RstzipBase() {
    max_chunksize = 0;
    total_instr = 0;
    total_noninstr = 0;
    total_loop_chunk = 0;
    total_nonloop_chunk = 0;
    total_zpavadiff = 0;
    total_pavadiff = 0;
    zero_offset_count = 0;

    memset(offset_count, 0, (OFFSET_64BITS_IDX + 1) * sizeof(uint64_t));
    memset(chunksize_count, 0, CHUNKSIZE_RES * sizeof(uint64_t));

    print_chunk_chksm = 0;
    print_chunk_chunk_counter = 0;

    compress = -1;
    checksum_freq = CHECKSUM_FREQ;
  }  // RstzipBase::RstzipBase()

protected:
  // header info
  uint8_t rtype;
  uint16_t num_instr;		     // number of instructions in chunk
  uint64_t pc_start;		     // pc of 1st instruction in chunk

  // data buffers
  uint32_t instr_buf[MAX_CHUNKSIZE];         // instruction words in chunk
  uint64_t ea_buf[MAX_CHUNKSIZE];            // ea of ld/st+cti instructions
  flags_t flags_buf[MAX_CHUNKSIZE];          // flags for each instruction
  uint8_t noninstr_count_buf[MAX_CHUNKSIZE]; // counts of non-instr chunks
  int lastRegIdBuf[MAX_CHUNKSIZE];           // the regid observed in an instruction
  rstf_instrT noninstr_buf[MAX_CHUNKSIZE];   // non-instr records in chunk

  // misc info
  int num_ea;			     // number of ld/st+cti instrs in chunk
  int num_noninstr;		     // non-instruction records in chunk
  int num_total;		     // num_instr + num_noninstr
  int num_noninstr_count;	     // size of noninstr_count_buf[]


  // flags support
  flags_t set_flags(flags_t* flags, int mask, int val) {
    flags_t flgs = *flags;

    if (val) {
      flgs = flgs | mask;
    } else {
      flgs = flgs & ~mask;
    }

    *flags = flgs;

    return flgs;
  }  // RstzipBase::set_flags()

  uint64_t compute_checksum64() {
    int i;
    uint64_t chksm;

    chksm = rtype + num_instr + pc_start;

    for (i = 0; i < num_instr; i++) {
      chksm += instr_buf[i] + flags_buf[i];
    }

    for (i = 0; i < num_ea; i++) {
      chksm += ea_buf[i];
    }

    for (i = 0; i < num_noninstr; i++) {
      chksm += noninstr_buf[i].rtype;
    }

    for (i = 0; i < num_noninstr_count; i++) {
      chksm += noninstr_count_buf[i];
    }

    return chksm;
  }  // RstzipBase::compute_checksum64()

  int check_buffersize(int nrecs) {
    if (nrecs < MAX_CHUNKSIZE) {
      return MAX_CHUNKSIZE - nrecs;
    }

    return 0;
  }  // RstzipBase::check_buffersize()

  int get_flags(flags_t flags, int mask) {
    return ((flags & mask) ? 1 : 0);
  }  // RstzipBase::get_flags()

  uint64_t print_chunk_chksm;
  uint64_t print_chunk_chunk_counter;

  void print_chunk(FILE* fp) {
    int i;

    if (rtype != 0) {
      fprintf(fp, "[BOC] rtype=%d\n", rtype);
      fprintf(fp, "num_instr=%d\n", num_instr);
      fprintf(fp, "pc_start=0x%llx\n", pc_start);
      fprintf(fp, "\n");
      fprintf(fp, "num_ea=%d\n", num_ea);
      fprintf(fp, "num_noninstr=%d\n", num_noninstr);
      fprintf(fp, "num_total=%d\n", num_total);
      fprintf(fp, "num_noninstr_count=%d\n", num_noninstr_count);
      fprintf(fp, "\n");

      for (i = 0; i < num_instr; i++) {
	fprintf(fp, "(%x)\n", instr_buf[i]);
      }
      fprintf(fp, "\n");

      for (i = 0; i < num_instr; i++) {
	fprintf(fp, "(%02x)\n", flags_buf[i]);
      }
      fprintf(fp, "\n");

      for (i = 0; i < num_ea; i++) {
	fprintf(fp, "(0x%llx)\n", ea_buf[i]);
      }
      fprintf(fp, "\n");

      for (i = 0; i < num_noninstr_count; i++) {
	fprintf(fp, "%d ", noninstr_count_buf[i]);
      }
      fprintf(fp, "\n\n");

      for (i = 0; i < num_noninstr; i++) {
	print_rstrec(fp, &noninstr_buf[i]);
      }
      fprintf(fp, "\n");

      if (checksum_freq != 0) {
	print_chunk_chksm += compute_checksum64();
	print_chunk_chunk_counter++;

	if (print_chunk_chunk_counter % checksum_freq == 0) {
	  fprintf(fp, "checksum=%016llx\n", print_chunk_chksm);
	  print_chunk_chksm = 0;
	}
      }

      fprintf(fp, "[EOC] max_chunksize=%d\n", max_chunksize);
    }
  }  // RstzipBase::print_chunk()

  void print_rstbuf(FILE* fp, rstf_instrT buf[], int num) {
    int i;

    for (i = 0; i < num; i++) {
      print_rstrec(fp, &buf[i]);
    }
    fprintf(fp, "\n");
  }  // RstzipBase::print_rstbuf()

  void print_rstrec(FILE* fp, rstf_instrT* rst) {
    switch (rst->rtype) {
    case RSTHEADER_T:
      fprintf(fp, "rstheader\n");
      break;
    case INSTR_T:
      fprintf(fp, "[0x%llx] ", rst->pc_va);
      // fprintDiss(fp, rst->instr, rst->pc_va);
      fprintf(fp, "\n");
      break;
#if 0
    case ASI_T:
      fprintf(fp, "asi\n");
      break;
#endif
    case MEMVAL_T:
      fprintf( fp, "memval\n" );
      break;
    case TLB_T:
      fprintf(fp, "tlb\n");
      break;
    case THREAD_T:
      fprintf(fp, "thread\n");
      break;
    case TRAP_T:
      fprintf(fp, "trap\n");
      break;
    case TRAPEXIT_T:
      fprintf(fp, "trapexit\n");
      break;
    case REGVAL_T:
      fprintf(fp, "regval\n");
      break;
    case TIMESTAMP_T:
      fprintf(fp, "timestamp\n");
      break;
    case PROCESS_T:
      fprintf(fp, "process\n");
      break;
    case DMA_T:
      fprintf(fp, "dma\n");
      break;
    case STRDESC_T:
      fprintf(fp, "strdesc\n");
      break;
    case LEFTDELIM_T:
      fprintf(fp, "leftdelim\n");
      break;
    case RIGHTDELIM_T:
      fprintf(fp, "rightdelim\n");
      break;
    case PREG_T:
      fprintf(fp, "preg\n");
      break;
    case PHYSADDR_T:
      fprintf(fp, "physaddr\n");
      break;
    case PAVADIFF_T:
#if 0
      fprintf(fp, "pavadiff\n");
#else
      rstf_pavadiffT rst_pava;

      memcpy(&rst_pava, rst, sizeof(rstf_unionT));
      fprintf(fp, "pavadiff: icontext=%d dcontext=%d pc_pa_va=0x%016llx ea_pa_va=0x%016llx\n",
	      rst_pava.icontext, rst_pava.dcontext, rst_pava.pc_pa_va, rst_pava.ea_pa_va);
#endif
      break;
    case NULLREC_T:
      fprintf(fp, "nullrec\n");
      break;
    case STRCONT_T:
      fprintf(fp, "strcont\n");
      break;
    case FILEMARKER_T:
      fprintf(fp, "filemarker\n");
      break;
    case PATCH_T:
      fprintf(fp, "patch\n");
      break;
    case STATUS_T:
      fprintf(fp, "status\n");
      break;
#if 0
    case SNOOP_T:
      fprintf(fp, "snoop\n");
      break;
#endif
    case z_HEADER_T:
      fprintf(fp, "file header\n");
      break;
    case z_FOOTER_T:
      fprintf(fp, "file footer\n");
      break;
    case z_INSTR_T:
      fprintf(fp, "compressed header\n");
      break;
    case zL_INSTR_T:
      fprintf(fp, "compressed loop header\n");
      break;
    case z0_PAVADIFF_T:
      fprintf(fp, "compressed pavadiff [0]\n");
      break;
    case z1_PAVADIFF_T:
      fprintf(fp, "compressed pavadiff [1]\n");
      break;
    case z2_PAVADIFF_T:
      fprintf(fp, "compressed pavadiff [2]\n");
      break;
    case z3_PAVADIFF_T:
      fprintf(fp, "compressed pavadiff [3]\n");
      break;
    case z4_PAVADIFF_T:
      fprintf(fp, "compressed pavadiff [4]\n");
      break;
    case z5_PAVADIFF_T:
      fprintf(fp, "compressed pavadiff [5]\n");
      break;
    case z6_PAVADIFF_T:
      fprintf(fp, "compressed pavadiff [6]\n");
      break;
    case z7_PAVADIFF_T:
      fprintf(fp, "compressed pavadiff [7]\n");
      break;
    case z_CCR_T:
      fprintf(fp, "Condition Code Register\n" );
      break;
    case z_REGID_T:
      fprintf(fp, "Integer Register Id\n" );
      break;
    case z_REGVAL_8_T:
      fprintf(fp, "1-byte register value\n" );
      break;
    case z_REGVAL_16_T:
      fprintf(fp, "2-byte register value\n" );
      break;
    case z_REGVAL_32_T:
      fprintf(fp, "4-byte register value\n" );
      break;
    case z_REGVAL_64_T:
      fprintf(fp, "8-byte register value\n" );
      break;
    case z_REGIDX_T:
      fprintf(fp, "register value cache index\n" );
      break;
    case z_VALUE_MINUS1_T:
      fprintf(fp, "integer value -1\n" );
      break;
    case z_VALUE_0_T:
      fprintf(fp, "integer value 0\n" );
      break;
    case z_VALUE_1_T:
      fprintf(fp, "integer value 1\n" );
      break;
    case z_VALUE_2_T:
      fprintf(fp, "integer value 2\n" );
      break;
    case z_VALUE_3_T:
      fprintf(fp, "integer value 3\n" );
      break;
    case z_VALUE_4_T:
      fprintf(fp, "integer value 4\n" );
      break;
    case z_VALUE_5_T:
      fprintf(fp, "integer value 5\n" );
      break;
    case z_VALUE_6_T:
      fprintf(fp, "integer value 6\n" );
      break;
    case z_VALUE_7_T:
      fprintf(fp, "integer value 7\n" );
      break;
    case z_VALUE_8_T:
      fprintf(fp, "integer value 8\n" );
      break;
    case z_REGPAIR_T:
      fprintf(fp, "register pair marker\n" );
      break;

    default:
      int i, j, range = 1;
      uint8_t* c_ptr = (uint8_t*) (rst - range);

      for (i = range; i > 0; i--) {
	for (j = 0; j < sizeof(rstf_instrT); j++) {
	  fprintf(fp, "%02x", *c_ptr);
	  c_ptr++;
	}
	fprintf(fp, " -> -%d\n", i);
      }

      for (j = 0; j < sizeof(rstf_instrT); j++) {
	fprintf(fp, "%02x", *c_ptr);
	c_ptr++;
      }
      fprintf(fp, " -> Unknown rtype (%02x)\n", rst->rtype);

      for (i = 1; i <= range; i++) {
	for (j = 0; j < sizeof(rstf_instrT); j++) {
	  fprintf(fp, "%02x", *c_ptr);
	  c_ptr++;
	}
	fprintf(fp, " -> +%d\n", i);
      }

      exit(2);
    }

    fflush(fp);
  }  // RstzipBase::print_rstrec()

  bool isIntRegCompressable( const rstf_regvalT *r )
  {
      return r->regtype[0] == RSTREG_INT_RT &&
	  ( r->regtype[1] == RSTREG_UNUSED_RT || r->regtype[1] == RSTREG_CC_RT || r->regtype[1] == RSTREG_INT_RT );
  }


  bool compressedRegType( int rt )
  {
    
      switch( rt ){
	  case z_CCR_T:
	  case z_REGID_T:
	  case z_REGVAL_8_T:
	  case z_REGVAL_16_T:
	  case z_REGVAL_32_T:
	  case z_REGVAL_64_T:
	  case z_REGIDX_T:
	  case z_VALUE_0_T:
	  case z_VALUE_1_T:
	  case z_VALUE_2_T:
	  case z_VALUE_3_T:
	  case z_VALUE_4_T:
	  case z_VALUE_5_T:
	  case z_VALUE_6_T:
	  case z_VALUE_7_T:
	  case z_VALUE_8_T:
	  case z_VALUE_MINUS1_T:
	  case z_REGPAIR_T:
	      return true;
	  default:
	      return false;
      }
  }


}; // RstzipBase

// RST decompression class.
class Rstunzip : public RstzipBase {
public:
  Rstunzip() {
    inbuf = NULL;
    inbuf_ptr = NULL;
    outbuf= NULL;
    outbuf_ptr= NULL;

    rstz_decompress_unzipped_recs = 0;
    rstz_decompress_fbytes = 0;
    //rstz_decompress_prev_nrecs = 0;
    unzip_chunk_chksm_sum = 0;
    unzip_chunk_chunk_counter = 0;
    memset(&read_noninstr_rec_rst, 0, sizeof(rstf_unionT));

    icontext = 0;
#ifdef DEC_DEBUG
    iCtr = 1;
#endif
    lastRd = -1;
  }

  ~Rstunzip() {
    //free(inbuf);
    free(outbuf);
  }

  int rstz_decompress_unzipped_recs;  // new recs unzipped in next chunk in outbuf
  int rstz_decompress_fbytes;	      // number of bytes of compressed data fread() 
  // Decompress up to nrecs RST records from *infp into buf[].
  // Returns number of records decompressed.  Upon return, *infp will
  // point to the start of the next compressed record.
  int rstz_decompress(uint8_t** zbufptr, rstf_unionT* rstbuf, int nrecs) {
    int total_recs = 0;	       // total recs copied to buf[]
    rstf_instrT* buf_ptr = &rstbuf[0].instr;

#if 0
    if (nrecs == 0) {
      return 0;
    }
#endif

    inbuf = *zbufptr;
    outbuf = &rstbuf[0].instr;
    inbuf_ptr = inbuf;
    outbuf_ptr = outbuf;
    rstz_decompress_fbytes = 0;
    rstz_decompress_unzipped_recs = 0;

    total_recs = 0;

    // Unzip chunks from inbuf[] until buf[] cannot take another chunk.
    while (total_recs < nrecs) {
      rstz_decompress_unzipped_recs = unzip_chunk();

      if (num_instr > 0) {
	max_chunksize = MAX(max_chunksize, rstz_decompress_unzipped_recs);
#if _DEBUG0
	print_chunk(DBGFP);
	fprintf(DBGFP, "zrecs_o()=%d total_recs=%d nrecs=%d\n\n", zrecs_o(), total_recs, nrecs);
#endif
      }

      total_recs += rstz_decompress_unzipped_recs;
      total_instr += num_instr;
      total_noninstr += rstz_decompress_unzipped_recs - num_instr;

      if (*inbuf_ptr == z_FOOTER_T) {
	break;
      }
    }

    *zbufptr = inbuf_ptr + 1;

    return total_recs;
  }  // Rstunzip::rstz_decompress()

protected:

  // rd-compression member data:
  VCache valueCache;  
  int lastRd;
#ifdef DEC_DEBUG
  int iCtr;
#endif
  ///////////////////////////////

  uint8_t* inbuf;	       // input buffer for (de)compressed traces
  uint8_t* inbuf_ptr;	       // always points to current inbuf location
  rstf_instrT* outbuf;         // output buffer for (de)compressed traces
  rstf_instrT* outbuf_ptr;     // always points to current outbuf location

  Pstate pstate;
  int icontext;

  uint64_t unzip_chunk_chksm_sum;
  uint64_t unzip_chunk_chunk_counter;
  // Decompress one chunk from inbuf[] into outbuf[].  Return the
  // number of records decompressed.
  int unzip_chunk() {
    int prerecs, hashval, set;
    uint64_t chksm;
    hash_table_t* table;

    // init some data members
    rtype = 0;
    pc_start = 0;
    num_instr = 0;
    num_ea = 0;
    num_noninstr = 0;
    num_total = 0;
    num_noninstr_count = 0;

    memset(noninstr_count_buf, 0, MAX_CHUNKSIZE * sizeof(uint8_t));

    prerecs = 0;

    // find next compressed chunk rtype
    while ((*inbuf_ptr < z_FOOTER_T || *inbuf_ptr > zL_INSTR_T) && prerecs < MAX_CHUNKSIZE) {
      //print_rstrec(DBGFP, (rstf_instrT*) inbuf_ptr);

      if (*inbuf_ptr == PREG_T) {
	rstf_pregT preg;

	memcpy(&preg, inbuf_ptr, sizeof(rstf_pregT));
	//pstate[preg.primD].pstate = preg.pstate;
	pstate.pstate = preg.pstate;
      } else if (*inbuf_ptr == PAVADIFF_T) {
	rstf_pavadiffT pavadiff;

	memcpy(&pavadiff, inbuf_ptr, sizeof(rstf_pavadiffT));
	icontext = pavadiff.icontext;
      }

      write_rst2outbuf(read_noninstr_rec(), 1);
      prerecs++;
    }

    // If there were any non-instruction records before the chunk,
    // just return so the next time unzip_chunk() is called it will
    // start pointing at an instruction record.  This is necessary in
    // case prerecs + num_instr + num_noninstr > nrecs.
    if (prerecs == 0 && *inbuf_ptr != z_FOOTER_T) {
      // inbuf_ptr now points to a compressed chunk rtype
      read_inbuf(&rtype, sizeof(rtype));
      read_inbuf(&num_instr, sizeof(num_instr));
      read_inbuf(&pc_start, sizeof(pc_start));
	
#ifdef DEC_DEBUG
      static int chunkNumber = 0;
      fprintf(stderr, "Chunk #%d\n", chunkNumber++ );
      fprintf(stderr, "    decoding %u instructions starting at pc 0x%llx\n", num_instr, pc_start );
      for( int i = 0; i < num_instr; ++i ){
	  fprintf( stderr, "      %d) instr\n", iCtr++ );
      }
#endif

      hashval = hash.hash(pc_start);

      if (rtype <= z_INSTR_T) {	   // non-loop rtype
	read_inbuf(instr_buf, num_instr * sizeof(uint32_t));
	read_inbuf(flags_buf, num_instr * sizeof(flags_t));
	find_num_ea();
	read_ea(NULL);

	hash.write(pc_start, num_instr, instr_buf, num_ea, ea_buf, hashval);
	total_nonloop_chunk++;
      } else {			   // loop rtype
	set = hash.search(pc_start, num_instr, NULL, hashval);
	if (set == NOT_FOUND) {
	  hash.print_set(hashval);

	  fprintf(stderr, "Error: hash.search() returned NOT_FOUND "
		  "for zL64_INSTR_T, pc=0x%llx num_instr=%d\n",
		  pc_start, num_instr);
	  exit(2);
	}

	table = hash.read(set, hashval);
	memcpy(instr_buf, table->instr_buf, num_instr * sizeof(uint32_t));

	read_inbuf(flags_buf, num_instr * sizeof(flags_t));
	find_num_ea();
	read_ea(table);

	hash.update(num_ea, ea_buf, hashval, set);
	total_loop_chunk++;
      }

      find_num_noninstr_count();
      read_inbuf(noninstr_count_buf, num_noninstr_count * sizeof(uint8_t));
      find_num_noninstr();
#ifdef DEC_DEBUG
      fprintf( stderr, "    nr. non-instructions: %d\n", num_noninstr );
#endif
      read_noninstr_recs();

      if (checksum_freq != 0) {
	unzip_chunk_chksm_sum += compute_checksum64();
	unzip_chunk_chunk_counter++;

	if (unzip_chunk_chunk_counter % checksum_freq == 0) {
	  read_inbuf(&chksm, 8);
	  if (chksm != unzip_chunk_chksm_sum) {
	    //hash.print_set(hashval);
	    //print_chunk(stderr);

	    fprintf(stderr,
		    "\nError: checksum inequality (0x%llx != 0x%llx) after record %llu\n",
		    chksm, unzip_chunk_chksm_sum, total_instr + total_noninstr);
	    exit(3);
	  }
	  unzip_chunk_chksm_sum = 0;
	}
      }

      if (num_instr > 0) {
	if (num_instr + num_noninstr < MAX_CHUNKSIZE) {
	  chunksize_count[(num_instr + num_noninstr) / (MAX_CHUNKSIZE / CHUNKSIZE_RES)]++;
	} else {
	  chunksize_count[CHUNKSIZE_RES - 1]++;
	}
      }

      write_chunk();
    }

    return num_instr + num_noninstr + prerecs;
  }  // Rstunzip::unzip_chunk()

  // Build the RST's from instr_buf[], ea_buf[], flags_buf[], etc.,
  // and writes the records in the chunk to *outbuf.  Returns the
  // number of records written.
  int write_chunk() {
    int i, j, ea_cnt, noninstr_cnt, noninstr_buf_cnt;
    bool write_noninstr;
    rstf_instrT rst;

    ea_cnt = 0;
    noninstr_cnt = 0;
    noninstr_buf_cnt = 0;

    for (i = 0; i < num_instr; i++) {
      write_noninstr = false;

      rst.rtype = INSTR_T;

      // rst.notused = get_flags(flags_buf[i], NOTUSED);
      rst.notused = 0;
      get_flags(flags_buf[i], NOTUSED);

      rst.ea_valid = get_flags(flags_buf[i], EA_VALID);
      rst.tr = get_flags(flags_buf[i], TR);

      // rst.notused2 = get_flags(flags_buf[i], NOTUSED2);
      get_flags(flags_buf[i], NOTUSED2);
      rst.hpriv = 0;

      rst.pr = get_flags(flags_buf[i], PR);
      rst.bt = get_flags(flags_buf[i], BT);
      rst.an = get_flags(flags_buf[i], AN);

      rst.reservedCompress = 0; // this field might go away in the future
      int reservedCompress = get_flags(flags_buf[i], RSRVD_CMPRSS);
      // get_flags(flags_buf[i], RSRVD_CMPRSS);

      // rst.ihash = getIHash(instr_buf[i]); // removed - 20040210 (vp)
      rst.cpuid9_6 = 0;
      rst.notused3 = 0;

      rst.instr = instr_buf[i];
      rst.pc_va = pc_start + 4*i;

      // if (carry_ea(rst.ihash, rst.ea_valid)) { // replaced - 20040210 (vp)
      if (carry_ea(rst.instr, rst.ea_valid)) {
	rst.ea_va = ea_buf[ea_cnt];
	ea_cnt++;
      } else if (rst.an == 0 && rz_is_pc_relative_cti(instr_buf[i])) {
	// } else if (rst.an == 0 && ih_ispcrelcti(rst.ihash)) {
	if (rst.bt == 1) {
	  // rst.ea_va = getCtiEa(rst.instr, rst.ihash, rst.pc_va); // replaced 20040210 (vp)
	  if (rz_is_bpr(rst.instr)) {
	    rst.ea_va = rst.pc_va+BPR_DISP(rst.instr);
	  } else if (rz_is_bicc(rst.instr)||rz_is_fbfcc(rst.instr)) {
	    rst.ea_va = rst.pc_va+Bicc_DISP(rst.instr);
	  } else if (rz_is_bpcc(rst.instr)||rz_is_fbpfcc(rst.instr)) {
	    rst.ea_va = rst.pc_va+BPcc_DISP(rst.instr);
	  } else if (rz_is_call(rst.instr)) {
	    rst.ea_va = rst.pc_va+CALL_DISP(rst.instr);
	  } else {
	    fprintf(stderr, "Unknown branch type (rst.bt==1, instr word=%08x)\n", rst.instr);
	  }

	  if (pstate.getField(PSTATE_AM) == 1) {
	    rst.ea_va &= 0xffffffff;
	  }
	} else {
	  rst.ea_va = rst.pc_va + 8;
	}
      } else {
	rst.ea_va = 0;
      }

    
      // these need to be set (not just computed below) because these values 
      // are used in read_noninstr_rec() for register records that are not part 
      // of a chunk of instructions.
      lastRd = rst.instr >> 25 & 0x01F; 

      // write some non-instruction recs?
      if (reservedCompress == NONINSTR_FOLLOWS) {
	write_noninstr = true;
	// rst.reservedCompress = 0;
      }

      write_rst2outbuf(&rst, 1);

      if (write_noninstr) {
	for (j = 0; j < noninstr_count_buf[noninstr_cnt]; j++) {

	  if (noninstr_buf[noninstr_buf_cnt].rtype == PREG_T) {
	    rstf_pregT* context = (rstf_pregT*) &noninstr_buf[noninstr_buf_cnt];
	    //pstate[context->primD].pstate = context->pstate;
	    pstate.pstate = context->pstate;
	  } else if (noninstr_buf[noninstr_buf_cnt].rtype == PAVADIFF_T) {
	    rstf_pavadiffT* pavadiff = (rstf_pavadiffT*) &noninstr_buf[noninstr_buf_cnt];
	    icontext = pavadiff->icontext;
	  } else if ( noninstr_buf[noninstr_buf_cnt].rtype == REGVAL_T ) {
	      // DECOMPRESS: setting proper register id
	      rstf_regvalT *rv = (rstf_regvalT*) &noninstr_buf[noninstr_buf_cnt];

	      // not the best solution, but these values don't make it into the trace
	      // so we're free to adopt a better solution later.  SH
	      if ( rv->regid[0] == 255 ){
		decDebugP( "[write_chunk()] Setting regid[0] to %u\n", lastRd );
		rv->regid[0] = lastRd;
	      } 
	      if ( rv->regid[1] == 255 ){
		decDebugP( "[write_chunk()] Setting regid[1] to %u\n", lastRd );
		rv->regid[1] = lastRd;
	      } 

	  } 
	  write_rst2outbuf(&noninstr_buf[noninstr_buf_cnt], 1);
	  noninstr_buf_cnt++;
	}

	noninstr_cnt++;
      }
    }

    return num_instr + num_noninstr;
  }  // Rstunzip::write_chunk()

  // Read instr_buf[] to count number of (valid) ld/st instructions.
  int find_num_ea() {
    int i, ih;

    num_ea = 0;

    for (i = 0; i < num_instr; i++) {
      // ih = getIHash(instr_buf[i]); // removed - 20040210 (vp)

      // if (carry_ea(ih, get_flags(flags_buf[i], EA_VALID))) { // (replaced - 20040212 (vp)
      if (carry_ea(instr_buf[i], get_flags(flags_buf[i], EA_VALID))) {
        num_ea++;
      }
    }

    return num_ea;
  }  // Rstunzip::find_num_ea()

  // Read flags_buf[] to count RSRVD_CMPRSS=1 fields .
  int find_num_noninstr_count() {
    int i;

    num_noninstr_count = 0;

    for (i = 0; i < num_instr; i++) {
      if (get_flags(flags_buf[i], RSRVD_CMPRSS) == NONINSTR_FOLLOWS) {
        num_noninstr_count++;
      }
    }

    return num_noninstr;
  }  // Rstunzip::find_num_noninstr_count()

  // Sum noninstr_count_buf[].
  int find_num_noninstr() {
    int i;

    num_noninstr = 0;

    if (num_noninstr_count != 0) {
      num_noninstr = noninstr_count_buf[0];
    }

    for (i = 1; i < num_noninstr_count; i++) {
      num_noninstr += noninstr_count_buf[i];
    }

    return num_noninstr;
  }  // Rstunzip::find_num_instr()

  // Read n bytes from *inbuf_ptr into *to, and advance *inbuf_ptr.
  // Return the number of bytes read.
  int read_inbuf(void* to, size_t n) {
    memcpy(to, inbuf_ptr, n);
    inbuf_ptr += n;

    return n;
  }  // Rstunzip::read_inbuf()

  // Write n RST records from from into outbuf_ptr, and advance
  // outbuf_ptr.  Return the number of records written.
  int write_rst2outbuf(rstf_instrT* from, size_t n) {
    memcpy(outbuf_ptr, from, n * sizeof(rstf_instrT));
    outbuf_ptr += n;

    return n;
  }  // Rstunzip::write_rst2outbuf()

  int read_ea(hash_table_t* table) {
    int8_t offset8;
    int16_t offset16;
    int32_t offset32;
    int64_t offset64;
    int i, n;

    n = 0;

    if (num_ea > 0) {
      if (rtype == z_INSTR_T) {
	n = read_inbuf(ea_buf, num_ea * sizeof(uint64_t));
      } else {
	for (i = 0; i < num_ea; i++) {
	  n += read_inbuf(&offset8, sizeof(offset8));

	  switch (offset8) {
	  case RESERVED_OFFSET_8BITS:
	    n += read_inbuf(&offset8, sizeof(offset8));
	    ea_buf[i] = table->ea_buf[i] + offset8;

	    offset_count[OFFSET_8BITS_RESERVED_IDX]++;
#ifdef _DEBUG0
	    fprintf(DBGFP, "(Reserved 8) offset8=0x%02hx ", offset8);
	    fprintf(DBGFP,
		    "base=0x%llx offset8=0x%02hx ea=0x%llx\n",
		    table->ea_buf[i], offset8, ea_buf[i]);
#endif
	    break;
	  case RESERVED_OFFSET_16BITS:
	    n += read_inbuf(&offset16, sizeof(offset16));
	    ea_buf[i] = table->ea_buf[i] + offset16;

	    offset_count[OFFSET_16BITS_IDX]++;
#ifdef _DEBUG0
	    fprintf(DBGFP, "(Reserved 16) offset8=0x%02hx ", offset8);
	    fprintf(DBGFP,
		    "base=0x%llx offset16=0x%04hx ea=0x%llx\n",
		    table->ea_buf[i], offset16, ea_buf[i]);
#endif
	    break;
	  case RESERVED_OFFSET_32BITS:
	    n += read_inbuf(&offset32, sizeof(offset32));
	    ea_buf[i] = table->ea_buf[i] + offset32;

	    offset_count[OFFSET_32BITS_IDX]++;
#ifdef _DEBUG0
	    fprintf(DBGFP, "(Reserved 32) offset8=0x%02hx ", offset8);
	    fprintf(DBGFP,
		    "base=0x%llx offset32=0x%08x ea=0x%llx\n",
		    table->ea_buf[i], offset32, ea_buf[i]);
#endif
	    break;
	  case RESERVED_OFFSET_64BITS:
	    n += read_inbuf(&offset64, sizeof(offset64));
	    ea_buf[i] = table->ea_buf[i] + offset64;

	    offset_count[OFFSET_64BITS_IDX]++;
#ifdef _DEBUG0
	    fprintf(DBGFP, "(Reserved 64) offset8=0x%02hx ", offset8);
	    fprintf(DBGFP,
		    "base=0x%llx offset64=0x%016llx ea=0x%llx\n",
		    table->ea_buf[i], offset64, ea_buf[i]);
#endif
	    break;
	  default:
	    ea_buf[i] = table->ea_buf[i] + offset8;

	    if (offset8 == 0) {
	      zero_offset_count++;
	    }

	    offset_count[OFFSET_8BITS_IDX]++;
#ifdef _DEBUG0
	    fprintf(DBGFP,
		    "base=0x%llx offset8=0x%02hx ea=0x%llx\n",
		    table->ea_buf[i], offset8, ea_buf[i]);
#endif
	  }
	}
      }
    }

    return n;
  }  // Rstunzip::read_ea()

  rstf_unionT read_noninstr_rec_rst;

  rstf_instrT* read_noninstr_rec() {
    uint8_t ccValue;
    bool setCC = false; 
    read_noninstr_rec_rst.proto.rtype = *inbuf_ptr;

    decDebugP( "      %d) ", iCtr++ );

    if (read_noninstr_rec_rst.proto.rtype >= z0_PAVADIFF_T &&
	read_noninstr_rec_rst.proto.rtype <= z7_PAVADIFF_T) {

      decDebug( "decoded a z*_PAVADIFF_T\n" );

      switch (read_noninstr_rec_rst.proto.rtype) {
      case z0_PAVADIFF_T:
	memcpy(&read_noninstr_rec_rst, pava_cache.read(0),
	       sizeof(rstf_pavadiffT));
	pava_cache.update(0);
	break;
      case z1_PAVADIFF_T:
	memcpy(&read_noninstr_rec_rst, pava_cache.read(1),
	       sizeof(rstf_pavadiffT));
	pava_cache.update(1);
	break;
      case z2_PAVADIFF_T:
	memcpy(&read_noninstr_rec_rst, pava_cache.read(2),
	       sizeof(rstf_pavadiffT));
	pava_cache.update(2);
	break;
      case z3_PAVADIFF_T:
	memcpy(&read_noninstr_rec_rst, pava_cache.read(3),
	       sizeof(rstf_pavadiffT));
	pava_cache.update(3);
	break;
      case z4_PAVADIFF_T:
	memcpy(&read_noninstr_rec_rst, pava_cache.read(4),
	       sizeof(rstf_pavadiffT));
	pava_cache.update(4);
	break;
      case z5_PAVADIFF_T:
	memcpy(&read_noninstr_rec_rst, pava_cache.read(5),
	       sizeof(rstf_pavadiffT));
	pava_cache.update(5);
	break;
      case z6_PAVADIFF_T:
	memcpy(&read_noninstr_rec_rst, pava_cache.read(6),
	       sizeof(rstf_pavadiffT));
	pava_cache.update(6);
	break;
      case z7_PAVADIFF_T:
	memcpy(&read_noninstr_rec_rst, pava_cache.read(7),
	       sizeof(rstf_pavadiffT));
	pava_cache.update(7);
	break;
      default:
	fprintf(stderr, "Error: pava_cache.search() returned NOT_FOUND "
		"in read_noninstr_rec()\n");
	exit(2);
      }

      total_pavadiff++;
      total_zpavadiff++;
      inbuf_ptr++;


    } else if ( compressedRegType( read_noninstr_rec_rst.proto.rtype ) ) {
	// DECOMPRESS
	if( read_noninstr_rec_rst.proto.rtype == z_REGPAIR_T ){
	    decDebug( "*** z_REGPAIR_T ***" );
	    ++inbuf_ptr;
	    decompressReg( *inbuf_ptr, 0 );
	    decompressReg( *inbuf_ptr, 1 );
	} else {
	    decompressReg( read_noninstr_rec_rst.proto.rtype, 0 );
	}

    } else {
	  memcpy(&read_noninstr_rec_rst, inbuf_ptr, sizeof(rstf_pavadiffT));

	  if (read_noninstr_rec_rst.proto.rtype == PAVADIFF_T) {
	    total_pavadiff++;
	    pava_cache.write(&read_noninstr_rec_rst.pavadiff);
	  } 

#ifdef DEC_DEBUG
	  print_rstrec( stderr, &read_noninstr_rec_rst.instr );
#endif

	  inbuf_ptr += sizeof(rstf_pavadiffT);
    }

    return &read_noninstr_rec_rst.instr;
  }  // Rstunzip::read_noninstr_rec()



  void decompressReg( uint8_t curr_rt, int idx )
  {
    int regid = -1;
    int rt = curr_rt;
    
    decDebug( "       " );
    if ( rt == z_REGID_T ) {
	regid = *++inbuf_ptr;
	decDebugP( "z_REGID_T id = %u\n", regid );
	decDebug( "       " );
	++inbuf_ptr;
    }

    rt = *inbuf_ptr++;
    VCache::IdxT vcIdx;
    uint64_t value = 0;

    switch( rt ){
	case z_REGVAL_64_T:                                                                                                               
	    memcpy( &value, inbuf_ptr, sizeof( uint64_t) );
	    inbuf_ptr += sizeof( uint64_t ); 
	    vcIdx = valueCache.insert( value );
	    decDebugP( "z_REGVAL_64_T value=%llu, ", value );
	    decDebugP( "indexed to %u\n", vcIdx );
	    break;
	case z_REGVAL_32_T:                                                                                                               
	    {
		uint32_t val32 = 0;
		memcpy( &val32, inbuf_ptr, sizeof( uint32_t ) );
		inbuf_ptr += sizeof( uint32_t );
		vcIdx = valueCache.insert( val32 );
		value = val32;
		decDebugP( "z_REGVAL_32_T value=%u, ", val32 );
		decDebugP( "indexed to %u\n", vcIdx );
	    }
	    break;
	case z_REGVAL_16_T:                                                                                                               
	    {
		uint16_t val16 = 0;
		memcpy( &val16, inbuf_ptr, sizeof( uint16_t ) );
		inbuf_ptr += sizeof( uint16_t );
		value = val16;
		decDebugP( "z_REGVAL_16_T value=%llu\n", val16 );
	    }
	    break;
	case z_REGVAL_8_T:                                                                                                               
	    {
		uint8_t val8 = 0;
		memcpy( &val8, inbuf_ptr, sizeof( uint8_t ) );
		inbuf_ptr += sizeof( uint8_t );
		value = val8;
		decDebugP( "z_REGVAL_8_T value=%llu\n", val8 );
	    }
	    break;
	case z_VALUE_MINUS1_T:                                                                                                         
	    value = ~( 0x0ULL );
	    decDebugP( "z_VALUE_MINUS1_T [%u]\n", z_VALUE_MINUS1_T );
	    break;
	case z_VALUE_0_T:                                                                                                         
	    value = 0;
	    decDebugP( "z_VALUE_0_T [%u]\n", z_VALUE_0_T );
	    break;
	case z_VALUE_1_T:                                                                                                                 
	    value = 1;
	    decDebugP( "z_VALUE_1_T [%u]\n", z_VALUE_1_T );
	    break;
	case z_VALUE_2_T:                                                                                                                 
	    value = 2;
	    decDebugP( "z_VALUE_2_T [%u]\n", z_VALUE_2_T );
	    break;
	case z_VALUE_3_T:                                                                                                                 
	    value = 3;
	    decDebugP( "z_VALUE_3_T [%u]\n", z_VALUE_3_T );
	    break;
	case z_VALUE_4_T:                                                                                                                 
	    value = 4;
	    decDebugP( "z_VALUE_4_T [%u]\n", z_VALUE_4_T );
	    break;
	case z_VALUE_5_T:                                                                                                                 
	    value = 5;
	    decDebugP( "z_VALUE_5_T [%u]\n", z_VALUE_5_T );
	    break;
	case z_VALUE_6_T:                                                                                                                 
	    value = 6;
	    decDebugP( "z_VALUE_6_T [%u]\n", z_VALUE_6_T );
	    break;
	case z_VALUE_7_T:                                                                                                                 
	    value = 7;
	    decDebugP( "z_VALUE_7_T [%u]\n", z_VALUE_7_T );
	    break;
	case z_VALUE_8_T:                                                                                                                 
	    value = 8;
	    decDebugP( "z_VALUE_8_T [%u]\n", z_VALUE_8_T );
	    break;
	case z_REGIDX_T:                                                                                                                  
	    memcpy( &vcIdx, inbuf_ptr, sizeof( VCache::IdxT ) );
	    inbuf_ptr += sizeof( VCache::IdxT ); 
	    try {	
		value = valueCache[vcIdx];
	    } catch ( InvalidIndexException &i ){
		fprintf( stderr, "caught invalid index exception for index = %u\n", vcIdx );
		value = 0;
	    }
	    decDebugP( "z_REGIDX_T, index = %u, ", vcIdx );
	    decDebugP( "value = %llu\n", value );

	    break;
	default:
	    fprintf( stderr, "Found a record of type: " );
	    print_rstrec( stderr, &read_noninstr_rec_rst.instr );
	    assert( 0 );
    }
    decDebug( "       " );	     
	 
    if( !idx ){
	// Special cases when the index is 0

	if( *inbuf_ptr == z_CCR_T ){
	    ++inbuf_ptr;
	    read_noninstr_rec_rst.regval.regtype[1] = RSTREG_CC_RT;
	    read_noninstr_rec_rst.regval.regid[1] = *inbuf_ptr++;
	    decDebugP( "z_CCR_T value = 0x%x\n", read_noninstr_rec_rst.regval.regid[1] );
	} else {
	    read_noninstr_rec_rst.regval.regtype[1] = RSTREG_UNUSED_RT;
	    read_noninstr_rec_rst.regval.regid[1] = 0;
	}
	read_noninstr_rec_rst.regval.rtype = REGVAL_T;
	read_noninstr_rec_rst.regval.postInstr = 1;
	read_noninstr_rec_rst.regval.reg64[1] = 0;
    } 

    read_noninstr_rec_rst.regval.reg64[idx] = value;
    read_noninstr_rec_rst.regval.regtype[idx] = RSTREG_INT_RT;

    if( regid >= 0 ){
	read_noninstr_rec_rst.regval.regid[idx] = regid;
    } else {
	read_noninstr_rec_rst.regval.regid[idx] = 255;
    }
    decDebugP( "[read_noninstr_rec()] Setting regid[%d] to ", idx );
    decDebugP( "%u\n", read_noninstr_rec_rst.regval.regid[idx] );
  }

  int read_noninstr_recs() {
    int i, n;

    n = 0;

    for (i = 0; i < num_noninstr; i++) {
      memcpy(&noninstr_buf[i], read_noninstr_rec(), sizeof(rstf_instrT));
      n += sizeof(rstf_instrT);
    }

    return n;
  }  // Rstunzip::read_noninstr_recs()

  int zrecs_o() {
    return outbuf_ptr - outbuf;
  }  // Rstunzip::zrecs_o()

  int zbytes_i() {
    return inbuf_ptr - inbuf;
  }  // Rstunzip::zbytes_i()

};  // class Rstunzip

// Compression class.
class Rstzipv2 : public RstzipBase {
public:
  rstf_instrT* inbuf_ptr;  // always points to current inbuf location
  uint8_t* outbuf_ptr;	   // always points to current outbuf location

  Rstzipv2() 
  {
    zip_init();
  }

  ~Rstzipv2() {
    zip_close();
  }

  void zip_init() {
    inbuf = NULL;
    inbuf_ptr = NULL;
    outbuf = NULL;
    outbuf_ptr = NULL;

    rstz_compress_prev_nrecs = 0;
    zip_chunk_chksm = 0;
    zip_chunk_chunk_counter = 0;
    in_same_chunk_prev_pc = 0;
    lastRID = -1;
    inChunk = false;
  }

  void zip_close() {
    //free(outbuf);
  }

  int rstz_compress_prev_nrecs;
  // Compress nrecs RST records from rstbuf[] to rz2buf[].
  // Returns size of compressed nrecs records in rz2buf[].
  int rstz_compress(uint8_t* rz2buf, rstf_unionT* rstbuf, int nrecs) {
    int buf_instr = 0;

    if (rstbuf == NULL) {
      return 0;
    }

    inbuf = &rstbuf[0].instr;
    outbuf = rz2buf;
    inbuf_ptr = inbuf;
    outbuf_ptr = outbuf;

    while (zrecs_i() < nrecs) {
      zip_chunk(nrecs);

      max_chunksize = MAX(max_chunksize, num_instr + num_noninstr);
      buf_instr += num_instr;
#if _DEBUG0
      print_chunk(DBGFP);
      if (num_instr != 0) {
	fprintf(DBGFP, "zrecs_i()=%d zbytes_o()=%d nrecs=%d\n\n",
		zrecs_i(), zbytes_o(), nrecs);
      }
#endif
    }

    total_instr += buf_instr;
    total_noninstr += zrecs_i() - buf_instr;

    return zbytes_o();
  }  // Rstzip::zip()

#if 0
  int rstz_write_prev_nrecs;
  // Compress nrecs RST records from buf[] to *outfp; assume exactly
  // nrecs records exist in buf[].  Returns number of records
  // compressed.
  int rstz_write(rstf_unionT buf[], int nrecs) {
    int buf_instr = 0;

    inbuf = &buf[0].instr;

    if (outbuf == NULL || rstz_write_prev_nrecs < nrecs) {
      rstz_write_prev_nrecs = nrecs;

      free(outbuf);

      outbuf = (uint8_t*) malloc((nrecs+MAX_CHUNKSIZE) * sizeof(rstf_instrT));
      if (outbuf == NULL) {
	fprintf(stderr, "Error: could not allocate %d bytes "
		        "of memory in Rstzip::zip()\n",
		(nrecs+MAX_CHUNKSIZE) * sizeof(rstf_instrT));
	exit(2);
      }
    }

    inbuf_ptr = inbuf;
    outbuf_ptr = outbuf;

    while (zrecs_i() < nrecs) {
      zip_chunk(nrecs);

      max_chunksize = MAX(max_chunksize, num_instr + num_noninstr);
      buf_instr += num_instr;
#if _DEBUG0
      print_chunk(DBGFP);
      if (num_instr != 0) {
	fprintf(DBGFP, "zrecs_i()=%d zbytes_o()=%d nrecs=%d\n\n",
		zrecs_i(), zbytes_o(), nrecs);
      }
#endif
    }

    total_instr += buf_instr;
    total_noninstr += zrecs_i() - buf_instr;

    zfwrite(outbuf, zbytes_o());

    return zrecs_i();
  }  // Rstzip::zip()
#endif

protected:

  VCache valueCache;
  uint64_t currentPC;
  int lastRID;
  bool inChunk;

  rstf_instrT* inbuf;      // input rst buffer
  uint8_t* outbuf;         // output buffer for compressed traces

  uint64_t zip_chunk_chksm;
  uint64_t zip_chunk_chunk_counter;
  // Compress one chunk of RST records from *inbuf_ptr to *outbuf_ptr.
  void zip_chunk(int nrecs) {
    int hashval, set;

    rstf_instrT* inbuf_start = inbuf_ptr;

#if 0
    // CURRDEBUG
    for( int i = 0; i < 5; i++ ){
      print_rstrec(DBGFP, inbuf_start++ );
    }
#endif
    
    read_chunk(nrecs);

    // Read_chunk() initializes pc_start to zero and will set pc_start
    // if a chunk is read.
    if (pc_start != 0 & num_instr > 0) {
      hashval = hash.hash(pc_start);
      set = hash.search(pc_start, num_instr, instr_buf, hashval);

      if (set == NOT_FOUND) {
	write_chunk();
	hash.write(pc_start, num_instr, instr_buf, num_ea, ea_buf, hashval);
	total_nonloop_chunk++;
      } else {
	write_loop_chunk(hash.read(set, hashval));
	hash.update(num_ea, ea_buf, hashval, set);
	total_loop_chunk++;
      }

      if (checksum_freq != 0) {
	zip_chunk_chksm += compute_checksum64();
	zip_chunk_chunk_counter++;

	if (zip_chunk_chunk_counter % checksum_freq == 0) {
	  write_outbuf(&zip_chunk_chksm, 8);
	  zip_chunk_chksm = 0;
	}
      }
    }
  }  // Rstzip::zip_chunk()

  int make_pavadiff_rtype(int index) {
    int ztype;

    switch (index) {
    case 0:
      ztype = z0_PAVADIFF_T;
      break;
    case 1:
      ztype = z1_PAVADIFF_T;
      break;
    case 2:
      ztype = z2_PAVADIFF_T;
      break;
    case 3:
      ztype = z3_PAVADIFF_T;
      break;
    case 4:
      ztype = z4_PAVADIFF_T;
      break;
    case 5:
      ztype = z5_PAVADIFF_T;
      break;
    case 6:
      ztype = z6_PAVADIFF_T;
      break;
    case 7:
      ztype = z7_PAVADIFF_T;
      break;
    default:
      fprintf(stderr, "Error: index param > 7 in rstzip::make_pavadiff_rtype()\n");
      exit(2);
    }

    return ztype;
  }

  // Read one chunk of compressed data from *inbuf_ptr to instr_buf[],
  // ea_buf[], flags_buf[], etc.  Return the total number of records
  // written.
  int read_chunk(int nrecs) {
    rstf_instrT* inbuf_start;
    int ih;
    int lastRegid = -1;

    // init some data members
    rtype = 0;
    pc_start = 0;
    num_instr = 0;
    num_ea = 0;
    num_noninstr = 0;
    num_total = 0;
    num_noninstr_count = 0;

    memset(noninstr_count_buf, 0, MAX_CHUNKSIZE * sizeof(uint8_t));

    inbuf_start = inbuf_ptr;

    // find an INSTR_T record
    inChunk = false;
    while (zrecs_i() < nrecs && inbuf_ptr->rtype != INSTR_T) {
      //print_rstrec(DBGFP, inbuf_ptr);

      write_noninstr_rec(inbuf_ptr);
      inbuf_ptr++; 
    }

    // inbuf_ptr points to an INSTR_T now
    if (zrecs_i() < nrecs && inbuf_ptr->rtype == INSTR_T) {
      //print_rstrec(DBGFP, inbuf_ptr);

      pc_start = inbuf_ptr->pc_va;

#ifdef COM_DEBUG
      static int chunkNum = 0;
      fprintf( stderr, "writing chunk #%d\n", chunkNum++ );
#endif
      inChunk = true;
      while (zrecs_i() < nrecs && in_same_chunk(inbuf_ptr, nrecs, inbuf_ptr - inbuf_start + 1)) {
	if (inbuf_ptr->rtype == INSTR_T) {
	  // set instr_buf[]
	  instr_buf[num_instr] = inbuf_ptr->instr;

	  // save the destination register for regval records
	  // that follow this instruction.
	  lastRegid = inbuf_ptr->instr >> 25 & 0x01f;	

	  // set ea_buf[]
	  // ih = getIHash(inbuf_ptr->instr); // removed - 20040210 (vp)

	  // if (carry_ea(ih, inbuf_ptr->ea_valid)) { // replaced - 20040210 (vp)
	  if (carry_ea(inbuf_ptr->instr, inbuf_ptr->ea_valid)) {
	    ea_buf[num_ea] = inbuf_ptr->ea_va;
	    num_ea++;
	  }

	  // set flags_buf[]
	  flags_buf[num_instr] = 0;
	  set_flags(&flags_buf[num_instr], NOTUSED, inbuf_ptr->notused);
	  set_flags(&flags_buf[num_instr], EA_VALID, inbuf_ptr->ea_valid);
	  set_flags(&flags_buf[num_instr], TR, inbuf_ptr->tr);
	  // set_flags(&flags_buf[num_instr], NOTUSED2, inbuf_ptr->notused2);
	  set_flags(&flags_buf[num_instr], NOTUSED2, 0);
	  set_flags(&flags_buf[num_instr], PR, inbuf_ptr->pr);
	  set_flags(&flags_buf[num_instr], BT, inbuf_ptr->bt);
	  set_flags(&flags_buf[num_instr], AN, inbuf_ptr->an);
	  set_flags(&flags_buf[num_instr], RSRVD_CMPRSS, INSTR_FOLLOWS);

	  if (num_instr == UINT16_MAX) {
	    fprintf(stderr, "Error: num_instr > UINT16_MAX in Rstzip::read_chunk()\n");
	    exit(2);
	  }

	  num_instr++;

	  if (noninstr_count_buf[num_noninstr_count]) {
	    num_noninstr_count++;
	  }
	} else {
	  if (noninstr_count_buf[num_noninstr_count] == UINT8_MAX) {
	    fprintf(stderr, "Error: num_noninstr > %d in Rstzip::read_chunk()\n", UINT8_MAX);
	    exit(2);
	  }

	  // copy non-instrustion record to noninstr_buf[]
	  memcpy(&noninstr_buf[num_noninstr], inbuf_ptr, sizeof(rstf_unionT));
	  lastRegIdBuf[num_noninstr] = lastRegid;

	  // increment noninstr_count_buf[]
	  noninstr_count_buf[num_noninstr_count]++;

	  set_flags(&flags_buf[num_instr - 1], RSRVD_CMPRSS, NONINSTR_FOLLOWS);
	  num_noninstr++;
	}

	inbuf_ptr++;
      }
#ifdef COM_DEBUG
      fprintf( stderr, "    wrote %d instructions\n", num_instr );
      fprintf( stderr, "    wrote %d non-instructions\n", num_noninstr );
#endif
    }

    if (num_instr > 0) {
      if (num_instr + num_noninstr < MAX_CHUNKSIZE) {
	chunksize_count[(num_instr + num_noninstr) / (MAX_CHUNKSIZE / CHUNKSIZE_RES)]++;
      } else {
	chunksize_count[CHUNKSIZE_RES - 1]++;
      }
    }

    return inbuf_ptr - inbuf_start;
  }  // Rstzip::read_chunk()

  uint64_t in_same_chunk_prev_pc;
  // Chunks are terminated by:
  //   1) non-sequential instructions
  //   2) end of buffer
  //   3) MAX_CHUNKSIZE
  //   4) > UINT8_MAX sequential noninstruction records
  // Chunks are not terminated by non-instruction records (to improve
  // compression).
  bool in_same_chunk(rstf_instrT* rst, int nrecs, int chunk_recs) {
    int recs, ni_recs;

    if (chunk_recs >= MAX_CHUNKSIZE) {
      return false;
    } else if (rst->rtype == INSTR_T) {
      if (num_instr > 0) {
	if (rst->pc_va != in_same_chunk_prev_pc + 4) {
	  return false;
	}
      }

      in_same_chunk_prev_pc = rst->pc_va;
    } else {
      // find next rstf_instrT
      for (recs = zrecs_i(), ni_recs = 0;
	   recs < nrecs && ni_recs < UINT8_MAX && chunk_recs < MAX_CHUNKSIZE && rst->rtype != INSTR_T;
	   recs++, ni_recs++, chunk_recs++) {
	rst++;
      }

      if (recs < nrecs && chunk_recs < MAX_CHUNKSIZE) {
	if (rst->rtype != INSTR_T) {
	  return false;
	} else if (rst->pc_va != in_same_chunk_prev_pc + 4) {
	  return false;
	}
      } else {
	return false;
      }
    }

    return true;
  }  // Rstzip::in_same_chunk()

  // Write the chunk data from instr_buf[], ea_buf[], flags_buf[],
  // etc. to *outbuf_ptr.  Return the number of bytes written.
  int write_chunk() {
    int n = 0;

    rtype = z_INSTR_T;

    n += write_outbuf(&rtype, sizeof(rtype));
    n += write_outbuf(&num_instr, sizeof(num_instr));
    n += write_outbuf(&pc_start, sizeof(pc_start));

    n += write_outbuf(instr_buf, num_instr * sizeof(uint32_t));
    n += write_outbuf(flags_buf, num_instr * sizeof(flags_t));
    n += write_ea(NULL);
    n += write_outbuf(noninstr_count_buf, num_noninstr_count * sizeof(uint8_t));
    n += write_noninstr_recs();
 
    return n;
  }  // Rstzip::write_chunk()

  // Write the loop chunk data from instr_buf[], ea_buf[],
  // flags_buf[], etc. to *outbuf_ptr.  Return the number of bytes
  // written.
  int write_loop_chunk(hash_table_t* table) {
    int n = 0;

    rtype = zL_INSTR_T;

    n += write_outbuf(&rtype, sizeof(rtype));
    n += write_outbuf(&num_instr, sizeof(num_instr));
    n += write_outbuf(&pc_start, sizeof(pc_start));

    n += write_outbuf(flags_buf, num_instr * sizeof(flags_t));
    n += write_ea(table);
    n += write_outbuf(noninstr_count_buf, num_noninstr_count * sizeof(uint8_t));
    n += write_noninstr_recs();

    return n;
  }  // Rstzip::write_loop_chunk()

  int write_ea(hash_table_t* table) {
    int8_t offset8;
    int16_t offset16;
    int32_t offset32;
    int64_t offset64;
    int i, n;

    n = 0;

    // Nothing to write if num_ea == 0.
    if (num_ea > 0) {
      if (rtype == z_INSTR_T) {    // no compression
	n += write_outbuf(ea_buf, num_ea * sizeof(uint64_t));
      } else {                     // compression
	for (i = 0; i < num_ea; i++) {
	  offset64 = ea_buf[i] - table->ea_buf[i];

	  if (offset64 >= INT8_MIN && offset64 <= INT8_MAX) {
	    if (offset64 == RESERVED_OFFSET_8BITS ||
		offset64 == RESERVED_OFFSET_16BITS ||
		offset64 == RESERVED_OFFSET_32BITS ||
		offset64 == RESERVED_OFFSET_64BITS) {
	      offset8 = RESERVED_OFFSET_8BITS;
	      n += write_outbuf(&offset8, sizeof(offset8));

	      offset_count[OFFSET_8BITS_RESERVED_IDX]++;
#ifdef _DEBUG0
	      fprintf(DBGFP, "(Reserved 8) offset8=0x%02hx ",
		      table->ea_buf[i], offset8, ea_buf[i]);
#endif
	    } else {
	      offset_count[OFFSET_8BITS_IDX]++;

	      if (offset64 == 0) {
		zero_offset_count++;
	      }
	    }

	    offset8 = (int8_t) offset64 & 0xff;
	    n += write_outbuf(&offset8, sizeof(offset8));
#ifdef _DEBUG0
	    fprintf(DBGFP, "base=0x%llx offset8=0x%02hx ea=0x%llx\n",
		    table->ea_buf[i], offset8, ea_buf[i]);
#endif
	  } else if (offset64 >= INT16_MIN && offset64 <= INT16_MAX) {
	    offset8 = RESERVED_OFFSET_16BITS;
	    offset16 = (int16_t) offset64 & 0xffff;
	    n += write_outbuf(&offset8, sizeof(offset8));
	    n += write_outbuf(&offset16, sizeof(offset16));

	    offset_count[OFFSET_16BITS_IDX]++;
#ifdef _DEBUG0
	    fprintf(DBGFP, "(Reserved 16) offset8=0x%02hx ", offset8);
	    fprintf(DBGFP, "base=0x%llx offset16=0x%04hx ea=0x%llx\n",
		    table->ea_buf[i], offset16, ea_buf[i]);
#endif
	  } else if (offset64 >= INT32_MIN && offset64 <= INT32_MAX) {
	    offset8 = RESERVED_OFFSET_32BITS;
	    offset32 = (int32_t) offset64 & 0xffffffff;
	    n += write_outbuf(&offset8, sizeof(offset8));
	    n += write_outbuf(&offset32, sizeof(offset32));

	    offset_count[OFFSET_32BITS_IDX]++;
#ifdef _DEBUG0
	    fprintf(DBGFP, "(Reserved 32) offset8=0x%02hx ", offset8);
	    fprintf(DBGFP,
		    "base=0x%llx offset32=0x%08x ea=0x%llx\n",
		    table->ea_buf[i], offset32, ea_buf[i]);
#endif
	  } else {
	    offset8 = RESERVED_OFFSET_64BITS;
	    n += write_outbuf(&offset8, sizeof(offset8));
	    n += write_outbuf(&offset64, sizeof(offset64));

	    offset_count[OFFSET_64BITS_IDX]++;
#ifdef _DEBUG0
	    fprintf(DBGFP, "(Reserved 64) offset8=0x%02hx ", offset8);
	    fprintf(DBGFP, "base=0x%llx offset64=0x%016llx ea=0x%llx\n",
		    table->ea_buf[i], offset64, ea_buf[i]);
#endif
	  }
	}
      }    
    }

    return n;
  }  // Rstzip::write_ea()

  // Write n bytes from *from to *outbuf_ptr, and increment
  // outbuf_ptr.  Return the number of bytes written.
  int write_outbuf(void* from, size_t n) {
    memcpy(outbuf_ptr, from, n);
    outbuf_ptr += n;

    return n;
  }  // Rstzip::write_outbuf()

  int write_noninstr_rec(rstf_instrT* rst) {
    int index, n;

    static int niNr = 0;
    n = 0;


#ifdef COM_DEBUG
	print_rstrec( stderr, rst );
#endif

    comDebug( "      " );
    if (rst->rtype == PAVADIFF_T) {
      total_pavadiff++;
      index = pava_cache.search((rstf_pavadiffT*) rst);

      if (index == NOT_FOUND) {
	n = write_outbuf(rst, sizeof(rstf_instrT));
	pava_cache.write((rstf_pavadiffT*) rst);
      } else {
	uint8_t ztype = make_pavadiff_rtype(index);

	n = write_outbuf(&ztype, sizeof(uint8_t));
	pava_cache.update(index);

	total_zpavadiff++;
      } 
	comDebug( "writing PAVADIFF_T\n" );
      // COMPRESS
    } else if ( rst->rtype == REGVAL_T ){
	rstf_regvalT *regP = (rstf_regvalT*) rst;
	if ( isIntRegCompressable( regP ) ){
	    comDebug( "* Processing compressable register " );

	    if( regP->regtype[1] == RSTREG_INT_RT ){
		uint8_t tag = z_REGPAIR_T;
		comDebug( "[ *** z_REGPAIR_T *** ]" );
		n += write_outbuf( &tag, sizeof( uint8_t ) );
	    }

	    n += compressIntegerRecord( regP->regid[0], regP->reg64[0], regP->cpuid, lastRID );	

	    if( regP->regtype[1] == RSTREG_INT_RT ){
		n += compressIntegerRecord( regP->regid[1], regP->reg64[1], regP->cpuid, lastRID );

	    } else if( regP->regtype[1] == RSTREG_CC_RT ){
		n += writeCCRecord( regP->regid[1] );
	    }

	} else {
	    // we're not compressing this type of regval
	    n = write_outbuf( rst, sizeof(rstf_instrT) );
	    comDebug( "* Writing non-compressable REGVAL_T\n" );
	}
    } else {
	n = write_outbuf(rst, sizeof(rstf_instrT));	
    }

    ++niNr;
    return n;
  }

    unsigned compressIntegerRecord( uint8_t regid, uint64_t regval, uint8_t cpuid, int lastInstrRegId = -1 )
    {
	uint8_t tag;
	unsigned totalSize = 0;
	static uint8_t tagLookup[9] = { z_VALUE_0_T, z_VALUE_1_T, z_VALUE_2_T, z_VALUE_3_T,
					z_VALUE_4_T, z_VALUE_5_T, z_VALUE_6_T, z_VALUE_7_T, z_VALUE_8_T };
#ifdef COM_DEBUG
	static const char *tag2String[9] = { "z_VALUE_0_T", "z_VALUE_1_T", "z_VALUE_2_T", "z_VALUE_3_T",
				             "z_VALUE_4_T", "z_VALUE_5_T", "z_VALUE_6_T", "z_VALUE_7_T", "z_VALUE_8_T" };
#endif
 
	comDebugP( "(last regid = %u)\n", lastInstrRegId );
	comDebug( "       " );


	// if we can't get the regid from the instruction, then
	// we'll need to output it to the compressed trace.
	if( regid != lastInstrRegId || !inChunk ){
	    comDebugP( "z_REGID_T id = %u\n       ", regid );
	    tag = z_REGID_T;
	    totalSize += write_outbuf( &tag, sizeof( uint8_t ) );
	    totalSize += write_outbuf( &regid, sizeof( uint8_t ) );
	}

	VCache::IdxT idx;
	if( valueCache.hit( regval, idx ) ){
	    comDebugP( "z_REGIDX_T idx=%u ", idx );
	    comDebugP( " val=%llu\n", regval );
	    // if we hit in the value cache, then output the index.
	    tag = z_REGIDX_T;
	    totalSize += write_outbuf( &tag, sizeof( uint8_t ) );
	    totalSize += write_outbuf( &idx, sizeof( VCache::IdxT ) );

	} else if ( regval < 9 ){
	    // we have specific records for values < 8
	    tag = tagLookup[regval];
	    totalSize += write_outbuf( &tag, sizeof( uint8_t ) );
	    comDebugP( "%s ", tag2String[regval] );
	    comDebugP( "[%u]\n", tag );

	} else if( (regval & 0x0ff) == regval ){
	    // if the regval can be expressed in one byte, then it's wasteful to
	    // enter it in the value cache.   Instead, we output the 1-byte values
	    // to the trace. Note: we NEVER put these value in the value cache!!!
	    tag = z_REGVAL_8_T;
	    totalSize += write_outbuf( &tag, sizeof( uint8_t ) );
	    uint8_t rv8 = regval;
	    totalSize += write_outbuf( &rv8, sizeof( uint8_t ) );
	    comDebugP( "z_REGVAL_8_T val=%u\n", rv8 );

	} else if( (regval & 0x0ffff) == regval ){
	    // if the regval can be expressed in two bytes, then it's wasteful to
	    // enter it in the value cache.   Instead, we output the 2-byte values
	    // to the trace. Note: we NEVER put these value in the value cache!!!
	    tag = z_REGVAL_16_T;
	    totalSize += write_outbuf( &tag, sizeof( uint8_t ) );
	    uint16_t rv16 = regval;
	    totalSize += write_outbuf( &rv16, sizeof( uint16_t ) );
	    comDebugP( "z_REGVAL_16_T val=%u\n", rv16 );

	} else if( regval == ~(0x0ULL) ){
	    tag = z_VALUE_MINUS1_T;
	    totalSize += write_outbuf( &tag, sizeof( uint8_t ) );
	    comDebugP( "z_VALUE_MINUS1_T [%u]", tag );

	} else {
	    uint8_t size;
	    VCache::IdxT i = valueCache.insert( regval );

	    if( (regval & 0x0ffffffff ) == regval ){
		tag = z_REGVAL_32_T;
		uint32_t rv32 = regval;
		totalSize += write_outbuf( &tag, sizeof( uint8_t ) );
		totalSize += write_outbuf( &rv32, sizeof( uint32_t ) );
		comDebugP( "z_REGVAL_32_T val=%u", rv32 );
	    } else {
		tag = z_REGVAL_64_T;
		totalSize += write_outbuf( &tag, sizeof( uint8_t ) );
		totalSize += write_outbuf( &regval, sizeof( uint64_t ) );
		comDebugP( "z_REGVAL_64_T val=%llu", regval );
	    }
	    comDebugP( " indexed to %u\n", i );

	}

	comDebugP( "       size = %u\n", totalSize );

	return totalSize;
    }


    unsigned writeCCRecord( uint8_t CCRContents )
    { 
	unsigned totalSize = 0;

	uint8_t tag = z_CCR_T;
	totalSize += write_outbuf( &tag, sizeof( uint8_t ) );
	totalSize += write_outbuf( &CCRContents, sizeof( uint8_t ) );
	comDebugP( "       [CCR] = 0x%x\n", CCRContents );

	return totalSize;
    }


    
    

  int write_noninstr_recs() {
    int i, n;

    n = 0;

    for (i = 0; i < num_noninstr; i++) {
	lastRID = lastRegIdBuf[i];
	n += write_noninstr_rec(&noninstr_buf[i]);
    }

    return n;
  }

  int zrecs_i() {
    return inbuf_ptr - inbuf;
  }  // Rstzip::zrecs_i()()

  int zbytes_o() {
    return outbuf_ptr - outbuf;
  }  // Rstzip::zbytes_o()()

};  // Rstzip

#endif  // _RSTZIP_H
