// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: main.C
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

#include "read_symbols.h"
#include "trconv.H"

#define BUFFER_SIZE (128 << 10)

int process_buffer(Trace* itrace, Trace* otrace,
		   void* itr_buf, void* otr_buf,
		   int start, int ntr) {
  int i;
  static int buffer_instrs = 0;
  uint64_t prev_icount;
  int curcpu = -1;
  void* useless = itr_buf; // no CC warnings

  for (i = start;
       i < ntr && gbl.rcount < gbl.maxRecs && gbl.icount < gbl.maxInstrs;
       i++) {
    itrace->count();
    
    curcpu = itrace->getCpuID();
    if (curcpu == -1 || gbl.cpu[curcpu] == 1) {
      if (in_range(itrace->get_pc(), gbl.frompc, gbl.topc) &&
	  in_range(itrace->get_ea(), gbl.fromea, gbl.toea)) {
	prev_icount = gbl.icount;
	// -patchcleanrst, -pc_pavadiff, -ea_pavadiff done in count()

	// these records should be processed...
	if (!gbl.countOnly) {
	  // only check for instruction opcode errors?
	  if (gbl.checkError) {
	    if (itrace->check_ihash_error()) {
	      fprintf(stderr, "IHash Error (#%llu ih=%d): "
		      "Incorrect ihash value in input file.\n",
		      gbl.rcount - 1 + gbl.skipRecs, itrace->get_ihash());
	    }
	  } else /* if not gbl.checkError */ {
	    // is ihash valid?
	    if (gbl.checkIHash) {
	      // a valid nonzero ihash is assumed valid
	      if (itrace->check_ihash_error() == 0) {
		if (itrace->get_ihash() >= SPIX_SPARC_IOP_BN) {
		  gbl.checkIHash = false;
		}
	      } else {                           // ERROR!!!
		fprintf(stderr,
			"\nIHash Error (#%llu ih=%d): "
			"Correcting ihash values in output.\n\n",
			gbl.rcount - 1 + gbl.skipRecs, itrace->get_ihash());
		gbl.checkIHash = false;
		gbl.genIHash = true;             // generate ihash values
	      }
	    } // if gbl.checkIHash

	    // generate ihash?
	    if (gbl.genIHash) {
	      itrace->gen_ihash();
	    }

	    // print or convert trace?
	    if (gbl.totype == NONE) {            // then we're printing
	      uint64_t idx;

	      if (gbl.reorderIns) {
		idx = gbl.icount - 1 - gbl.skipInstrs;
	      } else if (gbl.reorderNoIns) {
		idx = gbl.rcount - gbl.icount +
		  gbl.skipRecs + gbl.skipInstrsRecs;
	      } else {
		idx = gbl.rcount - 1 + gbl.skipRecs + gbl.skipInstrsRecs;
	      }

	      if (gbl.record) {
		itrace->print_rec(idx);
	      } else if (gbl.disassembly) {
		itrace->print_dasm(idx);
	      } else {
		itrace->print_verb(idx);
	      }
	    } else if (gbl.fromtype == RST && gbl.totype == RST) {
	      otrace->copy_to_rst(itrace->copy_from_rst());
	    } else {                             // then we're converting
	      itrace->convert_to_master();
	    
	      if (prev_icount != gbl.icount) {   // instruction converted?
		otrace->convert_from_master(itrace->get_master());
	      }
	    }
	  } // checkError?
	} // if !gbl.countOnly

	if ((gbl.totype != NONE && prev_icount != gbl.icount) ||
	    (gbl.fromtype == RST && gbl.totype == RST)) {
	  otrace->inc_tr();
	  buffer_instrs++;

	  if (buffer_instrs == BUFFER_SIZE) {
	    otrace->reset_tr();
	    fwrite(otr_buf, gbl.tosize, buffer_instrs, gbl.outfp);
	    buffer_instrs = 0;
	  }
	}
      } // in_range pc, ea?
    }

    itrace->inc_tr();
  }

  return buffer_instrs;
}

void process_trace(Trace* itrace, Trace* otrace,
		   void* itr_buf, void* otr_buf) {
  int i, ntr, buffer_instrs;

  itrace->set_tr(itr_buf);
  if (otrace != NULL) {
    otrace->set_tr(otr_buf);
  }

  if (gbl.skipRecs) {

    if (0 && (gbl.infp != stdin)) {
      off_t offset;
      off_t filesize;
  
      fseeko(gbl.infp, 0, SEEK_END);
      filesize = ftello(gbl.infp);

      offset = gbl.skipRecs * gbl.fromsize;

      if (offset < filesize) {
	fseeko(gbl.infp, offset, SEEK_SET);
      } else {
	fprintf(stderr, "Fewer than %lld records in file '%s' (%lld).\n",
		gbl.skipRecs, gbl.infile, filesize / gbl.fromsize);
	exit(2);
      }
    } else {
      master_64bit_trace_t *buf;

      buf = (master_64bit_trace_t*) malloc(BUFFER_SIZE *
					   sizeof(master_64bit_trace_t));
	
      for (i = 0; i < gbl.skipRecs / BUFFER_SIZE; i++) {
	if (fread(buf, gbl.fromsize, BUFFER_SIZE, gbl.infp) < BUFFER_SIZE) {
	  fprintf(stderr, "Fewer than %lld records in file '%s'.\n",
		  gbl.skipRecs, gbl.infile);
	  exit(2);
	  if (gbl.fromtype == RST) {
	    rstf_unionT * ru = (rstf_unionT *) buf;
	    if (ru->proto.rtype == RSTHEADER_T) {
	      if (ru->header.majorVer*1000+ru->header.minorVer <= 2011) {
		gbl.rstf_pre212 = true;
	      }
	    } // if rstheader
	  } // if fromtype==rst
	} // if not end-of-file
      } // for skip recs

      if (fread(buf, gbl.fromsize, (uint32_t)(gbl.skipRecs % BUFFER_SIZE), gbl.infp) <
	  gbl.skipRecs % BUFFER_SIZE) {
	fprintf(stderr, "Fewer than %lld records in file '%s'.\n",
		gbl.skipRecs, gbl.infile);
	exit(2);
      }

      free(buf);
    }
  }

  else if (gbl.skipInstrs) {
    // if from type is rst, first record must be rstheader
      
    while ((ntr = fread(itr_buf, gbl.fromsize, BUFFER_SIZE, gbl.infp))) {
      if (gbl.fromtype == RST) {
	rstf_unionT * ru = (rstf_unionT *) itr_buf;
	if (ru->proto.rtype == RSTHEADER_T) {
	  if (ru->header.majorVer*1000+ru->header.minorVer <= 2011) {
	    gbl.rstf_pre212 = true;
	  }
	}
      }
      for (i = 0; gbl.icount < gbl.skipInstrs && i < ntr; i++) {
	itrace->count();                           // -patchcleanrst done here
	itrace->inc_tr();
      }

      if (gbl.icount == gbl.skipInstrs) {
	break;
      }

      itrace->reset_tr();
    }

    buffer_instrs = process_buffer(itrace, otrace, itr_buf, otr_buf, i, ntr);

    if (gbl.verify) {
      itrace->verify();
    }

    itrace->reset_tr();

    gbl.skipInstrsRecs = gbl.rcount;
    gbl.rcount = 0;
    gbl.icount = 0;
  }

  while (gbl.rcount < gbl.maxRecs &&
         gbl.icount < gbl.maxInstrs &&
         (ntr = fread(itr_buf, gbl.fromsize, BUFFER_SIZE, gbl.infp))) {
    buffer_instrs = process_buffer(itrace, otrace, itr_buf, otr_buf, 0, ntr);

    if (gbl.verify) {
      itrace->verify();
    }

    itrace->reset_tr();
  }

  // any leftover instrs to fwrite...?
  if (buffer_instrs) {
    fwrite(otr_buf, gbl.tosize, buffer_instrs, gbl.outfp);
  }

  if (gbl.verbose || gbl.countOnly) {
    print_counts(gbl.msgfp);
  }
}

int main(int argc, char *argv[]) {
  void* itr_buf;
  void* otr_buf;
  Trace* itrace;
  Trace* otrace;
  rtf99 itr_rtf99, otr_rtf99;
  Shade5 itr_shade5, otr_shade5;
  Shade6x32 itr_shade6x32, otr_shade6x32;
  Shade6x64 itr_shade6x64, otr_shade6x64;
  Master itr_master, otr_master;
  RSTF_Union itr_rstf_union, otr_rstf_union;
  
  init_globals(argv);
  parse_args(argc, argv);

  // make input trace buffer
  itr_buf = calloc(BUFFER_SIZE, gbl.fromsize);
  if (itr_buf == NULL) {
    fprintf(stderr,
	    "Could not allocate memory for itr_buf[] in main().\n");
    exit(2);
  }

  // make output trace buffer, if conversion specified
  if (gbl.totype != NONE) {
    otr_buf = calloc(BUFFER_SIZE, gbl.tosize);
    if (otr_buf == NULL) {
      fprintf(stderr,
	      "Could not allocate memory for otr_buf[] in main().\n");
      exit(2);
    }
  }

  switch (gbl.fromtype) {
  case RTF99:
    itrace = &itr_rtf99;
    break;
  case SHADE5:
    itrace = &itr_shade5;
    break;
  case SHADE6x32:
    itrace = &itr_shade6x32;
    break;
  case SHADE6x64:
    itrace = &itr_shade6x64;
    break;
  case MASTER64:
    itrace = &itr_master;
    break;
  case RST:
    itrace = &itr_rstf_union;
    break;
  case NONE:
    usage(argv[0]);
    exit(1);
  default:
    fprintf(stderr, switch_error_string, "fromtype", "main()", gbl.fromtype);
    exit(2);
  }

  switch (gbl.totype) {
  case RTF99:
    otrace = &otr_rtf99;
    break;
  case SHADE5:
    otrace = &otr_shade5;
    break;
  case SHADE6x32:
    otrace = &otr_shade6x32;
    break;
  case SHADE6x64:
    otrace = &otr_shade6x64;
    break;
  case MASTER64:
    otrace = &otr_master;
    break;
  case RST:
    otrace = &otr_rstf_union;
    break;
  case NONE:
    otrace = NULL;
    break;
  default:
    fprintf(stderr, switch_error_string, "totype", "main()", gbl.totype);
    exit(2);
  }

  process_trace(itrace, otrace, itr_buf, otr_buf);
    
  return 0;
}  // main()
