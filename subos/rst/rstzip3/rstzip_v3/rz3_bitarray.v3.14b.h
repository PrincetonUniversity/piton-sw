/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rz3_bitarray.v3.14b.h
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
/* rz3_bitarray.h
 * utility code for rstzip3
 *
 * Copyright (C) 2003 Sun Microsystems, Inc.
 * All Rights Reserved
 */

#ifndef _rz3_bitarray_h_
#define _rz3_bitarray_h_

#include <stdio.h>
#include <sys/types.h>
#include <strings.h>

#define rz3_bitarray_debug 0

// the rz3_bitarray is a space-efficient way to
// maintain lists of items whose size is not necessarily 8/16/32/64 bits.
// Access time is kept low by allocating a static array of size <maxsize_hint>.
// Exceeding this size involves memory reallocation() which may slow things down
// It is cheaper to specify a large maxsize_hint than to reallocate memory
struct rz3_bitarray {

  enum consts_e { u64_per_line = 128 };

  // nbits is the size of the array element. Must be <= 64
  rz3_bitarray(const char * arg_name, int nbits, int maxsize_hint) {
    if (nbits > 64) {
      fprintf(stderr, "ERROR: rz3_bitarray: nbits cannot be > 64. Specified = %d\n", nbits);
      exit(1);
    }

    name = strdup(arg_name);

    elemsize = nbits;

    elems_per_line = u64_per_line*64/elemsize;

    elem_mask = (~0ull) >> (64-elemsize);

    can_straddle = ((64 % elemsize) != 0);

    if (maxsize_hint == 0) {
      nlines = 1;
    } else {
      nlines = (maxsize_hint + elems_per_line - 1)/elems_per_line;
    }

    lines = new uint64_t * [nlines];
    int i;
    for (i=0; i<nlines; i++) {
      lines[i] = NULL;
    }

    count = 0;
    nextidx = 0;

    sum = 0;
  }

  ~rz3_bitarray() {
    int i;
    for (i=0; i<nlines; i++) {
      if (lines[i] != NULL) {
	delete [] lines[i];
	lines[i] = NULL;
      }
    }
    delete [] lines;
    free(name);
  }

  void clear() {
    count = 0;
    nextidx = 0;
    sum = 0;
  }

  void Push(uint64_t data_nbits) {
    data_nbits &= elem_mask; // zero-out upper bits of local copy of input arg

    if (rz3_bitarray_debug) { printf("rz3_bitarray %s [%d] <= %llx\n", name, count, data_nbits); fflush(stdout); }

    sum += data_nbits;

    // printf("rz3_bitarray::Push: count %d data %llx\n", count, data_nbits);
    int idx = count / elems_per_line;
    if (idx >= nlines) {
      // realloc lines
      nlines = (nlines + 1) * 1.5;
      uint64_t* * newlines = new uint64_t* [nlines];
      int i;
      for (i=0; i<idx; i++) {
	newlines[i] = lines[i];
      }
      for(i=idx; i<nlines; i++) {
	newlines[i] = NULL;
      }
      delete [] lines;
      lines = newlines;
    }
    if(lines[idx] == NULL) {
      lines[idx] = new uint64_t[u64_per_line];
    } // add new line

    int offset = count % elems_per_line;
    int u64_idx = (offset * elemsize) >> 6;
    int u64_offset = (offset * elemsize) & 0x3f;
    if (can_straddle && ((u64_offset + elemsize) > 64)) {
      // low-order bits
      int lbits = (64-u64_offset);
      uint64_t lmask = (1ull << lbits) - 1;
      uint64_t lowbits = data_nbits & lmask;
      lines[idx][u64_idx] &= ~(lmask << u64_offset);
      lines[idx][u64_idx] |= (lowbits << u64_offset);
      lines[idx][u64_idx+1] = data_nbits >> lbits;
      // printf("  lines[%d][%d] = %016llx, lines[%d][%d] = %016llx\n", idx, u64_idx, lines[idx][u64_idx], idx, u64_idx+1, lines[idx][u64_idx+1]);
    } else {
      lines[idx][u64_idx] &= ~(elem_mask << u64_offset); // zero out elem bits
      lines[idx][u64_idx] |= (data_nbits << u64_offset);
      // printf("  lines[%d][%d] = %016llx\n", idx, u64_idx, lines[idx][u64_idx]);
    }
    count++;
  } // Push()

  bool Get(int key, uint64_t & value) {
    if (key >= count) {
      return false;
    }

    value = 0x0;
    int idx = key/elems_per_line;
    int offset = key % elems_per_line;
    int u64_idx = (offset * elemsize) >> 6;
    int u64_offset = (offset * elemsize) & 0x3f;

    if (can_straddle && ((u64_offset+elemsize) > 64)) {
      int lbits = 64-u64_offset;
      value = lines[idx][u64_idx] >> u64_offset;
      int hbits = (u64_offset+elemsize-64);
      uint64_t hmask = (1ull << hbits) - 1;
      uint64_t hval = (lines[idx][u64_idx+1] & hmask);
      value |= (hval << lbits);
    } else {
      value = (lines[idx][u64_idx] >> u64_offset) & elem_mask;
    }

    return true;
  }

  // GetNext() is a stateful function that returns elements in the order they were inserted
  bool GetNext(uint64_t & value)
  {
    bool rv = Get(nextidx, value);
    if (rz3_bitarray_debug) { printf("rz3_bitarray %s [%d] <= %llx\n", name, nextidx, value); fflush(stdout); }
    nextidx++;
    return rv;
  }

  int Count() {
    return count;
  }

  uint64_t ComputeMemBufSize(int n_elements) {
    uint64_t full_lines = (n_elements/elems_per_line);
    uint64_t partial_line_bits = (n_elements % elems_per_line) * elemsize;
    uint64_t partial_line_u64_count = (partial_line_bits + 63)/64;
    return (full_lines * u64_per_line + partial_line_u64_count) * sizeof(uint64_t);
  }

  uint64_t GetMemBufSize() {
    return ComputeMemBufSize(count);
  }


  // returns number of bytes copied out - should be equal to SizeInBytes()
  uint64_t CopyTo(unsigned char * membuf) {
    int full_lines = (count/elems_per_line);
    int partial_line_bits = (count % elems_per_line) * elemsize;
    int partial_line_u64_count = (partial_line_bits + 63)/64;
    int i;
    uint64_t bytes_copied = 0;
    // copy full lines
    int full_line_size = u64_per_line * sizeof(uint64_t);
    for (i=0; i<full_lines; i++) {
      memcpy(membuf+bytes_copied, lines[i], full_line_size);
      bytes_copied += full_line_size;
    }

    // copy partial line
    memcpy(membuf+bytes_copied, lines[i], partial_line_u64_count*sizeof(uint64_t));
    bytes_copied += (partial_line_u64_count * sizeof(uint64_t));
    return bytes_copied;
  }

  // returns number of bytes copied in - should be equal to GetMemBufSIze()
  uint64_t CopyFrom(unsigned char * membuf, int arg_count) {

    count = arg_count;

    int full_lines = (count/elems_per_line);
    int partial_line_bits = (count % elems_per_line) * elemsize;
    int partial_line_u64_count = (partial_line_bits + 63)/64;

    int i;

    // do we have enough lines available?
    int lines_needed = full_lines;
    if (partial_line_u64_count) {
      lines_needed++;
    }

    if (lines_needed > nlines) {
      // allocate more line pointers. 1.5X current count or needed count, whichever larger
      int new_nlines = (nlines+1)*1.5;
      if (lines_needed > new_nlines) {
	new_nlines = lines_needed;
      }

      uint64_t ** newlines = new uint64_t * [new_nlines];

      // copy over <nlines> pointers>
      memcpy(newlines, lines, nlines * sizeof(uint64_t *));

      // zero pointers past nlines
      bzero(newlines+nlines, (new_nlines-nlines)*sizeof(uint64_t *));

      nlines = new_nlines;
      delete [] lines;
      lines = newlines;
    }

    uint64_t bytes_copied = 0;
    for (i=0; i<full_lines; i++) {
      if (lines[i] == NULL) {
	lines[i] = new uint64_t [u64_per_line];
      }
      int nbytes = u64_per_line*sizeof(uint64_t);
      memcpy(lines[i], membuf+bytes_copied, nbytes);
      bytes_copied += nbytes;
    }

    // partial line
    if (partial_line_u64_count) {
      if (lines[i] == NULL) {
	lines[i] = new uint64_t [u64_per_line];
      }
      int nbytes = partial_line_u64_count*sizeof(uint64_t);
      memcpy(lines[i], membuf+bytes_copied, nbytes);
      bytes_copied += nbytes;
    }

    return bytes_copied;
  } // CopyFrom()


  uint64_t GetSum() {
    return sum;
  }

  char * name; 
  int elemsize;
  int elems_per_line;
  uint64_t elem_mask; // shift u64 then AND with this mask to extract element

  bool can_straddle;

  int nlines;
  int count;
  int nextidx;
  uint64_t* *lines;

  uint64_t sum; // useful for generating prediction efficiency stats for elemsize=1. (may also be useful in other situations)
}; // rz3_bitarray


#endif //  _rz3_bitarray_h_
