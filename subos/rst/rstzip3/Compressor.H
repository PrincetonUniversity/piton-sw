/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: Compressor.H
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
// OpenSPARC T2 Processor File: Compressor.H
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
#ifndef _COMPRESSOR_H
#define _COMPRESSOR_H

#include "rstf/rstf.h"

#define COMPRESSOR_CLASS_VERSION_STR "1.00"

class Compressor {
public:
  virtual int getMajorVersion() = 0;

  virtual int getMinorVersion() = 0;

  virtual const char* getVersionStr() = 0;

  virtual int open(const char* file, const char* mode, const char* options) = 0;

  virtual int compress(rstf_unionT* rstbuf, int nrecs) = 0;

  virtual int decompress(rstf_unionT* rstbuf, int nrecs) = 0;

  virtual void close() = 0;
};

#endif  // _COMPRESSOR_H
