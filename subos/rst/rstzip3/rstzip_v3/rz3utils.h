/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rz3utils.h
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
/* rz3utils.h
 * utility programs for rstzip3
 *
 * Copyright (C) 2003 Sun Microsystems, Inc.
 * All Rights Reserved
 */

#ifndef _rz3utils_h_
#define _rz3utils_h_

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>


#include "rz3iu.h"
#include "rz3_bitarray.h"
#include "rz3_valuecache.h"


static int rz3_nbits(uint64_t v) {
  int rv = 1;
  while(v >> rv) {
    rv++;
  }
  return rv;
} // rz3_nbits()


template <class vtype> struct rz3_tagged_table {

  rz3_tagged_table(int size) {
    sz = size;
    tags = new uint64_t [sz];
    data= new vtype [sz];

    clear();
  }

  ~rz3_tagged_table() {
    delete [] tags; tags = NULL;
    delete [] data; data = NULL;
  }

  void clear() {
    bzero(tags, sz*sizeof(uint64_t));
    bzero(data, sz*sizeof(vtype));
  }

  void set(uint64_t key, const vtype value) {
    int idx = (key & (sz-1));
    tags[idx] = key;
    data[idx] = value;
  }

  vtype get(uint64_t key) {
    int idx = key & (sz-1);
    if (tags[idx] == key) {
      return data[idx];
    } else {
      return 0;
    }
  }

  int sz;
  uint64_t *tags;
  vtype *data;
}; // template <class vtype> struct rz3_tagged_table


template <class vtype> struct rz3_table {

  rz3_table(int size) {
    sz = size;
    data= new vtype [sz];

    clear();
  }

  ~rz3_table() {
    delete [] data; data = NULL;
  }

  void clear() {
    bzero(data, sz*sizeof(vtype));
  }

  void set(uint64_t key, const vtype value) {
    int idx = (key & (sz-1));
    data[idx] = value;
  }

  vtype get(uint64_t key) {
    int idx = key & (sz-1);
    return data[idx];
  }

  int sz;
  vtype *data;
}; // template <class vtype> struct rz3_table



// proximity list - used in rstzip3 to exploit temporal-spatial locality
// to compress ea_va and regval/memval values
struct rz3_prox_elem {
  int valid;
  uint64_t data;
  rz3_prox_elem * next;
  rz3_prox_elem * prev;
}; // struct rz3_prox_elem


struct rz3_prox_list {
  rz3_prox_list(int size) {
    sz = size;
    arr = new rz3_prox_elem[sz];

    clear();
  } // rz3_prox_list::()


  void clear() {
    int i;
    for (i=0; i<sz; i++) {

      if (i == 0) {
	arr[i].prev = NULL;
      } else {
	arr[i].prev = &(arr[i-1]);
      }

      if (i == (sz-1)) {
	arr[i].next = NULL;
      } else {
	arr[i].next = &(arr[i+1]);
      }

      arr[i].data = 0x0;
    } // for each allocated elem

  } // clear();

  uint64_t lookup(int idx) {
    int i;
    rz3_prox_elem *pe = arr;
    for (i=0; i<idx; i++) {
      pe = pe->next;
    }
    return pe->data;
  }


  // returns the index if match, -1 otherwise
  // if v is found in the prox list, it is moved
  // to the head of the list ("most recent" position)
  int ref(uint64_t v) {
    int i;
    rz3_prox_elem * pe = arr;
    assert(pe->prev == NULL);
    for (i=0; i<sz; i++) {
      if (pe->data == v) break;
      if (pe->next) {
	pe = pe->next;
      } else {
	assert(i==(sz-1));
      }
    }

    if (i==0) {
      return 0;
    }

    if (i < sz) { // hit
      pe->prev->next = pe->next;

      if (pe->next) {
	pe->next->prev = pe->prev;
      }

      pe->prev = NULL;
      pe->next = arr;
      arr->prev = pe;
      arr = pe;

      return i;
    } else { // miss
      // pe is last - move it to the head
      pe->data = v;
      pe->prev->next = NULL;
      pe->next = arr;
      pe->prev = NULL;
      arr->prev = pe;
      arr = pe;
      return -1;
    }
  } // int ref(uint64_t v)

  ~rz3_prox_list() {
    delete [] arr;
  }

  int sz;
  rz3_prox_elem * arr;

}; // struct rz3_prox_list


#endif // _rz3utils_h_
