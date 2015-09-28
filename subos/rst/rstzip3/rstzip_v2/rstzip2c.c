/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rstzip2c.c
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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "rstzip2if.H"

enum {
  BUFFERSIZE = 40000
};

static char zipname[] = "rstzip2";
static char unzipname[] = "rstunzip2";
static char* exename = zipname;

void fprintUsage(FILE* fp, int major, int minor) {
  fprintf(fp, 
  "Usage: %s [flags] [infile]\n"
  "\n"
  "(version %d.%02d, compiled %s) Compress / Decompress RST trace files.\n"
  "\n"
  "Flags:\n"
  "  -d           decompress\n"
  "  -h           give this help\n"
  "  -n #         decompress # records and exit (0=all, default=0)\n"
  "  -up          compress as uniprocessor trace (for old RST format)\n"
  "  -mp          compress as multiprocessor trace (for new RST format)\n"
  "  -s           print compression statistics\n"
  "  -nogz        do not apply gzip to the rstzip2 (de)compression\n"
  "  -o outfile   write output to outfile (Default: stdout)\n"
  "  infile       file to (de)compress (Default: stdin)\n"
  "\n"
  "NOTES: The 'old' RST format refers to RST versions 1.09 and below.\n"
  "       Rstzip2 is incompatible with rstzip compressed files.\n"
  "\n"
  "Example 1: rstzip2 -o file.rz2.gz file.rst\n"
  "Example 2: rstunzip2 file.rz2.gz | trconv | less\n"
  "Example 3: rstzip2 file.rst | rstunzip2 | trconv | less\n"
  "\n"
  "Uses libz.a (version 1.1.3) written by Jean-loup Gailly and Mark Adler.\n"
  "\n",
  exename, major, minor, __DATE__);
}

#ifdef __cplusplus

int main(int argc, char* argv[]) {
  Rstzip2if* rstzip = new Rstzip2if;
  char* infile = NULL;
  char* outfile = NULL;
  FILE* infp = stdin;
  FILE* outfp = stdout;
  rstf_unionT* rstbuf = NULL;
  long nrecs = 0;
  int numcpus = -1;
  int gzip = 1;
  int stats = 0;
  int decompress = 0;
  uint64_t totalrecs = 0;
  uint64_t decompress_nrecs = 0;
  int i;

  // Parse arguments.
  char* pname = strrchr(argv[0], '/');
  if (pname == NULL) {
    if (strcmp(argv[0], unzipname) == 0) {
      exename = unzipname;
    }
  } else {
    if (strcmp(pname + 1, unzipname) == 0) {
      exename = unzipname;
    }
  }

  for (i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-d") == 0) {
      decompress = 1;
    } else if (strcmp(argv[i], "-n") == 0) {
      i++;
      decompress_nrecs = strtoull(argv[i], NULL, 10);
    } else if (strcmp(argv[i], "-up") == 0) {
      numcpus = 1;
    } else if (strcmp(argv[i], "-mp") == 0) {
      numcpus = 0;
    } else if (strcmp(argv[i], "-s") == 0) {
      stats = 1;
    } else if (strcmp(argv[i], "-nogz") == 0) {
      gzip = 0;
    } else if (strcmp(argv[i], "-h") == 0 ||
	       strcmp(argv[i], "-help") == 0) {
      fprintUsage(stdout, rstzip->getMajorVersion(), rstzip->getMinorVersion());
      exit(0);
    } else if (strcmp(argv[i], "-o") == 0) {
      i++;
      outfile = argv[i];
    } else if (i == argc - 1) {
      infile = argv[i];
    } else {
      fprintUsage(stderr, rstzip->getMajorVersion(), rstzip->getMinorVersion());
      fprintf(stderr, "Error: unknown input parameter %s\n", argv[i]);
      exit(1);
    }
  }

  if (exename == unzipname) {
    decompress = 1;
  }

  if (decompress == 1) {
    if (outfile != NULL) {
      outfp = fopen(outfile, "w");
      if (outfp == NULL) {
	fprintf(stderr, "\nError: unable to open %s for writing.\n\n", outfile);
	exit(1);
      }
    }

    if (infile == NULL) {
      infile = (char*) malloc(2);
      strcpy(infile, "-");
    }
  } else {
    if (infile != NULL) {
      infp = fopen(infile, "r");
      if (infp == NULL) {
	fprintf(stderr, "\nError: unable to open %s for reading.\n\n", infile);
	fprintUsage(stderr, rstzip->getMajorVersion(), rstzip->getMinorVersion());
	exit(1);
      }
    }

    if (outfile == NULL) {
      outfile = (char*) malloc(2);
      strcpy(outfile, "-");
    }
  }

  rstbuf = (rstf_unionT*) malloc(BUFFERSIZE * sizeof(rstf_unionT));

  if (decompress == 0) {
    // Compression
    nrecs = fread(rstbuf, sizeof(rstf_unionT), BUFFERSIZE, infp);

    if (numcpus == -1) {
      if (rstbuf[0].proto.rtype == RSTHEADER_T) {
	if ((rstbuf[0].header.majorVer * 100) + rstbuf[0].header.minorVer < 110) {
	  numcpus = 1;
	}
      }
    }

    rstzip->openRstzip(outfile, BUFFERSIZE, gzip, stats, numcpus);

    while (nrecs > 0) {
      rstzip->compress(rstbuf, nrecs);
      nrecs = fread(rstbuf, sizeof(rstf_unionT), BUFFERSIZE, infp);
    }

    rstzip->closeRstzip();
  } else {
    // Decompression
    rstzip->openRstunzip(infile, BUFFERSIZE, gzip, stats);

    nrecs = rstzip->decompress(rstbuf, BUFFERSIZE);
    while (nrecs > 0) {
      if (decompress_nrecs > 0 && totalrecs + nrecs > decompress_nrecs) {
	totalrecs += fwrite(rstbuf, sizeof(rstf_unionT), decompress_nrecs - totalrecs, outfp);
	break;
      } else {
	totalrecs += fwrite(rstbuf, sizeof(rstf_unionT), nrecs, outfp);
      }
      nrecs = rstzip->decompress(rstbuf, BUFFERSIZE);
    }

    rstzip->closeRstunzip();
  }

  delete rstzip;
  free(rstbuf);

  fclose(infp);
  fclose(outfp);

  return 0;
}

#else  // __cplusplus

int main(int argc, char* argv[]) {
  Rstzip2if* rstzip = NULL;
  char* infile = NULL;
  char* outfile = NULL;
  FILE* infp = stdin;
  FILE* outfp = stdout;
  rstf_unionT* rstbuf = NULL;
  int nrecs = 0;
  int numcpus = -1;
  int gzip = 1;
  int stats = 0;
  int decompress = 0;
  uint64_t totalrecs = 0;
  uint64_t decompress_nrecs = 0;
  int i;

  // Parse arguments.
  char* pname = strrchr(argv[0], '/');
  if (pname == NULL) {
    if (strcmp(argv[0], unzipname) == 0) {
      exename = unzipname;
    }
  } else {
    if (strcmp(pname + 1, unzipname) == 0) {
      exename = unzipname;
    }
  }

  for (i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-d") == 0) {
      decompress = 1;
    } else if (strcmp(argv[i], "-n") == 0) {
      i++;
      decompress_nrecs = strtoull(argv[i], NULL, 10);
    } else if (strcmp(argv[i], "-up") == 0) {
      numcpus = 1;
    } else if (strcmp(argv[i], "-mp") == 0) {
      numcpus = 0;
    } else if (strcmp(argv[i], "-s") == 0) {
      stats = 1;
    } else if (strcmp(argv[i], "-nogz") == 0) {
      gzip = 0;
    } else if (strcmp(argv[i], "-h") == 0) {
      fprintUsage(stdout, rz2_getMajorVersion(rstzip), rz2_getMinorVersion(rstzip));
      exit(0);
    } else if (strcmp(argv[i], "-o") == 0) {
      i++;
      outfile = argv[i];
    } else if (i == argc - 1) {
      infile = argv[i];
    } else {
      fprintUsage(stderr, rz2_getMajorVersion(rstzip), rz2_getMinorVersion(rstzip));
      fprintf(stderr, "Error: unknown input parameter %s\n", argv[i]);
      exit(1);
    }
  }

  if (exename == unzipname) {
    decompress = 1;
  }

  if (decompress == 1) {
    if (outfile != NULL) {
      outfp = fopen(outfile, "w");
      if (outfp == NULL) {
	fprintf(stderr, "Error: unable to open %s for writing.\n", outfile);
	exit(1);
      }
    }

    if (infile == NULL) {
      infile = (char*) malloc(2);
      strcpy(infile, "-");
    }
  } else {
    if (infile != NULL) {
      infp = fopen(infile, "r");
      if (infp == NULL) {
	fprintf(stderr, "Error: unable to open %s for reading.\n", infile);
	exit(1);
      }
    }

    if (outfile == NULL) {
      outfile = (char*) malloc(2);
      strcpy(outfile, "-");
    }
  }

  rstbuf = (rstf_unionT*) malloc(BUFFERSIZE * sizeof(rstf_unionT));

  if (decompress == 0) {
    // Compression
    nrecs = fread(rstbuf, sizeof(rstf_unionT), BUFFERSIZE, infp);

    if (numcpus == -1) {
      if (rstbuf[0].proto.rtype == RSTHEADER_T) {
	if ((rstbuf[0].header.majorVer * 100) + rstbuf[0].header.minorVer < 110) {
	  numcpus = 1;
	}
      }
    }

    rstzip = rz2_openRstzip(outfile, BUFFERSIZE, gzip, stats, numcpus);
    while (nrecs > 0) {
      rz2_compress(rstzip, rstbuf, nrecs);
      nrecs = fread(rstbuf, sizeof(rstf_unionT), BUFFERSIZE, infp);
    }

    rz2_closeRstzip(rstzip);
  } else {
    // Decompression
    rstzip = rz2_openRstunzip(infile, BUFFERSIZE, gzip, stats);

    nrecs = rz2_decompress(rstzip, rstbuf, BUFFERSIZE);
    while (nrecs > 0) {
      if (decompress_nrecs > 0 && totalrecs + nrecs > decompress_nrecs) {
	totalrecs += fwrite(rstbuf, sizeof(rstf_unionT), decompress_nrecs - totalrecs, outfp);
	break;
      } else {
	totalrecs += fwrite(rstbuf, sizeof(rstf_unionT), nrecs, outfp);
      }
      nrecs = rz2_decompress(rstzip, rstbuf, BUFFERSIZE);
    }

    rz2_closeRstunzip(rstzip);
  }

  free(rstbuf);

  fclose(infp);
  fclose(outfp);

  return 0;
}

#endif
