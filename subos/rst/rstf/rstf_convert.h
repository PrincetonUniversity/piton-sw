/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rstf_convert.h
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
#ifndef _rstf_convert_h
#define _rstf_convert_h

#include "rstf.h"
#include "byteswap.h"

class rstf_convertT {
public:
  static void l2b(rstf_uint8T *t)
  {
    int i;
    uint8_t bytes[sizeof(rstf_protoT)/sizeof(uint8_t)], b;
    switch (t->arr8[0]) {
    case INSTR_T:
      b = t->arr8[1];
      t->arr8[1] = (b << 7) | ((b & 2) << 5) | ((b & 4) << 3) |
	((b & 8) << 1)	| ((b & 0x10) >> 1) | ((b & 0x20) >> 3) |
	((b & 0x40) >> 5) | (b >> 7);
      bytes[2] = t->arr8[3];
      bytes[3] = t->arr8[2];
      t->arr8[2] = (bytes[3] << 2) | (bytes[2] & 3);
      t->arr8[3] = (bytes[3] & 0xc0);
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case TRACEINFO_T:
      switch (t->arr8[1]) {
      case RSTT2_NLEVEL_T:
	*(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
	*(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
	*(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
	break;
      case RSTT2_CPUINFO_T:
	*(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
	*(uint16_t *)(&t->arr8[4]) = byteswap16(*(uint16_t *)(&t->arr8[4]));
	*(uint16_t *)(&t->arr8[6]) = byteswap16(*(uint16_t *)(&t->arr8[6]));
	break;
      case RSTT2_CPUIDINFO_T:
	for (i=4; i<24; i+=2)
	  *(uint16_t *)(&t->arr8[i]) = byteswap16(*(uint16_t *)(&t->arr8[i]));
	break;
      }
      break;
    case TLB_T:
      b = t->arr8[1];
      t->arr8[1] = (b << 7) | ((b & 2) << 5);
      *(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
      t->arr8[4] = (t->arr8[4] >> 2) | (t->arr8[4] << 6);
      t->arr8[5] = (t->arr8[5] << 4);
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case THREAD_T:
      *(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      break;
    case TRAP_T:
      t->arr8[1] = (t->arr8[1] << 7) | (t->arr8[1] >> 4);
      bytes[2] = t->arr8[3];
      bytes[3] = t->arr8[2];
      t->arr8[2] = (bytes[3] << 2) | (bytes[2] >> 6);
      t->arr8[3] = (bytes[2] << 2) | (bytes[3] >> 6);
      *(uint16_t *)(&t->arr8[4]) = byteswap16(*(uint16_t *)(&t->arr8[4]));
      bytes[6] = t->arr8[7];
      bytes[7] = t->arr8[6];
      t->arr8[6] = (bytes[7] << 4) | (bytes[6] >> 4);
      t->arr8[7] = (bytes[6] << 4) | (bytes[7] >> 4);
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case TRAPEXIT_T:
      bytes[2] = t->arr8[3];
      bytes[3] = t->arr8[2];
      t->arr8[2] = (bytes[3] << 2) | (bytes[2] & 3);
      t->arr8[3] = (bytes[3] & 0xc0);
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      break;
    case REGVAL_T:
      t->arr8[1] = (t->arr8[1] << 7) | (t->arr8[1] >> 1);
      bytes[6] = t->arr8[7];
      bytes[7] = t->arr8[6];
      t->arr8[6] = bytes[7] << 5;
      t->arr8[7] = 0;
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case CPU_T:
      *(uint16_t *)(&t->arr8[6]) = byteswap16(*(uint16_t *)(&t->arr8[6]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case PROCESS_T:
      *(uint32_t *)(&t->arr8[8]) = byteswap32(*(uint32_t *)(&t->arr8[8]));
      *(uint32_t *)(&t->arr8[12]) = byteswap32(*(uint32_t *)(&t->arr8[12]));
      *(uint32_t *)(&t->arr8[16]) = byteswap32(*(uint32_t *)(&t->arr8[16]));
      *(uint32_t *)(&t->arr8[20]) = byteswap32(*(uint32_t *)(&t->arr8[20]));
      break;
    case DMA_T:
      t->arr8[1] = t->arr8[1] >> 7;
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      break;
    case LEFTDELIM_T:
    case RIGHTDELIM_T:
      *(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      break;
    case PREG_T:
      *(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
      *(uint16_t *)(&t->arr8[6]) = byteswap16(*(uint16_t *)(&t->arr8[6]));
      t->arr8[9] = t->arr8[9] << 6;
      *(uint16_t *)(&t->arr8[16]) = byteswap16(*(uint16_t *)(&t->arr8[16]));
      *(uint16_t *)(&t->arr8[18]) = byteswap16(*(uint16_t *)(&t->arr8[18]));
      *(uint16_t *)(&t->arr8[20]) = byteswap16(*(uint16_t *)(&t->arr8[20]));
      *(uint16_t *)(&t->arr8[22]) = byteswap16(*(uint16_t *)(&t->arr8[22]));
      break;
    case PHYSADDR_T:
      t->arr8[1] = (t->arr8[1] << 7) | (t->arr8[1] >> 1);
      bytes[2] = t->arr8[3];
      bytes[3] = t->arr8[2];
      t->arr8[2] = (bytes[3] << 5);
      t->arr8[3] = 0;
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case PAVADIFF_T:
      t->arr8[1] = (t->arr8[1] << 7) | (t->arr8[1] >> 1);
      t->arr8[2] = (t->arr8[2] << 5);
      t->arr8[3] = 0;
      *(uint16_t *)(&t->arr8[4]) = byteswap16(*(uint16_t *)(&t->arr8[4]));
      *(uint16_t *)(&t->arr8[6]) = byteswap16(*(uint16_t *)(&t->arr8[6]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case FILEMARKER_T:
      t->arr8[1] = (t->arr8[1] << 7) | (t->arr8[1] >> 1);
      t->arr8[4] = (t->arr8[4] << 6);
      t->arr8[5] = t->arr8[6] = t->arr8[7] = 0;
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case PATCH_T:
      t->arr8[1] = (t->arr8[1] >> 7);
      *(uint16_t *)(&t->arr8[4]) = byteswap16(*(uint16_t *)(&t->arr8[4]));
      break;
    case HWINFO_T:
      t->arr8[1] = (t->arr8[1] << 7);
      *(uint16_t *)(&t->arr8[4]) = byteswap16(*(uint16_t *)(&t->arr8[4]));
      *(uint16_t *)(&t->arr8[6]) = byteswap16(*(uint16_t *)(&t->arr8[6]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case MEMVAL_T:
      b = t->arr8[1];
      t->arr8[1] = (b << 7) | ((b&2) << 5) | ((b&4) << 3) | (b >> 6);
      if (t->arr8[1] & 0x80) {	/* ismemval128 */
	*(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      }
      else {			/* ismemval64 */
	t->arr8[3] = (t->arr8[3] >> 4);
      }
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case BUSTRACE_T:
      b = t->arr8[1];
      t->arr8[1] = (b << 7) | ((b&2) << 5) | ((b&4) << 3) | ((b&8) << 1) |
	(b >> 4);
      bytes[2] = t->arr8[3];
      bytes[3] = t->arr8[2];
      t->arr8[2] = (bytes[3] << 2) | (bytes[2] >> 6);
      t->arr8[3] = (bytes[2] << 2) | (bytes[3] >> 6);
      bytes[5] = t->arr8[6];
      bytes[6] = t->arr8[5];
      bytes[7] = t->arr8[4];
      t->arr8[4] = (bytes[7] << 7) | ((bytes[7]&2) << 5) | (bytes[5] & 0x3f);
      t->arr8[5] = bytes[6];
      t->arr8[6] = (bytes[7] & 0xfc);
      t->arr8[7] = 0;
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case SNOOP_T:
      *(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint16_t *)(&t->arr8[16]) = byteswap16(*(uint16_t *)(&t->arr8[16]));
      break;
    case TSB_ACCESS_T:
      t->arr8[1] = (t->arr8[1] >> 7);
      bytes[2] = t->arr8[3];
      bytes[3] = t->arr8[2];
      t->arr8[2] = (bytes[2] >> 6);
      t->arr8[3] = (bytes[2] << 2) | (bytes[3] >> 6);
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case RFS_SECTION_HEADER_T:
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      break;
    case RFS_CW_T:
      bytes[1] = t->arr8[2];
      bytes[2] = t->arr8[1];
      t->arr8[1] = (bytes[1] << 6) | (bytes[2] >> 2);
      t->arr8[2] = (bytes[2] << 6) | (bytes[1] >> 2);
      switch (t->arr8[2] & 0x3f) {
      case cw_reftype_DMA_R:
      case cw_reftype_DMA_W:
	*(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
	break;
      default:
	t->arr8[5] = (t->arr8[5] << 7) | ((t->arr8[5] & 0x3e) << 1);
	t->arr8[6] = 0;
	t->arr8[7] = 0;
	break;
      }
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case RFS_BT_T:
      bytes[2] = t->arr8[2];
      bytes[3] = t->arr8[1];
      t->arr8[1] = (bytes[2] << 6) | (bytes[3] >> 2);
      t->arr8[2] = (bytes[3] << 6) | ((bytes[2] & 4) << 3);
      t->arr8[3] = 0;
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case TRAPPING_INSTR_T:
      b = t->arr8[1];
      t->arr8[1] = (b << 7) | ((b&2) << 5) | ((b&4) << 3) | ((b&8) << 1) |
	((b&0x10) >> 1);
      bytes[2] = t->arr8[3];
      bytes[3] = t->arr8[2];
      t->arr8[2] = (bytes[2] << 6) | (bytes[3] >> 2);
      t->arr8[3] = (bytes[3] << 6);
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    }
  }

  static void b2l(rstf_uint8T *t)
  {
    uint8_t bytes[sizeof(rstf_protoT)/sizeof(uint8_t)], b;
    int i;
    switch (t->arr8[0]) {
    case INSTR_T:
      b = t->arr8[1];
      t->arr8[1] = (b << 7) | ((b & 2) << 5) | ((b & 4) << 3) |
	((b & 8) << 1)	| ((b & 0x10) >> 1) | ((b & 0x20) >> 3) |
	((b & 0x40) >> 5) | (b >> 7);
      bytes[2] = (t->arr8[2] & 3);
      bytes[3] = (t->arr8[3] & 0xc0) | (t->arr8[2] >> 2);
      t->arr8[2] = bytes[3];
      t->arr8[3] = bytes[2];
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case TRACEINFO_T:
      switch (t->arr8[1]) {
      case RSTT2_NLEVEL_T:
	*(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
	*(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
	*(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
	break;
      case RSTT2_CPUINFO_T:
	*(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
	*(uint16_t *)(&t->arr8[4]) = byteswap16(*(uint16_t *)(&t->arr8[4]));
	*(uint16_t *)(&t->arr8[6]) = byteswap16(*(uint16_t *)(&t->arr8[6]));
	break;
      case RSTT2_CPUIDINFO_T:
	for (i=4; i<24; i+=2)
	  *(uint16_t *)(&t->arr8[i]) = byteswap16(*(uint16_t *)(&t->arr8[i]));
	break;
      }
      break;
    case TLB_T:
      b = t->arr8[1];
      t->arr8[1] = (b >> 7) | ((b & 0x40) >> 5);
      *(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
      t->arr8[4] = (t->arr8[4] >> 6) | (t->arr8[4] << 2);
      t->arr8[5] = (t->arr8[5] >> 4);
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case THREAD_T:
      *(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      break;
    case TRAP_T:
      t->arr8[1] = (t->arr8[1] >> 7) | (t->arr8[1] << 4);
      bytes[2] = (t->arr8[2] << 6) | (t->arr8[3] >> 2);
      bytes[3] = (t->arr8[3] << 6) | (t->arr8[2] >> 2);
      t->arr8[2] = bytes[3];
      t->arr8[3] = bytes[2];
      *(uint16_t *)(&t->arr8[4]) = byteswap16(*(uint16_t *)(&t->arr8[4]));
      bytes[6] = (t->arr8[6] << 4) | (t->arr8[7] >> 4);
      bytes[7] = (t->arr8[7] << 4) | (t->arr8[6] >> 4);
      t->arr8[6] = bytes[7];
      t->arr8[7] = bytes[6];
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case TRAPEXIT_T:
      bytes[2] = (t->arr8[2] & 3);
      bytes[3] = (t->arr8[3] & 0xc0) | (t->arr8[2] >> 2);
      t->arr8[2] = bytes[3];
      t->arr8[3] = bytes[2];
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      break;
    case REGVAL_T:
      t->arr8[1] = (t->arr8[1] >> 7) | (t->arr8[1] << 1);
      bytes[7] = t->arr8[6] >> 5;
      bytes[6] = 0;
      t->arr8[6] = bytes[7];
      t->arr8[7] = bytes[6];
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case CPU_T:
      *(uint16_t *)(&t->arr8[6]) = byteswap16(*(uint16_t *)(&t->arr8[6]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case PROCESS_T:
      *(uint32_t *)(&t->arr8[8]) = byteswap32(*(uint32_t *)(&t->arr8[8]));
      *(uint32_t *)(&t->arr8[12]) = byteswap32(*(uint32_t *)(&t->arr8[12]));
      *(uint32_t *)(&t->arr8[16]) = byteswap32(*(uint32_t *)(&t->arr8[16]));
      *(uint32_t *)(&t->arr8[20]) = byteswap32(*(uint32_t *)(&t->arr8[20]));
      break;
    case DMA_T:
      t->arr8[1] = t->arr8[1] << 7;
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      break;
    case LEFTDELIM_T:
    case RIGHTDELIM_T:
      *(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      break;
    case PREG_T:
      *(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
      *(uint16_t *)(&t->arr8[6]) = byteswap16(*(uint16_t *)(&t->arr8[6]));
      t->arr8[9] = t->arr8[9] >> 6;
      *(uint16_t *)(&t->arr8[16]) = byteswap16(*(uint16_t *)(&t->arr8[16]));
      *(uint16_t *)(&t->arr8[18]) = byteswap16(*(uint16_t *)(&t->arr8[18]));
      *(uint16_t *)(&t->arr8[20]) = byteswap16(*(uint16_t *)(&t->arr8[20]));
      *(uint16_t *)(&t->arr8[22]) = byteswap16(*(uint16_t *)(&t->arr8[22]));
      break;
    case PHYSADDR_T:
      t->arr8[1] = (t->arr8[1] >> 7) | (t->arr8[1] << 1);
      bytes[3] = t->arr8[2] >> 5;
      bytes[2] = 0;
      t->arr8[2] = bytes[3];
      t->arr8[3] = bytes[2];
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case PAVADIFF_T:
      t->arr8[1] = (t->arr8[1] >> 7) | (t->arr8[1] << 1);
      t->arr8[2] = (t->arr8[2] >> 5);
      t->arr8[3] = 0;
      *(uint16_t *)(&t->arr8[4]) = byteswap16(*(uint16_t *)(&t->arr8[4]));
      *(uint16_t *)(&t->arr8[6]) = byteswap16(*(uint16_t *)(&t->arr8[6]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case FILEMARKER_T:
      t->arr8[1] = (t->arr8[1] >> 7) | (t->arr8[1] << 1);
      t->arr8[4] = (t->arr8[4] >> 6);
      t->arr8[5] = t->arr8[6] = t->arr8[7] = 0;
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case PATCH_T:
      t->arr8[1] = (t->arr8[1] << 7);
      *(uint16_t *)(&t->arr8[4]) = byteswap16(*(uint16_t *)(&t->arr8[4]));
      break;
    case HWINFO_T:
      t->arr8[1] = (t->arr8[1] >> 7);
      *(uint16_t *)(&t->arr8[4]) = byteswap16(*(uint16_t *)(&t->arr8[4]));
      *(uint16_t *)(&t->arr8[6]) = byteswap16(*(uint16_t *)(&t->arr8[6]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case MEMVAL_T:
      b = t->arr8[1];
      t->arr8[1] = (b >> 7) | ((b&0x40) >> 5) | ((b&0x20) >> 3) | (b << 6);
      if (b & 0x80) {		/* ismemval128 */
	*(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      }
      else {			/* ismemval64 */
	t->arr8[3] = (t->arr8[3] << 4);
      }
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case BUSTRACE_T:
      b = t->arr8[1];
      t->arr8[1] = (b >> 7) | ((b&0x40) >> 5) | ((b&0x20) >> 3) |
	((b&0x10) >> 1) | (b << 4);
      bytes[2] = (t->arr8[3] >> 2) | (t->arr8[2] << 6);
      bytes[3] = (t->arr8[2] >> 2) | (t->arr8[3] << 6);
      t->arr8[2] = bytes[3];
      t->arr8[3] = bytes[2];
      b = t->arr8[4];
      bytes[7] = (b >> 7) | ((b&0x40) >> 5) | (t->arr8[6] & 0xfc);
      t->arr8[4] = bytes[7];
      t->arr8[6] = (b & 0x3f);
      t->arr8[7] = 0;
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case SNOOP_T:
      *(uint16_t *)(&t->arr8[2]) = byteswap16(*(uint16_t *)(&t->arr8[2]));
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint16_t *)(&t->arr8[16]) = byteswap16(*(uint16_t *)(&t->arr8[16]));
      break;
    case TSB_ACCESS_T:
      t->arr8[1] = (t->arr8[1] << 7);
      bytes[2] = (t->arr8[2] << 6) | (t->arr8[3] >> 2);
      bytes[3] = (t->arr8[3] << 6);
      t->arr8[2] = bytes[3];
      t->arr8[3] = bytes[2];
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case RFS_SECTION_HEADER_T:
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      break;
    case RFS_CW_T:
      bytes[1] = (t->arr8[2] << 2) | (t->arr8[1] >> 6);
      bytes[2] = (t->arr8[1] << 2) | (t->arr8[2] >> 6);
      t->arr8[1] = bytes[2];
      t->arr8[2] = bytes[1];
      switch (bytes[1] >> 2) {
      case cw_reftype_DMA_R:
      case cw_reftype_DMA_W:
	*(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
	break;
      default:
	b = t->arr8[5];
	t->arr8[5] = (b >> 7) | ((b&0x7c) >> 1);
	t->arr8[6] = 0;
	t->arr8[7] = 0;
	break;
      }
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case RFS_BT_T:
      bytes[3] = (t->arr8[2] >> 6) | (t->arr8[1] << 2);
      bytes[2] = (t->arr8[1] >> 6) | ((t->arr8[2] & 0x20) >> 3);
      t->arr8[1] = bytes[3];
      t->arr8[2] = bytes[2];
      t->arr8[3] = 0;
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    case TRAPPING_INSTR_T:
      b = t->arr8[1];
      t->arr8[1] = (b >> 7) | ((b&0x40) >> 5) | ((b&0x20) >> 3) |
	((b&0x10) >> 1) | ((b&8) << 1);
      bytes[2] = (t->arr8[2] >> 6);
      bytes[3] = (t->arr8[2] << 2) | (t->arr8[3] >> 6);
      t->arr8[2] = bytes[3];
      t->arr8[3] = bytes[2];
      *(uint32_t *)(&t->arr8[4]) = byteswap32(*(uint32_t *)(&t->arr8[4]));
      *(uint64_t *)(&t->arr8[8]) = byteswap64(*(uint64_t *)(&t->arr8[8]));
      *(uint64_t *)(&t->arr8[16]) = byteswap64(*(uint64_t *)(&t->arr8[16]));
      break;
    }
  }
};

#endif
