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


CONFIGS = 1c1t 1c4t 2c1t 2c4t

XILINX_CONFIGS = $(XILINX_TOP)/configs
XILINX_RESET   = $(XILINX_TOP)/reset


PROM_BINS      = $(CONFIGS:%=%_prom.bin)
OBP_PROM_BINS  = $(CONFIGS:%=%_obp_prom.bin)
RESET_BINS     = $(CONFIGS:%=../%_reset.bin)
HV_BINS        = $(CONFIGS:%=../configs/%-hv.md)
OBP_HV_BINS    = $(CONFIGS:%=../configs/%-obp-hv.md)
GUEST_BINS     = $(CONFIGS:%=../configs/%-guest.md)


MAKE_PROM = $(XILINX_TOOLS)/make_prom/make_prom


all install :: $(PROM_BINS) $(OBP_PROM_BINS)


$(PROM_BINS) $(OBP_PROM_BINS) : q.bin openboot.bin $(MAKE_PROM) nvram.bin $(RESET_BINS) $(HV_BINS) $(OBP_HV_BINS) $(GUEST_BINS)


$(MAKE_PROM):
	@cd $(XILINX_TOOLS)/make_prom ; make $(TARGET)

$(RESET_BINS):
	@cd $(XILINX_TOP)/reset ; make $(TARGET)

$(HV_BINS) $(OBP_HV_BINS) $(GUEST_BINS):
	@cd $(XILINX_TOP)/configs ; make $(TARGET)


q.bin:
	ln -fs $(SIM_ROOT)/hypervisor/src/greatlakes/ontario/t1_fpga/q.bin

openboot.bin:
	ln -fs $(SIM_ROOT)/obp/obp/arch/sun4v/niagara/t1_fpga/openboot.bin



1c1t_prom.bin: $(XILINX_RESET)/1c1t_reset.bin $(XILINX_CONFIGS)/1c1t-guest.md $(XILINX_CONFIGS)/1c1t-hv.md
	$(MAKE_PROM) -g $(XILINX_CONFIGS)/1c1t-guest.md \
		    -H $(XILINX_CONFIGS)/1c1t-hv.md    \
		    -r $(XILINX_RESET)/1c1t_reset.bin    \
		    -p $@

1c4t_prom.bin: $(XILINX_RESET)/1c4t_reset.bin $(XILINX_CONFIGS)/1c4t-guest.md $(XILINX_CONFIGS)/1c4t-hv.md
	$(MAKE_PROM) -g $(XILINX_CONFIGS)/1c4t-guest.md \
		    -H $(XILINX_CONFIGS)/1c4t-hv.md    \
		    -r $(XILINX_RESET)/1c4t_reset.bin    \
		    -p $@

2c1t_prom.bin: $(XILINX_RESET)/2c1t_reset.bin $(XILINX_CONFIGS)/2c1t-guest.md $(XILINX_CONFIGS)/2c1t-hv.md
	$(MAKE_PROM) -g $(XILINX_CONFIGS)/2c1t-guest.md \
		    -H $(XILINX_CONFIGS)/2c1t-hv.md    \
		    -r $(XILINX_RESET)/2c1t_reset.bin    \
		    -p $@

2c4t_prom.bin: $(XILINX_RESET)/2c4t_reset.bin $(XILINX_CONFIGS)/2c4t-guest.md $(XILINX_CONFIGS)/2c4t-hv.md
	$(MAKE_PROM) -g $(XILINX_CONFIGS)/2c4t-guest.md \
		    -H $(XILINX_CONFIGS)/2c4t-hv.md    \
		    -r $(XILINX_RESET)/2c4t_reset.bin    \
		    -p $@

1c1t_obp_prom.bin: $(XILINX_RESET)/1c1t_reset.bin $(XILINX_CONFIGS)/1c1t-guest.md $(XILINX_CONFIGS)/1c1t-obp-hv.md
	$(MAKE_PROM) -g $(XILINX_CONFIGS)/1c1t-guest.md \
		    -H $(XILINX_CONFIGS)/1c1t-obp-hv.md    \
		    -r $(XILINX_RESET)/1c1t_reset.bin    \
		    -p $@

1c4t_obp_prom.bin: $(XILINX_RESET)/1c4t_reset.bin $(XILINX_CONFIGS)/1c4t-guest.md $(XILINX_CONFIGS)/1c4t-obp-hv.md
	$(MAKE_PROM) -g $(XILINX_CONFIGS)/1c4t-guest.md \
		    -H $(XILINX_CONFIGS)/1c4t-obp-hv.md    \
		    -r $(XILINX_RESET)/1c4t_reset.bin    \
		    -p $@

2c1t_obp_prom.bin: $(XILINX_RESET)/2c1t_reset.bin $(XILINX_CONFIGS)/2c1t-guest.md $(XILINX_CONFIGS)/2c1t-obp-hv.md
	$(MAKE_PROM) -g $(XILINX_CONFIGS)/2c1t-guest.md \
		    -H $(XILINX_CONFIGS)/2c1t-obp-hv.md    \
		    -r $(XILINX_RESET)/2c1t_reset.bin    \
		    -p $@

2c4t_obp_prom.bin: $(XILINX_RESET)/2c4t_reset.bin $(XILINX_CONFIGS)/2c4t-guest.md $(XILINX_CONFIGS)/2c4t-obp-hv.md
	$(MAKE_PROM) -g $(XILINX_CONFIGS)/2c4t-guest.md \
		    -H $(XILINX_CONFIGS)/2c4t-obp-hv.md    \
		    -r $(XILINX_RESET)/2c4t_reset.bin    \
		    -p $@


clobber:: clean
	$(RM) $(PROM_BINS) $(OBP_PROM_BINS)

clean::
	$(RM) openboot.bin q.bin 1c1t_reset.bin 1c4t_reset.bin 2c1t_reset.bin


.KEEP_STATE:
