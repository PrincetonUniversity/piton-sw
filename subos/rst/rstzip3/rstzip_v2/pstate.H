/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: pstate.H
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
// OpenSPARC T2 Processor File: pstate.H
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
enum {
  PSTATE_CLE = 2,
  PSTATE_TLE,
  PSTATE_MM,
  PSTATE_RED,
  PSTATE_PEF,
  PSTATE_AM,
  PSTATE_PRIV,
  PSTATE_IE,
  PSTATE_AG
};

class Pstate {
public:
  uint32_t pstate;

  Pstate() {
    pstate = 0x0;  // PSTATE.AM == 0
  }

  int getField(int field) {
    int pstate_field;

    switch (field) {
    case PSTATE_CLE:
      pstate_field = (pstate << 22) >> 31;
      break;
    case PSTATE_TLE:
      pstate_field = (pstate << 23) >> 31;
      break;
    case PSTATE_MM:
      pstate_field = (pstate << 24) >> 30;
      break;
    case PSTATE_RED:
      pstate_field = (pstate << 26) >> 31;
      break;
    case PSTATE_PEF:
      pstate_field = (pstate << 27) >> 31;
      break;
    case PSTATE_AM:
      pstate_field = (pstate << 28) >> 31;
      break;
    case PSTATE_PRIV:
      pstate_field = (pstate << 29) >> 31;
      break;
    case PSTATE_IE:
      pstate_field = (pstate << 30) >> 31;
      break;
    case PSTATE_AG:
      pstate_field = (pstate << 31) >> 31;
      break;
    default:
      fprintf(stderr, "Warning: invalid field param passed to Pstate::getField() (field=%d)\n", field);
    }

    return pstate_field;
  }
};  // Pstate
