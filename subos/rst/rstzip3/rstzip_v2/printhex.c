/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: printhex.c
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
#include "stdio.h"

void usage() {
  fprintf(stderr, "Usage: printhex file\n");
}

int main(int argc, char* argv[]) {
  FILE* infp;
  int c, bytes;
  
  infp = fopen(argv[1], "r");
  if (infp == NULL) {
    usage();
    fprintf(stderr, "\nError: unable to open input file: %s\n", argv[1]);
    exit(1);
  }

  fprintf(stdout, "\n");

  for (bytes = 0; (c = fgetc(infp)) != EOF; bytes++) {
    if (bytes % 40 == 0) {
      fprintf(stdout, "\n");
    }

    fprintf(stdout, "%02x", c);
  }

  fprintf(stdout, "\n\n%d bytes read\n\n", bytes);

  return 0;
}
