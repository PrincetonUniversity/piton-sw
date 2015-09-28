// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: gen_test1.C
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
/* gen_test1.C
 * generate an rst record of each type - verify that trconv displays it correctly
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>


#include "rstf/rstf.h"

const char usage[] = "gen_test1.C > output.rst";

void zeroit(rstf_unionT * pr)
{
  memset(pr, 0, sizeof(rstf_unionT));
}

void dumpit(rstf_unionT * pr)
{
  if (fwrite(pr, sizeof(rstf_unionT), 1, stdout) != 1) {
    perror("gen_test1: error writing to stdout");
  }
}

int main(int argc, char *argv[])
{
  rstf_unionT ru;
  assert(sizeof(ru) == 24);

  zeroit(&ru);
  ru.header.rtype = RSTHEADER_T;
  ru.header.majorVer = RSTF_MAJOR_VERSION;
  ru.header.minorVer = RSTF_MINOR_VERSION;
  ru.header.percent = '%';
  sprintf(ru.header.header_str, "RST Header v%s", RSTF_VERSION_STR);
  dumpit(&ru);

  const char desc_string[] = "hex digits F-0: FEDCBA9876543210";
  zeroit(&ru);
  ru.string.rtype = STRCONT_T;
  memcpy(ru.string.string, desc_string, 23);
  dumpit(&ru);
  ru.string.rtype = STRDESC_T;
  strcpy(ru.string.string, desc_string+23);
  dumpit(&ru);

  zeroit(&ru);
  ru.tlb.rtype = TLB_T;
  ru.tlb.demap = 0;
  ru.tlb.tlb_type = 0; // instr
  ru.tlb.tlb_index = 12;
  ru.tlb.tlb_no = 1;
  rstf_tlbT_set_cpuid(&ru.tlb, 593);
  ru.tlb.tte_tag = 0x00000000ffd00000ull;
  ru.tlb.tte_data = 0xc000000000e00064ull;
  dumpit(&ru);

  zeroit(&ru);
  ru.tlb.rtype = TLB_T;
  ru.tlb.demap = 0;
  ru.tlb.tlb_type = 1; // instr
  ru.tlb.tlb_index = 137;
  ru.tlb.tlb_no = 2;
  rstf_tlbT_set_cpuid(&ru.tlb, 0);
  ru.tlb.tte_tag = 0x0000030016054000ull;
  ru.tlb.tte_data = 0x8000000066cd4036ull;
  dumpit(&ru);

  zeroit(&ru);
  ru.preg.rtype = PREG_T;
  ru.preg.asiReg = 0x80;
  ru.preg.traplevel = 1;
  ru.preg.traptype = 13;
  ru.preg.pstate = 0x16;
  rstf_pregT_set_cpuid(&ru.preg, 1023);
  ru.preg.primA = ru.preg.primD = 1432;
  ru.preg.secD = 0;
  dumpit(&ru);

  zeroit(&ru);
  ru.pavadiff.rtype = PAVADIFF_T;
  ru.pavadiff.ea_valid = 1;
  rstf_pavadiffT_set_cpuid(&ru.pavadiff, 347);
  ru.pavadiff.icontext = ru.pavadiff.dcontext = 1432;
  ru.pavadiff.pc_pa_va = 0x1300000;
  ru.pavadiff.ea_pa_va = 0xff00768000;
  dumpit(&ru);

  zeroit(&ru);
  ru.instr.rtype = INSTR_T;
  ru.instr.ea_valid = 1;
  ru.instr.tr = 0;
  ru.instr.hpriv = 1;
  ru.instr.pr = 0;
  ru.instr.bt = 0;
  ru.instr.an = 0;
  rstf_instrT_set_cpuid(&ru.instr, 347);
  ru.instr.instr = 0xde0fbfe8; // ldub
  ru.instr.pc_va = 0xdcba4fcc;
  ru.instr.ea_va = 0x1047e8;
  dumpit(&ru);

  zeroit(&ru);
  ru.trapping_instr.rtype = TRAPPING_INSTR_T;
  rstf_trapping_instrT_set_cpuid(&ru.trapping_instr, 347);
  ru.trapping_instr.hpriv=1;
  ru.trapping_instr.priv=0;
  ru.trapping_instr.iftrap = 0;
  ru.trapping_instr.pc_va = 0x4350fc00;
  ru.trapping_instr.instr = 0xde0fbfe8;
  ru.trapping_instr.ea_va_valid = 1;
  ru.trapping_instr.ea_va = 0x3141590;
  ru.trapping_instr.ea_pa_valid = 0;
  dumpit(&ru);

  zeroit(&ru);
  ru.trap.rtype = TRAP_T;
  ru.trap.is_async = 1;
  ru.trap.tl = 1;
  rstf_trapT_set_cpuid(&ru.trap, 2);
  ru.trap.ttype = 76;
  ru.trap.pstate = 0x16;
  ru.trap.pc = 0x3643b8;
  ru.trap.npc = 0x3643bc;
  dumpit(&ru);

} // main()
