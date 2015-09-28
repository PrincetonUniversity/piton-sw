/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: cpuid.h
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
#ifndef _CPUID_H
#define _CPUID_H

#include "rstf/rstf.h"

#ifdef __cplusplus
extern "C" {
#endif

// Returns -1 if record type has no cpuid field.
int getRstCpuID(rstf_unionT* rst);

// Set cpuid field in rst.  Returns rst.
rstf_unionT* setRstCpuID(rstf_unionT* rst, int cpuid);

#ifdef __cplusplus
}
#endif

#endif  // _CPUID_H
