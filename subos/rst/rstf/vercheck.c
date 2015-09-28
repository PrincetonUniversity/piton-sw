/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: vercheck.c
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
// 
// ANSI C file: vercheck.c
// R. W. Quong		Aug  6 2001
// 

#include <stdlib.h>		// atof()
#include <stdio.h>		// fopen(), stderr
#include "vercheck.h"

  // get the index in equivTab
int verIndex (double ver, double equivTab [][3] ) {
    int i = 0;
    for (i=0; i>=0; i++) {		// rely on breaking out of loop
	double (*dp)[3] = &equivTab[i];
	if ((*dp)[0] <= ver && ver < (*dp)[1]) {
	    return i;
	}
	if ((*dp)[0] < 0 || (*dp)[1] < 0) {
	    return -1;
	}

	// version numbers greater than 4000 are extremely likely
	if ((*dp)[0] > 4000 || (*dp)[1] > 4000) {
	    return -1;
	}
    }
    return -1;
}

  // compare version strings, by converting them to doubles via atof()
  // compare compile version CT_STR with runtime version RT_STR using 
  // version comparison table VT.
  // If problems, use modname XYZ in the error/warning messages.
static int generic_verCheck (
  const char* ct_str, const char* rt_str, double vt[][3] , const char* modname
) {
    double ct_ver = atof(ct_str);
    double rt_ver = atof(rt_str);
    return ver_check_dbl(ct_ver, rt_ver, vt, modname);
} /* generic_verCheck */

static int ver_check_dbl (
    double ct_ver, double rt_ver, double vt[][3], const char* modname
) {
    int rtidx = verIndex(rt_ver, vt);  // index into vt
    int ctidx = verIndex(ct_ver, vt);  // index into vt

    if (rtidx == -1) {
	fprintf(stderr, "Warning: pkg=%s version %f cannot find entry\n",
		    modname, rt_ver);
    }
    if (ctidx == -1) {
	fprintf(stderr, "Warning: pkg=%s version %f cannot find entry\n",
		    modname, ct_ver);
    }

    if (rtidx == ctidx) {
	return VERCHECK_MATCH;
    } else {
	int rtMajor = vt[rtidx][2];
	int ctMajor = vt[ctidx][2];
	if (rtMajor == ctMajor) {
	    fprintf(stderr,
    "Warning: pkg=%s version mismatch: compiled-against=%6.3f got=%6.3f\n",
		    modname, ct_ver, rt_ver);
	    return VERCHECK_SEMIMATCH;
	} else {
	    fprintf(stderr,
    "ERROR: %s version mismatch: compiled-against=%6.3f got=%6.3f\n",
		    modname, ct_ver, rt_ver);
	    return VERCHECK_MISMATCH;
	}
    }
} /* ver_check_dbl */

    
