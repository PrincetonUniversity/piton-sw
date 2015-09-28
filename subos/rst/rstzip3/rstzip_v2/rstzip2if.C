// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: rstzip2if.C
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
#include <assert.h>

#include "rstzip2if.H"
#include "rstzipif.H"

// C++ rstzip2 (de)compression class.

Rstzip2if::Rstzip2if() {
  rstzip = new RstzipIF;
  assert(rstzip != NULL);
}

Rstzip2if::~Rstzip2if() {
  delete rstzip;
}

// ==== Version routines ====

int Rstzip2if::getMajorVersion() {
  return RSTZIP_MAJOR_VERSION;
}

int Rstzip2if::getMinorVersion() {
  return RSTZIP_MINOR_VERSION;
}

// ==== Compression routines ====

int Rstzip2if::openRstzip(const char* outfile, int buffersize, int gzip, int stats, int numcpus) {
  return rstzip->openRstzip(outfile, buffersize, gzip, stats, numcpus);
}

int Rstzip2if::compress(rstf_unionT* rstbuf, int nrecs) {
  return rstzip->compress(rstbuf, nrecs);
}

void Rstzip2if::closeRstzip() {
  rstzip->closeRstzip();
}

// ==== Decompression routines ====

int Rstzip2if::openRstunzip(const char* infile, int buffersize, int gzip, int stats) {
  return rstzip->openRstunzip(infile, buffersize, gzip, stats);
}

int Rstzip2if::decompress(rstf_unionT* rstbuf, int nrecs) {
  return rstzip->decompress(rstbuf, nrecs);
}

void Rstzip2if::closeRstunzip() {
  rstzip->closeRstunzip();
}

// C wrapper prototypes.

int rz2_getMajorVersion(Rstzip2if* rstzip) {
  return rstzip->getMajorVersion();
}

int rz2_getMinorVersion(Rstzip2if* rstzip) {
  return rstzip->getMinorVersion();
}

Rstzip2if* rz2_openRstzip(char* outfile, int buffersize, int gzip, int stats, int numcpus) {
  Rstzip2if* rstzip = new Rstzip2if;

  assert(rstzip != NULL);
  rstzip->openRstzip(outfile, buffersize, gzip, stats, numcpus);

  return rstzip;
}

int rz2_compress(Rstzip2if* rstzip, rstf_unionT* rstbuf, int nrecs) {
  return rstzip->compress(rstbuf, nrecs);
}

void rz2_closeRstzip(Rstzip2if* rstzip) {
  rstzip->closeRstzip();
  delete rstzip;
}

Rstzip2if* rz2_openRstunzip(char* infile, int buffersize, int gzip, int stats) {
  Rstzip2if* rstunzip = new Rstzip2if;

  assert(rstunzip != NULL);
  rstunzip->openRstunzip(infile, buffersize, gzip, stats);

  return rstunzip;
}

int rz2_decompress(Rstzip2if* rstunzip, rstf_unionT* rstbuf, int nrecs) {
  return rstunzip->decompress(rstbuf, nrecs);
}

void rz2_closeRstunzip(Rstzip2if* rstunzip) {
  rstunzip->closeRstunzip();
  delete rstunzip;
}
