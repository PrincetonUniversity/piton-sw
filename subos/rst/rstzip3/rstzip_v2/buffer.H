/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: buffer.H
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
// OpenSPARC T2 Processor File: buffer.H
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
#ifndef _BUFFER_H
#define _BUFFER_H

#include <stdlib.h>
#include <sys/types.h>

typedef struct {
  rstf_unionT* rst;
  unsigned nrecs;
} RstSplit;

class RstzipBuffer {
public:
  rstf_unionT* rstbuf;
  int nrecs;
  int curindex;

  RstzipBuffer(int bufsize) {
    rstbuf = (rstf_unionT*) malloc((bufsize + PADDING) * sizeof(rstf_unionT));
    nrecs = 0;
    curindex = 0;
    buffersize = bufsize;
  }

  ~RstzipBuffer() {
    free(rstbuf);
  }

  int fillBuffer(rstf_unionT* buf, int bufrecs) {
    if (nrecs + bufrecs < buffersize + PADDING) {
      memcpy(&rstbuf[nrecs], buf, bufrecs * sizeof(rstf_unionT));
      nrecs += bufrecs;
    } else {
      fprintf(stderr, "Error: in FillRstBuffer::fillBuffer(): nrecs=%d, bufrecs=%d, max buffersize is %d\n",
	      nrecs, bufrecs, buffersize + PADDING);
      exit(1);
    }

    return nrecs;
  }

  int getLastCpuRecIndex() {
    int i;

    for (i = nrecs - 1; i >= 0; i--) {
      if (rstbuf[i].proto.rtype == CPU_T) {
	break;
      }
    }

    return i;
  }

  int shiftBuffer(int index) {
    if (index > nrecs) {
      fprintf(stderr, "Error: in RstzipBuffer::shiftBuffer() index (%d) > nrecs (%d)\n", index, nrecs);
      exit(1);
    } 

    if (index > 0) {
      // Only do this if we have something to move.
      // index = 0 when we flush this buffer; index = -1 when we're done decompressing.
      nrecs -= index;
      memmove(&rstbuf[0], &rstbuf[index], nrecs * sizeof(rstf_unionT));
    } else {
      nrecs = 0;
    }

    curindex = 0;

    return nrecs;
  }

protected:
  enum {
    PADDING = 1000
  };

  int buffersize;
};  // RstzipBuffer

#endif  // _BUFFER_H
