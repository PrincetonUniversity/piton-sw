# ========== Copyright Header Begin ==========================================
# 
# OpenSPARC T2 Processor File: Makefile
# Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
# 
# The above named program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public
# License version 2 as published by the Free Software Foundation.
# 
# The above named program is distributed in the hope that it will be 
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public
# License along with this work; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
# 
# ========== Copyright Header End ============================================
#
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
  
TOP = ../..

include  $(TOP)/Makefile.common


CPPFLAGS += -I$(XILINX_TOP)/include
STAND_ALONE_CPPFLAGS = -DT1_FPGA_STAND_ALONE


CONFIGS = 1c1t 1c4t 2c1t 2c4t

DBIN_CFGS  = $(CONFIGS:%=%-guest.md)
DTXT_CFGS  = $(CONFIGS:%=%-guest.txt)
HBIN_CFGS  = $(CONFIGS:%=%-hv.md)
HTXT_CFGS  = $(CONFIGS:%=%-hv.txt)
HV_PP_CFGS = $(CONFIGS:%=%-hv.pp)


OBP_HBIN_CFGS = $(CONFIGS:%=%-obp-hv.md)


all install :: $(DBIN_CFGS) $(DTXT_CFGS) $(HBIN_CFGS) $(OBP_HBIN_CFGS) $(HTXT_CFGS)

%-guest.pp: %_guest.desc
	$(CPP) $(CPPFLAGS) $< $@

%-hv.pp: %_hv.desc
	$(CPP) $(CPPFLAGS) $(STAND_ALONE_CPPFLAGS) $< $@

%-obp-hv.pp: %_hv.desc
	$(CPP) $(CPPFLAGS) $< $@

%-guest.md: %-guest.pp
	$(MDGEN) --binary $(VERBOSE) --outfile $@ $<

%-guest.txt: %-guest.pp
	$(MDGEN) --text --outfile $@ $<

%-hv.md: %-hv.pp
	$(MDGEN) --binary $(VERBOSE) --outfile $@ $<

%-obp-hv.md: %-obp-hv.pp
	$(MDGEN) --binary $(VERBOSE) --outfile $@ $<

%-hv.txt: %-hv.pp
	$(MDGEN) --text --outfile $@ $<

clean ::
	$(RM) *.pp $(HTXT_CFGS) $(DTXT_CFGS)

clobber :: clean
	$(RM) $(HBIN_CFGS) $(OBP_HBIN_CFGS) $(DBIN_CFGS)

.KEEP_STATE:
