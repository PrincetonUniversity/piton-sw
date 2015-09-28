// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: diffrst.C
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
#include <string.h>

#include "rstf/rstf.h"
#include "spix6plus/ITYPES.h"
#include "cpuid.h"

#define ALWAYS (11)
#define NEVER  (12)
#define ATRACE (13)

static int isldst(int ih) {
  return (ih_isload(ih) || ih_isstore(ih));
}

void usage(char* argv[]) {
  fprintf(stderr,
	  "Usage: %s [-allowdiff ihash|timestamp]+ rstfile1 rstfile2\n\n",
	  argv[0]);
  fprintf(stderr,
	  "Reads two rst files, writes nonidentical records to diff.rst.\n"
	  "\n"
	  "  -allowdiff\n"
	  "     ihash       Do not compare ihash values\n"
	  "     timestamp   Do not compare cpu timestamp values\n"
	  "     ntbranchea  Allow orig nt branch ea to be pc+4 instead of pc+8...\n"
          "     cpuid       Allow cpuid fields to differ\n"
	  " rstfile	    Use - to read from stdin.\n"
	  "\n");
}

int doerror(uint64_t rec, rstf_unionT* rst_orig, rstf_unionT* rst_new, FILE* outfp) {
  rstf_stringT string;

  string.rtype = STRDESC_T;
  sprintf(string.string, "Rec# %llu", rec);

  printf("%s differs\n", string.string);
  fflush(stdout);

  fwrite(&string, sizeof(rstf_stringT), 1, outfp);
  fwrite(rst_orig, sizeof(rstf_unionT), 1, outfp);
  fwrite(rst_new, sizeof(rstf_unionT), 1, outfp);
  fflush(outfp);

  return 1;
}

int main(int argc, char* argv[]) {
  rstf_unionT rst[3];
  FILE* infp0;
  FILE* infp1;
  FILE* outfp;
  bool allowihashdiff;
  bool allowtimestampdiff;
  bool allowntbrancheadiff;
  bool allowcpuiddiff;
  uint64_t i, diffrecs;
  char* a;
  char* b;
  char* filename[2];

  if (argc < 3) {
    usage(argv);
    exit(1);
  }

  // Set default flags
  allowihashdiff = false;
  allowtimestampdiff = false;
  allowntbrancheadiff = false;
  allowcpuiddiff = false;

  // Parse command line args
  for (i = 1; i < argc; i++) {
    a = argv[i];
    b = (i < argc) ? argv[i+1] : NULL;

    if (strcmp("-allowdiff", a) == 0) {
      if (strcmp("ihash", b) == 0) {
	allowihashdiff = true;
      } else if (strcmp("timestamp", b) == 0) {
	allowtimestampdiff = true;
      } else if (strcmp("ntbranchea", b) == 0) {
	allowntbrancheadiff = true;
      } else if (strcmp("cpuid", b) == 0) {
	allowcpuiddiff = true;
      }

      i++;
    } else if (i == argc - 2) {
      if (strcmp("-", a) == 0) {
	infp0 = stdin;
      } else {
	infp0 = fopen(a, "r");
      }

      filename[0] = a;
    } else if (i == argc - 1) {
      if (strcmp("-", a) == 0) {
	infp1 = stdin;
	filename[1] = a;
      } else {
	infp1 = fopen(a, "r");
      }
    } else {
      usage(argv);
      fprintf(stderr, "Error: unknown input parameter %s\n", a);
      exit(1);
    }
  }

  outfp = fopen("diff.rst", "w");
  diffrecs = 0;

  for (i = 0; 1; i++) {
    fread(&rst[0], sizeof(rstf_unionT), 1, infp0);
    fread(&rst[1], sizeof(rstf_unionT), 1, infp1);

    // File size difference?
    if (feof(infp0) || feof(infp1)) {
      break;
    }

    // Are records the different?
    if (memcmp(&rst[0], &rst[1], sizeof(rstf_unionT)) != 0) {
      if (rst[0].proto.rtype == INSTR_T) {
	rst[2] = rst[0];

	// Check ihash
	if (allowihashdiff == true) {
	  rst[2].instr.ihash = rst[1].instr.ihash;
	}

	// Check not taken branch ea
	if (allowntbrancheadiff == true) {
	  if (ih_isbranch(rst[2].instr.ihash) && rst[2].instr.bt == 0) {
	    if (rst[2].instr.ea_va == rst[1].instr.ea_va - 4) {
	      rst[2].instr.ea_va = rst[1].instr.ea_va;
	    }
	  }
	}

	if (allowcpuiddiff == true) {
	  rst[2].instr.cpuid = rst[0].instr.cpuid;
	}

	// Ignore invalid ea's
	if (rst[2].instr.ea_valid == 0) {
	  rst[2].instr.ea_va = rst[1].instr.ea_va;
	}

	if (memcmp(&rst[2], &rst[1], sizeof(rstf_unionT)) != 0) {
	  diffrecs += doerror(i, &rst[0], &rst[1], outfp);
	}
      } else if (rst[0].proto.rtype == CPU_T) {
	if (rst[0].cpu.cpu != rst[1].cpu.cpu) {
	  if (allowcpuiddiff == false) {
	    diffrecs += doerror(i, &rst[0], &rst[1], outfp);
	  }
	} else if (allowtimestampdiff == false) {
	  if (rst[0].cpu.timestamp != rst[1].cpu.timestamp) {
	    diffrecs += doerror(i, &rst[0], &rst[1], outfp);
	  }
	}
      } else if (allowcpuiddiff == true) {
	rst[2] = rst[0];
	setRstCpuID(&rst[2], getRstCpuID(&rst[1]));

	if (memcmp(&rst[2], &rst[1], sizeof(rstf_unionT)) != 0) {
	  diffrecs += doerror(i, &rst[0], &rst[1], outfp);
	}
      } else {
	diffrecs += doerror(i, &rst[0], &rst[1], outfp);
      }
    }
  }

  fprintf(stdout, "\nTotal: %llu recs differ\n", diffrecs);

  if (feof(infp0) == 0 || feof(infp1) == 0) {
    fprintf(stdout, "\nWarning: input filesizes differ.\n");
  }

  fclose(infp0);
  fclose(infp1);
  fclose(outfp);

  return 0;
}
