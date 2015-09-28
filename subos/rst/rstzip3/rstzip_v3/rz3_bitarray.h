/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rz3_bitarray.h
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
/* new rz3_bitarray.h
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

#if defined(ARCH_AMD64)
#include "rstf/byteswap.h"
#endif

// set this to 1 for debugging - outputs every update to each bitarray
const int rz3_bitarray_debug = 0;

// class rz3_bitarray_base {
class rz3_bitarray {
 public:

  // rz3_bitarray_base(const char * arg_name, int arg_nbits, int size_hint) {
  rz3_bitarray(const char * arg_name, int arg_nbits, int size_hint) {
    name = strdup(arg_name);

    elemsize = arg_nbits;

    elem_mask = (~0ull) >> (64-elemsize);

    maxcount = 0;
    u64 = NULL;

    int desired_count;
    if (size_hint) {
      desired_count = size_hint;
    } else {
      desired_count = (1024*64/elemsize);
    }

    reallocate(desired_count);

    clear();

    straddle = ((64%elemsize) != 0);
  }


  // ~rz3_bitarray_base() {
  ~rz3_bitarray() {
    if(u64 != NULL) {
      delete [] u64;
    }
    free(name);
  }

  virtual void clear() {
    count = 0;
    nextidx = 0;
    sum = 0;
    nbits = 0;
  }

  virtual void Push(uint64_t data_nbits) {
    data_nbits &= elem_mask;

    if (rz3_bitarray_debug) { printf("rz3_bitarray %s [%d] <= %llx\n", name, count, data_nbits); fflush(stdout); }

    if (count >= maxcount) { // we havent written u64[count] yet. cannot write if count>=maxcount
      reallocate(count+1);
    }

    int u64idx = nbits/64;
    int offs = nbits%64;
    if (straddle && ((64-offs) < elemsize)) {
      // low-order bits
      int lbits = (64-offs);
      uint64_t lmask = (1ull << lbits) - 1;
      uint64_t lowbits = data_nbits & lmask;
      u64[u64idx] &= ~(lmask << offs);
      u64[u64idx] |= (lowbits << offs);
      u64[u64idx+1] = data_nbits >> lbits;
    } else {
      u64[u64idx] &= ~(elem_mask << offs);
      u64[u64idx] |= (data_nbits << offs);
    }
    count++;
    nbits += elemsize;
    sum += data_nbits;
  }


  virtual bool Get(int key, uint64_t & value)
  {
    if (key >= count) {
      if (rz3_bitarray_debug) fprintf(stderr, "rz3_bitarray %s: Error: Get(%d) - count is %d\n", name, key, count);
      return false;
    }

    value = 0x0;
    int u64idx = (key*elemsize)/64;
    int offs = (key*elemsize)%64;
    if (straddle && ((offs+elemsize)>64)) {
      int hbits = (offs+elemsize)-64;
      int lbits = elemsize-hbits;
      value = u64[u64idx] >> offs;
      uint64_t hmask = (1ull << hbits)-1;
      uint64_t hval = u64[u64idx+1] & hmask;
      value |= (hval << lbits);
    } else {
      value = (u64[u64idx] >> offs) & elem_mask;
    }
    return true;
  }

  // GetNext() is a stateful function that returns elements in the order they were inserted
  virtual bool GetNext(uint64_t & value)
  {
    bool rv = Get(nextidx, value);
    if (rz3_bitarray_debug) { printf("rz3_bitarray %s [%d] <= %llx\n", name, nextidx, value); fflush(stdout); }
    nextidx++;
    return rv;
  }

  virtual int Count() {
    return count;
  }

  virtual uint64_t ComputeMemBufSize(int n_elements)
  {
    int n_u64 =  (n_elements * elemsize + 63)/64;
    return n_u64 * sizeof(uint64_t);
  }

  virtual uint64_t GetMemBufSize() {
    return ComputeMemBufSize(count);
  }

  virtual uint64_t CopyTo(unsigned char * membuf)
  {
    int n_u64 = (nbits+63)/64;
    uint64_t sz = n_u64*sizeof(uint64_t);
#if defined(ARCH_AMD64)
    for (int i=0; i<n_u64; i++) {
      u64[i] = byteswap64(u64[i]);
    }
#endif
    memcpy(membuf, u64, sz);
    return sz;
  }

  virtual uint64_t CopyFrom(unsigned char * membuf, int arg_count)
  {
    if (arg_count > maxcount) {
      reallocate(arg_count);
    }
    count = arg_count;
    nbits = count * elemsize;
    int n_u64 = (nbits + 63)/64;
    int sz = n_u64 * sizeof(uint64_t);
    memcpy(u64, membuf, sz);
#if defined(ARCH_AMD64)
    for (int i=0; i<n_u64; i++) {
      u64[i] = byteswap64(u64[i]);
    }
#endif
    return sz;
  }

  // GetSum only returns a valid value if elements are Push()'ed. Not if the are CopyFrom()'ed.
  virtual uint64_t GetSum() {
    return sum;
  }


 protected:

  void reallocate(int desired_size) {
    if (desired_size <= maxcount) return;

    if (desired_size < (2*maxcount)) {
      desired_size = 2*maxcount;
    }

    int new_u64_count = (desired_size * elemsize + 63)/64;
    uint64_t * new_u64 = new uint64_t [new_u64_count];
    if (u64 != NULL) {
      memcpy(new_u64, u64, u64_count*sizeof(uint64_t));
      delete [] u64;
    }

    u64 = new_u64;
    u64_count = new_u64_count;

    maxcount = desired_size;

  }

  char * name;

  int elemsize;
  uint64_t elem_mask;

  int count; // count of valid elements in the array
  int maxcount; // the most number of elements that can exist in the array

  int nbits;

  int nextidx;

  int u64_count;

  uint64_t * u64;

  uint64_t sum;

  bool straddle;

}; // class rz3_bitarray_base


#if 0

// the rz3_bitarray is a space-efficient way to
// maintain lists of items whose size is not necessarily 8/16/32/64 bits.
// We try to balance memory usage and speed requirements.
// To this end, we implement 2 types of bit-arrays: fixed and growable.
// Fixed arrays are fast but can waste space.
// Growable arrays allocate space only as required

class rz3_bitarray {
 public:
  // nbits is the size of the array element. Must be <= 64
  rz3_bitarray(const char * arg_name, int nbits, int size_hint)
  {
    impl = new rz3_bitarray_base(arg_name, nbits, size_hint);
  }

  ~rz3_bitarray() {
    delete impl;
  }

  void clear() {
    impl->clear();
  }

  void Push(uint64_t data_nbits) {
    impl->Push(data_nbits);
  }

  bool Get(int key, uint64_t & value) {
    return impl->Get(key, value);
  }

  // GetNext() is a stateful function that returns elements in the order they were inserted
  bool GetNext(uint64_t & value)
  {
    return impl->GetNext(value);
  }


  int Count() {
    return impl->Count();
  }


  uint64_t ComputeMemBufSize(int n_elements) {
    return impl->ComputeMemBufSize(n_elements);
  }


  uint64_t GetMemBufSize() {
    return impl->GetMemBufSize();
  }


  uint64_t CopyTo(unsigned char * membuf) {
    return impl->CopyTo(membuf);
  }


  uint64_t CopyFrom(unsigned char * membuf, int arg_count) {
    return impl->CopyFrom(membuf, arg_count);
  }

  uint64_t GetSum() {
    return impl->GetSum();
  }

 protected:
  rz3_bitarray_base * impl;
}; // class rz3_bitarray

#endif


#endif // _rz3_bitarray_h_
