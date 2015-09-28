/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: hash.H
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
// OpenSPARC T2 Processor File: hash.H
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
#ifndef _HASH_H
#define _HASH_H

// File: hash.H
//
// Date: August 23, 2000
//
#include <string.h>

#include "rstf/rstf.h"

// table size = HASH_TBL_ASSOC * HASH_TBL_SIZE
#define HASH_TBL_ASSOC    (4)
#define HASH_TBL_SIZE  (3391) // 1013, 2371, 3391, 4093, 6073, 8093 are prime

#define HASH_FUNC_STRING "((pc >> 2) * 47) % HASH_TBL_SIZE"

#define NOT_FOUND      (-1)

typedef struct {
  uint8_t timestamp;

  uint16_t num_instr;
  uint16_t num_ea;
  //  uint16_t instr_buf_size;
  //  uint16_t ea_buf_size;

  uint64_t pc_start;

  uint32_t* instr_buf;
  uint64_t* ea_buf;
} hash_table_t;

class RstzipHash {
public:
  // constructor (zeros table[][])
  RstzipHash() {
    hash_init();
  }  // RstzipHash::RstzipHash()

  // destructor (frees table[][])
  ~RstzipHash() {
    hash_close();
  }  // RstzipHash::RstzipHash()

  void hash_init() {
    memset(table, 0, HASH_TBL_ASSOC * HASH_TBL_SIZE * sizeof(hash_table_t));
  }

  void hash_close() {
    int i, j;

    for (i = 0; i < HASH_TBL_ASSOC; i++) {
      for (j = 0; j < HASH_TBL_SIZE; j++) {
	if (table[i][j].instr_buf != NULL) {
	  trz_free(table[i][j].instr_buf, table[i][j].num_instr * sizeof(uint32_t));
	}

	if (table[i][j].ea_buf != NULL) {
	  trz_free(table[i][j].ea_buf, table[i][j].num_ea * sizeof(uint64_t));
	}
      }
    }
  }

  int search(uint64_t pc_start, int num_instr,
	     uint32_t instr_buf[], int hashval) {
    int i, j;

    for (i = 0; i < HASH_TBL_ASSOC; i++) {
      if (table[i][hashval].pc_start == pc_start) {
	if (table[i][hashval].num_instr >= num_instr) {
	  if (instr_buf != NULL) {
	    for (j = 0; j < num_instr; j++) {
	      if (table[i][hashval].instr_buf[j] != instr_buf[j]) {
                return NOT_FOUND;
              }
            }

            return i;
          } else {
            return i;
	  }
	}
      } 
    }

    return NOT_FOUND;
  }  // RstzipHash::search()

  hash_table_t* read(int set, int hashval) {
    return &table[set][hashval];
  }  // RstzipHash::read()

  void write(uint64_t pc_start,
	     uint16_t num_instr, uint32_t instr_buf[],
	     uint16_t num_ea, uint64_t ea_buf[],
	     int hashval) {
    int set = replace(pc_start, hashval);
    hash_table_t* tbl = &table[set][hashval];

    copy_instr_buf(tbl, instr_buf, num_instr);
    copy_ea_buf(tbl, ea_buf, num_ea);

    tbl->pc_start = pc_start;
    tbl->num_instr = num_instr;
    tbl->num_ea = num_ea;

    // No need to update if timestamp was HASH_TBL_ASSOC - 1 already
    if (tbl->timestamp != HASH_TBL_ASSOC - 1) {
      update(num_ea, ea_buf, hashval);
    }
  }  // RstzipHash::write()

  void update(int num_ea, uint64_t ea_buf[],
	      int hashval, int index = NOT_FOUND) {
    int i;
    uint8_t prev_timestamp;

    if (index == NOT_FOUND) {
      prev_timestamp = 0;
    } else {
      prev_timestamp = table[index][hashval].timestamp;
    }

    for (i = 0; i < HASH_TBL_ASSOC; i++) {
      if (table[i][hashval].timestamp > prev_timestamp) {
	table[i][hashval].timestamp--;
      }
    }

    if (index != NOT_FOUND) {
      table[index][hashval].timestamp = HASH_TBL_ASSOC - 1;
      memcpy(table[index][hashval].ea_buf, ea_buf, num_ea * sizeof(uint64_t));
    }
  }  // RstzipHash::update()

  int hash(uint64_t pc) {
    return (int) (((pc >> 2) * 47) % HASH_TBL_SIZE);
  }  // RstzipHash::hash()

#define SEGMENT_SIZE (512)

  size_t get_segment_size(long num, size_t size) {
    return (((num * size) / SEGMENT_SIZE) + 1) * SEGMENT_SIZE;
  }

  void print_table(hash_table_t* tbl) {
    int i;

    fprintf(stdout, "Hash Table [%d]:\n", tbl->timestamp);
    fprintf(stdout, "  pc_start=0x%llx\n", tbl->pc_start);
    fprintf(stdout, "  num_instr=%d\n", tbl->num_instr);
    fprintf(stdout, "  num_ea=%d\n", tbl->num_ea);
    fflush(stdout);

    for (i = 0; i < tbl->num_instr; i++) {
      fprintf(stdout, "  instr_buf[%d]=0x%08x\n", i, tbl->instr_buf[i]);
    }
    fprintf(stdout, "\n");

    for (i = 0; i < tbl->num_ea; i++) {
      fprintf(stdout, "  ea_buf[%d]=0x%016llx\n", i, tbl->ea_buf[i]);
    }
    fprintf(stdout, "\n");

    fflush(stdout);
  }  // RstzipHash::print_table()

  void print_set(int hashval) {
    int i;

    fprintf(stdout, "hashval=%d\n", hashval);
    for (i = 0; i < HASH_TBL_ASSOC; i++) {
      print_table(&table[i][hashval]);
    }
  }

  void print() {
    int i, j;

    for (i = 0; i < HASH_TBL_ASSOC; i++) {
      for (j = 0; j < HASH_TBL_SIZE; j++) {
	if (table[i][j].pc_start) {
	  fprintf(stdout, "1");
	} else {
	  fprintf(stdout, "0");
	}
      }

      fprintf(stdout, "\n\n");
    }
  }  // RstzipHash::print()

#if 0

#define MALLOC_WORD (0xbaddcafe)

  void* trz_malloc(size_t size) {
    int* ptr;

    if (size % 4 != 0) {
      fprintf(stderr, "Error: size param in RstzipHash::trz_malloc() is not word aligned (%u)\n", size);
      exit(2);
    }

    ptr = (int*) calloc(1, size);

    if (ptr == NULL) {
      fprintf(stderr, "Error: unable to alloc %d bytes in RstzipHash::trz_malloc()\n", size);
      exit(2);
    }

#ifdef _DEBUG0
    for (int i = 0; i < size / 4; i++) {
      ptr[i] = MALLOC_WORD;
    }
#endif

    return (void*) ptr;
  }

#define FREE_WORD (0xdeadbeef)

  void trz_free(void* ptr, size_t size) {
#ifdef _DEBUG0
    int* int_ptr = (int*) ptr;
#endif

    if (size > 0) {
      if (size % 4 != 0) {
	fprintf(stderr, "Error: size param in RstzipHash::trz_free() is not word aligned (%u)\n", size);
	exit(2);
      }

#ifdef _DEBUG0
      for (int i = 0; i < size / 4; i++) {
	int_ptr[i] = FREE_WORD;
      }
#endif
    }
    
    free(ptr);
  }

#else

  void* trz_malloc(size_t size) {
    return calloc(1, size);
  }

  void trz_free(void* ptr, size_t size) {
    size = 0;
    free(ptr);
  }

#endif

protected:
  hash_table_t table[HASH_TBL_ASSOC][HASH_TBL_SIZE];

  void invalidate(hash_table_t* tbl) {
    trz_free(tbl->instr_buf, tbl->num_instr * sizeof(uint32_t));

    tbl->timestamp = 0;
    tbl->pc_start = 0;
    tbl->num_instr = 0;
  }

  int replace(uint64_t pc_start, int hashval) {
    int i;

    for (i = 0; i < HASH_TBL_ASSOC; i++) {
      if (table[i][hashval].timestamp == 0) {
	table[i][hashval].timestamp = HASH_TBL_ASSOC;
	return i;
      }
    }

    fprintf(stderr, "Error: no pc=0x%llx or timestamp=0 found at hashval=%d in "
	            "Hash_Table_C::replace()\n", pc_start, hashval);
    exit(2);
  }  // RstzipHash::replace()

  void copy_instr_buf(hash_table_t* tbl, uint32_t instr_buf[], int num_instr) {
    size_t old_segment_size, new_segment_size;

    old_segment_size = get_segment_size(tbl->num_instr, sizeof(uint32_t));
    new_segment_size = get_segment_size(num_instr, sizeof(uint32_t));

    if (old_segment_size != new_segment_size || tbl->instr_buf == NULL) {
      if (tbl->instr_buf != NULL) {
	trz_free(tbl->instr_buf, tbl->num_instr * sizeof(uint32_t));
      }

      tbl->instr_buf = (uint32_t*) trz_malloc(new_segment_size);

      if (tbl->instr_buf == NULL) {
	fprintf(stderr, "Error: unable to malloc %d bytes in "
			"RstzipHash::copy_instr_buf()\n",
		new_segment_size);
	exit(2);
      }
    }

    //tbl->num_instr = num_instr;
    
    memcpy(tbl->instr_buf, instr_buf, num_instr * sizeof(uint32_t));
  }  // RstzipHash::copy_instr_buf()

  void copy_ea_buf(hash_table_t* tbl, uint64_t ea_buf[], int num_ea) {
    size_t old_segment_size, new_segment_size;

    old_segment_size = get_segment_size(tbl->num_ea, sizeof(uint64_t));
    new_segment_size = get_segment_size(num_ea, sizeof(uint64_t));

    if (old_segment_size < new_segment_size || tbl->ea_buf == NULL) {
      if (tbl->ea_buf != NULL) {
	trz_free(tbl->ea_buf, tbl->num_ea * sizeof(uint64_t));
      }

      tbl->ea_buf = (uint64_t*) trz_malloc(2 * new_segment_size);

      if (tbl->ea_buf == NULL) {
	fprintf(stderr, "Error: unable to malloc %d bytes in RstzipHash::copy_ea_buf()\n",
		new_segment_size);
	exit(2);
      }
    }

    //tbl->num_ea = num_ea;
    
    memcpy(tbl->ea_buf, ea_buf, num_ea * sizeof(uint64_t));
  }  // RstzipHash::copy_ea_buf()

};  // RstzipHash

// This *MUST* correspond to the number of compressed pavadiff
// rtypes in librstzip.H !!!!
#define PAVADIFF_CACHESIZE (8)

typedef struct {
  uint8_t timestamp;
  rstf_pavadiffT rst;
} pavadiff_table_t;

class RstzipPavadiffCache {
public:
  RstzipPavadiffCache() {
    pavadiff_cache_init();
  }

  void pavadiff_cache_init() {
    memset(table, 0, PAVADIFF_CACHESIZE * sizeof(pavadiff_table_t));
  }

  int search(rstf_pavadiffT* rst) {
    int i;

    for (i = 0; i < PAVADIFF_CACHESIZE; i++) {
      if (memcmp(&table[i].rst, rst, sizeof(rstf_pavadiffT)) == 0) {
	return i;
      } else if (rst->ea_valid == 0) {
	if (memcmp(&table[i].rst, rst, sizeof(rstf_pavadiffT) - sizeof(rst->ea_pa_va)) == 0) {
	  return i;
	}
      }
    }

    return NOT_FOUND;
  }

  rstf_pavadiffT* read(int index) {
    return &table[index].rst;
  }

  void write(rstf_pavadiffT* rst) {
    int index = replace();

    table[index].rst = *rst;

    if (table[index].timestamp != PAVADIFF_CACHESIZE - 1) {
      update();
    }
  }

  void update(int index = NOT_FOUND) {
    int i;
    uint8_t prev_timestamp;

    if (index == NOT_FOUND) {
      prev_timestamp = 0;
    } else {
      prev_timestamp = table[index].timestamp;
    }

    for (i = 0; i < PAVADIFF_CACHESIZE; i++) {
      if (table[i].timestamp > prev_timestamp) {
	table[i].timestamp--;
      }
    }

    if (index != NOT_FOUND) {
      table[index].timestamp = PAVADIFF_CACHESIZE - 1;
    }
  }

protected:
  pavadiff_table_t table[PAVADIFF_CACHESIZE];

  int replace() {
    int i;

    for (i = 0; i < PAVADIFF_CACHESIZE; i++) {
      if (table[i].timestamp == 0) {
	table[i].timestamp = PAVADIFF_CACHESIZE;
	return i;
      }
    }

    fprintf(stderr,
	    "Error: no timestamp=0 found in Pavadiff_Cache::replace()\n");
    exit(2);
  }
};

#endif  // _HASH_H
