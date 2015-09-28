/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: header.H
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
// OpenSPARC T2 Processor File: header.H
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
#ifndef _HEADER_H
#define _HEADER_H

#include <string.h>
#include <stdlib.h>

#define RSTZIP_HEADER_NUMCPU_STRING "Numcpus="

class RstzipHeader {
public:
  RstzipHeader() {
    memset(header, 0, RSTZIP_HEADERSIZE);
    strcpy(header, "RZ2 -- Rstzip2 compressed RST file.\n");
  }

  char* getHeader() {
    return header;
  }

  void setNumcpus(int numcpus) {
    char text[80];

    sprintf(text, "%s%d.\n", RSTZIP_HEADER_NUMCPU_STRING, numcpus);
    strcat(header, text);
  }

  int getNumcpus() {
    char* pnumcpu = strstr(header, RSTZIP_HEADER_NUMCPU_STRING);

    if (pnumcpu != NULL) {
      return atoi(pnumcpu + sizeof(RSTZIP_HEADER_NUMCPU_STRING) - 1);
    }

    return 0;
  }

  int getHeaderSize() {
    return strlen(header);
  }

  int getMaxHeaderSize() {
    return RSTZIP_HEADERSIZE;
  }

  int isValid() {
    return (strncmp(header, "RZ2", 3) == 0);
  }

protected:
  enum {
    RSTZIP_HEADERSIZE = 512
  };

  char header[RSTZIP_HEADERSIZE];
};  // RstzipHeader

#endif  // _HEADER_H
