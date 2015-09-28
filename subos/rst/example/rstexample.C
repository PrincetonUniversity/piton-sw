// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: rstexample.C
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
#include <stdlib.h>
#include <sys/types.h>
#include <string.h>

#include "rstf/rstf.h"
#include "rstzip/Rstzip.H"

const char usage[] = "rstexample <input-trace-file>";


int main(int argc, char **argv)
{
  // argv[1] must be input file
  const char * ifname = NULL;

  int i=1;
  while(i<argc) {
    const char * arg = argv[i++];
    if (strcmp(arg, "-h") == 0) {
      printf("Usage: %s\n", usage);
      exit(0);
    } else if (ifname != NULL) {
      fprintf(stderr, "ERROR: rstexample: input file %s already specified\nUsage: %s\n", ifname, usage);
      exit(1);
    } else {
      ifname = arg;
    }
  }

  if (ifname == NULL) {
    printf("Usage: %s\n", usage);
    exit(0);
  }

  // create an rstzip instance
  Rstzip * rz = new Rstzip;
  int rv=rz->open(ifname, "r", "verbose=0");
  if (rv != RSTZIP_OK) {
    fprintf(stderr, "ERROR: rstexample: Rstzip error opening input file %s\n", ifname);
    exit(1);
  }

  const int max_ncpu=1<<10; // RST supports 10-bit cpuids
  int64_t icounts[max_ncpu]; 
  memset(icounts, 0, max_ncpu*sizeof(int64_t));
  int64_t total_icount = 0;

  int nrecs;
  rstf_unionT buf[rstzip_opt_buffersize];
  while((nrecs = rz->decompress(buf, rstzip_opt_buffersize)) != 0) {
    int i;
    for (i=0; i<nrecs; i++) {
      rstf_unionT * rp = buf+i;
      if (rp->proto.rtype == INSTR_T) {
	total_icount++;
        int cpuid = rstf_instrT_get_cpuid(&(rp->instr));
        icounts[cpuid]++;
      }
    }
  }
  rz->close();
  delete rz;
  rz=NULL;

  printf("Total icount=%lld\n", total_icount);
  for (i=0; i<max_ncpu; i++) {
    if (icounts[i] > 0) {
      printf("cpu%d: icount=%lld\n", i, icounts[i]);
    }
  }
} // main()
