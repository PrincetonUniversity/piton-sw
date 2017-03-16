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

ASFLAGS += -xregsym=no -I$(XILINX_TOP)/include

CONFIGS = 1c1t 1c2t 1c4t 2c1t 2c4t 4c1t

RESET_BINS = $(CONFIGS:%=%_reset.bin)
RESET_OBJS = $(CONFIGS:%=%_reset.o)
RESET_EXES = $(CONFIGS:%=%_reset)


all install :: $(RESET_BINS)


1c2t_reset.o := MP_CFLAGS=-DT1_FPGA_1C2T

1c4t_reset.o := MP_CFLAGS=-DT1_FPGA_1C4T

2c1t_reset.o := MP_CFLAGS=-DT1_FPGA_2C1T

2c4t_reset.o := MP_CFLAGS=-DT1_FPGA_2C4T

4c1t_reset.o := MP_CFLAGS=-DT1_FPGA_4C1T

%_reset.o:    reset.s
	$(COMPILE.s) $(MP_CFLAGS) -o $@ $<

%_reset.bin: %_reset
	$(OBJCOPY) -O binary $< $@

%_reset: %_reset.o mapfile
	$(LD) -o $@ -e start_reset -dn -z defs -M mapfile $<


clean::
	$(RM) $(RESET_OBJS)

clobber:: clean
	$(RM) $(RESET_BINS) $(RESET_EXES)



.KEEP_STATE:
