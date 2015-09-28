/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: rz3_perf_stats.h
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
/* rz3_perf_stats.h
 * performance statistics gathering and reporting
 */


enum rz3_perf_stats_e {
  rz3_perf_stat_NIL=0,

  rz3_perf_stat_nrecords,
  rz3_perf_stat_instr_count,

  rz3_perf_stat_bt_refs, // instr bt field
  rz3_perf_stat_bt_misses,

  rz3_perf_stat_an_misses,

  rz3_perf_stat_ras_refs,
  rz3_perf_stat_ras_misses,

  rz3_perf_stat_ea_valid_misses,

  rz3_perf_stat_ea_prox_list_refs,
  rz3_perf_stat_ea_prox_list_misses,
  rz3_perf_stat_ea_lookup_table_misses,

  rz3_perf_stat_regval_count,
  rz3_perf_stat_raw_regid_count,
  rz3_perf_stat_raw_
}; // enum rz3_perf_stats_e

struct rz3_perf_stats {

}; // struct rz3_perf_stats
