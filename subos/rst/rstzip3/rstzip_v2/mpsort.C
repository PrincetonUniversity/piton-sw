// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: mpsort.C
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
#include <stdio.h>
#include <string.h>

#include "mpsort.H"

#define NRECS (32000)
#define NCPUS (4)

int main(int argc, char* argv[]) {
  FILE* infp = NULL;
  FILE* outfp = stdout;
  rstf_unionT* multirst = NULL;
  RstSplit* unirst = NULL;
  CpuCount* cpucount = NULL;
  int index[NCPUS] = { 0 };
  rstf_cpuT rstcpu = { CPU_T, 0, 0, 0, 0, 0 };
  int curcpu = 0;
  int firstcpurec = 1;
  int i, j, count, nrecs, cpucountrecs;

  // Quick check of command line.
  if (argc != 2) {
    fprintf(stderr, "mpsort rstfile\n");
    exit(1);
  }

  // Open input file.
  infp = fopen(argv[1], "r");

  // Allocate buffers.
  multirst = (rstf_unionT*) calloc(NRECS, sizeof(rstf_unionT));
  unirst = (RstSplit*) calloc(NCPUS, sizeof(RstSplit));
  for (i = 0; i < NCPUS; i++) {
    unirst[i].rst = (rstf_unionT*) calloc(NRECS, sizeof(rstf_unionT));
  }
  cpucount = (CpuCount*) calloc(NRECS, sizeof(CpuCount));

  nrecs = fread(multirst, sizeof(rstf_unionT), NRECS, infp);

  while (nrecs > 0) {
    for (i = 0; i < NCPUS; i++) {
      unirst[i].nrecs = 0;
      index[i] = 0;
    }

    cpucountrecs = sortRstTrace(multirst, nrecs, unirst, cpucount, &curcpu);
    firstcpurec = 1;
    j = 0;

    for (i = 0; i < cpucountrecs; i++) {
      curcpu = cpucount[i].cpu;
      count = cpucount[i].count;

      if (firstcpurec != 1) {
	rstcpu.cpu = curcpu;
	memcpy(&multirst[j], &rstcpu, sizeof(rstf_unionT));
	j++;
      }

      memcpy(&multirst[j], &unirst[curcpu].rst[index[curcpu]],
	     count * sizeof(rstf_unionT));
      index[curcpu] += count;
      j += count;

      firstcpurec = 0;
    }

    fwrite(multirst, sizeof(rstf_unionT), nrecs, outfp);
    nrecs = fread(multirst, sizeof(rstf_unionT), NRECS, infp);
  }

  free(multirst);
  for (i = 0; i < NCPUS; i++) {
    free(unirst[i].rst);
  }
  free(unirst);
  free(cpucount);
}


