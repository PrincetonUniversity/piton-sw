// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: rstzip.C
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
/* rstzip.C
 * compressor binary for rstzip (includes rstzip1, 2, 3 (and other versions)
 */


#include <stdio.h>
#include <stdlib.h>
#include <libgen.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

#include "rstf/rstf.h"

#if defined(ARCH_AMD64)
#include "rstf/rstf_convert.h"
#endif

#include "Rstzip.H"

const char usage[] =
  "rstzip [-h] [-v] [-verbose] [-d] [-n #] [-s] [-o outfile] [[-i] infile]\n"
  "  -v        # print version number and exit\n"
  "  -h        # print this help string and exit\n"
  "  -verbose  # print verbose diagnostics\n"
  "  -d        # decompress. default if invoked as rstunzip\n"
  "  -n <nrec> # (de)compress nrec records and exit\n"
  "  -up       # obsolete option. ignored\n"
  "  -s        # print compression statistics. verbose stats if -verbose\n"
  "  -o file   # output file. default: stdout (only if non-tty)\n"
  "  [i] file  # input file. default: stdin (only if non-tty)\n\n"
  "Example 1: rstzip -i file.rst -o file.rz.gz\n"
  "Example 2: rstunzip file.rz2.gz | trconv -x|less\n"
  "Example 3: rstunzip2 file.rz2.gz | rstzip -o file.rz.gz\n";


int main(int argc, char **argv)
{
  const char * infile = NULL;
  const char * outfile = NULL;

  int64_t record_count = (int64_t) ((~0ull)>>1); // some ridiculously large number

  bool c_nd;


  bool verbose = false;
  bool stats = false;

  Rstzip * rz = new Rstzip;


  char * cmd = strdup(argv[0]);
  char * bn = basename(cmd);
  if ((strcmp(bn, "rstunzip") == 0) || (strcmp(bn, "rstunzip2") == 0) || (strcmp(bn, "rstunzip3") == 0)) {
    c_nd = false;
  } else {
    c_nd = true;
  }

  int i = 1;
  while(i < argc) {
    const char * arg = argv[i++];
    if (strcmp(arg, "-h") == 0) {
      printf("Usage: %s\n", usage);
      exit(0);
    } else if (strcmp(arg, "-v") == 0) { // print version number from the newest rstzip compressor
      printf("rstzip version %s, build date %s\n", rz->getVersionStr(), __DATE__);
      exit(0);
    } else if (strcmp(arg, "-verbose") == 0) {
      verbose = true;
    } else if (strcmp(arg, "-s") == 0) {
      stats = true;
    } else if (strcmp(arg, "-d") == 0) {
      c_nd = false;
    } else if (strcmp(arg, "-n") == 0) {
      if (argv[i] == NULL) {
	fprintf(stderr, "ERROR: %s requires an argument\nUsage: %s\n", arg, usage);
	exit(1);
      }
      int rv = sscanf(argv[i], "%lld", &record_count);
      if (rv != 1) {
	fprintf(stderr, "ERROR parsing argument: %s %s\nUsage: %s\n", arg, argv[i], usage);
	exit(1);
      }
      i++;
    } else if (strcmp(arg, "-o") == 0) {
      if (argv[i] == NULL) {
	fprintf(stderr, "ERROR: %s requires an argument\nUsage; %s\n", arg, usage);
	exit(1);
      }
      outfile = argv[i++];
    } else if (strcmp(arg, "-i") == 0) {
      if (infile != NULL) {
	fprintf(stderr, "ERROR: input file %s already specified. Offending arg=%s\nUsage: %s\n",
		infile, arg, usage);
	exit(1);
      }
      if (argv[i] == NULL) {
	fprintf(stderr, "ERROR: %s requires an argument\nUsage; %s\n", arg, usage);
	exit(1);
      }
      infile = argv[i++];
    } else {
      if (infile != NULL) {
	fprintf(stderr, "ERROR: input file %s already specified. Offending arg=%s\nUsage: %s\n",
		infile, arg, usage);
	exit(1);
      }
      infile = arg;
    }
  } // while more args

  if ((infile == NULL)  &&  isatty(STDIN_FILENO)) {
    fprintf(stderr, "Error: rstzip cannot read binary input from tty\nUsage: %s\n", usage);
    exit(0);
  }

  if ((outfile == NULL) && isatty(STDOUT_FILENO)) {
    fprintf(stderr, "Error: rstzip cannot write binary output to tty\nUsage: %s", usage);
    exit(1);
  }

  if (record_count == 0) {
    exit(0);
  }

  char rz3_options[256];
  bzero(rz3_options, 256);
  if (verbose) {
    strcat(rz3_options, " verbose=1 ");
  }
  if (stats) {
    strcat(rz3_options, " stats=1 ");
  }

  int rv;

  if (c_nd) {
    // compress
    FILE * fp;
    if (infile != NULL) {
      fp = fopen(infile, "r");
      if (fp == NULL) {
	perror(infile);
	exit(1);
      }
    } else {
      infile = "<STDIN>";
      fp = stdin;
    }

    rv = rz->open(outfile, "w", rz3_options);
    if (outfile == NULL) {
      outfile = "<STDOUT>";
    }
    if (rv != RSTZIP_OK) {
      fprintf(stderr, "ERROR: rstzip::open error writing %s\n", outfile);
      exit(1);
    }

    rstf_unionT * rstbuf = new rstf_unionT [rstzip_opt_buffersize];

    int64_t more = record_count;

    int n;
    while(more) {
      int req = (more > rstzip_opt_buffersize) ? rstzip_opt_buffersize : more;
      n = fread(rstbuf, sizeof(rstf_unionT), req, fp);
      if (n == 0) break;
#if defined(ARCH_AMD64)
      for (int i=0; i<n; i++) {
	rstf_convertT::b2l((rstf_uint8T*)&rstbuf[i]);
      }
#endif
      int rv = rz->compress(rstbuf, n);
      if (rv != n) {
	fprintf(stderr, "ERROR: rstzip: could not compress %d records (rz->compress() returned %d\n", n, rv);
	break;
      }
      more -= n;
    }
    rz->close();
    delete rz; rz=NULL;

    delete []rstbuf; rstbuf = NULL;

    if (fp != stdin) {
      fclose(fp); fp = NULL;
    }

  } else {
    // decompress
    FILE * fp;
    if (outfile != NULL) {
      fp = fopen(outfile, "w");
      if (fp == NULL) {
	perror(outfile);
	exit(1);
      }
    } else {
      outfile = "<STDOUT>";
      fp = stdout;
    }

    rv = rz->open(infile, "r", rz3_options);
    if (infile == NULL) {
      infile = "<STDIN>";
    }
    if (rv != RSTZIP_OK) {
      fprintf(stderr, "ERROR: rstzip::open error reading %s\n", infile);
      exit(1);
    }

    rstf_unionT * rstbuf = new rstf_unionT [rstzip_opt_buffersize];

    int64_t more = record_count;

    while(more) {
      int req = (more > rstzip_opt_buffersize) ? rstzip_opt_buffersize : more;
      int n = rz->decompress(rstbuf, req);
      if (n == 0) break;

      int rv = fwrite(rstbuf, sizeof(rstf_unionT), n, fp);
      if (rv != n) {
	fprintf(stderr, "ERROR: rstzip: could not write %d decompressed records to ", n);
	perror(outfile);
	break;
      }
      more -= n;
    }
    rz->close();
    delete rz; rz = NULL;

    delete [] rstbuf; rstbuf = NULL;

    if (fp != stdout) {
      fclose(fp); fp = NULL;
    }

  } // compress or decompress?
} // int main(int argc, char **argv)

