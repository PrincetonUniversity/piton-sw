// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T2 Processor File: Rstzip.C
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
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include <ctype.h>
#include <limits.h>

#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <pwd.h>

#include "Rstzip.H"

#include "rstzip_v3/rstzip3.h"

#include "rstzip_v2/rstzip2if.H"

#include <zlib.h>

/* the latest rstzip version supported by this rstzip library is rstzip3_major_version.rstzip3_minor_version */

struct Rstzip_impl {
  enum agent_e {agent_NIL = 0, rstzip3_agent, rstzip2_agent, rstzip1_agent, rstzip0_agent} agent; // rstzip0 is raw (uncompressed) rst
  // rstzip1 and 2 agents goes here


  Rstzip_impl() {
    agent = agent_NIL;
    c_nd = false;
    verbose = false;
    stats = false;
    records_checked_for_traceid = 0;
    filename = NULL;
    rz3obj = NULL;
    rz2obj = NULL;
    rz0gzf = NULL;
  }

  ~Rstzip_impl() {

    if (filename != NULL) {
      free(filename); filename = NULL;
    }
  }

  void process_opt_str(const char * opts) {
    if (opts != NULL) {
      if (strstr(opts, "verbose=1") != NULL) {
	verbose = true;
      }
      if (strstr(opts, "stats=1") != NULL) {
	stats = true;
      }

      if (strstr(opts, "version=0") != NULL) {
	agent = rstzip0_agent;
      } else if (strstr(opts, "version=1") != NULL) {
	agent = rstzip1_agent;
      } else if (strstr(opts, "version=2") != NULL) {
	agent = rstzip2_agent;
      } else if (strstr(opts, "version=3") != NULL) {
	agent = rstzip3_agent;
      } // else - leave agent undefined
    }
  }

  int getMajorVersion();
  int getMinorVersion();
  const char * getVersionStr();

  char * filename;

  bool c_nd;
  bool verbose;
  bool stats;
  int records_checked_for_traceid;

  struct rstzip3 * rz3obj;
  Rstzip2if * rz2obj;
  gzFile rz0gzf;
}; // struct Rstzip_impl


int Rstzip_impl::getMajorVersion()
{
  switch(agent) {
  case rstzip1_agent:
    return -1;
    break;
  case rstzip2_agent:
    return rz2obj->getMajorVersion();
    break;
  case rstzip3_agent:
  default:
    return rz3obj->getMajorVersion();
  }
} // int Rstzip::getMajorVersion()




int Rstzip_impl::getMinorVersion()
{
  switch(agent) {
  case rstzip1_agent:
    return -1;
    break;
  case rstzip2_agent:
    return rz2obj->getMajorVersion();
    break;
  case rstzip3_agent:
  default:
    return rz3obj->getMinorVersion();
  }
} // int Rstzip_impl::getMinorVersion()



const char * Rstzip_impl::getVersionStr()
{
  switch(agent) {
  case rstzip1_agent:
    return "error";
    break;
  case rstzip2_agent:
    // return rz2obj->getVersionStr();
    return "2.1";
    break;
  case rstzip3_agent:
  default:
    return rz3obj->getVersionStr();
  }
} // const char * Rstzip_impl::getVersionStr()






Rstzip::Rstzip()
{
  impl = new Rstzip_impl;
}

Rstzip::~Rstzip()
{
  delete impl;
} // Rstzip::~Rstzip()


int Rstzip::getMajorVersion()
{
  return impl->getMajorVersion();
}



int Rstzip::getMinorVersion()
{
  return impl->getMinorVersion();
}


const char * Rstzip::getVersionStr()
{
  return impl->getVersionStr();
}





int Rstzip::open(const char * filename, const char * mode, const char *opts)
{

  if (filename != NULL) {
    impl->filename = strdup(filename);
  } else {
    impl->filename = strdup("NULL");
  }

  // If open for writing: use latest rstzip (rz3).
  // If open for reading, there are many possibilities:
  // 1. pipe or file (seekable or not)
  // 2. gzip'ed or raw rstzip or RAW RST
  // We work under those parameters.
  // We do not allocate a compressor object until we know the exact version
  // of the input from the rstzip header in the input.
  // We use gzread to take care of gzip/non-gzip data.
  // If we do not find an rstzip header OR an rst header, we bail.

  // process the options string
  impl->process_opt_str(opts);

  if ((mode == NULL) || (mode[0] == 0)) {
    fprintf(stderr, "ERROR: Rstzip::open(): mode must be \"r\" or \"w\"\n");
    return RSTZIP_ERROR;
  } else if (strcmp(mode, "r") == 0) {
    impl->c_nd = false;
  } else if (strcmp(mode, "w") == 0) {
    impl->c_nd = true;
  } else {
    fprintf(stderr, "ERROR: Rstzip::open(): mode must be \"r\" or \"w\"\n. Specified=%s\n", mode);
  }

  if (impl->c_nd) {

    impl->agent = Rstzip_impl::rstzip3_agent; // default
    impl->rz3obj = new rstzip3(filename, "w");
    if (impl->rz3obj->error()) {
      return RSTZIP_ERROR;
    }
    if (impl->verbose) impl->rz3obj->setverbose();
    if (impl->stats) impl->rz3obj->setstats();

  } else {


    if (filename != NULL) {
      /* if input is not stdin read in a few bytes to determine rstzip version */
      gzFile gzf = gzopen(filename, "r");
      if (gzf == NULL) {
	fprintf(stderr, "ERROR: Rstzip::open(): failed gzopen of output file "); perror(filename);
	return RSTZIP_ERROR;
      }

      // if version hasn't been specified, try to determine version using input data */

      enum Rstzip_impl::agent_e agent = Rstzip_impl::agent_NIL;

      // read the first 24 bytes to check version
      uint8_t b24[24];
      int rv = gzread(gzf, b24, 24);
      if (rv != 24) {
	return RSTZIP_ERROR;
      }
      gzclose(gzf);

      // check version string
      if ((b24[0] == 'R') && (b24[1] == 'Z')) {
	int ver = b24[2]-'0';
	if (ver == 3) {
	  agent = Rstzip_impl::rstzip3_agent;
	} else if (ver == 2) {
	  agent = Rstzip_impl::rstzip2_agent;
	} else if (ver == 1) {
	  agent = Rstzip_impl::rstzip1_agent;
	} else {
	  if (impl->agent != Rstzip_impl::rstzip0_agent) {
	    fprintf(stderr, "ERROR: Rstzip::open(): invalid rstzip signature RZ%c (\\%03o) in input file %s\n", (isprint(b24[2])? b24[2] : '?'), b24[2], filename);
	    return RSTZIP_ERROR;
	  }
	} // which RZ version in input file?
      } else if (strstr(filename, ".rst\0") != NULL) {
	agent = Rstzip_impl::rstzip0_agent;
      } else /* no rstzip signature */ {
	// if we find a valid rst header, open it as an uncompressed rst file
	rstf_headerT * hdr = (rstf_headerT *) b24;
	if ((hdr->rtype == RSTHEADER_T) && (hdr->percent == '%') && (hdr->header_str[0] != 0) && (strcmp(hdr->header_str, RSTF_MAGIC) == 0)) {
	  agent = Rstzip_impl::rstzip0_agent;
	} else if (impl->agent == Rstzip_impl::agent_NIL){
	  fprintf(stderr, "ERROR: Rstzip::open(): could not determine input file type\n");
	  return RSTZIP_ERROR;
	}
      } // RZ or uncompressed rstzip?

      // at this point, we have either determined version information from the file, or it was specified using the option string.
      // if neither of these two cases is true, or if the two don't match, signal an error
      if (impl->agent == Rstzip_impl::agent_NIL) {
	if (agent == Rstzip_impl::agent_NIL) {
	  fprintf(stderr, "ERROR: Rstzip::open(): could not determine input file type\n");
	  return RSTZIP_ERROR;
	} else {
	  impl->agent = agent;
	}
      } else {
	if ((agent != Rstzip_impl::agent_NIL) && (agent != impl->agent)) {
	  fprintf(stderr, "Warning: rstzip: specified rstzip major version does not match input data\n");
	}
      }

    } else /* input from stdin */ {
      // for now, assume rz3
      if (impl->agent == Rstzip_impl::agent_NIL) {
	impl->agent = Rstzip_impl::rstzip3_agent;
      } // else - version specified in options string
    } // input from stdin or disk file?


    switch(impl->agent) {

    case Rstzip_impl::rstzip3_agent:

      impl->rz3obj = new rstzip3(filename, "r");
      if (impl->rz3obj->error()) {
	return RSTZIP_ERROR;
      }
      if (impl->verbose) impl->rz3obj->setverbose();
      if (impl->stats) impl->rz3obj->setstats();

      break;

    case Rstzip_impl::rstzip2_agent:
      impl->rz2obj = new Rstzip2if();
      impl->rz2obj->openRstunzip(filename, 40000, /* gzip */ 1, (impl->stats? 1: 0));
      break;

    case Rstzip_impl::rstzip1_agent:

      break;
    case Rstzip_impl::rstzip0_agent:
      impl->rz0gzf = gzopen(filename, "r");
      if (impl->rz0gzf == NULL) {
	fprintf(stderr, "ERROR: Rstzip::open(): failed gzopen of output file "); perror(filename);
	return RSTZIP_ERROR;
      }

      break;
    default:
      return RSTZIP_ERROR;

    } // which agent?

  } // compress/decompress?

  return RSTZIP_OK;
} // int Rstzip::open(const char * filename, const char * mode, const char *obs)




int Rstzip::compress(rstf_unionT * rstbuf, int nrecs)
{
  if (! impl->c_nd) {
    fprintf(stderr, "ERROR: Rstzip::compress() - cannot compress in \"r\" (decompress) mode\n");
    return 0;
  }

  return impl->rz3obj->compress(rstbuf, nrecs);
} // int Rstzip::compress(rstf_unionT * rstbuf, int nrecs)


int Rstzip::decompress(rstf_unionT * rstbuf, int nrecs)
{
  if (impl->c_nd) {
    fprintf(stderr, "ERROR: Rstzip::decompress() - cannot decompress in \"w\" (compress) mode\n");
    return 0;
  }

  int rv;
  switch(impl->agent) {
  case Rstzip_impl::rstzip3_agent:
    rv = impl->rz3obj->decompress(rstbuf, nrecs);
    break;
  case Rstzip_impl::rstzip2_agent:
    {
      int more = nrecs;
      while(more) {
        int n = (more >= 40000) ? 40000 : more; // magic buffer size from old rstzip2 main
        int actual = impl->rz2obj->decompress(rstbuf + (nrecs-more), n);
        if (actual == 0) break;
	more -= n;
      } // while more
      rv = nrecs - more;
    }
    break;
  case Rstzip_impl::rstzip1_agent:
    fprintf(stderr, "rstzip1 decompress: unimplmented");
    return 0;
    break;
  case Rstzip_impl::rstzip0_agent:
    rv = gzread(impl->rz0gzf, rstbuf, nrecs*sizeof(rstf_unionT))/24;

  default:
    fprintf(stderr, "Rstzip::decompress: invalid state (Rstzip_impl::agent)\n");
    return 0;
  }

  return rv;
} // int Rstzip::decompress(rstf_unionT * rstbuf, int nrecs)


void Rstzip::close()
{
  if (impl->c_nd) {
    delete impl->rz3obj;
  } else {
    switch(impl->agent) {
    case Rstzip_impl::rstzip1_agent:
    case Rstzip_impl::rstzip2_agent:
      impl->rz2obj->closeRstunzip();
      break; // unsupported
    case Rstzip_impl::rstzip3_agent:
      delete impl->rz3obj;
      impl->rz3obj = NULL;
      break;
    case Rstzip_impl::rstzip0_agent:
      gzclose(impl->rz0gzf); impl->rz0gzf = NULL;
    default:
      break;
    }
  }
} // void Rstzip::close()



// C interface (legacy)

Rstzip * rzMakeRstzip()
{
  return new Rstzip;
}

int rzGetMajorVersion(Rstzip* rz)
{
  return rz->getMajorVersion();
}

int GetMinorVersion(Rstzip * rz)
{
  return rz->getMinorVersion();
}

const char * rzGetVersionStr(Rstzip * rz)
{
  return rz->getVersionStr();
}


int rzOpen(Rstzip * rz, const char * file, const char * md, const char * options)
{
  return rz->open(file, md, options);
}

int rzCompress(Rstzip * rz, rstf_unionT * rstbuf, int nrecs)
{
  return rz->compress(rstbuf, nrecs);
}

int rzDecompress(Rstzip * rz, rstf_unionT * rstbuf, int nrecs)
{
  return rz->decompress(rstbuf, nrecs);
}

void rzClose(Rstzip * rz)
{
  rz->close();
}
