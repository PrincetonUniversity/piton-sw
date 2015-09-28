/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: footer.H
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
// OpenSPARC T2 Processor File: footer.H
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
#ifndef _FOOTER_H
#define _FOOTER_H

class RstzipFooter {
public:
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

  RstzipFooter() {
    init();
  }

  void init() {
    int i;

    max_chunksize = 0;
    total_instr = 0;
    total_noninstr = 0;
    total_loop_chunk = 0;
    total_nonloop_chunk = 0;
    total_zpavadiff = 0;
    total_pavadiff = 0;
    zero_offset_count = 0;

    for (i = 0; i < OFFSET_64BITS_IDX + 1; i++) {
      offset_count[i] = 0;
    }

    for (i = 0; i < CHUNKSIZE_RES; i++) {
      chunksize_count[i] = 0;
    }
  }

  void fprint(FILE* fp) {
    int i;

    fprintf(fp, "\n");
    fprintf(fp, "Max chunksize                    = %d\n", max_chunksize);
    fprintf(fp, "Total instr recs                 = %llu\n", total_instr);
    fprintf(fp, "Total non-instr recs             = %llu\n", total_noninstr);
    fprintf(fp, "Total compressed chunks          = %llu\n", total_loop_chunk);
    fprintf(fp, "Total uncompressed chunks        = %llu\n", total_nonloop_chunk);
    fprintf(fp, "Total compressed pavadiff recs   = %llu\n", total_zpavadiff);
    fprintf(fp, "Total uncompressed pavadiff recs = %llu\n", total_pavadiff - total_zpavadiff);
    fprintf(fp, "Total EA zero offsets            = %llu\n", zero_offset_count);
    fprintf(fp, "\n");

    fprintf(fp, "%14s%14s\n", "EA offset size", "Count");
    for (i = 0; i <= OFFSET_64BITS_IDX; i++) {
      switch (i) {
      case OFFSET_8BITS_IDX:
	fprintf(fp, "%-14d%14llu\n", 8, offset_count[i]);
	break;
      case OFFSET_8BITS_RESERVED_IDX:
	fprintf(fp, "%-14d%14llu\n", 8, offset_count[i]);
	break;
      case OFFSET_16BITS_IDX:
	fprintf(fp, "%-14d%14llu\n", 16, offset_count[i]);
	break;
      case OFFSET_32BITS_IDX:
	fprintf(fp, "%-14d%14llu\n", 32, offset_count[i]);
	break;
      case OFFSET_64BITS_IDX:
	fprintf(fp, "%-14d%14llu\n", 64, offset_count[i]);
	break;
      }
    }
    fprintf(fp, "\n");

    fprintf(fp, "%-14s%14s\n", "Chunk size", "Count");
    for (i = 0; i < CHUNKSIZE_RES; i++) {
      switch (i) {
      case 0:
	fprintf(fp, "%-14s%14llu\n", "   0-99", chunksize_count[i]);
	break;
      case 1:
	fprintf(fp, "%-14s%14llu\n", "100-199", chunksize_count[i]);
	break;
      case 2:
	fprintf(fp, "%-14s%14llu\n", "200-299", chunksize_count[i]);
	break;
      case 3:
	fprintf(fp, "%-14s%14llu\n", "300-399", chunksize_count[i]);
	break;
      case 4:
	fprintf(fp, "%-14s%14llu\n", "400-499", chunksize_count[i]);
	break;
      case 5:
	fprintf(fp, "%-14s%14llu\n", "500-599", chunksize_count[i]);
	break;
      case 6:
	fprintf(fp, "%-14s%14llu\n", "600-699", chunksize_count[i]);
	break;
      case 7:
	fprintf(fp, "%-14s%14llu\n", "700-799", chunksize_count[i]);
	break;
      case 8:
	fprintf(fp, "%-14s%14llu\n", "800-899", chunksize_count[i]);
	break;
      case 9:
	fprintf(fp, "%-14s%14llu\n", "900-   ", chunksize_count[i]);
	break;
      }
    }
    fprintf(fp, "\n");
  }
};  // RstzipFooter

#endif  // _FOOTER_H
