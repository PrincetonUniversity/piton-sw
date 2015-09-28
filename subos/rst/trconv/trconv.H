/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: trconv.H
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
// OpenSPARC T2 Processor File: trconv.H
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
// File: trconv.H
//
// Description: Part of trconv library file, trconv.o, for printing and
//		converting execution traces
//
// How to add another RST record type to trconv:
//
// This file, trconv.H, is the main file supporting the class
// definitions of each trace record type.  It includes a global struct
// "gbl" containing variables used throughout trconv, including the
// counts of each record type.  Also here is the base class "Trace"
// containing the pure virtual functions you will need to define in
// your new derived class.
//
// To create a new derived class, copy one of the existing classes,
// and modify it accordingly.  RSTF_Traceinfo is a simple example;
// RSTF_Instr is a more elaborate example.
//
// All RST traces are first processed by RSTF_Union.  In
// RSTF_Union the rtype of each RST record is examined, and the
// corresponding class member function is called.  The protected member
// function RSTF_Union::get_rst_type() determines to RST rtype and
// returns a pointer to the corresponding RST class.
//
// Finally in init_globals(char *argv[]) in trconv.C, initialize
// the new counter variable to 0.  And in print_counts(FILE* outfp) in
// trconv.C add an fprintf(stdout, ...) statement to print the count
// of the new record type.
//
// Cross you fingers, recompile (ignore the warnings about "master is
// defined but not used" and various member functions being "too large
// and will not be expanded inline", they're normal), and run...

#pragma ident "@(#)  trconv.H  1.19: 11/06/07 11:35:08 @(#)"

#include <assert.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
#include <time.h>

#include <string>
#include <map>

#define RSTF_NOADDR -1

#include "rstf/rstf.h"
#include "rstf/rstf_deprecated.h"
#if defined(ARCH_AMD64)
#include "rstf/rstf_convert.h"
#endif

#include "MISC.h"
#include "ITYPES.h"

#define MAX_CPUID  (1024)
#define NUM_VERIFY (8)

#define PSTATE_AM (0x8)

extern char switch_error_string[];

enum { 
    NONE = 0, 
    RTF99,
    SHADE5, 
    SHADE6x32, 
    SHADE6x64,
    MASTER64,
    RST
};

typedef struct {
  // format options
  int fromtype;               // -from FX
  int totype;                 // -to FX

  // selection options
  uint64_t maxRecs;           // -n N
  uint64_t maxInstrs;         // -n Ni
  uint64_t skipRecs;          // -s N
  uint64_t skipInstrs;        // -s Ni
  uint64_t frompc;            // -pc=pc1[,pc2]   // -frompc ?
  uint64_t topc;              //                 // -topc ?
  uint64_t fromea;            // -ea=ea1[,ea2]   // -fromea ?
  uint64_t toea;              //                 // -toea ?
  char cpu[MAX_CPUID + 1];    // -cpu=
  uint16_t pstate[MAX_CPUID + 1];	// monitor pstate.am per cpu

  // printing options
  bool record;		// -a
  bool disassembly;		// -d
  bool verbose;		// -x
  bool showIdx;		// -nid
  bool countOnly;		// -c
#ifdef _PRINT_PA
  bool printPA;		// -pa
#endif // _PRINT_PA
#ifdef _VALUE_TRACE
  bool valueTrace;            // -vt
#endif // _VALUE_TRACE
  FILE* msgfp;                // -msg ?
  bool show_syms;
  symbol_table_t symbol_table;

  // verification options
  bool verify;		// -nv
  bool checkError;		// -e
  bool fast;			// -fast

  // rst options
  bool onlyIns;		// -i
  bool reorderIns;		// -ic
  bool noIns;			// -ni
  bool reorderNoIns;		// -nic
  bool branch;		// -branch  (-nobranch?)
  bool pc_pavadiff;		// -pc_pavadiff  (-nopc_pavadiff?)
  bool ea_pavadiff;		// -ea_pavadiff  (-noea_pavadiff?)

  // patching options
  bool clean;			// -patchcleanrst
  bool genIHash;		// -patchihash

  // output options
  FILE* infp;                 // [input-file]
  FILE* outfp;                // -stdout || -o

  // convenient variables
  char* progname;
  char* infile;
  int fromsize;
  int tosize;

  bool checkIHash;

  uint64_t icount, rcount;   // instr count & total record count.
  uint64_t skipInstrsRecs;

  // rst-related

  bool rstf_pre212;

  // rst types
  uint64_t headercount, 
  // instrcount, ---> use icount
  //asicount, 
    traceinfocount, // ASI_T == TRACEINFO_T, TRACEINFO_T is to replace ASI_T
    tlbcount, 
    threadcount, 
    pregcount, 
    trapcount,
    trapexitcount, 
    trappinginstrcount,
    cpucount, 
    dmacount, 
    snoopcount,
    tsb_access_count,
    rfs_section_header_count,
    bpwarming_count,
    cachewarming_count,
    delimcount, // combination of leftdelim & rightdelim
    physaddrcount, 
    pavadiffcount, 
  //nullrec??? // null record, can be ignored
    filemarkercount,
  //hwinfocount,
    recnumcount,
    stringcount, // combination of strdesc & strcont
    statuscount, 
    patchcount, 
    regvalcount, 
    memval64count,
    memval128count,
    bustracecount,
    processcount,
    timesynccount,
    devidstrcount,
    zerocount,
    unknowncount;

#ifdef _PRINT_PA
  bool ea_pavadiff_valid[MAX_INSTR_CPUID];
  uint64_t ea_pavadiff_value[MAX_INSTR_CPUID];
  bool pc_pavadiff_valid[MAX_INSTR_CPUID];
  uint64_t pc_pavadiff_value[MAX_INSTR_CPUID];
#endif	// _PRINT_PA

    std::map<int, std::string> devid2string;
} Globals_T;

extern Globals_T gbl;

extern char usage_string[];

void usage(char progName[]);

void parse_args(int argc, char *argv[], bool debug = false);

void init_globals(char *argv[]);

int format2int(const char str[]);

int format2size(int format);

bool streqprefix(const char* a, const char* b);

bool streq(const char* a, const char* b);

void get_pc_range(char* pc_str);

void get_range(char* str, uint64_t *from, uint64_t* to);

void get_cpu_range(char* pc_str);

bool in_range(const uint64_t x, const uint64_t a, const uint64_t b);

void print_counts(FILE* outfp);

// base class for all trace structs
class Trace {
public:
    // increments global record and instruction counts
    virtual void count() {
	gbl.rcount++;
	gbl.icount++;
    }

    // prints record fields without disassembly of instruction records
    virtual void print_rec(uint64_t idx) = 0;

    // prints record disassenbly
    virtual void print_dasm(uint64_t idx) {
	print_rec(idx);
    }  // Trace::print_dasm()

    // prints verbose record disassembly
    virtual void print_verb(uint64_t idx) {
	print_rec(idx);
    }  // Trace::print_verb()

    // converts record type to Tmaster64
    virtual void convert_to_master() {
	// not converted
    }  // Trace::convert_to_master()

    // converts master to record type
    virtual void convert_from_master(Tmaster64* master) {
      Tmaster64* useless = master;
	// not converted
    }  // Trace::convert_from_master()

    // sets ihash field to correct value for instruction records
    virtual void gen_ihash() {
	// not generated
    }  // Trace::gen_ihash()

    // verifies ihash value of instruction records;
    // returns 1 on error, 0 otherwise
    virtual int check_ihash_error() {
	return 0;
    }  // Trace::check_ihash_error()

    // verifies pc values of instruction records; prints message on error
    virtual void verify() {
	// not verified
    }  // Trace::verify()

    // returns RSTF_NOADDR for non-instruction, non-trap types
    virtual uint64_t get_pc() {
	return RSTF_NOADDR;
    }  // Trace::get_pc()

    // returns RSTF_NOADDR for non-instruction types
    virtual uint64_t get_ea() {
	return RSTF_NOADDR;
    }  // Trace::get_ea()

    // returns ihash value in trace record
    virtual int get_ihash() {
	return 0;
    }  // Trace::get_ihash()

    // increments trace pointer to next trace record in trace buffer
    virtual void inc_tr() = 0;

    // sets trace pointer to ptr; optionally sets tr_orig to ptr also
    virtual void set_tr(void* ptr, bool set_orig = true) = 0;

    // resets trace pointer to tr_orig
    virtual void reset_tr() = 0;

    // returns pointer to static protected data member this_master
    virtual Tmaster64* get_master() {
	return &this_master;
    }  // Trace::get_master()

    // used for piping to and from rst trace types
    virtual rstf_unionT* copy_from_rst() {
	// do nothing (except for RSTF_Union::copy_from_rst() )
	return NULL;
    }

    // used for piping to and from rst trace types
    virtual void copy_to_rst(rstf_unionT* from) {
      rstf_unionT* useless = from;
	// do nothing (except for RSTF_Union::copy_to_rst() )
    }

    // used to verify branch targets in RSTF disassembly printouts
    int check_branch_ea(uint64_t dis_ea, uint64_t tr_ea) {
	if (dis_ea != tr_ea) {
	    if ((dis_ea ^ tr_ea) != (0xffffffff00000000ull)) {
		fprintf(stderr, "trconv: warning: branch target != effective address "
			"(Rec #%llu: 0x%llx != 0x%llx)\n",
			gbl.rcount - 1, dis_ea, tr_ea);
		return 1;
	    }
	}

	return 0;
    }

  virtual int getCpuID() {
    return -1;
  }

protected:
    // static data member, shared by all derived classes
    static Tmaster64 this_master;

};  // Trace

//======================================================================
//======================================================================
class RSTF_Header : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.headercount++;
	if (tr->majorVer*1000 + tr->minorVer <= 2011) {
	  gbl.rstf_pre212 = true;
	}
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "header  : majorVer=%d minorVer=%d %s",
		tr->majorVer, tr->minorVer, tr->header_str);
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Header::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Header::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_headerT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Header::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Header::reset_tr()

protected:
    rstf_headerT* tr;
    rstf_headerT* tr_orig;
};  // RSTF_Header

//======================================================================
//======================================================================
class RSTF_Instr : public Trace {
public:
  virtual void count() {
    gbl.rcount++;
    gbl.icount++;

    if (gbl.clean == true) {
      if (!tr->ea_valid){
	tr->ea_va = RSTF_NOADDR;
      }
    } 
  }  // RSTF_Instr::count()

  virtual void print_dasm(uint64_t idx) {
    char dis_string[80];
    uint64_t ea_va = -1;

    int cpuid = getCpuID();

    sprintDiss(dis_string, tr->instr, tr->pc_va);

    int ihash = spix_sparc_iop(SPIX_SPARC_V9, &tr->instr);
    // if (ih_isbranch(tr->ihash) || tr->ihash == SPIX_SPARC_IOP_CALL) {
    if (ih_isbranch(ihash) || ihash == SPIX_SPARC_IOP_CALL) {
      if (gbl.branch && tr->bt) {
	ea_va = getCtiEa(tr->instr, ihash, tr->pc_va);

	if (gbl.pstate[cpuid] & PSTATE_AM) {
	  ea_va &= 0xffffffff;
	}

	if (!tr->an) {
          check_branch_ea(ea_va, tr->ea_va);
        }
      }
    }

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "instr   : cpuid=%d ", cpuid);

    if (tr->hpriv) {
      fprintf(gbl.outfp, "h ");
    } else if (tr->pr) {
      fprintf(gbl.outfp, "p ");
    } else {
      fprintf(gbl.outfp, "u ");
    }

    fprintf(gbl.outfp, "[0x%016llx] ", tr->pc_va);
    if (gbl.show_syms) {
	char		*symbol;
	uint64_t	offset;
	if (gbl.symbol_table.search_symbol_table(tr->pc_va, symbol, offset)) {
	    fprintf(gbl.outfp, "(%s+0x%llx) ", symbol, offset);
	}
	else {
	    fprintf(gbl.outfp, "(???+???) ", symbol, offset);
	}
    }
    fprintf(gbl.outfp, "%-32s", dis_string);

    if (ih_iscti(ihash)) {
      if (tr->bt) {
	fprintf(gbl.outfp, "T ");
      } else { 
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

#ifdef _PRINT_PA
    if (gbl.printPA) {
      if (!tr->an) {
	if (tr->ea_valid) {
	  fprintf(gbl.outfp, "v[0x%016llx] ", tr->ea_va);

	  if ((ih_isload(ihash) || ih_isstore(ihash)) &&
	      tr->tr == 0) {
	    if (gbl.ea_pavadiff_valid[cpuid]) {
	      fprintf(gbl.outfp, "p[0x%016llx] ", tr->ea_va + gbl.ea_pavadiff_value[cpuid]);
	    }
	  } else {
	    if (gbl.pc_pavadiff_valid[cpuid]) {
	      fprintf(gbl.outfp, "p[0x%016llx] ", tr->ea_va + gbl.pc_pavadiff_value[cpuid]);
	    }
	  }
	} else if (tr->bt) {	// so it must be a branch...(?)
	  fprintf(gbl.outfp, "<0x%016llx> ", tr->ea_va);
	}
      }
    } else 
#endif //_PRINT_PA
    {
      if (!tr->an) {
	if (tr->ea_valid) {
	  fprintf(gbl.outfp, "[0x%016llx] ", tr->ea_va);
	} else if (tr->bt) {	// so it must be a branch...(?)
	  fprintf(gbl.outfp, "<0x%016llx> ", tr->ea_va);
	}
      }
    }

    if (tr->an) {
      fprintf(gbl.outfp, "an ");
    }

    if (tr->tr) {
      fprintf(gbl.outfp, "tr "); 
    }

    fprintf(gbl.outfp, "\n");
  }  // RSTF_Instr::print_dasm()

  virtual void print_rec(uint64_t idx) {
    if (gbl.showIdx) {
      fprintf(gbl.outfp, "%6lld ", idx);
    }

    // int ihash = spix_sparc_iop(SPIX_SPARC_V9, &tr->instr);
    fprintf(gbl.outfp, "instr   : cpuid=%d ", gbl.rstf_pre212? tr->cpuid: rstf_instrT_get_cpuid(tr));
    fprintf(gbl.outfp, "pc=0x%016llx ", tr->pc_va);
    fprintf(gbl.outfp, "instr=0x%08x ", tr->instr);
    // fprintf(gbl.outfp, "ihash=%-3d ", ihash);
    fprintf(gbl.outfp, "hpriv=%d ", tr->hpriv);
    fprintf(gbl.outfp, "pr=%d ", tr->pr);
    fprintf(gbl.outfp, "bt=%d ", tr->bt);
    fprintf(gbl.outfp, "ea=0x%016llx ", tr->ea_va);
    fprintf(gbl.outfp, "ev=%d ", tr->ea_valid);
    fprintf(gbl.outfp, "an=%d ", tr->an);
    fprintf(gbl.outfp, "tr=%d ", tr->tr); 
    fprintf(gbl.outfp, "\n");
  }  // RSTF_Instr::print_rec()

  virtual void print_verb(uint64_t idx) {
    char dis_string[80];
    uint64_t ea_va = -1;
    int cpuid = gbl.rstf_pre212? tr->cpuid: rstf_instrT_get_cpuid(tr);

    sprintDiss(dis_string, tr->instr, tr->pc_va);
    int ihash = spix_sparc_iop(SPIX_SPARC_V9, &tr->instr);
    if (ih_isbranch(ihash) || ihash == SPIX_SPARC_IOP_CALL) {
      if (gbl.branch && tr->bt) {
	ea_va = getCtiEa(tr->instr, ihash, tr->pc_va);

	if (gbl.pstate[cpuid] & PSTATE_AM) {
	  ea_va &= 0xffffffff;
	}

	if (!tr->an) {
	  check_branch_ea(ea_va, tr->ea_va);
	}
      }
    }

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "instr   : cpuid=%d ", cpuid);

    if (tr->hpriv) {
      fprintf(gbl.outfp, "h ");
    } else if (tr->pr) {
      fprintf(gbl.outfp, "p ");
    } else {
      fprintf(gbl.outfp, "u ");
    }

    fprintf(gbl.outfp, "[0x%016llx] ", tr->pc_va);
    fprintf(gbl.outfp, "%-32s", dis_string);
    fprintf(gbl.outfp, "(0x%08x) ", tr->instr);
    fprintf(gbl.outfp, "%3d ", ihash);

    if (ih_iscti(ihash)) {
      if (tr->bt) {
	fprintf(gbl.outfp, "T ");
      } else { 
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

#ifdef _PRINT_PA
    if (gbl.printPA) {
      fprintf(gbl.outfp, "v[0x%016llx]", tr->ea_va);
      if (!tr->ea_valid) {
	fprintf(gbl.outfp, "x ");
      } else {
	fprintf(gbl.outfp, " ");
      }

      if ((ih_isload(ihash) || ih_isstore(ihash)) &&
	  tr->tr == 0) {
	if (gbl.ea_pavadiff_valid[cpuid]) {
	  fprintf(gbl.outfp, "p[0x%016llx] ", tr->ea_va + gbl.ea_pavadiff_value[cpuid]);
	}
      } else {
	if (gbl.pc_pavadiff_valid[cpuid]) {
	  fprintf(gbl.outfp, "p[0x%016llx] ", tr->ea_va + gbl.pc_pavadiff_value[cpuid]);
	}
      }
    } else 
#endif // _PRINT_PA
    {
      fprintf(gbl.outfp, "[0x%016llx]", tr->ea_va);
      if (!tr->ea_valid) {
	fprintf(gbl.outfp, "x ");
      } else {
	fprintf(gbl.outfp, " ");
      }
    }

    if (tr->an) {
      fprintf(gbl.outfp, "an ");
    }

    if (tr->tr) {
      fprintf(gbl.outfp, "tr "); 
    }

    fprintf(gbl.outfp, "\n");
  }  // RSTF_Instr::print_verb()

  virtual void convert_to_master() {
    this_master.tr_pc_va = tr->pc_va;
    this_master.tr_ea_va = tr->ea_va ;
    this_master.tr_tid = 0;
    this_master.tr_ih = spix_sparc_iop(SPIX_SPARC_V9, &tr->instr);
    this_master.tr_reserved0 = 0;
    this_master.tr_taken = tr->bt; 
    this_master.tr_annulled = tr->an; 
    this_master.tr_i = tr->instr;
    this_master.tr_reserved1 = 0;
    this_master.tr_pc_pa = 0;
    this_master.tr_ea_pa = 0;
    this_master.tr_context = 0;
    //this_master.tr_traceinfo = 0;
    this_master.tr_got_trap = tr->tr;
    this_master.tr_privmode = tr->pr;
    this_master.tr_va_valid = tr->ea_valid;
  }  // RSTF_Instr::convert_to_master()

  virtual void convert_from_master(Tmaster64* master) {
    tr->rtype = INSTR_T;
    tr->notused = 0;
    tr->ea_valid = master->tr_va_valid;
    tr->tr = master->tr_got_trap;
    tr->pr = master->tr_privmode;
    tr->bt = master->tr_taken;
    tr->an = master->tr_annulled;
    // tr->ihash = master->tr_ih;
    tr->instr = master->tr_i;
    tr->pc_va = master->tr_pc_va;
    tr->ea_va = master->tr_ea_va;
  }  // RSTF_Instr::convert_from_master()

  virtual void gen_ihash() {
    // tr->ihash = getIHash(tr->instr);
  }  // RSTF_Instr::gen_ihash()

  virtual int check_ihash_error() {
#if 0
    if (tr->ihash != getIHash(tr->instr)) {
      return 1;
    }
#endif
    return 0;
  }  // RSTF_Instr::check_ihash_error()

  virtual void verify() {
    rstf_instrT* vtr = tr - NUM_VERIFY;    
    int i;

    for (i = 0; i < NUM_VERIFY - 1; i++) {
      if (vtr[i].rtype == INSTR_T) {
	if (vtr[i].pc_va % 4 != 0 && RSTF_IS_BADADDR(vtr[i].pc_va) == 0) {
	  fprintf(stderr, "trconv: Error: Incorrect pc value in input file.\n");
	  set_tr(&vtr[i], false);
	  print_verb(gbl.rcount - NUM_VERIFY + i);
	  //exit(2);
	}
      }
    }
  }  // RSTF_Instr::verify()

  virtual uint64_t get_pc() {
    return tr->pc_va;
  }  // RSTF_Instr::get_pc()

  virtual uint64_t get_ea() {
    if (tr->ea_valid) {
      return tr->ea_va;
    }

    return RSTF_NOADDR;
  }  // RSTF_Instr::get_ea()

  virtual int get_ihash() {
    return spix_sparc_iop(SPIX_SPARC_V9, &tr->instr);
  }  // RSTF_Instr::get_ihash()

  virtual void inc_tr() {
    tr++;
  }  // RSTF_Instr::inc_tr()

  virtual void set_tr(void* ptr, bool set_orig = true) {
    tr = (rstf_instrT*) ptr;

    if (set_orig) {
      tr_orig = tr;
    }
  }  // RSTF_Instr::set_tr()

  virtual void reset_tr() {
    tr = tr_orig;
  }  // RSTF_Instr::reset_tr()

  virtual int getCpuID() {
    return gbl.rstf_pre212? tr->cpuid: rstf_instrT_get_cpuid(tr);
  }

protected:
  rstf_instrT* tr;
  rstf_instrT* tr_orig;
};  // RSTF_Instr

#if 0  // deprecated
//======================================================================
//======================================================================
// ASI_T is deprecated, is replaced by TRACEINFO_T with the same enum value.
class RSTF_Asi : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.asicount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	//FIXME should use rstf_traceinfoT, but it is not done yet, stay tune.

	fprintf(gbl.outfp, "asi     :  rtype=%d asi=%d", tr->rtype, tr->asi);
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Asi::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Asi::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_asiT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Asi::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Asi::reset_tr()

protected:
    rstf_asiT* tr;
    rstf_asiT* tr_orig;
};  // RSTF_Asi
#endif

//======================================================================
//======================================================================
class RSTF_Traceinfo : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.traceinfocount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	switch(ti_level->rtype2) {
	case RSTT2_NLEVEL_T:
	  { time_t t = ti_level->time64;
	    fprintf(gbl.outfp, "trinfo  : LEVEL=%d time=%s", ti_level->level, ctime(&t));
	  }
	  break;
	case RSTT2_CPUINFO_T:
	  fprintf(gbl.outfp, "trinfo  : NCPUS=%d mincpuid=%d maxcpuid=%d\n", ti_cpuinfo->numcpus,
		  ti_cpuinfo->min_cpu_id, ti_cpuinfo->max_cpu_id);
	  break;
	case RSTT2_CPUIDINFO_T:
	  fprintf(gbl.outfp, "trinfo  : CPUIDS={ ");
	  int i;
	  for (i=0; i<10; i++) {
	    fprintf(gbl.outfp, "%d,", ti_cpuid->cpuids[i]);
	  }
	  fprintf(gbl.outfp, "}\n");
	  break;

	default:
	  fprintf(gbl.outfp, "Unknown TRACEINFO record\n");
	}
    }  // RSTF_Traceinfo::print_rec()

    virtual void inc_tr() {
	ti_level++;
    }  // RSTF_Traceinfo::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	ti_level = (rstf_traceinfo_levelT*) ptr;
	ti_cpuinfo = (rstf_cpuinfoT*) ptr;
	ti_cpuid = (rstf_cpuidinfoT*) ptr;

	if (set_orig) {
	    tr_orig = ti_level;
	}
    }  // RSTF_Traceinfo::set_tr()

    virtual void reset_tr() {
	ti_level = (rstf_traceinfo_levelT*) tr_orig;
	ti_cpuinfo = (rstf_cpuinfoT*) tr_orig;
	ti_cpuid = (rstf_cpuidinfoT*) tr_orig;
    }  // RSTF_Traceinfo::reset_tr()

protected:
    rstf_traceinfo_levelT* ti_level;
    rstf_cpuinfoT * ti_cpuinfo;
    rstf_cpuidinfoT * ti_cpuid;
    rstf_traceinfo_levelT* tr_orig;
};  // RSTF_Traceinfo

//======================================================================
//======================================================================
class RSTF_Tlb : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.tlbcount++;
    }

    virtual void print_rec(uint64_t idx) {
	uint64_t pa;

	pa = tr->tte_data;
	pa &= (~ 0x1fffULL);
	pa &= 0x7ffffffffffULL;

	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "tlb     : cpuid=%d demap=%d ", getCpuID(), tr->demap);      
	fprintf(gbl.outfp, "type=%d ", tr->tlb_type);      
	//fprintf(gbl.outfp, "valid=%d ", tr->valid);      
	fprintf(gbl.outfp, "index=%-4d ", tr->tlb_index);      
	fprintf(gbl.outfp, "no=%d ", tr->tlb_no);
	//fprintf(gbl.outfp, "state=0x%04x ", tr->state);      
	//fprintf(gbl.outfp, "context=0x%04x ", tr->context);      
	fprintf(gbl.outfp, "tag=0x%016llx ", tr->tte_tag);      
	fprintf(gbl.outfp, "data=0x%016llx ", tr->tte_data);      
	fprintf(gbl.outfp, "pa=0x%llx", pa);      
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Tlb::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Tlb::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_tlbT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Tlb::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Tlb::reset_tr()

    virtual int getCpuID() {
      return gbl.rstf_pre212? tr->cpuid: rstf_tlbT_get_cpuid(tr);
    }

protected:
    rstf_tlbT* tr;
    rstf_tlbT* tr_orig;
};  // RSTF_Tlb

//======================================================================
//======================================================================
class RSTF_Thread : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.threadcount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "thread  :  rtype=%d", tr->rtype);    
	//fprintf(gbl.outfp, "thread  :  rtype=%d newtid=%d newpid=%d", 
	//	tr->rtype, tr->newtid, tr->newpid);    
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Thread::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Thread::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_threadT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Thread::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Thread::reset_tr()

protected:
    rstf_threadT* tr;
    rstf_threadT* tr_orig;
};  // RSTF_Thread

inline void
decode_pstate_bits (FILE* const out, uint16_t pstate)
{
    fprintf (out, "(");
    if ((pstate & 0x800) != 0) {	// Cheetah specific
	fprintf(out, " IG");
    }
    if ((pstate & 0x400) != 0) {	// Cheetah specific
	fprintf(out, " MG");
    }
    if ((pstate & 0x4) != 0) {
	fprintf(out, " PRIV");
    }
    if ((pstate & 0x2) != 0) {
	fprintf(out, " IE");
    }
    if ((pstate & 0x1) != 0) {
	fprintf(out, " AG");
    }
    fprintf (out, ") ");
}
//======================================================================
//======================================================================
class RSTF_Trap : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.trapcount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "trap    : cpuid=%d ", getCpuID());
	fprintf(gbl.outfp, "async==%d ", tr->is_async); 
	fprintf(gbl.outfp, "tl=%d ", tr->tl); 
	fprintf(gbl.outfp, "ttype=0x%03x ", tr->ttype); 
	switch (tr->ttype) {

	    case 0x12:
		fprintf(gbl.outfp, "(unimplemented LDD instr) ");
		break;

	    case 0x24: case 0x25: case 0x26: case 0x27:
		fprintf(gbl.outfp, "(clean window) ");
		break;

	    case 0x40: case 0x41: case 0x42: case 0x43:
	    case 0x44: case 0x45: case 0x46: case 0x47:
	    case 0x48: case 0x49: case 0x4A: case 0x4B:
	    case 0x4C: case 0x4D: case 0x4E: case 0x4F:
		fprintf(gbl.outfp, "(interrupt request lvl n) ");
		break;

	    case 0x60:
		fprintf(gbl.outfp, "(interrupt request) ");
		break;

	    case 0x64: case 0x65: case 0x66: case 0x67:
		fprintf(gbl.outfp, "(ITLB miss) ");
		break;

	    case 0x68: case 0x69: case 0x6A: case 0x6B:
		fprintf(gbl.outfp, "(DTLB miss) ");
		break;

	    case 0x80: case 0x81: case 0x82: case 0x83:
	    case 0x84: case 0x85: case 0x86: case 0x87:
	    case 0x88: case 0x89: case 0x8A: case 0x8B:
	    case 0x8C: case 0x8D: case 0x8E: case 0x8F:
	    case 0x90: case 0x91: case 0x92: case 0x93:
	    case 0x94: case 0x95: case 0x96: case 0x97:
	    case 0x98: case 0x99: case 0x9A: case 0x9B:
	    case 0x9C: case 0x9D: case 0x9E: case 0x9F:
		fprintf(gbl.outfp, "(spill normal) ");
		break;
		
	    case 0xA0: case 0xA1: case 0xA2: case 0xA3:
	    case 0xA4: case 0xA5: case 0xA6: case 0xA7:
	    case 0xA8: case 0xA9: case 0xAA: case 0xAB:
	    case 0xAC: case 0xAD: case 0xAE: case 0xAF:
	    case 0xB0: case 0xB1: case 0xB2: case 0xB3:
	    case 0xB4: case 0xB5: case 0xB6: case 0xB7:
	    case 0xB8: case 0xB9: case 0xBA: case 0xBB:
	    case 0xBC: case 0xBD: case 0xBE: case 0xBF:
		fprintf(gbl.outfp, "(spill other) ");
		break;

	    case 0xC0: case 0xC1: case 0xC2: case 0xC3:
	    case 0xC4: case 0xC5: case 0xC6: case 0xC7:
	    case 0xC8: case 0xC9: case 0xCA: case 0xCB:
	    case 0xCC: case 0xCD: case 0xCE: case 0xCF:
	    case 0xD0: case 0xD1: case 0xD2: case 0xD3:
	    case 0xD4: case 0xD5: case 0xD6: case 0xD7:
	    case 0xD8: case 0xD9: case 0xDA: case 0xDB:
	    case 0xDC: case 0xDD: case 0xDE: case 0xDF:
		fprintf(gbl.outfp, "(fill normal) ");
		break;

	    // 0x100 - 0x176 - Tcc instruction executed
	    case 0x100: case 0x101: case 0x102: case 0x103:
	    case 0x108: case 0x109: case 0x10a: case 0x10b:
	    case 0x120: case 0x121: case 0x122: case 0x123:
	    case 0x124: case 0x125: case 0x126: case 0x127:
	    case 0x140:
		fprintf(gbl.outfp, "(tcc instr.) ");
		break;

	    default:
		/* do nothing */
		break;
	}
	fprintf(gbl.outfp, "pstate=0x%03x ", tr->pstate); 
	decode_pstate_bits (gbl.outfp, tr->pstate);
	fprintf(gbl.outfp, "syscall=0x%04x ", tr->syscall); 
	fprintf(gbl.outfp, "pc=0x%016llx ", tr->pc); 
	fprintf(gbl.outfp, "npc=0x%016llx", tr->npc); 
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Trap::print_rec()

    virtual uint64_t get_pc() {
	return tr->pc;
    }  // RSTF_Trap::get_pc()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Trap::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_trapT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Trap::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Trap::reset_tr()

    virtual int getCpuID() {
      return gbl.rstf_pre212? tr->cpuid: rstf_trapT_get_cpuid(tr);
    }

protected:
    rstf_trapT* tr;
    rstf_trapT* tr_orig;
};  // RSTF_Trap

//======================================================================
//======================================================================
class RSTF_Trapexit : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.trapexitcount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "trapexit: cpuid=%d tl=%d ", getCpuID(), tr->tl);
	fprintf(gbl.outfp, "tstate=%d ", tr->tstate);
	//fprintf(gbl.outfp, "pc=0x%016llx ", tr->pc);
	//fprintf(gbl.outfp, "npc=0x%016llx ", tr->npc);
	fprintf(gbl.outfp, "\n"); 
    }  // RSTF_Trapexit::print_rec()

#if 0
    virtual uint64_t get_pc() {
	return tr->pc;
    }  // RSTF_Trapexit::get_pc()
#endif

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Trapexit::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_trapexitT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Trapexit::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Trapexit::reset_tr()

    virtual int getCpuID() {
      return gbl.rstf_pre212? tr->cpuid: rstf_trapexitT_get_cpuid(tr);
    }

protected:
    rstf_trapexitT* tr;
    rstf_trapexitT* tr_orig;
};  // RSTF_Trapexit



//======================================================================
//======================================================================
class RSTF_Regval : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.regvalcount++;
    }

#ifdef _VALUE_TRACE
    virtual void print_rec_valueTrace(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "regval  : ");
	fprintf(gbl.outfp, "cpuid=%d ", getCpuID());
	// fprintf(gbl.outfp, "postInstr=%d ", tr->postInstr);
	for(long i=0; i<2; i++) {
	    vtPrintReg(gbl.outfp, tr->regtype[i], tr->regid[i], tr->reg64[i], i);
	}
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Regval::print_rec()
#endif // _VALUE_TRACE
    virtual void print_rec_normal(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "regval  : ");
	fprintf(gbl.outfp, "cpuid=%d ", getCpuID());
	fprintf(gbl.outfp, "postInstr=%d ", tr->postInstr);
	fprintf(gbl.outfp, "regtype[0]=%d ", tr->regtype[0]);
	fprintf(gbl.outfp, "regid[0]=%d ", tr->regid[0]);
	fprintf(gbl.outfp, "reg64[0]=0x%llx ", tr->reg64[0]);
	fprintf(gbl.outfp, "regtype[1]=%d ", tr->regtype[1]);
	fprintf(gbl.outfp, "regid[1]=%d ", tr->regid[1]);
	fprintf(gbl.outfp, "reg64[1]=0x%llx", tr->reg64[1]);  
	fprintf(gbl.outfp, "\n");
	//fprintf(gbl.outfp, "regnum=%d ", tr->regnum);
	//fprintf(gbl.outfp, "reg32=%d ", tr->reg32);
    }  // RSTF_Regval::print_rec()

    virtual void print_rec(uint64_t idx) {
#ifdef _VALUE_TRACE
	if (gbl.valueTrace) {
	    print_rec_valueTrace(idx);
	} else 
#endif // _VALUE_TRACE
	{
	    print_rec_normal(idx);
	}
    }

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Regval::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_regvalT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Regval::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Regval::reset_tr()

    virtual int getCpuID() {
      return gbl.rstf_pre212? tr->cpuid: rstf_regvalT_get_cpuid(tr);
    }

protected:
    rstf_regvalT* tr;
    rstf_regvalT* tr_orig;
#ifdef _VALUE_TRACE
    virtual void 
    vtPrintIntRegName(FILE *outfp, long regid) 
    {
	if (regid < 0 || regid >= 32) {
	    fprintf(stderr, "trconv: warning: Register number %d should be <32 (Rec #%llu)\n", regid, gbl.rcount);
	}
	static char prefix[5] = "goli"; 
	char toprint[3] = "g0";
	toprint[0] = prefix[(regid/8)];
	toprint[1] = '0' + (regid%8);
	fprintf(outfp, "%%%s ", toprint);
    }

    virtual void
    vtPrintFloatReg(FILE *outfp, long regid, uint64_t reg64, 
        	    long i, char &isQuad, uint64_t &quadWord)
    {
	if (regid >= 0 && regid < 32) {
	    // Single
	    if(isQuad) {
		fprintf(stderr, 
		    "trconv: warning: quad register encountered (#%llu)\n", 
		    gbl.rcount);
	    }
	    float f = (float) reg64;
	    fprintf(outfp, "(Reg %d: %%f%d = %f(0x%llx)) ", i, regid, f, reg64);
	}
	else if (regid < 64) {
	    // Double
	    if(isQuad) {
		fprintf(stderr, 
		    "trconv: warning: quad register encountered (#%llu)\n", 
		    gbl.rcount);
	    }
	    double d = (double) reg64;
	    fprintf(outfp, "(Reg %d: %%d%d = %f(0x%llx)) ", i, ((regid - 32) * 2), d, reg64);
	}
	else {
	    if (regid >= 80) {
		fprintf(stderr, "trconv: warning: regid = %d should have been <80 (Rec #%llu\n", regid, gbl.rcount);
	    }
	    if (i == 0) {
		isQuad = 1;
		quadWord = reg64;
	    }
	    else {
		if(isQuad) {
		    fprintf(stderr, 
			"trconv: warning: quad register encountered (#%llu)\n", 
			gbl.rcount);
		}
		fprintf(outfp, "(Reg 0+1: %%q%d = 0x%016llx%016llx) ", 
		    i, ((regid - 64) * 4), quadWord, reg64);
	    }
	}
    }

    virtual void
    vtPrintPrivReg(FILE *outfp, long regid)
    {
	switch (regid) {
	    case RSTREG_TPC_R: fprintf(outfp, "%%tpc "); break;
	    case RSTREG_TNPC_R: fprintf(outfp, "%%tnpc "); break;
	    case RSTREG_TSTATE_R: fprintf(outfp, "%%tstate "); break;
	    case RSTREG_TT_R: fprintf(outfp, "%%tt "); break;
	    case RSTREG_TICK_R: fprintf(outfp, "%%tick "); break;
	    case RSTREG_TBA_R: fprintf(outfp, "%%tba "); break;
	    case RSTREG_PSTATE_R: fprintf(outfp, "%%pstate "); break;
	    case RSTREG_TL_R: fprintf(outfp, "%%tl "); break;
	    case RSTREG_PIL_R: fprintf(outfp, "%%pil "); break;
	    case RSTREG_CWP_R: fprintf(outfp, "%%cwp "); break;
	    case RSTREG_CANSAVE_R: fprintf(outfp, "%%cansave "); break;
	    case RSTREG_CANRESTORE_R: fprintf(outfp, "%%canrestore "); break;
	    case RSTREG_CLEANWIN_R: fprintf(outfp, "%%cleanwin "); break;
	    case RSTREG_OTHERWIN_R: fprintf(outfp, "%%otherwin "); break;
	    case RSTREG_WSTATE_R: fprintf(outfp, "%%wstate "); break;
	    case RSTREG_FQ_R: fprintf(outfp, "%%fq "); break;
	    case RSTREG_VERSION_R: fprintf(outfp, "%%ver "); break;
	    case RSTREG_TPC_RBASE + 0:
	    case RSTREG_TPC_RBASE + 1:
	    case RSTREG_TPC_RBASE + 2:
	    case RSTREG_TPC_RBASE + 3:
	    case RSTREG_TPC_RBASE + 4:
		if (regid == RSTREG_TPC_RBASE){	// does not make sense to have trap level 0
		    fprintf(stderr, "trconv: warning: TPC should not be present for trap level 0 (#%llu) \n", gbl.rcount);
		}
		fprintf(outfp, "%%tpc[%d]", regid-RSTREG_TPC_RBASE); break;
	    case RSTREG_TNPC_RBASE + 0:
	    case RSTREG_TNPC_RBASE + 1:
	    case RSTREG_TNPC_RBASE + 2:
	    case RSTREG_TNPC_RBASE + 3:
	    case RSTREG_TNPC_RBASE + 4:
		if (regid == RSTREG_TNPC_RBASE){	// does not make sense to have trap level 0
		    fprintf(stderr, "trconv: warning: TNPC should not be present for trap level 0 (#%llu) \n", gbl.rcount);
		}
		fprintf(outfp, "%%tnpc[%d]", regid-RSTREG_TNPC_RBASE); break;
	    case RSTREG_TSTATE_RBASE + 0:
	    case RSTREG_TSTATE_RBASE + 1:
	    case RSTREG_TSTATE_RBASE + 2:
	    case RSTREG_TSTATE_RBASE + 3:
	    case RSTREG_TSTATE_RBASE + 4:
		if (regid == RSTREG_TSTATE_RBASE){	// does not make sense to have trap level 0
		    fprintf(stderr, "trconv: warning: TSTATE should not be present for trap level 0 (#%llu) \n", gbl.rcount);
		}
		fprintf(outfp, "%%tstate[%d]", regid-RSTREG_TSTATE_RBASE); break;
	    case RSTREG_TT_RBASE + 0: case RSTREG_TT_RBASE + 1: case RSTREG_TT_RBASE + 2: case RSTREG_TT_RBASE + 3: case RSTREG_TT_RBASE + 4:
		if (regid == RSTREG_TT_RBASE){	// does not make sense to have trap level 0
		    fprintf(stderr, "trconv: warning: TT should not be present for trap level 0 (#%llu) \n", gbl.rcount);
		}
		fprintf(outfp, "%%tt[%d]", regid-RSTREG_TT_RBASE); break;
	    default:
		fprintf(outfp, "%%unknownpr%d ", regid);
		// fprintf(stderr, "trconv: warning: Unknown priv regid %d (#%llu)", regid, gbl.rcount);
		break;
	}
    }

    virtual void
    vtPrintOtherReg(FILE *outfp, long regid)
    {
      switch (regid) {
      case RSTREG_Y_R: fprintf(outfp, "%%y "); break;
      case RSTREG_CC_R: fprintf(outfp, "%%cc "); break;
      case RSTREG_ASI_R: fprintf(outfp, "%%asi "); break;
      case RSTREG_TICK_R: fprintf(outfp, "%%tick "); break;
      case RSTREG_PC_R: fprintf(outfp, "%%pc "); break;
      case RSTREG_FPRS_R: fprintf(outfp, "%%fprs "); break;
	// case RSTREG_ASR_R: fprintf(outfp, "%%asr "); break;
      case RSTREG_ASR_PCR_R: fprintf(outfp, "%%pcr "); break;
      case RSTREG_ASR_PIC_R: fprintf(outfp, "%%pic "); break;
      case RSTREG_ASR_IEU_CTRL_R: fprintf(outfp, "%%ieu_ctrl "); break;
      case RSTREG_ASR_GSR_R: fprintf(outfp, "%%gsr "); break;
      case RSTREG_ASR_INTR_SET_R: fprintf(outfp, "%%intr_set "); break;
      case RSTREG_ASR_INTR_CLR_R: fprintf(outfp, "%%intr_clr "); break;
      case RSTREG_ASR_INTR_WRITE_R: fprintf(outfp, "%%intr_write "); break;
      case RSTREG_ASR_TICK_CMPR_R: fprintf(outfp, "%%tick_cmpr "); break;
      case RSTREG_ASR_STICK_REG_R: fprintf(outfp, "%%stick "); break;
      case RSTREG_ASR_STICK_CMPR_R: fprintf(outfp, "%%stick_cmpr "); break;
      case RSTREG_ASR_STICK_THR_STR_R: fprintf(outfp, "%%stick_thr_str "); break;
      case RSTREG_ASR_NPC_R: fprintf(outfp, "%%npc "); break;
      case RSTREG_ASR_FSR_R: fprintf(outfp, "%%fsr "); break;

      default:
	  fprintf(outfp, "%%UnknownASR ");
	  break;
      }
    }

    virtual void
    vtPrintReg(FILE *outfp, long regtype, long regid, uint64_t reg64, int i) 
    {
	static char isQuad = 0;
	static uint64_t quadWord = 0x0;
	switch (regtype) {
	    case RSTREG_INT_RT:
		if(isQuad) {
		    fprintf(stderr, 
			"trconv: warning: quad register encountered (#%llu)\n", 
			gbl.rcount);
		}
		fprintf(outfp, "(Reg %d: ", i);
		vtPrintIntRegName(outfp, regid);
		fprintf(outfp, "= 0x%llx) ", reg64);
		break;
	    case RSTREG_FLOAT_RT:
		vtPrintFloatReg(outfp, regid, reg64, i, isQuad, quadWord);
		break;
	    case RSTREG_PRIV_RT:
		if(isQuad) {
		    fprintf(stderr, 
			    "trconv: warning: quad register encountered (#%llu)\n", 
			    gbl.rcount);
		}
		fprintf(outfp, "(Reg %d: ", i);
		vtPrintPrivReg(outfp, regid);
		fprintf(outfp, "= 0x%llx) ", reg64);
		if (regid == RSTREG_PSTATE_R)
		    decode_pstate_bits (outfp, reg64);
		break;
	    case RSTREG_OTHER_RT:
		if(isQuad) {
		    fprintf(stderr, 
			    "trconv: warning: quad register encountered (#%llu)\n", 
			gbl.rcount);
		}
		fprintf(outfp, "(Reg %d: ", i);
		vtPrintOtherReg(outfp, regid);
		fprintf(outfp, "= 0x%llx) ", reg64);
		break;
	    case RSTREG_UNUSED_RT:
		if(isQuad) {
		    fprintf(stderr, 
			"trconv: warning: quad register encountered (#%llu)\n", 
			gbl.rcount);
		}
		// fprintf(outfp, "(Reg %d unused)", i);
		break;
	    case RSTREG_CC_RT:
		fprintf(outfp, "(Reg %d: %%ccr=0x%02x) ", i, regid);
		break;
	    case RSTREG_FCC_RT:
		fprintf(outfp, "(Reg %d: %%fcc=0x%02x) ", i, regid);
		break;
	    case RSTREG_MMU_RT:
	      if (regid == RSTREG_MMU_PCONTEXT) {
		fprintf(outfp, "(Reg %d: PContext=0x%02llx) ", i, reg64);
	      } else if (regid == RSTREG_MMU_SCONTEXT) {
		fprintf(outfp, "(Reg %d: SContext=0x%02llx) ", i, reg64);
	      } else {
		  fprintf(stderr, "trconv: warning: (#%llu) (Reg %d: Unknown MMU RegID %d = 0x%02x)\n",
			  gbl.rcount, i, regid, reg64);
	      }
	      break;

	    case RSTREG_HPRIV_RT:
	      switch(regid) {
	      case RSTREG_HPR_HPSTATE:
		  fprintf(outfp, "(Reg %d: %%hpstate=0x%llx) ", i, reg64);
		  break;
	      case RSTREG_HPR_HTSTATE:
		  fprintf(outfp, "(Reg %d: %%htstate=0x%llx) ", i, reg64);
		  break;
	      case RSTREG_HPR_HINTP:
		  fprintf(outfp, "(Reg %d: %%hintp=0x%llx) ", i, reg64);
		  break;
	      case RSTREG_HPR_HTBA:
		  fprintf(outfp, "(Reg %d: %%htba=0x%llx) ", i, reg64);
		  break;
	      case RSTREG_HPR_HVER:
		  fprintf(outfp, "(Reg %d: %%hver=0x%llx) ", i, reg64);
		  break;
	      case RSTREG_HPR_HSTICK_CMPR:
		  fprintf(outfp, "(Reg %d: %%hstick_cmpr=0x%llx) ", i, reg64);
		  break;
	      default:
		  fprintf(outfp, "(Reg %d: UnknownHPR%d = 0x%llx) ", i, regid, reg64);
	      }
	      break;

	    default:
		fprintf(stderr, "trconv: warning: Unknown regtype %d for reg[%d] (#%llu)", regtype, i, gbl.rcount);
		break;
	}
    }
#endif // _VALUE_TRACE
};  // RSTF_Regval

//======================================================================
//======================================================================
class RSTF_Cpu : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.cpucount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "cpu     : cpuid=%d ", getCpuID());
	fprintf(gbl.outfp, "timestamp=%llu", tr->timestamp); 
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Cpu::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Cpu::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_cpuT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Cpu::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Cpu::reset_tr()

    virtual int getCpuID() {
      return tr->cpu;
    }

protected:
    rstf_cpuT* tr;
    rstf_cpuT* tr_orig;
};  // RSTF_Cpu

//======================================================================
//======================================================================
class RSTF_Process : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.processcount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "process : ");
	fprintf(gbl.outfp, "%d ", tr->oldpid);
	fprintf(gbl.outfp, "%d ", tr->newpid);
	fprintf(gbl.outfp, "%d ", tr->oldcontext);
	fprintf(gbl.outfp, "%d", tr->newcontext);
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Process::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Process::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_processT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Process::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Process::reset_tr()

protected:
    rstf_processT* tr;
    rstf_processT* tr_orig;
};  // RSTF_Process

//======================================================================
//======================================================================
class RSTF_Dma : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.dmacount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "dma     : ");
	//fprintf(gbl.outfp, "rtype=%d ", tr->rtype);
	fprintf(gbl.outfp, "iswrite=%d ", tr->iswrite);
	fprintf(gbl.outfp, "start_pa=0x%016llx ", tr->start_pa);    
	fprintf(gbl.outfp, "nbytes=%d ", tr->nbytes);
	if (tr->devid) {
	    fprintf(gbl.outfp, "dev_id=%d ", tr->devid);
	    std::string idstring = gbl.devid2string[tr->devid];
	    if (idstring.length() == 0) {
		idstring = "unknown";
	    }
	    fprintf(gbl.outfp, "(%s)", idstring.c_str());
	}
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Dma::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Dma::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_dmaT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Dma::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Dma::reset_tr()

protected:
    rstf_dmaT* tr;
    rstf_dmaT* tr_orig;
};  // RSTF_Dma

//======================================================================
//======================================================================
class RSTF_String : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.stringcount++;
    }

    virtual void print_rec(uint64_t idx) {
	static char desc_string[800];
	static char* desc_str = desc_string;
	char cont_string[32];
	int i;

	if (tr->rtype == STRDESC_T) {
	    if (gbl.showIdx) {
		fprintf(gbl.outfp , "%6lld ", idx);
	    }

	    for (i = 0; i < 23; i++) {
		if (tr->string[i] == 0) {
		    break;
		}
	    }

	    if (i == 23) {
		fprintf(stderr,
			"trconv: warning: strdesc string not null terminated (#%llu)\n",
			gbl.rcount);
	    }

	    strncpy(desc_str, tr->string, 23);
	    desc_str += 23;
	    desc_str[0] = 0;

	    fprintf(gbl.outfp, "strdesc : \"%s\"\n", desc_string);
	    desc_str = desc_string;
	} else {
	    strncpy(desc_str, tr->string, 23);
	    desc_str += 23;
	    desc_str[0] = 0;

	    strncpy(cont_string, tr->string, 23);
	    cont_string[23] = 0;

	    if (gbl.fast) {
		if (gbl.showIdx) {
		    fprintf(gbl.outfp , "%6lld ", idx);
		}

		fprintf(gbl.outfp, "strcont : \"%s\"\n", cont_string);
	    }
	}
    }  // RSTF_String::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_String::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_stringT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_String::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_String::reset_tr()

protected:
    rstf_stringT* tr;
    rstf_stringT* tr_orig;
};  // RSTF_String

//======================================================================
//======================================================================
class RSTF_Delim : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.delimcount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	if (tr->rtype == LEFTDELIM_T) {
	    fprintf(gbl.outfp, "delimTl : ");
	} else {
	    fprintf(gbl.outfp, "delimTr : ");
	}
	fprintf(gbl.outfp, "id=%d ", tr->id);    
	fprintf(gbl.outfp, "what=%d ", tr->what);    
	fprintf(gbl.outfp, "length=%d", tr->length);  
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Delim::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Delim::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_delimT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Delim::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Delim::reset_tr()

protected:
    rstf_delimT* tr;
    rstf_delimT* tr_orig;
};  // RSTF_Delim

//======================================================================
//======================================================================
class RSTF_Preg : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.pregcount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "preg    : cpuid=%d ", getCpuID());
	fprintf(gbl.outfp, "asiReg=%d ", tr->asiReg);    
	//fprintf(gbl.outfp, "last_context=%d ", tr->lastcontext);    
	fprintf(gbl.outfp, "trap_lvl=0x%02x ", tr->traplevel);    
	fprintf(gbl.outfp, "trap_type=0x%02x ", tr->traptype);    
	fprintf(gbl.outfp, "pstate=0x%04x ", tr->pstate);    
	decode_pstate_bits(gbl.outfp, tr->pstate);
	fprintf(gbl.outfp, "primA=%d ", tr->primA);    
	fprintf(gbl.outfp, "secA=%d ", tr->secA);    
	fprintf(gbl.outfp, "primD=%d ", tr->primD);    
	fprintf(gbl.outfp, "secD=%d", tr->secD); 
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Preg::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Preg::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_pregT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Preg::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Preg::reset_tr()

    virtual int getCpuID() {
      return gbl.rstf_pre212? tr->cpuid: rstf_pregT_get_cpuid(tr);
    }

protected:
    rstf_pregT* tr;
    rstf_pregT* tr_orig;
};  // RSTF_Preg

//======================================================================
//======================================================================
class RSTF_Physaddr : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.physaddrcount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "physadd : ");
	fprintf(gbl.outfp, "pc_pa=0x%08llx ", tr->pc_pa);
	if (tr->ea_valid) {
	    fprintf(gbl.outfp, "ea_pa=0x%08llx ", tr->ea_pa);
	} else {
	    fprintf(gbl.outfp, "((ea_pa=0x%08llx)) ", tr->ea_pa);
	}
	fprintf(gbl.outfp, "ea_valid=%d", tr->ea_valid);
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Physaddr::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Physaddr::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_physaddrT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Physaddr::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Physaddr::reset_tr()

protected:
    rstf_physaddrT* tr;
    rstf_physaddrT* tr_orig;
};  // RSTF_Physaddr

#define PAVADIFF_MASK (0x1fff)	// lower 13 bits

//======================================================================
//======================================================================
class RSTF_Pavadiff : public Trace {
public:
    virtual void count() {
	static uint64_t prev_pc_pa_va = 0;

	gbl.rcount++;
	gbl.pavadiffcount++;

	if (gbl.pc_pavadiff) {
	    if (tr->pc_pa_va != prev_pc_pa_va) {
		prev_pc_pa_va = tr->pc_pa_va;

		if (tr->pc_pa_va & PAVADIFF_MASK) {
		    fprintf(gbl.msgfp, "trconv: warning: pc pa-va error "
			    "(#%llu pc_pa_va=0x%llx not multiple of pagesize)\n",
			    gbl.rcount - 1, tr->pc_pa_va);
		}
	    }

	    if (tr->ea_valid) {
		if (tr->ea_pa_va & PAVADIFF_MASK) {
		    fprintf(gbl.msgfp, "trconv: warning: ea pa-va error "
			    "(#%llu ea_pa_va=0x%llx not multiple of pagesize)\n",
			    gbl.rcount - 1, tr->ea_pa_va);
		}
	    }
	}
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "pavadiff: cpuid=%d ", getCpuID());
	fprintf(gbl.outfp, "icontext=%d ", tr->icontext);
	fprintf(gbl.outfp, "dcontext=%d ", tr->dcontext);
	fprintf(gbl.outfp, "pc_pa_va=0x%016llx ", tr->pc_pa_va);
	if (tr->ea_valid) {
	    fprintf(gbl.outfp, "ea_pa_va=0x%016llx ", tr->ea_pa_va);
	} else {
	    fprintf(gbl.outfp, "((ea_pa_va=0x%016llx)) ", tr->ea_pa_va);
	}
	fprintf(gbl.outfp, "ea_valid=%d", tr->ea_valid);
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Pavadiff::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Pavadiff::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_pavadiffT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Pavadiff::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Pavadiff::reset_tr()

    virtual int getCpuID() {
      return gbl.rstf_pre212? tr->cpuid: rstf_pavadiffT_get_cpuid(tr);
    }

protected:
    rstf_pavadiffT* tr;
    rstf_pavadiffT* tr_orig;
};  // RSTF_Pavadiff

//======================================================================
//======================================================================
class RSTF_Filemarker : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.filemarkercount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	if (tr->recNum == 0) {
	    // FILEMARKER_T
	    fprintf(gbl.outfp, "filemark: ");
	    fprintf(gbl.outfp, "recNum=%u ", tr->recNum);
	    fprintf(gbl.outfp, "level=%u ", tr->level);
	    fprintf(gbl.outfp, "incount=%llu ", tr->incount);
	    fprintf(gbl.outfp, "outcount=%llu", tr->outcount);
	    fprintf(gbl.outfp, "\n");
	}
	else {
	    // RECNUM_T
	    rstf_recnumT *ttr = (rstf_recnumT *)tr;
	    fprintf(gbl.outfp, "recnum  : cpuid=%d ", gbl.rstf_pre212? tr->cpuID: rstf_filemarkerT_get_cpuid(tr));
	    fprintf(gbl.outfp, "recNum=%u ", ttr->recNum);
	    fprintf(gbl.outfp, "level=%u ", ttr->level);
	    fprintf(gbl.outfp, "level=%d ", ttr->recType);
	    fprintf(gbl.outfp, "incount=%llu", ttr->incount);
	    fprintf(gbl.outfp, "\n");
	}
    }  // RSTF_Filemarker::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Filemarker::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_filemarkerT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Filemarker::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Filemarker::reset_tr()

protected:
    rstf_filemarkerT* tr;
    rstf_filemarkerT* tr_orig;
};  // RSTF_Filemarker

//======================================================================
//======================================================================
class RSTF_Status : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.statuscount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "status  : ");
	fprintf(gbl.outfp, "status=");
    
	switch (tr->status) {
	case RST_EOF:
	    fprintf(gbl.outfp, "RST_EOF\n");
	    break;
	case RST_ERROR:
	    fprintf(gbl.outfp, "RST_ERROR\n");
	    break;
	case RST_STATUS_END:
	    fprintf(gbl.outfp, "RST_STATUS_END\n");
	    break;
	default:
	    fprintf(gbl.outfp, "Unknown status id: %d\n", tr->status);
	}
    }  // RSTF_Status::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Status::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_statusT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Status::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Status::reset_tr()

protected:
    rstf_statusT* tr;
    rstf_statusT* tr_orig;
};  // RSTF_Status

//======================================================================
//======================================================================
class RSTF_Patch : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.patchcount++;
    }

    virtual void print_rec(uint64_t idx) {
	char text[16] = {0};

	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "patch   : ");
	fprintf(gbl.outfp, "isbegin=%d ", tr->isBegin);
	fprintf(gbl.outfp, "rewindrecs=%d ", tr->rewindrecs);
	fprintf(gbl.outfp, "id=%d ", tr->id);
	fprintf(gbl.outfp, "length=%d ", tr->length);
	fprintf(gbl.outfp, "descr=%s", memcpy(text, tr->descr, 8));
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Patch::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Patch::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_patchT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Patch::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Patch::reset_tr()

protected:
    rstf_patchT* tr;
    rstf_patchT* tr_orig;
};  // RSTF_Patch

//======================================================================
//======================================================================
class RSTF_Hwinfo : public Trace {

	//FIXME nothing is defined yet, stay tune.

};  // RSTF_Hwinfo



//======================================================================
//======================================================================
class RSTF_Memval64 : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.memval64count++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "mem64   : ");
	//fprintf(gbl.outfp, "128=%1d ", tr->ismemval128);
	fprintf(gbl.outfp, "isVA=%1d ", tr->addrisVA);
	//fprintf(gbl.outfp, "cont=%1d ", tr->isContRec);
	//fprintf(gbl.outfp, "zero5=%1d ", tr->zero5);
	fprintf(gbl.outfp, "cpuid=%d ", getCpuID());
	fprintf(gbl.outfp, "sz=%d ", tr->size);
	fprintf(gbl.outfp, "addr=0x%016llx ", tr->addr);
	fprintf(gbl.outfp, "val=0x%llx ", tr->val);
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Memval64::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Memval64::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_memval64T*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Memval64::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Memval64::reset_tr()

  virtual int getCpuID() {
    return gbl.rstf_pre212? tr->cpuid: rstf_memval64T_get_cpuid(tr);
  }

protected:
    rstf_memval64T* tr;
    rstf_memval64T* tr_orig;
};  // RSTF_Memval64

//======================================================================
//======================================================================
class RSTF_Memval128 : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.memval128count++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "mem128  : ");
	//fprintf(gbl.outfp, "128=%1d ", tr->ismemval128);
	fprintf(gbl.outfp, "isVA=%1d ", tr->addrisVA);
	fprintf(gbl.outfp, "cont=%1d ", tr->isContRec);
	//fprintf(gbl.outfp, "zero5=%1d ", tr->zero5);
	fprintf(gbl.outfp, "cpuid=%d ", getCpuID());
	if (tr->isContRec == 0) {
	  fprintf(gbl.outfp, "addr=0x%016llx ", makeAddr());
	}
	fprintf(gbl.outfp, "val[0]=0x%llx ", tr->val[0]);
	fprintf(gbl.outfp, "val[1]=0x%llx ", tr->val[1]);
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Memval128::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Memval128::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_memval128T*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Memval128::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Memval128::reset_tr()

  virtual int getCpuID() {
    return gbl.rstf_pre212? tr->cpuid: rstf_memval128T_get_cpuid(tr);
  }

protected:
    rstf_memval128T* tr;
    rstf_memval128T* tr_orig;

  uint64_t makeAddr() {
    int64_t addr = 0;
    int8_t* paddr = (int8_t*) &addr;

    if (tr->isContRec == 0) {
      paddr[0] = tr->addr36_43;
      addr >>= 20;
      addr |= (tr->addr04_35 << 4);
    }

    return (uint64_t) addr;
  }
};  // RSTF_Memval128



//======================================================================
//======================================================================
class RSTF_Bustrace : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.bustracecount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "bustrace: ");
	fprintf(gbl.outfp, "dv=%1d ", tr->dirtyvictim);
	fprintf(gbl.outfp, "sh=%1d ", tr->shared);
	fprintf(gbl.outfp, "own=%1d ", tr->owned);
	fprintf(gbl.outfp, "mc=%1d ", tr->memcancel);
	//fprintf(gbl.outfp, "bt_type=%2d ", tr->bt_type);
	fprintf(gbl.outfp, "txType=%2d ", tr->txType);
	fprintf(gbl.outfp, "aid=%2d ", tr->agentid);
	fprintf(gbl.outfp, "tscale=%1d ", tr->nsScale);
	fprintf(gbl.outfp, "ts=%7d ", tr->timestamp);
	fprintf(gbl.outfp, "addr=0x%016llx ", tr->addr_pa);
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Bustrace::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Bustrace::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_bustraceT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Bustrace::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Bustrace::reset_tr()

protected:
    rstf_bustraceT* tr;
    rstf_bustraceT* tr_orig;
};  // RSTF_Bustrace


//======================================================================
//======================================================================
class RSTF_Snoop : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.snoopcount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	if (tr->device_type == DEVICE_CPU) {
	    fprintf(gbl.outfp, "snoop   : cpuid=%d ", tr->device_id);
	}
	else {
	    fprintf(gbl.outfp, "snoop   : unknown device=%d ", tr->device_id);
	}

	switch(tr->snoopreq) {
	    case SNOOP_RTO:
		fprintf(gbl.outfp, "RTO ");
		break;

	    case SNOOP_RTS:
		fprintf(gbl.outfp, "RTS ");
		break;

	    default:
		fprintf(gbl.outfp, "Unknown snoop type ");
		break;
	}
	fprintf(gbl.outfp, "[0x%016llx]\n", tr->addr_pa);
    }  // RSTF_Snoop::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Snoop::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_snoopT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Snoop::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Snoop::reset_tr()

protected:
    rstf_snoopT* tr;
    rstf_snoopT* tr_orig;
};  // RSTF_Snoop



class RSTF_tsb_access : public Trace {
public:
  virtual void count() {
    gbl.rcount++;
    gbl.tsb_access_count++;
  }

  virtual void print_rec(uint64_t idx) {
    if (gbl.showIdx) {
      fprintf(gbl.outfp, "%6lld ", idx);
    }
    fprintf(gbl.outfp, "tsbaccess: cpuid=%d ", getCpuID());
    fprintf(gbl.outfp, "%s ", (tr->isdata? "DTSB": "ITSB"));
    fprintf(gbl.outfp, "pa=0x%016llx\n", tr->pa);
  } // RSTF_tsb_access::print_rec()

  virtual void inc_tr() {
    tr++;
  }

  virtual void set_tr(void * ptr, bool set_orig = true) {
    tr = (rstf_tsb_accessT*) ptr;
    if (set_orig) {
      tr_orig = tr;
    }
  } // RSTF_tsb_access::set_tr()

  virtual void reset_tr() {
    tr = tr_orig;
  }

  virtual int getCpuID() {
    return gbl.rstf_pre212? tr->cpuid: rstf_tsb_accessT_get_cpuid(tr);
  }
protected:
  rstf_tsb_accessT * tr;
  rstf_tsb_accessT * tr_orig;
}; // class RSTF_tsb_access : public Trace


class RSTF_rfs_section_header : public Trace {
 public:
  virtual void count() {
    gbl.rcount++;
    gbl.rfs_section_header_count++;
  }

  virtual void print_rec(uint64_t idx) {
    if (gbl.showIdx) {
      fprintf(gbl.outfp, "%6lld ", idx);
    }

    fprintf(gbl.outfp, "rfs_section_header: ");

    switch(tr->section_type) {
    case RFS_CW_T:
      fprintf(gbl.outfp, "CacheWarming: ");
      break;
    case RFS_BT_T:
      fprintf(gbl.outfp, "BranchTrace: ");
      break;
    case RFS_RST_T:
      fprintf(gbl.outfp, "RST Trace: ");
      break;
    default:
      fprintf(gbl.outfp, "Unknown Type: ");
      break;
    }

    if (tr->n_records == rfs_unknown_nrecords) {
      fprintf(gbl.outfp, "All remaining records\n");
    } else {
      fprintf(gbl.outfp, "%lld records\n", tr->n_records);
    }

  }

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Snoop::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_rfs_section_headerT *) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }

    virtual void reset_tr() {
	tr = tr_orig;
    }

 protected:
  rstf_rfs_section_headerT * tr;
  rstf_rfs_section_headerT * tr_orig;
}; // class RSTF_rfs_section_header : public Trace


class RSTF_bpwarming : public Trace {
 public:
  virtual void count() {
    gbl.rcount++;
    gbl.bpwarming_count++;
  }

  virtual void print_rec(uint64_t idx) {
    if (gbl.showIdx) {
      fprintf(gbl.outfp, "%6lld ", idx);
    }

    fprintf(gbl.outfp, "bpwarm  : ");

    char dis_string[80];
    sprintDiss(dis_string, tr->instr, tr->pc_va);

    fprintf(gbl.outfp, "cpuid=%d [0x%016llx] %08x %-32s %c [0x%016llx]", getCpuID(), tr->pc_va, tr->instr, dis_string, (tr->taken? 'T' : 'N'), tr->npc_va);

  }

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Snoop::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_bpwarmingT *) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }

    virtual void reset_tr() {
	tr = tr_orig;
    }

  virtual int getCpuID() {
    return gbl.rstf_pre212? tr->cpuid: rstf_bpwarmingT_get_cpuid(tr);
  }

 protected:
  rstf_bpwarmingT * tr;
  rstf_bpwarmingT * tr_orig;
}; // class Rstf_bpwarming: public Trace




class RSTF_cachewarming : public Trace {
 public:
  virtual void count() {
    gbl.rcount++;
    gbl.cachewarming_count++;
  }

  virtual void print_rec(uint64_t idx) {
    if (gbl.showIdx) {
      fprintf(gbl.outfp, "%6lld ", idx);
    }

    fprintf(gbl.outfp, "cachewarm: ");

    fprintf(gbl.outfp, "cpuid=%d ", getCpuID());
    switch(tr->reftype) {
    case cw_reftype_I:
      fprintf(gbl.outfp, "ifetch     ");
      break;
    case cw_reftype_R:
      fprintf(gbl.outfp, "load       ");
      break;
    case cw_reftype_W:
      fprintf(gbl.outfp, "store      ");
      break;
    case cw_reftype_PF_I:
      fprintf(gbl.outfp, "i-prefetch ");
      break;
    case cw_reftype_PF_D:
      fprintf(gbl.outfp, "d-prefetch ");
      break;
    case cw_reftype_DMA_R:
      fprintf(gbl.outfp, "dma-read   ");
      break;
    case cw_reftype_DMA_W:
      fprintf(gbl.outfp, "dma-write  ");
      break;
    default:
      fprintf(gbl.outfp, "unknown reftype ");
      break;
    }

    if (tr->reftype == cw_reftype_DMA_R || tr->reftype == cw_reftype_DMA_W) {
      fprintf(gbl.outfp, "pa=0x%016llx size=%08x\n", tr->pa, tr->refinfo.dma_size);
    } else {
      fprintf(gbl.outfp, "asi=%02x ", tr->refinfo.s.asi);
      fprintf(gbl.outfp, "va=0x%016llx pa=0x%016llx ", tr->va, tr->pa);
      if (tr->reftype == cw_reftype_PF_D) {
	fprintf(gbl.outfp, "fcn=%d\n", tr->refinfo.s.fcn);
      } else {
	fprintf(gbl.outfp, "\n");
      }
    }
  }

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Snoop::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_cachewarmingT *) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }

    virtual void reset_tr() {
	tr = tr_orig;
    }

  virtual int getCpuID() {
    return gbl.rstf_pre212 ? tr->cpuid : rstf_cachewarmingT_get_cpuid(tr);
  }

 protected:
  rstf_cachewarmingT * tr;
  rstf_cachewarmingT * tr_orig;
}; // class Rstf_cachewarming: public Trace


class RSTF_Trapping_Instr : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.trappinginstrcount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "tr_instr : cpuid=%d", rstf_trapping_instrT_get_cpuid(tr));

	if (tr->hpriv) fprintf(gbl.outfp, " h"); else if (tr->priv) fprintf(gbl.outfp, " p"); else fprintf(gbl.outfp, " u");

	fprintf(gbl.outfp, " [0x%016llx] ", tr->pc_va);

	if (tr->iftrap) {
	  fprintf(gbl.outfp, "ifetch_trap");
	} else {
	  fprintf(gbl.outfp, "%08x", tr->instr);
	  // output decoded instr
	  if (tr->ea_va_valid) {
	    fprintf(gbl.outfp, " [%llx]", tr->ea_va);
	    if (tr->ea_pa_valid) {
	      fprintf(gbl.outfp, " ea_pa valid");
	    } else {
	      fprintf(gbl.outfp, " ea_pa INVALID");
	    }
	  } // if ea_va_valid
	} // tr->iftrap?

	fprintf(gbl.outfp, "\n"); 
    }  // RSTF_Trapexit::print_rec()

#if 0
    virtual uint64_t get_pc() {
	return tr->pc;
    }  // RSTF_Trapexit::get_pc()
#endif

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Trapexit::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_trapping_instrT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Trapexit::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Trapexit::reset_tr()

    virtual int getCpuID() {
      return gbl.rstf_pre212? tr->cpuid: rstf_trapping_instrT_get_cpuid(tr);
    }

protected:
    rstf_trapping_instrT* tr;
    rstf_trapping_instrT* tr_orig;
};  // RSTF_TRAPPING_INSTR_T


//======================================================================
//======================================================================
class RSTF_Timesync : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.timesynccount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "timesync: cpuid=%d ", getCpuID());
	fprintf(gbl.outfp, "seqnum=%llu ", tr->sequence_number); 
	switch(tr->subtype) {
	case rstf_timesyncT_local:
	    fprintf(gbl.outfp, "local");
	    break;
	case rstf_timesyncT_global:
	    fprintf(gbl.outfp, "global");
	    break;
	default:
	    fprintf(gbl.outfp, "unknown-sync-type");
	    break;
	}
	fprintf(gbl.outfp, "\n");
    }  // RSTF_Timesync::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_TimeSync::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_timesyncT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Timesync::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Timesync::reset_tr()

    virtual int getCpuID() {
      return rstf_timesyncT_get_cpuid(tr);
    }

protected:
    rstf_timesyncT* tr;
    rstf_timesyncT* tr_orig;
};  // RSTF_Timesync



//======================================================================
//======================================================================
class RSTF_Devidstr : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.devidstrcount++;
    }

    virtual void print_rec(uint64_t idx) {
	static uint32_t id;
	static std::string idstring;
	char cstr[20];

	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	if (tr->id != rstf_devidstr_continuation_id) {
	    id = tr->id;
	}

	int i;
	for (i=0; i<19; i++) {
	    if (tr->str[i] != '\0') {
		idstring += tr->str[i];
		cstr[i] = tr->str[i];
	    } else {
		break;
	    }
	}
	cstr[i] = 0;

	fprintf(gbl.outfp, "devidstr: id=%d \"%s\"\n", id, cstr);

	if (i < 19) {
	    gbl.devid2string[tr->id] = idstring;
	    idstring.clear();
	}
    }  // RSTF_Devidstr::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Devidstr::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_devidstrT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Devidstr::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Devidstr::reset_tr()

protected:
    rstf_devidstrT* tr;
    rstf_devidstrT* tr_orig;
};  // RSTF_Devidstr

//======================================================================
//======================================================================
class RSTF_Zero : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.zerocount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld\t\tZero Record", idx);
	}

    }  // RSTF_Zero::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Zero::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_xxxT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Zero::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Zero::reset_tr()

protected:
    rstf_xxxT* tr;
    rstf_xxxT* tr_orig;
};  // RSTF_Zero

//======================================================================
//======================================================================
class RSTF_Unknown : public Trace {
public:
    virtual void count() {
	gbl.rcount++;
	gbl.unknowncount++;
    }

    virtual void print_rec(uint64_t idx) {
	if (gbl.showIdx) {
	    fprintf(gbl.outfp , "%6lld ", idx);
	}

	fprintf(gbl.outfp, "unknown : [Unsupported record type; rtype=%d]\n",
		tr->rtype);
    }  // RSTF_Unknown::print_rec()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Unknown::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_protoT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Unknown::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Unknown::reset_tr()

protected:
    rstf_protoT* tr;
    rstf_protoT* tr_orig;
};  // RSTF_Unknown

//======================================================================
//======================================================================
class RSTF_Union : public Trace {
public:
    virtual void count() {
	Trace* tr_trace;

#if defined(ARCH_AMD64)
	rstf_convertT::b2l((rstf_uint8T *)tr);
#endif
	tr_trace = get_rst_type();

	if (tr_trace != NULL) {
	    tr_trace->set_tr(tr, false);
	    tr_trace->count();
	}
    }  // RSTF_Union::count()

    virtual void print_dasm(uint64_t idx) {
	Trace* tr_trace;

	print_header();

	if (gbl.onlyIns) {
	    if (tr->proto.rtype == INSTR_T) {
		tr_instr.set_tr(tr, false);
		tr_instr.print_dasm(idx);
	    }
	} else {
	    tr_trace = get_rst_type();

	    if (gbl.noIns && tr->proto.rtype == INSTR_T) {
		tr_trace = NULL;
	    }

	    if (tr_trace) {
		tr_trace->set_tr(tr, false);
		tr_trace->print_dasm(idx);
	    }
	}
    }  // RSTF_Union::print_dasm()

    virtual void print_rec(uint64_t idx) {
	Trace* tr_trace;

	print_header();
    
	if (gbl.onlyIns) {
	    if (tr->proto.rtype == INSTR_T) {
		tr_instr.set_tr(tr, false);
		tr_instr.print_rec(idx);
	    }
	} else {
	    tr_trace = get_rst_type();

	    if (gbl.noIns && tr->proto.rtype == INSTR_T) {
		tr_trace = NULL;
	    }

	    if (tr_trace) {
		tr_trace->set_tr(tr, false);
		tr_trace->print_rec(idx);
	    }
	}
    }  // RSTF_Union::print_rec()

    virtual void print_verb(uint64_t idx) {
	Trace* tr_trace;

	print_header();

	if (gbl.onlyIns) {
	    if (tr->proto.rtype == INSTR_T) {
		tr_instr.set_tr(tr, false);
		tr_instr.print_verb(idx);
	    }
	} else {
	    tr_trace = get_rst_type();

	    if (gbl.noIns && tr->proto.rtype == INSTR_T) {
		tr_trace = NULL;
	    }

	    if (tr_trace) {
		tr_trace->set_tr(tr, false);
		tr_trace->print_verb(idx);
	    }
	}
    }  // RSTF_Union::print_verb()

    virtual void convert_to_master() {
	if (tr->proto.rtype == INSTR_T) {
	    tr_instr.set_tr(tr, false);
	    tr_instr.convert_to_master();
	}
    }  // RSTF_Union::convert_to_master()

    virtual void convert_from_master(Tmaster64* master) {
	tr_instr.set_tr(tr, false);
	tr_instr.convert_from_master(master);
    }  // RSTF_Union::convert_from_master()

    virtual void gen_ihash() {
	if (tr->proto.rtype == INSTR_T) {
	    tr_instr.set_tr(tr, false);
	    tr_instr.gen_ihash();
	}      
    }  // RSTF_Union::gen_ihash()

    virtual int check_ihash_error() {
	if (tr->proto.rtype == INSTR_T) {
	    tr_instr.set_tr(tr, false);
	    return tr_instr.check_ihash_error();
	}      

	return 0;
    }  // RSTF_Union::check_ihash_error()

    // check pc value of last NUM_VERIFY records in buffer
    virtual void verify() {
	tr_instr.set_tr(tr_orig, true);
	tr_instr.set_tr(tr, false);
	tr_instr.verify();
    }  // RSTF_Union::verify()

    virtual uint64_t get_pc() {
	switch (tr->proto.rtype) {
	case INSTR_T:
	    return tr->instr.pc_va;
	case TRAP_T:
	    return tr->trap.pc;
#if 0
	case TRAPEXIT_T:
	    return tr->trapexit.pc;
#endif
	}

	return RSTF_NOADDR;
    }  // RSTF_Union::get_pc()

    virtual uint64_t get_ea() {
	if (tr->proto.rtype == INSTR_T) {
	    if (tr->instr.ea_valid) {
		return tr->instr.ea_va;
	    }
	}

	return RSTF_NOADDR;
    }  // RSTF_Union::get_ea()

    virtual int get_ihash() {
      if (tr->proto.rtype == INSTR_T) {
	return spix_sparc_iop(SPIX_SPARC_V9, &tr->instr.instr);
	// return tr->instr.ihash;
      }

	return 0;
    }  // RSTF_Union::get_ihash()

    virtual void inc_tr() {
	tr++;
    }  // RSTF_Union::inc_tr()

    virtual void set_tr(void* ptr, bool set_orig = true) {
	tr = (rstf_unionT*) ptr;

	if (set_orig) {
	    tr_orig = tr;
	}
    }  // RSTF_Union::set_tr()

    virtual void reset_tr() {
	tr = tr_orig;
    }  // RSTF_Union::reset_tr()

    virtual rstf_unionT* copy_from_rst() {
	return tr;
    }  // RSTF_Union::copy_from_rst()

    virtual void copy_to_rst(rstf_unionT* from) {
	*tr = *from;
    }  // RSTF_Union::copy_to_rst()

    virtual int getCpuID() {
      return get_rst_type()->getCpuID();
    }

protected:
    rstf_unionT* tr;
    rstf_unionT* tr_orig;

    RSTF_Header tr_header;
    RSTF_Instr tr_instr;
    //RSTF_Asi tr_asi;
    RSTF_Traceinfo tr_traceinfo;
    RSTF_Tlb tr_tlb;
    RSTF_Thread tr_thread;
    RSTF_Trap tr_trap;
    RSTF_Trapexit tr_trapexit;
    RSTF_Trapping_Instr tr_trapping_instr;
    RSTF_Bustrace tr_bustrace;
    RSTF_Regval tr_regval;
    RSTF_Memval64 tr_memval64;
    RSTF_Memval128 tr_memval128;
    RSTF_Cpu tr_cpu;
    RSTF_Process tr_process;
    RSTF_Dma tr_dma;
    RSTF_String tr_string;
    RSTF_Delim tr_delim;
    RSTF_Preg tr_preg;
    RSTF_Physaddr tr_physaddr;
    RSTF_Pavadiff tr_pavadiff;
    RSTF_Filemarker tr_filemarker;
    RSTF_Status tr_status;
    RSTF_Patch tr_patch;
    //RSTF_Hwinfo tr_hwinfo;
    //RSTF_Memval tr_memval;
    RSTF_Snoop tr_snoop;
    RSTF_tsb_access tr_tsb_access;
    RSTF_rfs_section_header tr_rfs_shdr;
    RSTF_bpwarming tr_bpwarming;
    RSTF_cachewarming tr_cachewarming;

    RSTF_Timesync tr_timesync;
    RSTF_Devidstr tr_devidstr;

    RSTF_Zero		tr_zero;
    RSTF_Unknown	tr_unknown;

    Trace* get_rst_type() {
      int cpuid = -1;
	switch (tr->proto.rtype) {
	case RSTHEADER_T:
	    return &tr_header;
	case INSTR_T:
	    return &tr_instr;
	//case ASI_T: // ASI is deprecated. ASI_T == TRACEINFO_T
	    //return &tr_asi;
	case TRACEINFO_T:
	  return &tr_traceinfo;
	case TLB_T:
	    return &tr_tlb;
	case THREAD_T:
	    return &tr_thread;
	case TRAP_T:
	    return &tr_trap;
	case TRAPEXIT_T:
	    return &tr_trapexit;
	case TRAPPING_INSTR_T:
	  return & tr_trapping_instr;
	case BUSTRACE_T:
	    return &tr_bustrace;
	case REGVAL_T:
	    return &tr_regval;
	case MEMVAL_T:
	  if (tr->memval64.ismemval128) {
	      return &tr_memval128;
	  }
	  return &tr_memval64;
	case CPU_T: // CPU_T == TIMESTAMP_T
	    return &tr_cpu;
	case PROCESS_T:
	    return &tr_process;
	case DMA_T:
	    return &tr_dma;
	case STRDESC_T: 
	case STRCONT_T:
	    return &tr_string;
	case LEFTDELIM_T: 
	case RIGHTDELIM_T:
	    return &tr_delim;
	case PREG_T:
	  gbl.pstate[gbl.rstf_pre212? tr->preg.cpuid: rstf_pregT_get_cpuid(&tr->preg)] = tr->preg.pstate;
	    return &tr_preg;
	case PHYSADDR_T:
	    return &tr_physaddr;
	case PAVADIFF_T:
#ifdef _PRINT_PA
	  cpuid = gbl.rstf_pre212? tr->pavadiff.cpuid: rstf_pavadiffT_get_cpuid(&tr->pavadiff);
	  if (tr->pavadiff.ea_valid) {
	    gbl.ea_pavadiff_valid[cpuid] = true;
	    gbl.ea_pavadiff_value[cpuid] = tr->pavadiff.ea_pa_va;
	  }
	  gbl.pc_pavadiff_value[cpuid] = tr->pavadiff.pc_pa_va;
	  gbl.pc_pavadiff_valid[cpuid] = true;
#endif
	  return &tr_pavadiff;
	case FILEMARKER_T: // FILEMARKER_T == RECNUM_T
	    return &tr_filemarker;
	case STATUS_T:
	    return &tr_status;
	case PATCH_T:
	    return &tr_patch;
	case HWINFO_T:
	    //return &tr_hwinfo;
	    return &tr_unknown;
	case SNOOP_T:
	    return &tr_snoop;
	case TSB_ACCESS_T:
	  return &tr_tsb_access;
	case RFS_SECTION_HEADER_T:
	  return &tr_rfs_shdr;
	case RFS_BT_T:
	  return & tr_bpwarming;
	case RFS_CW_T:
	  return & tr_cachewarming;
	case TIMESYNC_T:
	    return & tr_timesync;
	case DEVIDSTR_T:
	    return & tr_devidstr;
	case RST_ZERO_T:
	    return &tr_zero;
	default:
	    return &tr_unknown;
	}
    }  // RSTF_Union::get_rst_type()

    void print_header() {
	static bool prheader = true;

	if (prheader) {
	    fprintf(gbl.outfp, "RST trace format (%s)\n", gbl.infile);
	    fprintf(gbl.outfp, "================\n");

	    if (!gbl.noIns) {
		if (gbl.disassembly) {
		    if (gbl.showIdx) {
			fprintf(gbl.outfp,
				"               User/                                                Branch\n"
				" Rec # Type    Priv PC                  Disassembly                 Taken  EA \n");
		    } else {
			fprintf(gbl.outfp,
				"        User/                                                Branch\n"
				"Type    Priv PC                  Disassembly                 Taken  EA \n");
		    }
		} else if (gbl.verbose) {
		    if (gbl.showIdx) {
			fprintf(gbl.outfp,
				"               User/                                                                     Br\n"
				" Rec # Type    Priv PC                  Disassembly                      Instr Word   IH Tk EA (x = invalid ea)\n");
		    } else {
			fprintf(gbl.outfp,
				"        User/                                                                     Br\n"
				"Type    Priv PC                  Disassembly                      Instr Word   IH Tk EA (x = invalid ea)\n");
		    }
		}
	    }

	    prheader = false;
	}
    }  // RSTF_Union::print_header()
};  // RSTF_Union

//======================================================================
//======================================================================

// Trtf99 and Tshade5 use Shade5 ihash values;
// all other formats use the Shade6 ihash values.
//
class rtf99 : public Trace {
public:
  virtual void print_dasm(uint64_t idx) {
    char dis_string[80];
    sprintDiss(dis_string, tr->tr_i, tr->tr_pc);

    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_pc);
    fprintf(gbl.outfp, "%-32s", dis_string);
    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_ea);
    fprintf(gbl.outfp, "0x%x", tr->tr_misc);

    fprintf(gbl.outfp, "\n");
  }  // rtf99::print_dasm()

  virtual void print_rec(uint64_t idx) {
    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_pc);
    fprintf(gbl.outfp, "(0x%08x) ", tr->tr_i); 
    fprintf(gbl.outfp, "%3d ", tr->tr_ih);
    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_ea);
    fprintf(gbl.outfp, "0x%x ", tr->tr_misc);
    fprintf(gbl.outfp, "\n");
  }  // rtf99::print_rec()

  virtual void print_verb(uint64_t idx) {
    char dis_string[80];
    sprintDiss(dis_string, tr->tr_i, tr->tr_pc);

    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_pc);
    fprintf(gbl.outfp, "%-32s", dis_string);
    fprintf(gbl.outfp, "(0x%08x) ", tr->tr_i);
    fprintf(gbl.outfp, "%3d ", tr->tr_ih);
    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_ea);
    fprintf(gbl.outfp, "0x%x", tr->tr_misc);

    fprintf(gbl.outfp, "\n");
  }  // rtf99::print_verb()

  virtual void convert_to_master() {
    this_master.tr_pc_va = tr->tr_pc;
    this_master.tr_ea_va = tr->tr_ea ;
    this_master.tr_tid = 0;
    this_master.tr_ih = tr->tr_ih;
    this_master.tr_reserved0 = 0;
    this_master.tr_taken = tr->tr_misc & 1; 
    this_master.tr_annulled = (tr->tr_misc << 1) & 1; 
    this_master.tr_iwstart = 0;
    this_master.tr_i = tr->tr_i;
    this_master.tr_reserved1 = 0;
    this_master.tr_pc_pa = 0;
    this_master.tr_ea_pa = 0;
    this_master.tr_context = 0;
    this_master.tr_asi = 0;
    this_master.tr_got_trap = 0;
    this_master.tr_asi_change = 0;
    this_master.tr_privmode = 0;
  }  // rtf99::convert_to_master()

  virtual void convert_from_master(Tmaster64* master) {
    tr->tr_pc = (uint32_t)master->tr_pc_va;
    tr->tr_ea = (uint32_t)master->tr_ea_va;
    tr->tr_ih = master->tr_ih;
    tr->tr_misc = master->tr_taken + (master->tr_annulled >> 1); 
    tr->tr_i = master->tr_i;
  }  // rtf99::convert_from_master()

  virtual void gen_ihash() {
    tr->tr_ih = getIHash(tr->tr_i);
  }  // tfr99::gen_ihash()

  virtual int check_ihash_error() {
    if (tr->tr_ih != getIHash(tr->tr_i)) {
      return 1;
    }

    return 0;
  }  // rtf99::check_ihash_error()

  virtual void verify() {
    Trtf99 * vtr = tr - NUM_VERIFY;    
    int i;

    for (i = 0; i < NUM_VERIFY - 1; i++) {
      if (vtr[i].tr_pc % 4 != 0 && RSTF_IS_BADADDR(vtr[i].tr_pc) == 0) {
	fprintf(stderr, "trconv: Error: Incorrect pc value in input file.\n");
	set_tr(&vtr[i], false);
	print_verb(gbl.rcount - NUM_VERIFY + i);
	//exit(2);
      }
    }
  }  // rtf99::verify()

  virtual uint64_t get_pc() {
    return tr->tr_pc;
  }  // rtf99::get_pc()

  virtual uint64_t get_ea() {
    return tr->tr_ea;
  }  // rtf99::get_ea()

  virtual int get_ihash() {
    return tr->tr_ih;
  }  // rtf99::get_ihash()

  virtual void inc_tr() {
    tr++;
  }  // rtf99::inc_tr()

  virtual void set_tr(void* ptr, bool set_orig = true) {
    tr = (Trtf99 *) ptr;

    if (set_orig) {
      tr_orig = tr;
    }
  }  // rtf99::set_tr()

  virtual void reset_tr() {
    tr = tr_orig;
  }  // rtf99::reset_tr()

protected:
  Trtf99 * tr;
  Trtf99 * tr_orig;

  void print_header() {
    static bool prheader = false;

    if (!prheader) {
      fprintf(gbl.outfp, "rtf99 trace format (%s)\n", gbl.infile);
      fprintf(gbl.outfp, "====================\n");

      if (gbl.record) {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, " Rec #  tr_pc        tr_i       "
		  "tr_ih tr_ea      misc\n");
	} else {
	  fprintf(gbl.outfp, " tr_pc        tr_i       "
		  "tr_ih tr_ea      misc\n");
	}
      } else if (gbl.disassembly) {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, " Rec #  PC          Disassembly"
		  "                      EA          Misc\n");
	} else {
	  fprintf(gbl.outfp, " PC          Disassembly"
		  "                      EA          Misc\n");
	}
      } else {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, " Rec #  PC          Disassembly"
		  "                      Instr Word   IH  EA\n");
	} else {
	  fprintf(gbl.outfp, " PC          Disassembly"
		  "                      Instr Word   IH  EA\n");
	}
      }

      prheader = true;
    }
  }  // rtf99::print_header()
};  // rtf99

// Trtf99 and Tshade5 use Shade5 ihash values;
// all other formats use the Shade6 ihash values.

class Shade5 : public Trace {
public:
  virtual void print_dasm(uint64_t idx) {
    char dis_string[80];
    sprintDiss(dis_string, tr->tr_i, tr->tr_pc);

    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_pc);
    fprintf(gbl.outfp, "%-32s", dis_string);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else {
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    if (tr->tr_annulled) {
      fprintf(gbl.outfp, "an ");
    } else {
      fprintf(gbl.outfp, "[0x%08x] ", tr->tr_ea);
    }

    fprintf(gbl.outfp, "\n");
  }  // Shade5::print_dasm()

  virtual void print_rec(uint64_t idx) {
    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_pc);
    fprintf(gbl.outfp, "(0x%08x) ", tr->tr_i);
    fprintf(gbl.outfp, "%3d ", tr->tr_ih);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else {
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_ea);
    fprintf(gbl.outfp, "%d ", tr->tr_annulled);
    fprintf(gbl.outfp, "\n");
  }  // Shade5::print_rec()

  virtual void print_verb(uint64_t idx) {
    char dis_string[80];
    sprintDiss(dis_string, tr->tr_i, tr->tr_pc);

    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_pc);
    fprintf(gbl.outfp, "%-32s", dis_string);
    fprintf(gbl.outfp, "(0x%08x) ", tr->tr_i);
    fprintf(gbl.outfp, "%3d ", tr->tr_ih);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else {
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_ea);

    if (tr->tr_annulled) {
      fprintf(gbl.outfp, "an ");
    }

    fprintf(gbl.outfp, "\n");
  }  // Shade5::print_verb()

  virtual void convert_to_master() {
    this_master.tr_pc_va = tr->tr_pc;
    this_master.tr_ea_va = tr->tr_ea ;
    this_master.tr_tid = 0;
    this_master.tr_ih = tr->tr_ih;
    this_master.tr_reserved0 = 0;
    this_master.tr_taken = tr->tr_taken; 
    this_master.tr_annulled = tr->tr_annulled; 
    this_master.tr_iwstart = 0;
    this_master.tr_i = tr->tr_i;
    this_master.tr_reserved1 = 0;
    this_master.tr_pc_pa = 0;
    this_master.tr_ea_pa = 0;
    this_master.tr_context = 0;
    this_master.tr_asi = 0;
    this_master.tr_got_trap = 0;
    this_master.tr_asi_change = 0;
    this_master.tr_privmode = 0;
  }  // Shade5::convert_to_master()

  virtual void convert_from_master(Tmaster64* master) {
    tr->tr_pc = (uint32_t) master->tr_pc_va;
    tr->tr_ea = (uint32_t) master->tr_ea_va;
    tr->tr_ih = master->tr_ih;        
    tr->tr_taken = master->tr_taken; 
    tr->tr_annulled = master->tr_annulled; 
    tr->tr_i = master->tr_i;
  }  // Shade5::convert_from_master()

  virtual void gen_ihash() {
    tr->tr_ih = getIHash(tr->tr_i);
  }  // Shade5::gen_ihash()

  virtual int check_ihash_error() {
    if (tr->tr_ih != getIHash(tr->tr_i)) {
      return 1;
    }

    return 0;
  }  // Shade5::check_ihash_error()

  virtual void verify() {
    Tshade5* vtr = tr - NUM_VERIFY;    
    int i;

    for (i = 0; i < NUM_VERIFY - 1; i++) {
      if (vtr[i].tr_pc % 4 != 0 && RSTF_IS_BADADDR(vtr[i].tr_pc) == 0) {
	fprintf(stderr, "trconv: Error: Incorrect pc value in input file.\n");
	set_tr(&vtr[i], false);
	print_verb(gbl.rcount - NUM_VERIFY + i);
	//exit(2);
      }
    }
  }  // Shade5::verify()

  virtual uint64_t get_pc() {
    return tr->tr_pc;
  }  // Shade5::get_pc()

  virtual uint64_t get_ea() {
    return tr->tr_ea;
  }  // Shade5::get_ea()

  virtual int get_ihash() {
    return tr->tr_ih;
  }  // Shade5::get_ihash()

  virtual void inc_tr() {
    tr++;
  }  // Shade5::inc_tr()

  virtual void set_tr(void* ptr, bool set_orig = true) {
    tr = (Tshade5*) ptr;

    if (set_orig) {
      tr_orig = tr;
    }
  }  // Shade5::set_tr()

  virtual void reset_tr() {
    tr = tr_orig;
  }  // Shade5::reset_tr()

protected:
  Tshade5* tr;
  Tshade5* tr_orig;

  void print_header() {
    static bool prheader = true;

    if (prheader) {
      fprintf(gbl.outfp, "Shade5 trace format (%s)\n", gbl.infile);
      fprintf(gbl.outfp, "=====================\n");

      if (gbl.record) {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, " Rec #  tr_pc        tr_i       "
		  "tr_ih   tr_ea      an\n");
	} else {
	  fprintf(gbl.outfp, " tr_pc        tr_i       "
		  "tr_ih   tr_ea      an\n");
	}
      } else if (gbl.disassembly) {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, "                               "
		  "                     Br\n"
		  " Rec #  PC          Disassembly"
		  "                     Tk EA\n");
	} else {
	  fprintf(gbl.outfp, "                        "
		  "                     Br\n"
		  " PC          Disassembly"
		  "                     Tk EA\n");
	}
      } else {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, "                               "
		  "                                      Br\n"
		  " Rec #  PC          Disassembly"
		  "                      Instr Word   IH Tk EA\n");
	} else {
	  fprintf(gbl.outfp, "                        "
		  "                                      Br\n"
		  " PC          Disassembly"
		  "                      Instr Word   IH Tk EA\n");
	}
      }

      prheader = false;
    }
  }
};  // Shade5

class Shade6x32 : public Trace {
public:
  virtual void print_dasm(uint64_t idx) {
    char dis_string[80];
    sprintDiss(dis_string, tr->tr_i, tr->tr_pc);

    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_pc);
    fprintf(gbl.outfp, "%-32s", dis_string);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else {
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    if (tr->tr_annulled) {
      fprintf(gbl.outfp, "an ");
    } else {
      fprintf(gbl.outfp, "[0x%08x] ", tr->tr_ea);
    }

    if (tr->tr_tid) {
      fprintf(gbl.outfp, "[0x%08x] ", tr->tr_tid); 
    }

    if (tr->tr_iwstart) {
      fprintf(gbl.outfp, "wi ");
    }

    fprintf(gbl.outfp, "\n");
  }  // Shade6x32::print_dasm()

  virtual void print_rec(uint64_t idx) {
    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_pc);
    fprintf(gbl.outfp, "(0x%08x) ", tr->tr_i);
    fprintf(gbl.outfp, "%3d ", tr->tr_ih);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else {
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_ea);
    fprintf(gbl.outfp, "%d ", tr->tr_annulled);
    fprintf(gbl.outfp, "%d ", tr->tr_iwstart);
    fprintf(gbl.outfp, "0x%08x ", tr->tr_tid);
    fprintf(gbl.outfp, "\n");
  }  // Shade6x32::print_rec()

  virtual void print_verb(uint64_t idx) {
    char dis_string[80];
    sprintDiss(dis_string, tr->tr_i, tr->tr_pc);

    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_pc);
    fprintf(gbl.outfp, "%-32s", dis_string);
    fprintf(gbl.outfp, "(0x%08x) ", tr->tr_i);
    fprintf(gbl.outfp, "%3d ", tr->tr_ih);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else {
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    fprintf(gbl.outfp, "[0x%08x] ", tr->tr_ea);

    if (tr->tr_annulled) {
      fprintf(gbl.outfp, "an ");
    }

    if (tr->tr_tid) {
      fprintf(gbl.outfp, "[0x%08x] ", tr->tr_tid); 
    }

    if (tr->tr_iwstart) {
      fprintf(gbl.outfp, "wi ");
    }

    fprintf(gbl.outfp, "\n");
  }  // Shade6x32::print_verb()

  virtual void convert_to_master() {
    this_master.tr_pc_va = tr->tr_pc;
    this_master.tr_ea_va = tr->tr_ea ;
    this_master.tr_tid = tr->tr_tid;
    this_master.tr_ih = tr->tr_ih;
    this_master.tr_reserved0 = tr->tr_shade_reserved0;
    this_master.tr_taken = tr->tr_taken; 
    this_master.tr_annulled = tr->tr_annulled; 
    this_master.tr_iwstart = tr->tr_iwstart;
    this_master.tr_i = tr->tr_i;
    this_master.tr_reserved1 = tr->tr_shade_reserved1;
    this_master.tr_pc_pa = 0;
    this_master.tr_ea_pa = 0;
    this_master.tr_context = 0;
    this_master.tr_asi = 0;
    this_master.tr_got_trap = 0;
    this_master.tr_asi_change = 0;
    this_master.tr_privmode = 0;
  }  // Shade6x32::convert_to_master()

  virtual void convert_from_master(Tmaster64* master) {
    tr->tr_pc = (uint32_t)master->tr_pc_va;
    tr->tr_ea = (uint32_t)master->tr_ea_va ;
    tr->tr_tid = master->tr_tid;
    tr->tr_ih = master->tr_ih;
    tr->tr_ih = tr->tr_ih;
    tr->tr_shade_reserved0 = master->tr_reserved0;
    tr->tr_taken = master->tr_taken; 
    tr->tr_annulled = master->tr_annulled; 
    tr->tr_iwstart = master->tr_iwstart;
    tr->tr_i = master->tr_i;
    tr->tr_shade_reserved1 = master->tr_reserved1;
  }  // Shade6x32::convert_from_master()

  virtual void gen_ihash() {
    tr->tr_ih = getIHash(tr->tr_i);
  }  // Shade6x32::gen_ihash()

  virtual int check_ihash_error() {
    if (tr->tr_ih != getIHash(tr->tr_i)) {
      return 1;
    }

    return 0;
  }  // Shade6x32::check_ihash_error()

  virtual void verify() {
    Tshade6x32* vtr = tr - NUM_VERIFY;    
    int i;

    for (i = 0; i < NUM_VERIFY - 1; i++) {
      if (vtr[i].tr_pc % 4 != 0 && RSTF_IS_BADADDR(vtr[i].tr_pc) == 0) {
	fprintf(stderr, "trconv: Error: Incorrect pc value in input file.\n");
	set_tr(&vtr[i], false);
	print_verb(gbl.rcount - NUM_VERIFY + i);
	//exit(2);
      }
    }
  }  // Shade6x32::verify()

  virtual uint64_t get_pc() {
    return tr->tr_pc;
  }  // Shade6x32::get_pc()

  virtual uint64_t get_ea() {
    return tr->tr_ea;
  }  // Shade6x32::get_ea()

  virtual int get_ihash() {
    return tr->tr_ih;
  }  // Shade6x32::get_ihash()

  virtual void inc_tr() {
    tr++;
  }  // Shade6x32::inc_tr()

  virtual void set_tr(void* ptr, bool set_orig = true) {
    tr = (Tshade6x32*) ptr;

    if (set_orig) {
      tr_orig = tr;
    }
  }  // Shade6x32::set_tr()

  virtual void reset_tr() {
    tr = tr_orig;
  }  // Shade6x32::reset_tr()

protected:
  Tshade6x32* tr;
  Tshade6x32* tr_orig;

  void print_header() {
    static bool prheader = true;

    if (prheader) {
      fprintf(gbl.outfp, "Shade6 (32bit) trace format (%s)\n", gbl.infile);
      fprintf(gbl.outfp, "=============================\n");

      if (gbl.record) {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, " Rec #  tr_pc        tr_i       "
		  "tr_ih   tr_ea       a w tr_tid\n");
	} else {
	  fprintf(gbl.outfp, " tr_pc        tr_i       "
		  "tr_ih   tr_ea       a w tr_tid\n");
	}
      } else if (gbl.disassembly) {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, "                               "
		  "                     Br\n"
		  " Rec #  PC          Disassembly"
		  "                     Tk EA\n");
	} else {
	  fprintf(gbl.outfp, "                        "
		  "                     Br\n"
		  " PC          Disassembly"
		  "                     Tk EA\n");
	}
      } else {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, "                               "
		  "                                      Br\n"
		  " Rec #  PC          Disassembly"
		  "                      Instr Word   IH Tk EA\n");
	} else {
	  fprintf(gbl.outfp, "                        "
		  "                                      Br\n"
		  " PC          Disassembly"
		  "                      Instr Word   IH Tk EA\n");
	}
      }

      prheader = false;
    }
  }
};  // Shade6x32


class Shade6x64 : public Trace {
public:
  virtual void print_dasm(uint64_t idx) {
    char dis_string[80];
    sprintDiss(dis_string, tr->tr_i, tr->tr_pc);

    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%016llx] ", tr->tr_pc);
    fprintf(gbl.outfp, "%-32s", dis_string);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else {
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    if (tr->tr_annulled) {
      fprintf(gbl.outfp, "an ");
    } else {
      fprintf(gbl.outfp, "[0x%016llx] ", tr->tr_ea);
    }

    if (tr->tr_tid) {
      fprintf(gbl.outfp, "[0x%08x] ", tr->tr_tid); 
    }

    if (tr->tr_iwstart) {
      fprintf(gbl.outfp, "wi ");
    }

    fprintf(gbl.outfp, "\n");
  }  // Shade6x64::print_dasm()

  virtual void print_rec(uint64_t idx) {
    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%016llx] ", tr->tr_pc);
    fprintf(gbl.outfp, "(0x%08x) ", tr->tr_i);
    fprintf(gbl.outfp, "%3d ", tr->tr_ih);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else {
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    fprintf(gbl.outfp, "[0x%016llx] ", tr->tr_ea);
    fprintf(gbl.outfp, "%d ", tr->tr_annulled);
    fprintf(gbl.outfp, "%d ", tr->tr_iwstart);
    fprintf(gbl.outfp, "0x%08x ", tr->tr_tid);
    fprintf(gbl.outfp, "\n");
  }  // Shade6x64::print_rec()

  virtual void print_verb(uint64_t idx) {
    char dis_string[80];
    sprintDiss(dis_string, tr->tr_i, tr->tr_pc);

    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, "[0x%016llx] ", tr->tr_pc);
    fprintf(gbl.outfp, "%-32s", dis_string);
    fprintf(gbl.outfp, "(0x%08x) ", tr->tr_i);
    fprintf(gbl.outfp, "%3d ", tr->tr_ih);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else {
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    fprintf(gbl.outfp, "[0x%016llx] ", tr->tr_ea);

    if (tr->tr_annulled) {
      fprintf(gbl.outfp, "an ");
    }

    if (tr->tr_tid) {
      fprintf(gbl.outfp, "[0x%08x] ", tr->tr_tid); 
    }

    if (tr->tr_iwstart) {
      fprintf(gbl.outfp, "wi ");
    }

    fprintf(gbl.outfp, "\n");
  }  // Shade6x64::print_verb()

  virtual void convert_to_master() {
    this_master.tr_pc_va = tr->tr_pc;
    this_master.tr_ea_va = tr->tr_ea ;
    this_master.tr_tid = tr->tr_tid;
    this_master.tr_ih = tr->tr_ih;
    this_master.tr_reserved0 = tr->tr_shade_reserved0;
    this_master.tr_taken = tr->tr_taken; 
    this_master.tr_annulled = tr->tr_annulled; 
    this_master.tr_iwstart = tr->tr_iwstart;
    this_master.tr_i = tr->tr_i;
    this_master.tr_reserved1 = tr->tr_shade_reserved1;
    this_master.tr_pc_pa = 0;
    this_master.tr_ea_pa = 0;
    this_master.tr_context = 0;
    this_master.tr_asi = 0;
    this_master.tr_got_trap = 0;
    this_master.tr_asi_change = 0;
    this_master.tr_privmode = 0;
  }  // Shade6x64::convert_to_master()

  virtual void convert_from_master(Tmaster64* master) {
    tr->tr_pc = master->tr_pc_va;
    tr->tr_ea = master->tr_ea_va ;
    tr->tr_tid = master->tr_tid;
    tr->tr_ih = master->tr_ih;
    tr->tr_shade_reserved0 = master->tr_reserved0;
    tr->tr_taken = master->tr_taken; 
    tr->tr_annulled = master->tr_annulled; 
    tr->tr_iwstart = master->tr_iwstart;
    tr->tr_i = master->tr_i;
    tr->tr_shade_reserved1 = master->tr_reserved1;
  }  // Shade6x64::convert_from_master()

  virtual void gen_ihash() {
    tr->tr_ih = getIHash(tr->tr_i);
  }  // Shade6x64::gen_ihash()

  virtual int check_ihash_error() {
    if (tr->tr_ih != getIHash(tr->tr_i)) {
      return 1;
    }

    return 0;
  }  // Shade6x64::check_ihash_error()

  virtual void verify() {
    Tshade6x64* vtr = tr - NUM_VERIFY;    
    int i;

    for (i = 0; i < NUM_VERIFY - 1; i++) {
      if (vtr[i].tr_pc % 4 != 0 && RSTF_IS_BADADDR(vtr[i].tr_pc) == 0) {
	fprintf(stderr, "trconv: Error: Incorrect pc value in input file.\n");
	set_tr(&vtr[i], false);
	print_verb(gbl.rcount - NUM_VERIFY + i);
	//exit(2);
      }
    }
  }  // Shade6x64::verify()

  virtual uint64_t get_pc() {
    return tr->tr_pc;
  }  // Shade6x64::get_pc()

  virtual uint64_t get_ea() {
    return tr->tr_ea;
  }  // Shade6x64::get_ea()

  virtual int get_ihash() {
    return tr->tr_ih;
  }  // Shade6x64::get_ihash()

  virtual void inc_tr() {
    tr++;
  }  // Shade6x64::inc_tr()

  virtual void set_tr(void* ptr, bool set_orig = true) {
    tr = (Tshade6x64*) ptr;

    if (set_orig) {
      tr_orig = tr;
    }
  }  // Shade6x64::set_tr()

  virtual void reset_tr() {
    tr = tr_orig;
  }  // Shade6x64::reset_tr()

protected:
  Tshade6x64* tr;
  Tshade6x64* tr_orig;

  void print_header() {
    static bool prheader = true;

    if (prheader) {
      fprintf(gbl.outfp, "Shade6 (64bit) trace format (%s)\n", gbl.infile);
      fprintf(gbl.outfp, "=============================\n");

      if (gbl.record) {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, " Rec #  tr_pc                tr_i       "
		  "tr_ih   tr_ea               a w tr_tid\n");
	} else {
	  fprintf(gbl.outfp, " tr_pc                tr_i       "
		  "tr_ih   tr_ea               a w tr_tid\n");
	}
      } else if (gbl.disassembly) {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, "                                       "
		  "                     Br\n"
		  " Rec #  PC                  Disassembly"
		  "                     Tk EA\n");
	} else {
	  fprintf(gbl.outfp, "                                "
		  "                     Br\n"
		  " PC                  Disassembly"
		  "                     Tk EA\n");
	}
      } else {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, "                                       "
		  "                                      Br\n"
		  " Rec #  PC                  Disassembly"
		  "                      Instr Word   IH Tk EA\n");
	} else {
	  fprintf(gbl.outfp, "                                "
		  "                                      Br\n"
		  " PC                  Disassembly"
		  "                      Instr Word   IH Tk EA\n");
	}
      }

      prheader = false;
    }
  }  // Shade6x64::print_header()
};  // Shade6x64

class Master : public Trace {
public:
  virtual void print_dasm(uint64_t idx) {
    char dis_string[80];
    sprintDiss(dis_string, tr->tr_i, tr->tr_pc_va);

    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    if (tr->tr_privmode) {
      fprintf(gbl.outfp, "p ");
    } else {
      fprintf(gbl.outfp, "u ");
    }

    fprintf(gbl.outfp, "[0x%016llx] ", tr->tr_pc_va);
    fprintf(gbl.outfp, "%-32s", dis_string);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else { 
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    if (tr->tr_va_valid && !tr->tr_annulled) {
      fprintf(gbl.outfp, "[0x%016llx]", tr->tr_ea_va);
    }

    if (tr->tr_annulled) {
      fprintf(gbl.outfp, "an ");
    }

    if (tr->tr_got_trap) {
      fprintf(gbl.outfp, "tr "); 
    }

    if (tr->tr_asi_change) {
      fprintf(gbl.outfp, "asi ");
    }

    if (tr->tr_iwstart) {
      fprintf(gbl.outfp, "wi ");
    }

    fprintf(gbl.outfp, "\n");
  }  // Master::print_dasm()

  virtual void print_rec(uint64_t idx) {
    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    fprintf(gbl.outfp, " [0x%016llx] ", tr->tr_pc_va);
    fprintf(gbl.outfp, "[0x%016llx] ", tr->tr_pc_pa);
    fprintf(gbl.outfp, "(0x%08x) ", tr->tr_i);

    if (tr->tr_privmode) {
      fprintf(gbl.outfp, " p ");
    } else {
      fprintf(gbl.outfp, " u ");
    }

    fprintf(gbl.outfp, "%3d ", tr->tr_ih);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else {
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    fprintf(gbl.outfp, "[0x%016llx] ", tr->tr_ea_va);
    fprintf(gbl.outfp, "<0x%016llx> ", tr->tr_ea_pa);
    fprintf(gbl.outfp, "%d ", tr->tr_va_valid);
    fprintf(gbl.outfp, " %d ", tr->tr_annulled);
    fprintf(gbl.outfp, " %d ", tr->tr_got_trap);
    fprintf(gbl.outfp, " %d ", tr->tr_asi_change);
    fprintf(gbl.outfp, "0x%04x", tr->tr_tid);
    fprintf(gbl.outfp, " %d ", tr->tr_context);
    fprintf(gbl.outfp, " %d ", tr->tr_asi);
    fprintf(gbl.outfp, " %d ", tr->tr_iwstart);
    fprintf(gbl.outfp, "\n");
  }  // Master::print_rec

  virtual void print_verb(uint64_t idx) {
    char dis_string[80];
    sprintDiss(dis_string, tr->tr_i, tr->tr_pc_va);

    print_header();

    if (gbl.showIdx) {
      fprintf(gbl.outfp , "%6lld ", idx);
    }

    if (tr->tr_privmode) {
      fprintf(gbl.outfp, "p ");
    } else {
      fprintf(gbl.outfp, "u ");
    }

    fprintf(gbl.outfp, "[0x%016llx] ", tr->tr_pc_va);
    fprintf(gbl.outfp, "<0x%016llx> ", tr->tr_pc_pa);
    fprintf(gbl.outfp, "%-32s", dis_string);
    fprintf(gbl.outfp, "(0x%08x) ", tr->tr_i);
    fprintf(gbl.outfp, "%3d ", tr->tr_ih);

    if (ih_iscti(tr->tr_ih)) {
      if (tr->tr_taken) {
	fprintf(gbl.outfp, "T ");
      } else {
	fprintf(gbl.outfp, "N ");
      }
    } else {
      fprintf(gbl.outfp, "  ");
    }

    fprintf(gbl.outfp, "[0x%016llx]", tr->tr_ea_va);

    if (!tr->tr_va_valid) {
      fprintf(gbl.outfp, "x ");
    } else {
      fprintf(gbl.outfp, "  ");
    }

    fprintf(gbl.outfp, "<0x%016llx> ", tr->tr_ea_pa);

    if (tr->tr_annulled) {
      fprintf(gbl.outfp, "an ");
    }

    if (tr->tr_got_trap) {
      fprintf(gbl.outfp, "tr "); 
    }

    if (tr->tr_asi_change) {
      fprintf(gbl.outfp, "asi ");
    }

    if (tr->tr_iwstart) {
      fprintf(gbl.outfp, "wi ");
    }

    fprintf(gbl.outfp, "\n");
  }  // Master::print_verb()

  virtual void convert_to_master() {
    this_master = *tr;
  }  // Master::convert_to_master

  virtual void convert_from_master(Tmaster64* master) {
    *tr = *master;
  }  // Master::convert_from_master()

  virtual void gen_ihash() {
    tr->tr_ih = getIHash(tr->tr_i);
  }  // Master::gen_ihash()

  virtual int check_ihash_error() {
    if (tr->tr_ih != getIHash(tr->tr_i)) {
      return 1;
    }

    return 0;
  }  // Master::check_ihash_error()

  virtual void verify() {
    Tmaster64* vtr = tr - NUM_VERIFY;    
    int i;

    for (i = 0; i < NUM_VERIFY - 1; i++) {
      if (vtr[i].tr_pc_va % 4 != 0 && RSTF_IS_BADADDR(vtr[i].tr_pc_va) == 0) {
	fprintf(stderr, "trconv: Error: Incorrect pc value in input file.\n");
	set_tr(&vtr[i], false);
	print_verb(gbl.rcount - NUM_VERIFY + i);
	//exit(2);
      }
    }
  }  // Master::verify()

  virtual uint64_t get_pc() {
    return tr->tr_pc_va;
  }  // Master::get_pc()

  virtual uint64_t get_ea() {
    return tr->tr_ea_va;
  }  // Master::get_ea()

  virtual int get_ihash() {
    return tr->tr_ih;
  }  // Master::get_ihash()

  virtual void inc_tr() {
    tr++;
  }  // Master::inc_tr()

  virtual void set_tr(void* ptr, bool set_orig = true) {
    tr = (Tmaster64*) ptr;

    if (set_orig) {
      tr_orig = tr;
    }
  }  // Master::set_tr()

  virtual void reset_tr() {
    tr = tr_orig;
  }  // Master::reset_tr()

protected:
  Tmaster64* tr;
  Tmaster64* tr_orig;

  void print_header() {
    static bool prheader = true;

    if (prheader) {
      fprintf(gbl.outfp, "Master trace format (%s)\n", gbl.infile);
      fprintf(gbl.outfp, "===================\n");

      if (gbl.record) {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, " Rec #   tr_pc_va             tr_pc_pa             "
		  "tr_i          tr_ih   tr_ea_va             tr_ea_pa       "
		  "    va an gt ac tid   cx  a iw\n");
	} else {
	  fprintf(gbl.outfp, "  tr_pc_va             tr_pc_pa             "
		  "tr_i          tr_ih   tr_ea_va             tr_ea_pa       "
		  "    va an gt ac tid   cx  a iw\n");
	}
      } else if (gbl.disassembly) {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, "      Usr/                             "
		  "                       Br\n"
		  " Rec # Pr PC                  Disassembly"
		  "                     Tk EA\n");
	} else {
	  fprintf(gbl.outfp, "Usr/                            "
		  "                       Br\n"
		  "Pr PC                  Disassembly"
		  "                     Tk EA\n");
	}
      } else {
	if (gbl.showIdx) {
	  fprintf(gbl.outfp, "      Usr/                                 "
		  "                                           "
		  "              Br\n"
		  " Rec # Pr PC (virtual)         PC (physical)"
		  "       Disassembly                      "
		  "Instr Word   IH"
		  " Tk EA (virtual, x=inv)   EA (physical)\n");
	} else {
	  fprintf(gbl.outfp, "Usr/                                 "
		  "                                           "
		  "              Br\n"
		  "Pr PC (virtual)         PC (physical)"
		  "       Disassembly                      "
		  "Instr Word   IH"
		  " Tk EA (virtual, x=inv)   EA (physical)\n");
	}
      }

      prheader = false;
    }  // Master::print_header()
  }
};  // Master

