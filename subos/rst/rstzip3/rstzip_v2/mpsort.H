/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: mpsort.H
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
// OpenSPARC T2 Processor File: mpsort.H
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
#ifndef _MPSORT_H
#define _MPSORT_H

#include <stdlib.h>
#include <limits.h>

#include "rstf/rstf.h"

enum {
  RSTZIP_MAXCPUS = 32	// max cpus supported in trace
};

typedef struct {
  unsigned cpu   : 1;	// max number of cpus = 2
  unsigned count : 7;	// max rec count = 127; 0 means extended
} CpuCountZ2p;

typedef struct {
  unsigned cpu   : 2;	// max number of cpus = 4
  unsigned count : 6;	// max rec count = 63; 0 means extended
} CpuCountZ4p;

typedef struct {
  unsigned cpu   : 3;	// max number of cpus = 32
  unsigned count : 5;	// max rec count = 31; 0 means extended
} CpuCountZ8p;

typedef struct {
  unsigned cpu   : 4;	// max number of cpus = 16
  unsigned count : 4;	// max rec count = 15; 0 means extended
} CpuCountZ16p;

typedef struct {
  unsigned cpu   : 5;	// max number of cpus = 32
  unsigned count : 3;	// max rec count = 7; 0 means extended
} CpuCountZ32p;

typedef struct {
  int cpu;
  int count;
} CpuCount;

typedef struct {
  rstf_unionT* rst;
  unsigned nrecs;
} RstSplit;

// multirst is a buffer containing nrstrecs records
// unirst[n] is a buffer with space for nrstrecs records
// cpucount is a buffer with space for nrstrecs CpuCount records
// *curcpu is the cpu for the previous RST record
// The total number of CpuCount records is returned.
int sortRstTrace(rstf_unionT* multirst, int nrecs,
		 RstSplit* unirst, CpuCount* cpucount, int* curcpu) {
  int total_recs = 0;
  int cpu = 0;
  int numcpus = 0;  // Number of cpu's in this trace.
  int count = 0;
  int i, j;

  for (i = 0, j = 0; i < nrecs; i++) {
    if (multirst[i].proto.rtype == CPU_T) {
      cpucount[j].cpu = *curcpu;
      cpucount[j].count = count;
      j++;

      *curcpu = multirst[i].cpu.cpu;
      count = 0;
    } else {
      count++;

      unirst[*curcpu].rst[unirst[*curcpu].nrecs] = multirst[i];
      unirst[*curcpu].nrecs++;
    }
  }

  cpucount[j].cpu = *curcpu;
  cpucount[j].count = count;

  return (j + 1);
}

#endif  // _MPSORT_H

