/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: Rstzip.H
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
// OpenSPARC T2 Processor File: Rstzip.H
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
#ifndef _Rstzip_H_
#define _Rstzip_H_

// version number of Rstzip.H interface. not of the rstzip library
#define RSTZIP_VERSION_STR "3.19"

#include"rstf/rstf.h"
// #include "Compressor.H"


#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  RSTZIP_OK = 1,
  RSTZIP_ERROR = -1
} RstzipReturnVals;

  // this constant is provided as the default optimal buffer size.
  // alternative buffer sizes may be specified to the compressor using the options string
  // FIXME: the rstzip object can be queried for the buffer size of the input trace after the open() call

const int rstzip_opt_buffersize = 1<<15; // new since library version 3.22

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus

// ==== C++ Compression example ====
//
//    rz = new Rstzip;
//    rz->open(outfile, "w", "verbose=0");
//    nrecs = fread(rstbuf, sizeof(rstf_unionT), RZ_opt_bufsize, infp);
//    while (nrecs > 0) {
//      rstzip->compress(rstbuf, nrecs);
//      nrecs = fread(rstbuf, sizeof(rstf_unionT), opt_bufsize, infp);
//    }
//    rz->close();
//    delete rz;

// ==== C++ Decompression example ====
//
//    rz = new Rstzip;
//    rz->open(infile, "r", "verbose=0");
//    nrecs = rstzip->decompress(rstbuf, RZ_opt_bufsize);
//    while (nrecs > 0) {
//      fwrite(rstbuf, sizeof(rstf_unionT), nrecs, outfp);
//      nrecs = rz->decompress(rstbuf, RZ_opt_bufsize;
//    }
//    rz->close();

// class Rstzip : public Compressor {
class Rstzip {
public:
  Rstzip();

  ~Rstzip();

  // SYNOPSIS
  // virtual int getMajorVersion();
  // virtual int getMinorVersion();
  // virtual const char* getVersionStr();
  //
  // DESCRIPTION
  // Return compressor library version information.
  virtual int getMajorVersion();

  virtual int getMinorVersion();

  virtual const char* getVersionStr();

  // SYNOPSIS
  // virtual int
  // open(const char* file, const char* md, const char* options)
  //
  // DESCRIPTION
  // Opens 'file' for compressing or decompressing, and associates the
  // rstzip object with it.
  // 
  // The argument 'md' points to a string with one of the following
  // sequences:
  //   r  Open the compressed file for reading (decompression).
  //   w  Open the noncompressed file for writing (compression).
  // One of "r" and "w" must be specified.
  //
  // If the file parameter is NULL, the input file is set to stdin or stdout
  // depending on the mode: stdin if "r" and stdout if "w"
  //
  // options: all rstzip2 options are optional with this version.
  // Unrecognized options will be discarded. Recognized options are:
  //
  // verbose=0|1        <= produce verbose output while compressing/decompressing
  // stats=0|1          <= print compression statistics
  // ver=0|1|2|3        <= for decompression only: specify version of incoming file
  //
  //     when opening a disk file, rstzip detects its version automatically.
  //     however, when reading from stdin, rstzip v3 is assumed unless specified in
  //     this manner. If more than one version is specified, results are unpredictable
  //     Version 0 indicates a RAW RST trace file.
  //
  // FIXME: ADD information about buffersize here
  //
  // Note: normally, a raw RST trace can be detected by the presence of a valid RST
  // Header record. However, if this record is absent, manually specifying ver=0 is
  // the only way to indicate to rstzip that the input file is a raw rst file.
  //
  // example: const char * rz3_options = "verbose=0 stats=1"
  //
  // RETURN VALUES
  // Returns RSTZIP_OK (1) if the file is successfully opened; returns 
  // RSTZIP_ERROR (-1) otherwise.
  virtual int open(const char* file, const char* md, const char* options);

  // SYNOPSIS
  // virtual int compress(rstf_unionT* rstbuf, int nrecs);
  //
  // DESCRIPTION
  // Compresses exactly 'nrecs' RST records from 'rstbuf', and writes
  // the compressed data to the file opened by open().
  //
  // For best performance, 'nrecs' should be set to rstzip_opt_buffersize
  // or an integral multiple thereof. This minimizes memcpy() overhead.
  //
  // RETURN VALUES
  // The number of RST records compressed is returned; this value
  // should be equal to 'nrecs'.
  virtual int compress(rstf_unionT* rstbuf, int nrecs);

  // SYNOPSIS
  // virtual int decompress(rstf_unionT* rstbuf, int nrecs);
  //
  // DESCRIPTION
  // Decompresses up to 'nrecs' records from the file opened by
  // open(), and writes the decompressed records into 'rstbuf'.
  //
  // For best performance, 'nrecs' should be set to rstzip3_opt_buffersize
  // or an integral multiple thereof. This minimizes memcpy() overhead.
  //
  //
  // RETURN VALUES
  // The number of RST records decompressed is returned; this value
  // should be equal to 'nrecs', unless the end of the compressed
  // trace is reached. Subsequent calls to decompress() will return 0.
  virtual int decompress(rstf_unionT* rstbuf, int nrecs);

  // SYNOPSIS
  // virtual void close();
  //
  // DESCRIPTION
  // Flushes all internal buffers, and closes the file specified by open().
  // This function must be called before exiting the program, or the 
  // (de)compressed file will be corrupted.
  //
  // RETURN VALUES
  // None.
  virtual void close();

  // FIXME: add function to flush internal buffer while compressing
  //   while decompressing, we don't have this option because the
  //   buffer size is fixed in the input compressed file.
  // virtual void flush();

  // FIXME: add function to return the dynamic optimal buffer size
  //
  // for compression, the optimal buffer size is one that would exactly
  // fill up the internal buffer, if any so that subsequent compress() calls
  // would not require memcpy() into the internal buffer.
  // 
  // for decompression, the optimal buffer size is one that would exactly
  // empty the internal buffer, if any, so that subsequent decompress() calls
  // would directly decompress into the caller's buffer.
  //
  // virtual int opt_buffer_size();

  // protected:
  // Compressor* rstzip;
private:
  struct Rstzip_impl * impl;

}; // class Rstzip;

#else  // __cplusplus

typedef struct Rstzip Rstzip;

#endif  // __cplusplus

#ifdef __cplusplus
extern "C" {
#endif

// SYNOPSIS
// Rstzip* rzMakeRstzip();
//
// DESCRIPTION
// Allocate an Rstip Compressor object.  The object is deallocated by the
// rzClose() function.
//
// RETURN VALUES
// Pointer to the allocated Rstzip Compressor object.
Rstzip* rzMakeRstzip();

int rzGetMajorVersion(Rstzip* rstzip);

int rzGetMinorVersion(Rstzip* rstzip);

const char* rzGetVersionStr(Rstzip* rstzip);

int rzOpen(Rstzip* rstzip, const char* file, const char* md, const char* options);

int rzCompress(Rstzip* rstzip, rstf_unionT* rstbuf, int nrecs);

int rzDecompress(Rstzip* rstzip, rstf_unionT* rstbuf, int nrecs);

void rzClose(Rstzip* rstzip);

#ifdef __cplusplus
}
#endif



// for backwards compatibility. this structure is not used in rstzip3
#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  uint32_t buffersize;
  uint8_t  numcpus;
  uint8_t  gzip;
  uint8_t  stats;
  uint8_t  version;
  uint8_t  rstzip;  // For Zio.H
} RstzipOptions;

#ifdef __cplusplus
}
#endif // #ifdef __cplusplus

char* makeRstzipOptionsString(RstzipOptions* opts);


#endif //  _Rstzip_H_
