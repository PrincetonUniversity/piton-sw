/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rstzip2if.H
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
// OpenSPARC T2 Processor File: rstzip2if.H
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
#ifndef _RSTZIP2IF_H
#define _RSTZIP2IF_H

// ==== Programming Notes ====
//
// All programs using these routines must be linked with 
//   /import/archperf/lib/32/librstzip2.a
//   /import/shade/v6/beta-2.0.0-32/lib/libspix_sparc.a
// and
//   /import/archperf/local/lib/32/libz.a
// or their respective 64bit versions.
// 
// See
//   /import/archperf/pkgs/rstzip2-2.00/rstzip2.C
// for an example of using this library.

#include "rstf/rstf.h"

#ifdef __cplusplus

class RstzipIF;  // Defined in rstzipif.H

// C++ rstzip2 (de)compression class.

class Rstzip2if {
 public:
  Rstzip2if();

  ~Rstzip2if();

  // ==== Compression example ====
  //
  //    rstzip->openRstzip(outfile, BUFFERSIZE, gzip, stats, numcpus);
  //    while (nrecs > 0) {
  //      rstzip->compress(rstbuf, nrecs);
  //      nrecs = fread(rstbuf, sizeof(rstf_unionT), BUFFERSIZE, infp);
  //    }
  //    rstzip->closeRstzip();

  // ==== Decompression example ====
  //
  //    rstzip->openRstunzip(infile, BUFFERSIZE, gzip, stats);
  //    nrecs = rstzip->decompress(rstbuf, BUFFERSIZE);
  //    while (nrecs > 0) {
  //      fwrite(rstbuf, sizeof(rstf_unionT), nrecs, outfp);
  //      nrecs = rstzip->decompress(rstbuf, BUFFERSIZE);
  //    }
  //    rstzip->closeRstunzip();

  // ==== Version routines ====

  // DESCRIPTION
  // Returns integers corresponding to the major and minor versions of the
  // compressor library.
  int getMajorVersion();
  int getMinorVersion();

  // ==== Compression routines ====

  // DESCRIPTION
  // Opens the file pointed to by 'outfile' and associates the Rstzip2if
  // object with it.
  //
  // The argument 'buffersize' specifies the memory allocation size
  // (in number of RST records) for the compressor's internal buffers.
  // This argument must be greater then or equal to the largest
  // 'nrecs' parameter that will be passed to passed to compress().
  //
  // The argument 'gzip' indicates whether the output should be gzip
  // compressed in addition to rstzip2 compressed.
  //   gzip = 1     Gzip the output.
  //   gzip = 0     Do not gzip the output.
  //
  // The argument 'stats' indicates whether compression statistics should
  // be printed to stderr after compression ends.
  //   stats = 1    Print compression stats
  //   stats = 0    Do no print compression stats.
  //
  // The argument 'numcpus' indicates whether the input trace is a 
  // multi-processor trace or not.
  //   numcpus = 1  Input is a uni-processor trace.  Use this for compressing
  //                RST traces from versions 1.09 and below.
  //   numcpus = 0  (or anything other than 1) Input is an MP trace.  Use
  //                this for compressing RST traces from versions 1.10 and
  //                above.
  //
  // RETURN VALUES
  // None.
  int openRstzip(const char* outfile, int buffersize, int gzip, int stats, int numcpus);

  // DESCRIPTION
  // Compresses exactly 'nrecs' RST records from 'rstbuf', and writes
  // the compressed data to the file opened by openRstzip().
  //
  // The argument 'nrecs' must be less than or equal to the
  // 'buffersize' passed to openRstzip(); otherwise, an error will be
  // reported and the program will exit.
  //
  // RETURN VALUES
  // The number of RST records compressed is returned; this value
  // should be equal to 'nrecs'.
  int compress(rstf_unionT* rstbuf, int nrecs);

  // DESCRIPTION
  // Flushes all internal compression buffers, writes compression statistics
  // to the file footer, and closes the file opened by openRstzip().  This
  // function must be called before exiting the program; otherwise, the end of
  // the compressed file will be corrupt.
  //
  // RETURN VALUES
  // None.
  void closeRstzip();

  // ==== Decompression routines ====

  // DESCRIPTION
  // Opens the file pointed to by 'infile' and associates the Rstzip2if
  // object with it.
  //
  // The argument 'buffersize' specifies the memory allocation size
  // (in number of RST records) for the compressor's internal buffers.
  // This argument must be greater then or equal to the largest
  // 'nrecs' parameter that will be passed to passed to decompress().
  //
  // The argument 'gzip' indicates whether the input should be gzip
  // decompressed in addition to rstzip2 decompressed.
  //   gzip = 1    Gunzip the input.
  //   gzip = 0    Do not gunzip the input.
  //
  // The argument 'stats' indicates whether compression statistics should
  // be printed to stderr after decompression ends.
  //   stats = 1   Print compression stats
  //   stats = 0   Do no print compression stats
  //
  // RETURN VALUES
  // None.
  int openRstunzip(const char* infile, int buffersize, int gzip, int stats);

  // DESCRIPTION
  // Decompresses up to 'nrecs' records from the file opened by
  // openRstunzip(), and writes the decompressed records into 'rstbuf'.
  //
  // The argument 'nrecs' must be less than or equal to the
  // 'buffersize' passed to openRstunzip(); otherwise, an error will be
  // reported and the program will exit.
  //
  // RETURN VALUES
  // The number of RST records decompressed is returned; this value
  // should be equal to 'nrecs'.
  int decompress(rstf_unionT* rstbuf, int nrecs);

  // DESCRIPTION
  // Flushes all internal decompression buffers, reads and compares
  // the decompression statistics with the file footer, and closes the
  // file opened by openRstunzip().  This function must be called
  // before exiting the program; otherwise, the end of the
  // decompressed file will be incomplete and possibly corrupt.
  //
  // RETURN VALUES
  // None.
  void closeRstunzip();

 protected:
  RstzipIF* rstzip;
};  // Rstzip2if

#else  // __cplusplus

  // Dummy C struct type.
  typedef struct Rstzip2if Rstzip2if;

#endif  // __cplusplus

#if 0

// C wrapper prototypes.

#ifdef  __cplusplus
extern "C" {
#endif

  // ==== Compression example ====
  //
  //    rstzip = rz2_openRstzip(outfile, BUFFERSIZE, gzip, stats, numcpus);
  //    while (nrecs > 0) {
  //      rz2_compress(rstzip, rstbuf, nrecs);
  //      nrecs = fread(rstbuf, sizeof(rstf_unionT), BUFFERSIZE, infp);
  //    }
  //    rz2_closeRstzip(rstzip);

  // ==== Decompression example ====
  //
  //    rstzip = rz2_openRstunzip(infile, BUFFERSIZE, gzip, stats);
  //    nrecs = rz2_decompress(rstzip, rstbuf, BUFFERSIZE);
  //    while (nrecs > 0) {
  //      fwrite(rstbuf, sizeof(rstf_unionT), nrecs, outfp);
  //      nrecs = rz2_decompress(rstzip, rstbuf, BUFFERSIZE);
  //    }
  //    rz2_closeRstunzip(rstzip);

  // ==== Version routines ====

  // DESCRIPTION
  // Returns integers corresponding to the major and minor versions of the
  // compressor library.
  int rz2_getMajorVersion(Rstzip2if* rstzip);
  int rz2_getMinorVersion(Rstzip2if* rstzip);

  // ==== Compression routines ====

  // DESCRIPTION
  // Opens the file pointed to by 'outfile' associates the Rstzip2if
  // object with it.
  //
  // The argument 'buffersize' specifies the memory allocation size
  // (in number of RST records) for the compressor's internal buffers.
  // This argument must be greater then or equal to the largest
  // 'nrecs' parameter that will be passed to passed to rz2_compress().
  //
  // The argument 'gzip' indicates whether the output should be gzip
  // compressed in addition to rstzip2 compressed.
  //   gzip = 1     Gzip the output.
  //   gzip = 0     Do not gzip the output.
  //
  // The argument 'stats' indicates whether compression statistics should
  // be printed to stderr after compression ends.
  //   stats = 1    Print compression stats
  //   stats = 0    Do no print compression stats.
  //
  // The argument 'numcpus' indicates whether the input trace is a 
  // multi-processor trace or not.
  //   numcpus = 1  Input is a uni-processor trace.  Use this for compressing
  //                RST traces from versions 1.09 and below.
  //   numcpus = 0  (or anything other than 1) Input is an MP trace.  Use
  //                this for compressing RST traces from versions 1.10 and
  //                above.
  //
  // RETURN VALUES
  // A pointer to the allocated Rstzip2if object is returned.
  Rstzip2if* rz2_openRstzip(const char* outfile, int buffersize, int gzip, int stats, int numcpus);

  // DESCRIPTION
  // Compresses exactly 'nrecs' RST records from 'rstbuf', and writes
  // the compressed data to the file opened by rz2_openRstzip().
  //
  // The argument 'rstzip' must point to an Rstzip2if object
  // previously allocated by calling rz2_openRstzip().
  //
  // The argument 'nrecs' must be less than or equal to the
  // 'buffersize' passed to rz2_openRstzip(); otherwise, an error will be
  // reported and the program will exit.
  //
  // RETURN VALUES
  // The number of RST records compressed is returned; this value
  // should be equal to 'nrecs'.
  int rz2_compress(Rstzip2if* rstzip, rstf_unionT* rstbuf, int nrecs);

  // DESCRIPTION
  // Flushes all internal compression buffers, writes compression statistics
  // to the file footer, and closes the file opened by rz2_openRstzip().  This
  // function must be called before exiting the program; otherwise, the end of
  // the compressed file will be corrupt.
  //
  // RETURN VALUES
  // None.
  void rz2_closeRstzip(Rstzip2if* rstzip);

  // ==== Decompression routines ====

  // DESCRIPTION
  // Opens the file pointed to by 'infile' and associates the Rstzip2if
  // object with it.
  //
  // The argument 'buffersize' specifies the memory allocation size
  // (in number of RST records) for the compressor's internal buffers.
  // This argument must be greater then or equal to the largest
  // 'nrecs' parameter that will be passed to passed to decompress().
  //
  // The argument 'gzip' indicates whether the input should be gzip
  // decompressed in addition to rstzip2 decompressed.
  //   gzip = 1    Gunzip the input.
  //   gzip = 0    Do not gunzip the input.
  //
  // The argument 'stats' indicates whether compression statistics should
  // be printed to stderr after decompression ends.
  //   stats = 1   Print compression stats
  //   stats = 0   Do no print compression stats
  //
  // RETURN VALUES
  // A pointer to the allocated Rstzip2if object is returned.
  Rstzip2if* rz2_openRstunzip(const char* infile, int buffersize, int gzip, int stats);

  // DESCRIPTION
  // Decompresses up to 'nrecs' records from the file opened by
  // rz2_openRstunzip(), and writes the decompressed records into 'rstbuf'.
  //
  // The argument 'nrecs' must be less than or equal to the
  // 'buffersize' passed to rz2_openRstunzip(); otherwise, an error will be
  // reported and the program will exit.
  //
  // RETURN VALUES
  // The number of RST records decompressed is returned; this value
  // should be equal to 'nrecs'.
  int rz2_decompress(Rstzip2if* rstzip, rstf_unionT* rstbuf, int nrecs);

  // DESCRIPTION
  // Flushes all internal decompression buffers, reads and compares
  // the decompression statistics with the file footer, and closes the
  // file opened by rz2_openRstunzip().  This function must be called
  // before exiting the program; otherwise, the end of the
  // decompressed file will be incomplete and possibly corrupt.
  //
  // RETURN VALUES
  // None.
  void rz2_closeRstunzip(Rstzip2if* rstzip);

#ifdef  __cplusplus
}
#endif

#endif

#endif  // _RSTZIP2IF_H
