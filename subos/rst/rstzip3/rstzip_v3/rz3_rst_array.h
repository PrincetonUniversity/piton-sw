/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rz3_rst_array.h
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
/* rz3_rst_array.h
 * incrementally-growing array of rst records
 */

#include <stdio.h>
#include <strings.h>
#include <sys/types.h>

#include "rstf/rstf.h"

struct rz3_rst_array {
  rz3_rst_array(int sz) {

    maxcount = sz;

    nlines = (maxcount + linesize - 1)/linesize;

    lines = new rstf_unionT * [nlines];
    int i;
    for (i=0; i<nlines; i++) {
      lines[i] = NULL;
    }
    count = 0;
  }

  bool Push(const rstf_unionT * rec) {
    if (count >= maxcount) return false;
    int lidx = (count / linesize);
    int offs = count % linesize;
    if (lines[lidx] == NULL) {
      assert(offs == 0);
      lines[lidx] = new rstf_unionT [linesize];
    }
    memcpy(&(lines[lidx][offs]), rec, sizeof(rstf_unionT));
    count++;
    return true;
  }

  bool Get(int idx, rstf_unionT * where) {
    if (idx >= count) {
      return false;
    }
    int lidx = idx / linesize;
    int offs = idx % linesize;
    memcpy(where, &(lines[lidx][offs]), sizeof(rstf_unionT));
    return true;
  }

  const rstf_unionT * GetPtr(int idx) {
    if (idx >= count) {
      return NULL;
    }
    int lidx = idx/linesize;
    int offs = idx % linesize;
    return &(lines[lidx][offs]);
  }

  int Count() {
    return count;
  }

  bool CopyFrom(rstf_unionT * membuf, int howmany) {
    if (howmany > maxcount) return false;
    count = howmany;
    int full_line_count = (count / linesize);
    int partial_line_size = (count % linesize);
    int i;
    int recs_copied = 0;
    for (i=0; i<full_line_count; i++) {
      lines[i] = new rstf_unionT [linesize];
      memcpy(lines[i], membuf+recs_copied, linesize*sizeof(rstf_unionT));
      recs_copied += linesize;
    }
    if (partial_line_size) {
      lines[i] = new rstf_unionT [linesize];
      memcpy(lines[i], membuf+recs_copied, partial_line_size*sizeof(rstf_unionT));
    }
    return true;
  } // CopyFrom()

  // membuf must accomodate <count> records. count is returned by the Count() function
  bool CopyTo(rstf_unionT * membuf) {
    int full_line_count = (count/linesize);
    int partial_line_size = (count % linesize);
    int recs_copied = 0;
    int i;
    for (i=0; i<full_line_count; i++) {
      memcpy(membuf+recs_copied, lines[i], linesize*sizeof(rstf_unionT));
      recs_copied += linesize;
    }
    if (partial_line_size) {
      memcpy(membuf+recs_copied, lines[i], partial_line_size * sizeof(rstf_unionT));
    }
    return true;
  }

  void clear() {
    count = 0;
  }

  ~rz3_rst_array() {
    int i;
    for (i=0; i<nlines; i++) {
      if (lines[i] != NULL) {
	delete [] lines[i];
      }
    }
    delete [] lines;
  }

  enum consts_e { linesize = 512 };
  int maxcount;
  int count;
  int nlines;
  rstf_unionT * *lines;
}; // rz3_rst_array
