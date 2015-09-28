/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rz3_valuecache.h
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
/* rz3_valuecache.h
 * multi-level value cache
 */

#ifndef _rz3_valuecache_h_
#define _rz3_valuecache_h_


#include <stdlib.h>
#include <sys/types.h>
#include <string.h>
#include <strings.h>


// set the following to 0 unless debugging
#define rz3_valuecache_debug 0

struct rz3_valuecache_module {

  rz3_valuecache_module(int arg_size, int arg_lsbits) {

    size = arg_size;
    lsbits = arg_lsbits;

    tags = new uint64_t [size];

    refs = misses = 0;

    Clear();
  }

  ~rz3_valuecache_module() {
    delete [] tags;
  }

  void Clear() {
    bzero(tags, size*sizeof(uint64_t));
  }


  int size;
  int lsbits;
  uint64_t *tags;

  uint64_t refs;
  uint64_t misses;

  // these are statistics-related variables set and used by rz3_valuecache
  int cost; // cost per hit
  uint64_t level_hits;
  uint64_t levelcost; // total cost of hits at this level

}; // struct rz3_valuecache_tbl


// these are hand-crafted values based on several tpcc, specweb, spec cpu traces
// size must be LESS THAN 2^idxbits because we use index=size as a special marker

// values are defined both as scalar consts and static const arrays because the scalar
// consts are used to define other static structs while the arrays are indexed by
// program variables
static const int rz3_valuecache_size0 = 7;
static const int rz3_valuecache_size1 = 31;
static const int rz3_valuecache_size2 = 61;
static const int rz3_valuecache_size3 = 127;
static const int rz3_valuecache_size4 = 509;
static const int rz3_valuecache_size5 = 2039;
static const int rz3_valuecache_size6 = 8191;
static const int rz3_valuecache_size[] = {
  rz3_valuecache_size0,
  rz3_valuecache_size1,
  rz3_valuecache_size2,
  rz3_valuecache_size3,
  rz3_valuecache_size4,
  rz3_valuecache_size5,
  rz3_valuecache_size6,
};

static const int rz3_valuecache_idxbits0 = 3;
static const int rz3_valuecache_idxbits1 = 5;
static const int rz3_valuecache_idxbits2 = 6;
static const int rz3_valuecache_idxbits3 = 7;
static const int rz3_valuecache_idxbits4 = 9;
static const int rz3_valuecache_idxbits5 = 11;
static const int rz3_valuecache_idxbits6 = 13;
static const int rz3_valuecache_idxbits[] = {
  rz3_valuecache_idxbits0,
  rz3_valuecache_idxbits1,
  rz3_valuecache_idxbits2,
  rz3_valuecache_idxbits3,
  rz3_valuecache_idxbits4,
  rz3_valuecache_idxbits5,
  rz3_valuecache_idxbits6,
};

static const int rz3_valuecache_lsbits0 = 4;
static const int rz3_valuecache_lsbits1 = 6;
static const int rz3_valuecache_lsbits2 = 7;
static const int rz3_valuecache_lsbits3 = 8;
static const int rz3_valuecache_lsbits4 = 9;
static const int rz3_valuecache_lsbits5 = 10;
static const int rz3_valuecache_lsbits6 = 12;
static const int rz3_valuecache_lsbits[] = {
  rz3_valuecache_lsbits0,
  rz3_valuecache_lsbits1,
  rz3_valuecache_lsbits2,
  rz3_valuecache_lsbits3,
  rz3_valuecache_lsbits4,
  rz3_valuecache_lsbits5,
  rz3_valuecache_lsbits6,
};

struct rz3_valuecache {

  enum consts_e {
    nlevels = 7
  };

  rz3_valuecache(const char * arg_name) {

    name = (arg_name == NULL) ? strdup("Noname") : strdup(arg_name);

    modules = new rz3_valuecache_module * [nlevels];

    lsbmask = new uint64_t [nlevels];

    int i;
    for (i=0; i<nlevels; i++) {
      modules[i] = new rz3_valuecache_module(rz3_valuecache_size[i], rz3_valuecache_lsbits[i]);
      lsbmask[i] = (1ull << rz3_valuecache_lsbits[i]) - 1;
    }

    refs = 0;
    misses = 0;

    level_id_bits = nbits(nlevels); // 0..(nlevels-1) and raw value is an additional level
  }

  ~rz3_valuecache() {
    int i;
    for (i=0; i<nlevels; i++) {
      delete modules[i];
      modules[i] = NULL;
    }
    delete [] modules;

    delete [] lsbmask;

    free(name);
  }


  void Clear() {
    int i;
    for (i=0; i<nlevels; i++) {
      modules[i]->Clear();
    }
  }


  int Ref(uint64_t v, uint64_t & key) {
    refs++;
    int i;

    if (rz3_valuecache_debug) fprintf(stderr, "valuecache %s: ref %lld: v=%llx ", name, refs, v);
    for (i=0; i<nlevels; i++) {
      modules[i]->refs++;

      uint64_t tag = (v >> rz3_valuecache_lsbits[i]);
      if (tag == 0) {
	// write a special idx to indicate tag=0
	uint64_t idx = rz3_valuecache_size[i]; // size is guaranteed to be <idxbits> because size is < 2^(idxbits>
	key = (idx << rz3_valuecache_lsbits[i]) | (v & lsbmask[i]);
	if (rz3_valuecache_debug) fprintf(stderr, "HIT: level=%d tag=0 idx=%x key=%llx\n", i, idx, key);
	return i;
      }
      uint64_t idx = tag % rz3_valuecache_size[i];
      if (modules[i]->tags[idx] == tag) {
	key = (idx << rz3_valuecache_lsbits[i]) | (v & lsbmask[i]);
	if (rz3_valuecache_debug) fprintf(stderr, "HIT: level=%d tag=%llx idx=%x key=%llx\n", i, tag, idx, key);
	return i;
      } else {
	modules[i]->tags[idx] = tag;
	modules[i]->misses++;
      }
    }
    if (rz3_valuecache_debug) fprintf(stderr, "MISS: key=value\n");

    misses++;
    key = v;
    return nlevels; // indicates a miss

  } // Ref()

  bool Retrieve(int level, uint64_t key, uint64_t & v)
  {

    if (level == nlevels) {
      v = key;
      if (rz3_valuecache_debug) fprintf(stderr, "valuecache %s: Retrieve: refs=%lld level %d key %llx (value=key)\n", name, refs, level, key);
    } else {

      uint64_t lsbits = key & lsbmask[level];
      uint idx = key >> rz3_valuecache_lsbits[level];

      if (idx == rz3_valuecache_size[level]) {
	v = lsbits;
      } else {
	v = (((uint64_t)modules[level]->tags[idx]) << rz3_valuecache_lsbits[level]) | lsbits;
      }

      if (rz3_valuecache_debug) fprintf(stderr, "valuecache %s: Retrieve: refs %lld level %d key %llx (idx %x lsb %llx)\n", name, refs, level, key, idx, lsbits);
    }


    uint64_t key2;
    int level2;
    level2 = Ref(v, key2);

    if ((level2 != level) || (key2 != key)) {
      fprintf(stderr, "valuecache %s: Retrieve ERROR - retrieved value does not match result of Ref()\n", name);
      fprintf(stderr, "  refs %lld level %d key %llx retrieved value %llx retrieved level %d retrieved key %llx\n", refs, level, key, v, level2, key2);
      return false;
    }
 
    return true;
  }


#if 0
  int Ref_noupdate(uint64_t v, uint64_t & key) {
    refs++;
    int i;

    for (i=0; i<nlevels; i++) {
      modules[i]->refs++;
      uint64_t tag = (v >> rz3_valuecache_lsbits[i]);
      if (tag == 0) {
	// write a special idx to indicate tag=0
	uint64_t idx = rz3_valuecache_size[i]-1;
	key = (idx << rz3_valuecache_lsbits[i]) | (v & lsbmask[i]);
	return i;
      }
      uint64_t idx = tag % rz3_valuecache_size[i];
      if (modules[i]->tags[idx] == tag) {
	key = (idx << rz3_valuecache_lsbits[i]) | (v & lsbmask[i]);
	return i;
      } else {
	// modules[i]->tags[idx] = tag;
	modules[i]->misses++;
      }
    }
    misses++;
    key = v;
    return nlevels; // indicates a miss

  }
#endif
  char * name;

  struct rz3_valuecache_module ** modules;

  uint64_t * lsbmask;

  uint64_t refs;
  uint64_t misses;

  int level_id_bits;

  void Report(FILE *fp) {
    fprintf(fp, "\nValuecache %s report:\n", name);
    fprintf(fp, "Refs %lld Misses %lld (%0.4f%%/ref)\n", refs, misses, misses*100.0/refs);

    uint64_t rawcost = misses * (64 + level_id_bits);

    uint64_t cost = 0;
    int i;
    for (i=0; i<nlevels; i++) {
      modules[i]->cost = modules[i]->lsbits + nbits(modules[i]->size-1);
      modules[i]->levelcost = (modules[i]->refs-modules[i]->misses) * (modules[i]->cost + level_id_bits);
      cost += modules[i]->levelcost;
    }
    cost += rawcost;

    uint64_t incr_cost = 0;
    for (i=0; i<nlevels; i++) {
      fprintf(fp, "level %d: Refs %lld Misses %lld (%0.4f%%/local-ref, %0.4f%%/ref)\n", i, modules[i]->refs, modules[i]->misses,
	      modules[i]->misses*100.0/modules[i]->refs, modules[i]->misses*100.0/refs);
      uint64_t levelcost = modules[i]->levelcost;
      incr_cost += levelcost;
      fprintf(fp, "  cost = %lld hits * (%d idxlsb + %d lvl bits) = %lld [%lld] (%0.4f/ref) %0.4f%% of total\n",
	     (modules[i]->refs-modules[i]->misses), modules[i]->cost, level_id_bits, levelcost, incr_cost, levelcost*1.0/refs, levelcost*100.0/cost);
    }

    fprintf(fp, "cost of raw ea: %lld * (64 + %d id-bits) = %lld %0.4f%% of total\n", misses, level_id_bits, rawcost, rawcost*100.0/cost);

    fprintf(fp, "Total cost: %lld (%0.4f bits/ref)\n", cost, cost*1.0/refs);

  }


  static int nbits(uint64_t n) {
    int rv = 1;
    while(n>>rv) {
      rv++;
    }
    return rv;
  }

}; // struct valuecache



#endif // _rz3_valuecache_h_
