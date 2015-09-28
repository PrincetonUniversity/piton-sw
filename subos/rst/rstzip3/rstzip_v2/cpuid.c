/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: cpuid.c
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
#include "cpuid.h"

int getRstCpuID(rstf_unionT* rst) {
  int cpuid = -1;

  switch (rst->proto.rtype) {
  case INSTR_T:
    cpuid = rst->instr.cpuid;
    break;
  case TLB_T:
    cpuid = rst->tlb.cpuid;
    break;
  case REGVAL_T:
    cpuid = rst->regval.cpuid;
    break;
  case PREG_T:
    cpuid = rst->preg.cpuid;
    break;
  case TRAP_T:
    cpuid = rst->trap.cpuid;
    break;
  case TRAPEXIT_T:
    cpuid = rst->trapexit.cpuid;
    break;
  case CPU_T:
    cpuid = rst->cpu.cpu;
    break;
  case PAVADIFF_T:
    cpuid = rst->pavadiff.cpuid;
    break;
  default:
    cpuid = -1;
  }

  return cpuid;
}

// use the set cpuid function from rstf.h instead of accessing the cpuid field directly
rstf_unionT* setRstCpuID(rstf_unionT* rst, int cpuid) {
  switch (rst->proto.rtype) {
  case INSTR_T:
    // rst->instr.cpuid = cpuid;
    rstf_instrT_set_cpuid(&rst->instr, cpuid);
    break;
  case TLB_T:
    // rst->tlb.cpuid = cpuid;
    rstf_tlbT_set_cpuid(&rst->tlb, cpuid);
    break;
  case REGVAL_T:
    // rst->regval.cpuid = cpuid;
    rstf_regvalT_set_cpuid(&rst->regval, cpuid);
    break;
  case PREG_T:
    // rst->preg.cpuid = cpuid;
    rstf_pregT_set_cpuid(&rst->preg, cpuid);
    break;
  case TRAP_T:
    // rst->trap.cpuid = cpuid;
    rstf_trapT_set_cpuid(&rst->trap, cpuid);
    break;
  case TRAPEXIT_T:
    // rst->trapexit.cpuid = cpuid;
    rstf_trapexitT_set_cpuid(&rst->trapexit, cpuid);
    break;
  case CPU_T:
    rst->cpu.cpu = cpuid;
    break;
  case PAVADIFF_T:
    // rst->pavadiff.cpuid = cpuid;
    rstf_pavadiffT_set_cpuid(&rst->pavadiff, cpuid);
    break;
  }

  return rst;
}
