/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rstf.c
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
#pragma ident "@(#)  rstf.c  1.3: 03/05/03 16:59:47 @(#)"
//
// This is C code, not C++
// 

#include <stdarg.h>		// ??
#include <stdio.h>		// fopen()
#include <string.h>		// strncmp()
#include <stdlib.h>		// putenv()

#include <sys/types.h>		// time_t
#include <sys/stat.h>		// struct stat
#include <time.h>		// time_t

#include "rstf.h"
#include "vercheck.c"

#ifndef true
  #define true 	1
  #define false 0
  typedef int boolean;
#endif

static int numbad = 0;			// number of bad RST recs
// static int dummy = RSTF_ATRACE_NO_PC;

#define print_type_size(out,type) \
	check(out, #type, sizeof(type), want);

static int streq (const char* a, const char* b) {
    return (strcmp(a, b) == 0);
}

static int endsWith (const char* str, const char* suffix) {
    int slen = strlen(str);
    int sufflen = strlen(suffix);
    return (sufflen <= slen) &&
	(strncmp(str+slen-sufflen, suffix, sufflen) == 0);
} /* endsWith */

//
// Version handling code
// 

  // Set of triples (AA,BB,CC), where
  //  Versions in the range [AA,BB) are compatiable.
  //  Versions with the same CC value are considered semi-compatible.
  //  Versions with different CC values are incompatible.
  //  The last entry should have AA = BB = CC = -1 .
  // Thus for this table:
  //   1.00 vs. 1.04 => compatible.
  //   1.04 vs. 1.06 => semi-compatible.
  //   1.07 vs. 1.09 => semi-compatible.
  //   1.10 vs. 2.02 => compatible.
double rst_vequivtab [][3] = {
    { 0.00,   1.00,  0.0 },
    { 1.00,   1.04,  1.0 },
    { 1.04,   1.06,  2.0 },
    { 1.06,   1.08,  2.0 },
    { 1.08,   1.10,  2.0 },
    { 1.10,   2.09,  3.0 },
    {  -1,    -1.0, -1.0 },
};

static double rstver2double (const char * str) {
    int x, y;
    int ni = sscanf(str, "%d.%d", &x, &y);
    double d = x*100 + y;
    return d / 100;
} /* rstver2double */

int rst_verCheck (
  const char* ct_str, const char* rt_str, double vt[][3], const char* modname
) {
    double ct_ver = rstver2double(ct_str);
    double rt_ver = rstver2double(rt_str);
    return ver_check_dbl(ct_ver, rt_ver, vt, modname);
} /* generic_verCheck */

int rstf_version_check_fn (const char* ct_version) {
    const char* rt_str = RSTF_VERSION_STR;
    return rst_verCheck(ct_version, rt_str, rst_vequivtab, "RST");
} /* rstf_version_check_fn */

int rstf_checkheader (const char* compile_time_ver, rstf_headerT *rec) {
    double ct_ver = rstver2double(compile_time_ver);
    if (rec->rtype == RSTHEADER_T) {
	double trace_ver = (100 * rec->majorVer) + rec->minorVer;
	trace_ver /= 100;

	if (rec->percent != '%') {
	    fprintf(stderr, "Non-compliant RST header: compile-on=%% got=%c\n",
		    rec->percent);
	}
	return ver_check_dbl(ct_ver, trace_ver, rst_vequivtab, "RST trace");
    }
    return VERCHECK_ERROR;
} /* rstf_checkheader */

typedef struct {
    FILE * f;
    int isCompressed;
} fileinfo_t;

static int nfileinfo = 0;
static fileinfo_t fileinfo[64];

static void printfi () {
    int i= 0;
    for (i=0; i<nfileinfo; i++) {
	fileinfo_t * pp = & fileinfo[i];
	fprintf(stderr,
		"[%d]->f=0x%0x iscompressed=%d\n", i, pp->f, pp->isCompressed);
    }
} /* printfi */

FILE * openRST (const char* filename) {
    FILE * f = NULL;
    int decompress = 
	endsWith(filename, ".rsz") ||
	endsWith(filename, ".rz.gz") ||
	endsWith(filename, ".rsz.gz") ||
	endsWith(filename, ".rzgz");
    int decompress2 = endsWith(filename, ".rz2.gz");
    if (decompress) {
	char command [2048];
	putenv("PATH=/import/archperf/bin:/usr/bin:/bin");
	sprintf(command, "rstzip -d -gz %s", filename);
	f = popen(command, "r");
    } else if (decompress2) {
	char command [2048];
	putenv("PATH=/import/archperf/bin:/usr/bin:/bin");
	sprintf(command, "rstunzip2 %s", filename);
	f = popen(command, "r");
    } else {
	f = fopen(filename, "r");
    }
    if (f != NULL) {
	fileinfo[nfileinfo].f = f;
	fileinfo[nfileinfo].isCompressed = decompress || decompress2;
	nfileinfo ++;
    }
    return f;
} /* openRST */

void closeRST (FILE* f) {
    int i= 0;
    for (i=0; i<nfileinfo; i++) {
	fileinfo_t * pp = & fileinfo[i];
	if (pp->f == f) {
	    if (pp->isCompressed) {
		pclose(f);
	    } else {
		fclose(f);
	    }
	    pp->f = NULL;
	    f = NULL;		/* we found it */
	    *pp = fileinfo[nfileinfo-1];
	    nfileinfo --;
	    break;
	}
    }
    /* guess the type of the file */
    if (f != NULL) {
	char* ftype = "unknown";
	if (isPipeRST(f)) {
	    pclose(f);
	    ftype = "pipe from popen";
	} else {
	    fclose(f);
	    ftype = "regular file";
	}
	fprintf(stderr, "closeRST(f=%x), guessed f is %s\n", f, ftype);
    }
} /* closeRST */

int isPipeRST (FILE* f) {
    struct stat statbuf;
    int fd = fileno(f);
    fstat(fd, &statbuf);
    return ((statbuf.st_mode & S_IFIFO) == S_IFIFO);
}

int isCompressedRSZ (char * buff, int bufflen) {
    // from running "od -x trace.rz.gz"
    static short want [] = {
	0x1f, 0x8b, 0x08, 0x00, -1, -1, -1, -1
    };
    int i;
    for (i=0; i<sizeof(want)/sizeof(want[0]) ; i++) {
	if (buff[i] != want[i] && want[i] != -1) {
	    return false;
	}
    }
    return true;
} /* isCompressedRSZ */

void check (FILE* out, const char* type, int tsize, int want) {
    fprintf(out, "sizeof(%18s) = %4d\n", type, tsize);
    if (tsize != want) {
	numbad ++;
	fprintf(out, "ERROR on (%s) field.\n", type, sizeof(type));
	fflush(out);
    }
} /* check */

static void initrec (void* ptr, uint8_t rtype) {
  INIT_RST_REC(ptr,rtype);
} /* initrec */

#define INIT_RST_REC_DBG(rstf_ptr,rtype_val) \
    do { \
	rstf_uint64T * p = (rstf_uint64T*) (rstf_ptr); \
	p->arr64[0] = (rtype_val); \
	p->arr64[0] <<= (64-8); \
	p->arr64[1] = 0; \
	p->arr64[2] = 0; \
    } while (0==1)

void testSizes () {
    FILE* out = stdout;
    rstf_protoT rec;
    rstf_protoT * p = &rec;
    int want = sizeof(rstf_unionT);

    print_type_size(out,rstf_unionT);
    print_type_size(out,rstf_protoT);
    print_type_size(out,rstf_whatT);
    print_type_size(out,rstf_instrT);
    print_type_size(out,rstf_tlbT);
    print_type_size(out,rstf_threadT);
    print_type_size(out,rstf_processT);
    print_type_size(out,rstf_pregT);
    print_type_size(out,rstf_trapT);
    print_type_size(out,rstf_cpuT);
    print_type_size(out,rstf_trapT);
    print_type_size(out,rstf_stringT);
    print_type_size(out,rstf_physaddrT);
    print_type_size(out,rstf_pavadiffT);
    print_type_size(out,rstf_memval64T);
    print_type_size(out,rstf_memval128T);
    print_type_size(out,rstf_bustraceT);
    print_type_size(out,rstf_filemarkerT);
    print_type_size(out,rstf_recnumT);
    print_type_size(out,rstf_hwinfoT);
    print_type_size(out,rstf_statusT);
    print_type_size(out,rstf_patchT);
    print_type_size(out,rstf_dmaT);
    printf("================\n");
    print_type_size(out,rstf_uint8T);
    print_type_size(out,rstf_uint16T);
    print_type_size(out,rstf_uint32T);
    print_type_size(out,rstf_uint64T);
    if (numbad == 0) {
	fprintf(out, "Good.  All records in rstf are the same size.\n");
    }

    initrec(&rec, INSTR_T);
    fprintf(out, "OK rtype=%d want=%d\n", rec.rtype, INSTR_T); fflush(out);
    initrec(&rec, TLB_T);
    fprintf(out, "OK rtype=%d want=%d\n", rec.rtype, TLB_T); fflush(out);
//    INIT_RST_REC_DBG( p , INSTR_T);
//    fprintf(out, "OK rtype=%d want=%d\n", rec.rtype, INSTR_T); fflush(out);
    INIT_RST_REC( p , INSTR_T);
    fprintf(out, "OK rtype=%d want=%d\n", rec.rtype, INSTR_T); fflush(out);
}

static void strcopy (char* dest, const char* src, int destsize) {
    strncpy(dest, src, destsize);
    dest[destsize-1] = '\0';
} /* strcopy */

int rstf_strncpy (void * dest_rstp, const char *str) {
    rstf_unionT * up = (rstf_unionT *) dest_rstp;
    rstf_headerT * hp = &(up->header);
    switch (up->string.rtype) {
      case RSTHEADER_T:
	  strncpy(hp->header_str, str, sizeof(hp->header_str));
	  break;
      default:
	  ;
    }
    return 0;
} /* rstf_strncpy */

  // initialize a header record with the current RST major/minor number.
  // The string 
int init_rstf_header (rstf_headerT * hp) {
    char buff[80];
    INIT_RST_REC(hp, RSTHEADER_T);
    hp->majorVer = RSTF_MAJOR_VERSION;
    hp->minorVer = RSTF_MINOR_VERSION;
    hp->percent   = '%';
    sprintf(buff, "%s v%s", RSTF_MAGIC, RSTF_VERSION_STR);
    rstf_strncpy(hp, buff);
    return 0;
}

int init_rstf_traceinfo_level (rstf_traceinfo_levelT * ti, int level) {
    INIT_RST_REC(ti, TRACEINFO_T);
    ti->rtype2 = RSTT2_NLEVEL_T;
    ti->level = level;
    ti->time64 = (uint64_t) time(NULL);
    return 0;
}

int init_rstf_string (rstf_stringT * strp, const char *str) {
    int len = strlen(str) + 1;		// null char adds 1
    int recsize = sizeof(strp->string);
    INIT_RST_REC(strp, STRDESC_T);
    if (recsize >= len) {
	strncpy(strp->string, str, recsize);
    } else {
	strncpy(strp->string, str, recsize-1);
	strp->string[recsize-1] = '\0';
    }
    return 0;
} /* init_rstf_string */

  // get the next string
const char* get_rstf_longstr (const rstf_stringT * p, int nrec, int *nrread) {
    static char buff [2048];
    char* end = buff;		// 
    int nr = 0;
    const int strcontsize = sizeof(p->string);
    while (nr < nrec) {
	const rstf_stringT * strp = & (p[nr]);
	int rem = buff + sizeof(buff) - end;	// remaining room
	if (rem < strcontsize) {
	    break;
	}
	if (strp->rtype == STRCONT_T) {
	    strncpy(end, strp->string, strcontsize);
	    end += strcontsize;
	    nr ++;
	} else if (strp->rtype == STRDESC_T) {
	    strcpy(end, strp->string);
	    end += strlen(strp->string);
	    nr ++;
	    break;
	} else {
	    break;
	}
    }
    if (nrread != NULL) {
	*nrread = nr;
    }
    *end = '\0';
    return buff;
} /* get_rstf_long_string */

#define	min(x,y) ((x)<(y) ? (x) : (y))

  // Initialize upto MAXREC records with the string STR, using
  // STRDESC_T and STRCONT_T records.  Handles strings of any length.
  // Returns the number of RST records used.
int init_rstf_strbuff (rstf_stringT * strp, const char *str, int maxrec) {
    int len = strlen(str) + 1;		// null char adds 1
    int recsize = sizeof(strp->string);
    int nrneeded = ((len) + (recsize-1))/ recsize;
    int canuse = min(maxrec, nrneeded);		// RST records we can use
    const char* ss = str;
    int i;
    for (i=0; i<canuse; i++) {
	if (i == (canuse-1) ) {
	    init_rstf_string( &strp[i], ss );
	} else {
	    strp[i].rtype = STRCONT_T;
	    strncpy(strp[i].string, ss, recsize);
	    ss += recsize;
	}
    }
    return canuse;
} /* init_rstf_strbuff */

  // Convenience fn to generate a RST_STRDESC record.  
int rstf_sprintf (rstf_stringT * strp, const char* fmt, ...) {
  #define BUFFLEN 1024
    char buff[BUFFLEN];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buff, BUFFLEN, fmt, ap);
  #undef BUFFLEN
    init_rstf_string(strp, buff);
    va_end(ap);
    return 0;
} /* rst_sprintf */

  // Convenience fn to generate a RST_STRDESC record.  
int rstf_snprintf (rstf_stringT * strp, int maxrec, const char* fmt, ...) {
  #define BUFFLEN 8192
    char buff[BUFFLEN];
    int nr = 0;
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buff, 8192, fmt, ap);
  #undef BUFFLEN
    nr = init_rstf_strbuff(strp, buff, maxrec);
    va_end(ap);
    return nr;
} /* rst_sprintf */

void printIfBadAddr (uint64_t xaddr) {
    if (RSTF_IS_BADADDR(xaddr)) {
	printf("Addr 0x%08llx is a known bad RST addr\n", xaddr);
    }
}

void checkRSTmacro () {
    uint64_t x = RSTF_ATRACE_NO_PC;

    printIfBadAddr(x);
    x = 0x314159ff;
    printIfBadAddr(x);
    x = 0x314159fe;
    printIfBadAddr(x);
    x = 0x1234567;;
    printIfBadAddr(x);
}
    
#define RCBUFFSIZE 8192
char* unixcommand (const char * command, int nl, int * statusptr) {
    static char charbuff[RCBUFFSIZE];
    FILE *ptr = popen(command, "r");
    char *buf = charbuff;
    char *result = NULL;

    if (ptr != NULL) {
	int status;
	while (fgets(buf, RCBUFFSIZE - (buf-charbuff), ptr) != NULL) {
	    int len = strlen(buf);
	    if (buf[len-1] == '\n') {
		// remove '\n', terminate string, in case last line of input
		buf[len] = '\0';
		result = charbuff;
		if (nl <= 1) {
		    buf[len-1] = '\0';		// discard last newline
		    break;
		}
		nl --;
		buf += len;
	    }
	}
	status = pclose(ptr);
	if (statusptr != NULL) {
	    *statusptr = status;
	}
    }
    return result;
} /* unixcommand */

static void genTestTrace (const char* str) {
    rstf_unionT  uuu[256];
    rstf_stringT * buff = & (uuu[1].string);	// [1] == skip past header
    int nr , nr2;
    char* now = unixcommand("date", 1, NULL);
    char* df = NULL;
    init_rstf_header(& uuu[0].header);
    rstf_sprintf(buff, "BEGIN it is %s", now);
    nr = rstf_snprintf(buff+1, 88, "it is now %s", now);
    df = unixcommand("df -lk", 44, NULL);
    nr2 = rstf_snprintf(buff+1+nr, 88, "Local mounted disks %s", df);
    rstf_sprintf(buff+1+nr+nr2, "END.  argv[0]=(%s)", str);
    fwrite(&uuu, sizeof(buff[0]), 3+nr+nr2, stdout);
    fflush(stdout);
} /* genTestTrace */

#if defined(TEST_RSTF)

static void usage (char* argv0) {
    printf("usage: %s [-tvf]\n", argv0);
    printf("  -f FILE = read 16K recs from FILE openRST(), send to stdout\n");
    printf("  -t = generate a test trace to stdout\n");
    printf("  -v = run version check code\n");
    printf(" Eg.  %s -t | trconv\n", argv0);
} /* usage */

  // check a 
static void checkVer () {
    const char* strArr [] =
	{ "1.00", "1.4", "1.7", "1.8", "1.10", "2.0", "2.02", "4.8" };
    int len = sizeof(strArr) / sizeof(strArr[0]);
    int i = 0;
    for (i=0; i<len; i++) {
	int j;
	const char * ct = strArr[i];
	for (j=i; j<len; j++) {
	    const char * rt = strArr[j];
	    int status = generic_verCheck(ct, rt,  rst_vequivtab, "XYZ");
	    int status2 = rst_verCheck(ct, rt,  rst_vequivtab, "RST");

	    printf("%d = verCheck(%s, %s)\n", status, ct, rt);
	    printf("%d = rst_verCheck(%s, %s)\n", status2, ct, rt);
	}
    }
} /* checkVer */

int main (int argc, char* argv []) {
    if (argc == 1) {
	testSizes();
	checkRSTmacro();
	usage(argv[0]);
    } else {
	int i;
	for (i=1; i<argc; i++) {
	    if ( streq(argv[1], "-f") ) {
		i++;
		if (i<argc) {
		    FILE * f = openRST(argv[i]);
		    if (f != NULL) {
			rstf_unionT ru [128];
			int nr = -1;
			int tot = 0;
			while ((nr=fread(ru, sizeof(ru[0]), 128, f)) > 0) {
			    fwrite(ru, sizeof(ru[0]), nr, stdout);
			    tot += nr;
			    if (tot > 16384) {
				break;
			    }
			}
			closeRST(f);
		    }
		}
	    } else if ( streq(argv[1], "-v") ) {
		checkVer();
	    } else if ( streq(argv[1], "-v") ) {
		checkVer();
	    } else if ( streq(argv[1], "-t") ) {
		genTestTrace(argv[0]);
	    }
	}
    }
}

#endif /* defined() */
