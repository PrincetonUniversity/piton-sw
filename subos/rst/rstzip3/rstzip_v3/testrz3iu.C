// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: testrz3iu.C
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
#include <sys/types.h>

#include "rz3iu.h"
#include "spix_sparc.h"

void mismatch(const char * fcn, uint32_t instr, bool sp, bool rz) {
  if (sp != rz) {
    printf("spix, rz3iu %s mismatch instr=%08x (%c/%c)\n", fcn, instr, sp?'T':'F', rz?'T':'F');
    exit(1);
  }
}

int main(int argc, char **argv)
{

  uint32_t instr;

  uint32_t start_instr = 0xc0000000;
  instr = start_instr;
  do {
    spix_sparc_iop_t iop = spix_sparc_iop(SPIX_SPARC_V9, &instr);

    if ((iop != SPIX_SPARC_IOP_ILLTRAP) && (((int)iop) != -1)) {
      mismatch("dcti", instr, spix_sparc_iop_isdcti(iop),  rz3iu_is_dcti(instr));

      mismatch("isbranch", instr, spix_sparc_iop_isbranch(iop), rz3iu_is_branch(instr));
      // in spix, ubranch <=> branch_always; and branch_never => cbranch
      // in rz3, ubranch includes br_always and br_never.
      mismatch("iscbranch", instr, spix_sparc_iop_iscbranch(iop), rz3iu_is_cbranch(instr)||rz3iu_is_ubranch_never(instr));
      mismatch("isubranch", instr, spix_sparc_iop_isubranch(iop), rz3iu_is_ubranch_always(instr));

      mismatch("isbpr", instr, spix_sparc_iop_isbpr(iop), rz3iu_is_bpr(instr));
      mismatch("isbpcc", instr, spix_sparc_iop_isbpcc(iop), rz3iu_is_bpcc(instr));
      mismatch("isbicc", instr, spix_sparc_iop_isbicc(iop), rz3iu_is_bicc(instr));
      mismatch("isfbfcc", instr, spix_sparc_iop_isfbfcc(iop), rz3iu_is_fbfcc(instr));
      mismatch("isfbpfcc", instr, spix_sparc_iop_isfbpfcc(iop), rz3iu_is_fbpfcc(instr));

      mismatch("iscall", instr, (iop==SPIX_SPARC_IOP_CALL), rz3iu_is_call(instr));
      mismatch("isreturn", instr, (iop==SPIX_SPARC_IOP_RETURN), rz3iu_is_return(instr));

      mismatch("isdone", instr, (iop==SPIX_SPARC_IOP_DONE), rz3iu_is_done(instr));
      mismatch("isretry", instr, (iop==SPIX_SPARC_IOP_RETRY), rz3iu_is_retry(instr));

      mismatch("isprefetch", instr, spix_sparc_iop_isprefetch(iop), rz3iu_is_prefetch(instr));
      mismatch("isload", instr, spix_sparc_iop_isload(iop)&&!spix_sparc_iop_isprefetch(iop), rz3iu_is_load(instr) || rz3iu_is_load_store(instr));
      mismatch("isustore", instr, spix_sparc_iop_isustore(iop), rz3iu_is_store(instr) || rz3iu_is_load_store_unconditional(instr));
      mismatch("iscstore", instr, spix_sparc_iop_iscstore(iop), rz3iu_is_load_store_conditional(instr));
    }

    if (instr & 0xffffff); else printf("%08x\n", instr);

    instr++;
  } while(instr != start_instr);

  return 0;
} // main
