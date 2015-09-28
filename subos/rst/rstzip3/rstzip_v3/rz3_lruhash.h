/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rz3_lruhash.h
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
/* rz3_lruhash.h
 * fully-associative cache with lru replacement
 */

#ifndef _rz3_lruhash_h_
#define _rz3_lruhash_h_

#include <stdio.h>
#include <strings.h>
#include <sys/types.h>

struct rz3_lruhash_elem {
  uint64_t v;

  rz3_lruhash_elem * next;
  rz3_lruhash_elem * prev;


  rz3_lruhash_elem() {
    k = 0;
    prev = next = NULL;
    inited = false;
  }

  int GetKey() {
    if (!inited) {
      fprintf(stderr, "warning: rz3_lruhash: rz3_lruhash_elem key not set\n");
    }
    return k;
  }

  bool SetKey(int key) {
    if (!inited) {
      k = key;
      inited = true;
      return true;
    } else {
      fprintf(stderr, "warning: rz3_lruhash: rz3_lruhash_elem key already set\n");
      return false;
    }
  }
 private:
  // "k" is equivalent to a java "final" variable - write once
  int k; // "key", which is an index into a linear array in this implementation
  bool inited;
}; // rz3_lruhash_elem


struct rz3_lruhash {

  int nbits(uint64_t n) {
    int rv = 1;
    while(n>>rv) {
      rv++;
    }
    return rv;
  }

  // size must be a power of 2
  rz3_lruhash(int arg_size) {
    size = arg_size;

    idxbits = nbits(size-1);
    arr = new rz3_lruhash_elem [size];

    searchtbl = new rz3_lruhash_elem * [size];

    Clear();

    refs = misses = searchtbl_hits = 0;
  }

  void Clear() {
    newest = arr;
    oldest = arr+(size-1);

    bzero(searchtbl, size*sizeof(rz3_lruhash_elem *));

    int i;
    for (i=0; i<size; i++) {
      rz3_lruhash_elem * elem = arr+i;
      elem->v = i;
      elem->SetKey(i);
      elem->prev = (elem == newest) ? NULL : arr+(i-1);
      elem->next = (elem == oldest) ? NULL : arr+(i+1);
      // insert into searchtbl
      searchtbl[search_idx_fn(elem->v)] = elem;
    }
  } // rz3_lruhash(int arg_size)


  ~rz3_lruhash() {
    delete [] arr;
    delete [] searchtbl;
  } // ~rz3_lruhash()

  // returns a "key" whose value is [0 .. size-1]
  // and whose size is CEIL(log2(arg_size)) bits
  bool Update(uint64_t v, int & k) {


    k = -1;
    refs++;

    // first search for elem
    int searchidx = search_idx_fn(v);
    if ((searchtbl[searchidx] != NULL) && (searchtbl[searchidx]->v == v)) {
      k = searchtbl[searchidx]->GetKey();
      searchtbl_hits++;
    } else {
      int i;
      for (i=0; i<size; i++) {
	if (arr[i].v == v) {
	  k = i;
	  break;
	}
      }
    }

    bool hit;
    if (k != -1) {
      BringToFront(&(arr[k]));
      hit = true;
    } else {
      k = oldest->GetKey();
      oldest->v = v;
      BringToFront(oldest);
      misses++;
      hit = false;
    }

    searchtbl[searchidx] = &(arr[k]);

    return hit;
  } // int Update(uint64_t v)

  // if key is good, stores corresponding value in v and returns true. also brings (key,v) to the front of the MRU list
  // returns false otherwise
  bool Get(int key, uint64_t & v) {
    if ((key < 0) || (key >= size)) return false;

    v = arr[key].v;

    BringToFront(&(arr[key]));
    int searchidx = search_idx_fn(v);
    searchtbl[searchidx] = &(arr[key]);
    return true;
  } // bool Get(int key, uint64_t & v)


  void BringToFront(rz3_lruhash_elem * elem) {
    if (elem == newest) return;

    elem->prev->next = elem->next;
    if (elem->next == NULL) {
      oldest = elem->prev;
    } else {
      elem->next->prev = elem->prev;
    }
    elem->prev = NULL;
    elem->next = newest;
    newest->prev = elem;
    newest = elem;
  }

  int search_idx_fn(uint64_t v) {
    return (v & (size-1)) ^ ((v >> idxbits) & (size-1));
  }

  void Report(FILE * fp) {
    fprintf(fp, "refs %lld misses %lld (%0.4f%%/ref)\n", refs, misses, misses*100.0/refs);
    uint64_t hits = refs-misses;
    fprintf(fp, "  fasthits %lld (%0.4f%%/hit, %0.4f%%/ref)\n", searchtbl_hits, searchtbl_hits*100.0/hits, searchtbl_hits*100.0/refs);
  }

  int size;

  int idxbits;

  rz3_lruhash_elem * newest;
  rz3_lruhash_elem * oldest;

  rz3_lruhash_elem * arr;

  rz3_lruhash_elem ** searchtbl; // search here first. if fails, search entire list

  uint64_t refs;
  uint64_t misses;
  uint64_t searchtbl_hits;
}; // struct rz3_lruhash

#endif // _rz3_lruhash_h_

