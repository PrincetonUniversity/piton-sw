/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: vercheck.h
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
#ifndef _vercheck_h
#define _vercheck_h

//
// At the end of this file I provide copy-and-paste code.
//
// General code for doing vs compiletime vs runtime version checking.
// To use this code:
// 
// 1) In your module.c file
//   #include "vercheck.c"   // Yes, include the .c not the .h (!)
//                           // I know this is ugly, but its very convenient
// 
// Since many modules will have this code
// the following functions are all defined static.

// 2) Define an array of triple doubles, like the example shown below.
// You might call it   xyz_vequivtab
// 
//   // Set of triples (AA,BB,CC), where
//   //  Versions in the range [AA,BB) are compatiable.
//   //  Versions with the same CC value are considered semi-compatible.
//   //  Versions with different CC values are incompatible
//   //  The last entry MUST have AA = BB = CC = -1 .
//   // Thus for this table:
//   //   1.00 vs. 1.03 => compatible.
//   //   1.00 vs. 1.04 => not compatible.
//   //   1.04 vs. 1.06 => semi-compatible.
//   //   1.07 vs. 1.09 => semi-compatible.
//   //   1.10 vs. 2.02 => compatible.
// double rst_vequivtab [][3] = {
//     { 0.00,   1.00,  0 },
//     { 1.00,   1.04,  1 },
//     { 1.04,   1.06,  2 },
//     { 1.06,   1.08,  2 },
//     { 1.08,   1.10,  2 },
//     { 1.10,   2.09,  3 },
//     {  -1,    -1.0, -1 },
// };
// 
// 2) In your module.c code for XYZ, define 
//         XYZ_version_check_fn (const char* ct_version);
// I suggest trying:
//
// int xyz_version_check_fn (const char* ct_version) {
//    const char* rt_str = XYZ_VERSION_STR;	// run time version
//    return generic_verCheck(ct_version, rt_str, xyz_vequivtab, "XYZ");
// }
//

enum {
    VERCHECK_MATCH = 0,
    VERCHECK_ERROR = 1,		// unknown error comparing versions
    VERCHECK_SEMIMATCH = 2,
    VERCHECK_MISMATCH = 4
};    

  // get the index in equivTab
static int verIndex (double ver, double equivTab [][3] );

  // compare version strings, by converting them to doubles via atof()
  // Note that via atof():  "1.2" => 1.2 and "1.10" => 1.1
  // compare compile version CT_STR with runtime version RT_STR using 
  // version comparison table VT.
  // If problems, use modname XYZ in the error/warning messages.
static int generic_verCheck (
  const char* ct_str, const char* rt_str, double vt[][3], const char* modname
);

  // compare version CT_VER with runtime version RT_VER using 
  // version comparison table VT.
  // If problems, use modname XYZ in the error/warning messages.
static int ver_check_dbl (
    double ct_ver, double rt_ver, double vt[][3], const char* modname
);

/* ================================================================
 * ================================================================
 * Copy-and-paste code.  Replace XYZ with your module name.
 *
 * Put the following in one of your .c files
 * ----------------

#include "vercheck.c"       // Yes, include the .c not the .h (!)

double xyz_vequivtab [][3] = {
    { 0.00,   1.00,  0 },
    { 1.00,   1.04,  1 },
    { 1.04,   1.06,  2 },
    { 1.06,   1.08,  2 },
    { 1.08,   1.10,  2 },
    { 1.10,   2.09,  3 },
    {  -1,    -1.0, -1 },
};

int xyz_version_check_fn (const char* ct_version) {
    const char* rt_str = XYZ_VERSION_STR;	// run time version
    return generic_verCheck(ct_version, rt_str, xyz_vequivtab, "XYZ");
}

 * ================================================================
 * Put the following in your .h file
 * ================================================================

#define XYZ_VERSION_STR    "2.04"
int xyz_version_check_fn (const char* compile_time_version);

  // Convenience macro for version checking
#define XYZ_CHECK_VERSION()   xyz_version_check_fn(XYZ_VERSION_STR)

 * End cut-and-paste
 * ================================================================ */      

#endif  /* _vercheck_h */
