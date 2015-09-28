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

INCLUDES += -I../../.. -I/import/archperf/include -I/import/shade/v6/latest-$(HOST3264)/inc

TARG = librstzip_v2.o

$(TARG)-32g: $(TARG)
$(TARG)-32opt: $(TARG)
$(TARG)-64g: $(TARG)
$(TARG)-64opt: $(TARG)
$(TARG)-amd64: $(TARG)

# CFILES = cpuid.c printhex.c rstzip2c.c
# CCFILES = diffrst.C mpsort.C rstzip2.C rstzip2if.C
# OBJS = $(CCFILES:%.C=%.o) $(CFILES:%.c=%.o)

CFILES = rstzip2if.C cpuid.c
HFILES = buffer.H cpuid.h footer.H hash.H header.H mpsort.H pstate.H rstzip2if.H rstzip.H rstzipif.H VCache.h
ALLSRCS = $(CFILES) $(HFILES)
OBJS = rstzip2if.o cpuid.o
$(TARG): $(OBJS)
	$(LD) -r -o $@ $(OBJS)


32g 32opt 64g 64opt amd64: setup
	cd $(BUILDTAG); $(MAKE) -f ../Makefile $(TARG)-$(BUILDTAG) ; cd ..

clean:
	-rm -rf $(OBJS) $(TARG) 32g 32opt 64g 64opt amd64

setup: FRC
	@echo rstzip_v2: making setup...
	@for a in 32g 32opt 64g 64opt amd64; do \
	  if test -d $$a; then true; else mkdir $$a; fi; \
	  for f in $(ALLSRCS); do  if test -L $$a/$$f; then unlink $$a/$$f; fi; ln -s ../$$f $$a/$$f; done \
	done
FRC:


.KEEP_STATE:
