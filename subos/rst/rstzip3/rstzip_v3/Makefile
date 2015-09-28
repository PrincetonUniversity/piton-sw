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
# Makefile for rst/rstzip/rstzip_v2

include ../../Makefile.master

TOP_DIR = ../..

INCLUDES += -I../../..

TARG = librz3.o

$(TARG)-32g: $(TARG)
$(TARG)-32opt: $(TARG)
$(TARG)-64g: $(TARG)
$(TARG)-64opt: $(TARG)

# CFILES = cpuid.c printhex.c rstzip2c.c
# CCFILES = diffrst.C mpsort.C rstzip2.C rstzip2if.C
# OBJS = $(CCFILES:%.C=%.o) $(CFILES:%.c=%.o)
CFILES = rstzip3.C rz3_section.C rz3iu.C compress_engine.C decompress_engine.C
HFILES = rstzip3.h rz3_bitarray.h rz3_bitarray.v3.14b.h rz3iu.h rz3_lruhash.h rz3_perf_stats.h rz3_rst_array.h rz3_section.h rz3utils.h rz3_valuecache.h
# ILFILES = regen.il

ALLSRCS = $(CFILES) $(HFILES) $(ILFILES)

OBJS = $(CFILES:%.C=%.o)

$(TARG): $(OBJS)
	$(LD) -r -o $@ $(OBJS)

$(TARG)-amd64: $(OBJS) byteswap.o
	$(LD) -r -o $(TARG) $(OBJS) byteswap.o 

byteswap.o: byteswap.s
	$(AS) -P -xarch=amd64 -DARCH_AMD64 byteswap.s

#compress_engine.o: compress_engine.C regen.il
#	$(CCC) $(CFLAGS) -c -o $@ regen.il compress_engine.C

32g 32opt 64g 64opt amd64: setup
	cd $(BUILDTAG); $(MAKE) -f ../Makefile $(TARG)-$(BUILDTAG) ; cd ..

clean:
	-rm -rf $(OBJS) $(TARG) 32g 32opt 64g 64opt amd64

setup: FRC
	@echo rstzip3: making setup...
	@for a in 32g 32opt 64g 64opt amd64; do \
	  if test -d $$a; then true; else mkdir $$a; fi; \
	  for f in $(ALLSRCS); do  if test -L $$a/$$f; then unlink $$a/$$f; fi; ln -s ../$$f $$a/$$f; done; \
	  if [ "amd64" -eq "$$a" ]; then if test -L $$a/byteswap.s; then unlink $$a/byteswap.s; fi; ln -s ../../../rstf/byteswap.s $$a/byteswap.s; fi; \
	done
FRC:

.KEEP_STATE:
