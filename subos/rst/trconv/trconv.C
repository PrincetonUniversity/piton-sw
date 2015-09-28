// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: trconv.C
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
/* Copyright (C) 2006 Sun Microsystems, Inc.
 * All Rights Reserved
 */

#pragma ident "@(#)  trconv.C  1.6: 11/01/07 14:57:38 @(#)"
#include <ctype.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "read_symbols.h"
#include "trconv.H"

Globals_T gbl;

// allocating space...
Tmaster64 Trace::this_master = {0};

char version_string[] = "(Version 1.5)";

char switch_error_string[] = "Invalid %s passed to %s: %d\n";

char usage_string[] =
  "Usage: %s [flags] [input-file]\n"
  "\n"
  "%s "
  "Prints and converts various trace formats.\n"
  "\n"
  "Format flags:\n" 
  "  -from FX       = assume input data is in format FX\n" 
  "  -to FX         = generate output format FX\n" 
  "  where FX is one of the following: \n" 
  "    shade5       = Shade5 format\n"
  "    shade6x32    = Shade6 format, using 32 bit addresses\n" 
  "    shade6x64    = Shade6 format, using 64 bit addresses\n" 
  "    rtf99        = a deprecated format\n" 
  "    rst          = (RQ's) really simple trace format (Default -from)\n" 
  "    null         = (only for \"-to FX\"), do not convert (Default -to)\n"
  "Selection flags:\n" 
  "  -n N           = stop after processing N records\n" 
  "  -n Ni          = stop after processing N instructions\n" 
  "  -s N           = skip the first N records\n" 
  "  -s Ni          = skip the first N instructions\n" 
  "  -pc=pc1[,pc2]  = only process instructions w/ pc=pc1 (or [pc1,pc2])\n"
  "  -ea=ea1[,ea2]  = only process instructions w/ ea=ea1 (or [ea1,ea2])\n"
  "  -cpu=cpu1[,cpu2,...] = only process records from selected cpu's\n"
  "                   Example: -cpu=m,n-q,p selects records from \n"
  "                   cpu's m, p, and all cpu's from n through q\n"
  "Printing flags:\n"
  "  -a             = print in trace record field format\n"
  "  -d             = print in instruction disassembly format (Default)\n"
  "  -x             = print verbose output format\n"
  "  -nid           = suppress trace index in output\n" 
  "  -c             = only count records from the trace file\n"
#ifdef _PRINT_PA
  "  -pa            = print both VA and PA of effective address\n"
#endif // _PRINT_PA
  "  -sym [file]    = read and use symbols from 'file'\n"
#ifdef _VALUE_TRACE
  "  -vt            = print registers in value trace format\n"
#endif // _VALUE_TRACE
  "Verification flags:\n"
  "  -nv            = do not verify pc values in trace file\n" 
  "  -e             = only check for ihash errors\n"
  "  -fast          = turn off all verification and patching options\n"
  "RST flags:\n"
  "  -i             = only process RST instruction records\n" 
  "  -ic            = like -i, but counts only instructions\n" 
  "  -ni            = do not process any RST instruction records\n" 
  "  -nic           = like -ni, but counts only non-instructions\n" 
  "  -rstdump || -r = macro for: -from rst -to null -d (Default)\n" 
  "  -nobranch      = do not verify branch ea's against disassembly\n"
  "  -nopc_pavadiff = do not verify rstf_pavadiffT.pc_pa_va field\n"
  "  -noea_pavadiff = do not verify rstf_pavadiffT.ea_pa_va field\n"
  "  -pstate_am 0|1 = set initial PSTATE.AM bit to 0 or 1 (Default: 0)\n"
  "Patching flags:\n"
  "  -patchcleanrst = clean up \"dirty\" ea value to be RSTF_NOADDR "
                     "in RST trace\n"
  "  -patchihash    = forces ihash value generation\n"
  "Output flags:\n"
  "  -stdout        = output to standard out (Default)\n"
  "  -o File        = output to File\n"
  "Miscellaneous:\n"
  "  -help || -h    = print this message and exit\n" 
  "  -version || -v = print version and exit\n"
  "\n"
  "Default flags are: -from rst -to null -d -stdout.\n"
  "(By default Spix5 ihash values are assumed for all trace formats\n"
  "*including* Shade6 traces...)\n"
  "\n"
  "Examples:\n"
  "   %% %s < rstfile\n"
  "   (print disassembled RST trace instructions)\n"
  "\n"
  "   %% %s -from rst [-to null] -s 1000i -patchihash rstfile\n"
  "   (print trace records, skip first 1000 instructions)\n"
  "\n"
  "   %% %s -r -pc=0x12345678,0x22222222 rstfile\n"
  "   (print disassembled RST trace instructions with pc values within \n"
  "   [0x12345678 0x22222222])\n\n";

void usage(char progName[]) {
  fprintf(stderr, usage_string,  progName,  version_string,
	  progName, progName, progName);
}

// initializes user_options
void parse_args(int argc, char *argv[], bool debug) { 
  int i;
  char* a;
  char* b;

  // parse arguments
  for (i = 1; i < argc; i++) {
    a = argv[i];
    b = (i < argc) ? argv[i+1] : NULL;

    if (streq(a, "-from")) {
      if (streq(b, "null")) {
	usage(argv[0]);
	fprintf(stderr, "Invalid input format.  Type %s -help\n", argv[0]);
	exit(1);
      } else { 
	gbl.fromtype = format2int(b);
      }
      i++;
    } else if (streq(a, "-to")) {
      if (streq(b, "null")) {
	gbl.totype = NONE;
      } else { 
	gbl.totype = format2int(b);
      }
      i++;

    } else if (streq(a, "-n")) {
      gbl.maxRecs = strtoll(b, NULL, 10);
      if (b[strlen(b) - 1] == 'i') {
	gbl.maxInstrs = gbl.maxRecs;
	gbl.maxRecs = INT64_MAX;
      }
      i++;
    } else if (streq(a, "-syms")) {
	if (b == NULL) {
	    usage(argv[0]);
	    fprintf(stderr, "Could not open file for writing: %s\n", b);
	    exit(1);
	}
	else {
	    if (gbl.symbol_table.read_symbol_file(b) == false) {
		fprintf(stderr, "Read of symbol table file '%s' failed\n",
		        b);
		exit(1);
	    }
	}
	gbl.show_syms = true;
	i++;
    } else if (streq(a, "-s")) {
      gbl.skipRecs = strtoll(b, NULL, 10);
      if (b[strlen(b) - 1] == 'i') {
	gbl.skipInstrs = gbl.skipRecs;
	gbl.skipRecs = 0;
      }
      i++;
    } else if (streqprefix(a, "-pc")) {
      get_range(a, &gbl.frompc, &gbl.topc);
    } else if (streqprefix(a, "-ea")) {
      get_range(a, &gbl.fromea, &gbl.toea);
    } else if (streqprefix(a, "-cpu")) {
      get_cpu_range(a);

    } else if (streq(a, "-a")) {
      gbl.disassembly = false;
      gbl.record = true;
      gbl.verbose = false;
    } else if (streq(a, "-d")) {
      gbl.disassembly = true;
      gbl.record = false;
      gbl.verbose = false;
    } else if (streq(a, "-x")) {
      gbl.disassembly = false;
      gbl.record = false;
      gbl.verbose = true;
    } else if (streq(a, "-nid")) {
      gbl.showIdx = false;
    } else if (streq(a, "-c")) {
      gbl.countOnly = true;
#ifdef _PRINT_PA
    } else if (streq(a, "-pa")) {
      gbl.printPA = true;
#endif // _PRINT_PA
#ifdef _VALUE_TRACE
    } else if (streq(a, "-vt")) {
      gbl.valueTrace = true;
#endif // _VALUE_TRACE

    } else if (streq(a, "-nv")) {
      gbl.verify = false;
    } else if (streq(a, "-e")) {
      gbl.checkError = true;
    } else if (streq(a, "-fast")) {
      gbl.fast = true;

    } else if (streq(a, "-i")) {
      gbl.onlyIns = true;
    } else if (streq(a, "-ic")) {
      gbl.onlyIns = true;
      gbl.reorderIns = true;
    } else if (streq(a, "-ni")) {
      gbl.noIns = true;
    } else if (streq(a, "-nic")) {
      gbl.noIns = true;
      gbl.reorderNoIns = true;
    } else if (streq(a, "-rstdump") || streq(a, "-r")) {
      gbl.fromtype = RST;
      gbl.totype = NONE;
    } else if (streq(a, "-nobranch")) {
      gbl.branch = false;
    } else if (streq(a, "-nopc_pavadiff")) {
      gbl.pc_pavadiff = false;
    } else if (streq(a, "-noea_pavadiff")) {
      gbl.ea_pavadiff = false;
    } else if (streq(a, "-pstate_am")) {
      unsigned am = atoi(b) << 3;
      int j;

      for (j = 0; j < MAX_CPUID + 1; j++) {
	gbl.pstate[j] = am;
      }

      i++;

    } else if (streq(a, "-patchcleanrst")) {
      gbl.clean = true;
    } else if (streq(a, "-patchihash")) {
      gbl.genIHash = true;

    } else if (streq(a, "-stdout")) {
      gbl.outfp = stdout;
    } else if (streq(a, "-o")) {
      gbl.outfp = fopen(b, "w");
      if (gbl.outfp == NULL) {
	usage(argv[0]);
	fprintf(stderr, "Could not open file for writing: %s\n", b);
	exit(1);
      }
      i++;

    } else if (streq(a, "-help") || streq(a, "-h")) {
      usage(argv[0]);
      exit(0);
    } else if (streq(a, "-version") || streq(a, "-v")) {
      fprintf(stderr, "%s %s\n", argv[0], version_string);
      exit(0);

    } else if (a[0] == '-') {
      usage(argv[0]);
      fprintf(stderr, "Unknown flag: %s\n", a);
      exit(1);
    } else if (i < argc - 1) {
      usage(argv[0]);
      fprintf(stderr, "Unknown flag: %s\n", a);
      exit(1);
    } else if (i == argc - 1) {
      gbl.infile = a;

      gbl.infp = fopen(a, "r");
      if (gbl.infp == NULL) {
	usage(argv[0]);
	fprintf(stderr, "Could not open input file: %s\n", a);
	exit(1);
      }
    }
  }

  if (gbl.fast) {
    gbl.verify = false;
    gbl.checkError = false;
    gbl.branch = false;
    gbl.pc_pavadiff = false;
    gbl.ea_pavadiff = false;
    gbl.clean = false;
    gbl.genIHash = false;
    gbl.checkIHash = false;
  }

  gbl.fromsize = format2size(gbl.fromtype);
  gbl.tosize = format2size(gbl.totype);

  if (debug) {
    for (i = 0; i < argc; i++) {
      fprintf(gbl.msgfp, "%s ", argv[i]);
    }
    fprintf(gbl.msgfp, "\n\n");

    // format options
    fprintf(gbl.msgfp, "fromtype = %d\n", gbl.fromtype);
    fprintf(gbl.msgfp, "totype = %d\n", gbl.totype);
    fprintf(gbl.msgfp, "\n");

    // selection options
    fprintf(gbl.msgfp, "maxRecs = %llu\n", gbl.maxRecs);
    fprintf(gbl.msgfp, "maxInstrs = %llu\n", gbl.maxInstrs);
    fprintf(gbl.msgfp, "skipRecs = %llu\n", gbl.skipRecs);
    fprintf(gbl.msgfp, "skipInstrs = %llu\n", gbl.skipInstrs);
    fprintf(gbl.msgfp, "frompc = 0x%llx\n", gbl.frompc);
    fprintf(gbl.msgfp, "topc = 0x%llx\n", gbl.topc);
    fprintf(gbl.msgfp, "fromea = 0x%llx\n", gbl.fromea);
    fprintf(gbl.msgfp, "toea = 0x%llx\n", gbl.toea);
    fprintf(gbl.msgfp, "\n");

    // priting options
    fprintf(gbl.msgfp, "record = %d\n", gbl.record);
    fprintf(gbl.msgfp, "disassembly = %d\n", gbl.disassembly);
    fprintf(gbl.msgfp, "verbose = %d\n", gbl.verbose);
    fprintf(gbl.msgfp, "showIdx = %d\n", gbl.showIdx);
    fprintf(gbl.msgfp, "countOnly = %d\n", gbl.countOnly);
#ifdef _PRINT_PA
    fprintf(gbl.msgfp, "print PA = %d\n", gbl.printPA);
#endif // _PRINT_PA
#ifdef _VALUE_TRACE
    fprintf(gbl.msgfp, "valueTrace = %d\n", gbl.valueTrace);
#endif // _VALUE_TRACE
    fprintf(gbl.msgfp, "msgfp = 0x%x\n", gbl.msgfp);
    fprintf(gbl.msgfp, "\n");

    // verification options
    fprintf(gbl.msgfp, "verify = %d\n", gbl.verify);
    fprintf(gbl.msgfp, "checkError = %d\n", gbl.checkError);
    fprintf(gbl.msgfp, "fast = %d\n", gbl.fast);
    fprintf(gbl.msgfp, "\n");

    // rsttrace options
    fprintf(gbl.msgfp, "onlyIns = %d\n", gbl.onlyIns);
    fprintf(gbl.msgfp, "reorderIns = %d\n", gbl.reorderIns);
    fprintf(gbl.msgfp, "noIns = %d\n", gbl.noIns);
    fprintf(gbl.msgfp, "reorderNoIns = %d\n", gbl.reorderNoIns);
    fprintf(gbl.msgfp, "branch = %d\n", gbl.branch);
    fprintf(gbl.msgfp, "pc_pavadiff = %d\n", gbl.pc_pavadiff);
    fprintf(gbl.msgfp, "ea_pavadiff = %d\n", gbl.ea_pavadiff);
    fprintf(gbl.msgfp, "\n");

    // patching options
    fprintf(gbl.msgfp, "clean = %d\n", gbl.clean);
    fprintf(gbl.msgfp, "genIHash = %d\n", gbl.genIHash);
    fprintf(gbl.msgfp, "\n");

    // output options
    fprintf(gbl.msgfp, "infp = 0x%x\n", gbl.infp);
    fprintf(gbl.msgfp, "outfp = 0x%x\n", gbl.outfp);
    fprintf(gbl.msgfp, "\n");

    // convenient variables
    fprintf(gbl.msgfp, "progname = %s\n", gbl.progname);
    fprintf(gbl.msgfp, "infile = %s\n", gbl.infile);
    fprintf(gbl.msgfp, "fromsize = %d bytes\n", gbl.fromsize);
    fprintf(gbl.msgfp, "tosize = %d bytes\n", gbl.tosize);

    fflush(gbl.msgfp);
  }
} // parse_args

void init_globals(char *argv[]) {
  // format options
  gbl.fromtype = RST;            // -from
  gbl.totype = NONE;             // -to

  // selection options
  gbl.maxRecs = INT64_MAX;       // -n
  gbl.maxInstrs = INT64_MAX;     // -n i
  gbl.skipRecs = 0;              // -s
  gbl.skipInstrs = 0;            // -s i
  gbl.frompc = 0;                // -frompc
  gbl.topc = 0;                  // -topc
  gbl.fromea = 0;                // -fromea
  gbl.toea = 0;                  // -toea
  for (int i = 0; i < MAX_CPUID; i++) {
    gbl.cpu[i] = 1;		 // -cpu
  }

  // printing options
  gbl.record = false;            // -a
  gbl.disassembly = true;        // -d
  gbl.verbose = false;           // -x
  gbl.countOnly = false;         // -c
  gbl.showIdx = true;            // -nid
#ifdef _PRINT_PA
  gbl.printPA = false;           // -pa
#endif // _PRINT_PA
#ifdef _VALUE_TRACE
  gbl.valueTrace = false;        // -vt
#endif // _VALUE_TRACE
  gbl.show_syms = false;	// -syms

  // verification options
  gbl.verify = true;             // -nv
  gbl.checkError = false;        // -e
  gbl.fast = false;              // -fast
  
  // rsttrace options
  gbl.onlyIns = false;           // -i
  gbl.reorderIns = false;        // -ic
  gbl.noIns = false;             // -ni
  gbl.reorderNoIns = false;      // -nic
  gbl.branch = true;             // -nobranch
  gbl.pc_pavadiff = true;        // -nopc_pavadiff
  gbl.ea_pavadiff = true;        // -noea_pavadiff
  gbl.msgfp = stderr;            // -msg

  // patching options
  gbl.clean = false;             // -patchcleanrst
  gbl.genIHash = false;          // -patchihash

  // output options
  gbl.infp = stdin;               // [input-file]
  gbl.outfp = stdout;             // -stdout || -o

  // convenient variables
  gbl.progname = argv[0];
  gbl.infile = (char*) malloc(8);
  if (gbl.infile == NULL) {
    fprintf(stderr, "Could not allocate 8 bytes for "
	            "infile in init_globals()\n");
    exit(1);
  }
  strcpy(gbl.infile, "stdin");

  gbl.checkIHash = true;          // check ihash until nonzero value confirmed

  gbl.icount = 0;
  gbl.rcount = 0;
  gbl.skipInstrsRecs = 0;

  for (int i = 0; i < MAX_CPUID + 1; i++) {
    gbl.pstate[i] = 0;			// assume 64bit addresses by default
  }

  // rst-related
  gbl.rstf_pre212 = false;

  // rst types
  gbl.headercount = 0;
  //gbl.asicount = 0;
  gbl.tlbcount = 0;
  gbl.threadcount = 0;
  gbl.trapcount = 0;
  gbl.trapexitcount = 0;
  gbl.regvalcount = 0;
  gbl.cpucount = 0;
  gbl.pregcount = 0;
  gbl.dmacount = 0;
  gbl.stringcount = 0;
  gbl.delimcount = 0;
  gbl.physaddrcount = 0;
  gbl.pavadiffcount = 0;
  gbl.filemarkercount = 0;
  gbl.snoopcount = 0;

  gbl.unknowncount = 0;

#ifdef _PRINT_PA
  for(int initCpuId=0; initCpuId<MAX_INSTR_CPUID; initCpuId++) {
    gbl.ea_pavadiff_valid[initCpuId] = false;
    gbl.ea_pavadiff_value[initCpuId] = 0;
    gbl.pc_pavadiff_valid[initCpuId] = false;
    gbl.pc_pavadiff_value[initCpuId] = 0;
  }
#endif // _PRINT_PA
}

int format2int(const char str[]) { 
  if (streq(str, "shade5") ) {
    return SHADE5;
  } else if (streq(str, "shade6x32") ) {
    return SHADE6x32;
  } else if (streq(str, "shade6x64") ) {
    return SHADE6x64;
  } else if (streq(str, "rtf99") ) {
    return RTF99;
  } else if (streq(str, "master") ){
    return MASTER64; 
  } else if (streq(str, "rst") ){
    return RST;
  } else if (streq(str, "null") ) {
    return NONE;
  } else {
    usage(gbl.progname);
    fprintf(stderr, "Invalid data format: \"%s\"\n", str);
    exit(1);
  }
}

int format2size(int format) {
  int size;

  switch (format) {
  case RTF99:
    size = sizeof(Trtf99);
    break;
  case SHADE5:
    size = sizeof(Tshade5);
    break;
  case SHADE6x32:
    size = sizeof(Tshade6x32);
    break;
  case SHADE6x64:
    size = sizeof(Tshade6x64);
    break;
  case MASTER64:
    size = sizeof(Tmaster64);
    break;
  case RST:
    size = sizeof(rstf_unionT);
    break;
  case NONE:
    size = 0;
    break;
  default:
    fprintf(stderr, switch_error_string, "format", "format2size", format);
    exit(2);
  }

  return size;
}

bool streq(const char* a, const char* b) { 
  return (strcmp(a, b) == 0);
} 

bool streqprefix(const char* a, const char* b) { 
  return (strncmp(a, b, strlen(b) ) == 0);
}

void get_range(char* str, uint64_t *from, uint64_t* to) {
  char* from_str;
  char* to_str;

  from_str = strstr(str, "=");
  if (from_str == NULL) {
    usage(gbl.progname);
    fprintf(stderr, "Invalid pc/ea given to -pc/-ea flag.\n");
    exit(1);
  } else {
    *from = strtoull(from_str + 1, NULL, 16);
  }

  to_str = strstr(str, ",");
  if (to_str != NULL) {
    *to = strtoull(to_str + 1, NULL, 16);
  }
}

int is_valid_cpu(int cpuid) {
  return (cpuid >= 0 && cpuid <= MAX_CPUID);
}

void get_cpu_range(char* str) {
  int cpuid, prev_cpuid;
  int i;

  for (i = 0; i <= MAX_CPUID; i++) {
    gbl.cpu[i] = 0;		 // -cpu
  }

  str = strchr(str, '=');
  if (str == NULL) {
    usage(gbl.progname);
    fprintf(stderr, "Error: invalid -cpu id given.\n");
    exit(1);
  }

  str++;
  while (isdigit(str[0])) {
    cpuid = strtol(str, &str, 10);
    if (is_valid_cpu(cpuid) == 0) {
      fprintf(stderr, "Error: invalid cpuid %d.\n", cpuid);
      exit(1);
    }
    prev_cpuid = cpuid;

    if (str[0] == '-') {
      str++;
      if (isdigit(str[0])) {
	cpuid = strtol(str, &str, 10);
	if (is_valid_cpu(cpuid) == 0) {
	  fprintf(stderr, "Error: invalid cpuid %d.\n", cpuid);
	  exit(1);
	}
      }
    }

    for (i = prev_cpuid; i <= cpuid; i++) {
      gbl.cpu[i] = 1;
    }

    str++;
  }
}

// range_ok(pc, frompc, topc);
// range_ok(ea, fromea, toea);
bool in_range(const uint64_t x, const uint64_t a, const uint64_t b) {
  if (a == 0 && b == 0) {               // process all records
    return true;
  } else if (x == RSTF_NOADDR) {
    return false;		        // invalid x (address)
  } else {
    if (a != 0 && b == 0) {             // process only x=a
      if (x == a) {
	return true;
      }
    } else if (a != 0 && b != 0) {      // process a<=x<=b
      if (x >= a && x <= b) {
	return true;
      }
    } else if (a == 0 && b != 0) {      // error
      // should never get here though...
      fprintf(stderr, "Invalid pc/ea given to -pc/-ea flag.\n");
      exit(1);
    }
  }

  return false;
}

void print_counts(FILE* outfp) {
  if (gbl.skipInstrs) {
    gbl.rcount += gbl.skipInstrsRecs;
  }

  fprintf(outfp, "\n");
  if (gbl.rcount == gbl.icount) {
    fprintf(outfp, "Counted: %lld instructions\n", gbl.icount);
  } else {
    fprintf(outfp, "Counted: %lld records\n\n", gbl.rcount);

    fprintf(outfp, "         %lld instruction recs\n", gbl.icount);
    fprintf(outfp, "         %lld header recs\n", gbl.headercount);
    fprintf(outfp, "         %lld traceinfo recs\n", gbl.traceinfocount);
    fprintf(outfp, "         %lld tlb recs\n", gbl.tlbcount);
    fprintf(outfp, "         %lld thread recs\n", gbl.threadcount);
    fprintf(outfp, "         %lld preg recs\n", gbl.pregcount);
    fprintf(outfp, "         %lld trap recs\n", gbl.trapcount);
    fprintf(outfp, "         %lld trapexit recs\n", gbl.trapexitcount);
    fprintf(outfp, "         %lld cpu recs\n", gbl.cpucount);
    fprintf(outfp, "         %lld dma recs\n", gbl.dmacount);
    fprintf(outfp, "         %lld snoop recs\n", gbl.snoopcount);
    fprintf(outfp, "         %lld delim recs\n", gbl.delimcount);
    fprintf(outfp, "         %lld physaddr recs\n", gbl.physaddrcount);
    fprintf(outfp, "         %lld pavadiff recs\n", gbl.pavadiffcount);
    fprintf(outfp, "         %lld rfs_sechdr recs\n", gbl.rfs_section_header_count);
    fprintf(outfp, "         %lld rfs_cachewarming recs\n", gbl.cachewarming_count);
    fprintf(outfp, "         %lld rfs_bpwarming recs\n", gbl.bpwarming_count);
    fprintf(outfp, "         %lld filemarker recs\n", gbl.filemarkercount);
    fprintf(outfp, "         %lld recnum recs\n", gbl.recnumcount);
    fprintf(outfp, "         %lld string recs\n", gbl.stringcount);
    fprintf(outfp, "         %lld status recs\n", gbl.statuscount);
    fprintf(outfp, "         %lld patch recs\n", gbl.patchcount);
    fprintf(outfp, "         %lld regval recs\n", gbl.regvalcount);
    fprintf(outfp, "         %lld memval64 recs\n", gbl.memval64count);
    fprintf(outfp, "         %lld memval128 recs\n", gbl.memval128count);
    fprintf(outfp, "         %lld bustrace recs\n", gbl.bustracecount);
    fprintf(outfp, "         %lld process recs\n", gbl.processcount);
    fprintf(outfp, "         %lld devidstr recs\n", gbl.devidstrcount);
    fprintf(outfp, "         %lld timesync recs\n", gbl.timesynccount);
    fprintf(outfp, "         %lld zero recs\n", gbl.zerocount);
  }

  if (gbl.unknowncount) {
    fprintf(outfp, "         %lld unknown recs\n\n", gbl.unknowncount);
  } else {
    fprintf(outfp, "\n");
  }

  if (gbl.skipRecs) {
    fprintf(outfp, "         %lld recs skipped (not counted)\n", gbl.skipRecs);
  }
  if (gbl.skipInstrs) {
    fprintf(outfp, "         %lld instruction recs skipped (counted)\n",
	    gbl.skipInstrs);
  }
}

