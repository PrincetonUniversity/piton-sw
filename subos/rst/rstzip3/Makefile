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
# Makefile for rst/rstzip
include ../Makefile.master

TOP_DIR = ..

TARG=rstzip

TARGETS = rstzip3 librstzip3.o librstzip3.so
$(TARG)-32g: $(TARGETS)
$(TARG)-32opt: $(TARGETS)
$(TARG)-64g: $(TARGETS)
$(TARG)-64opt: $(TARGETS)
$(TARG)-amd64: $(TARGETS)

32g 32opt 64g 64opt amd64: setup
	cd rstzip_v3 ; $(MAKE) $(BUILDTAG); cd ..
	cd rstzip_v2 ; $(MAKE) $(BUILDTAG); cd ..
	cd $(BUILDTAG); $(MAKE) -f ../Makefile $(TARG)-$(BUILDTAG); cd ..
	install -m 0664 -f $(INSTALL_DIR)/lib/$(HOST3264) $@/librstzip3.o
	install -m 0664 -f $(INSTALL_DIR)/lib/$(HOST3264) $@/librstzip3.so

clean: setup
	cd rstzip_v3 ; $(MAKE) clean ; cd ..
	cd rstzip_v2 ; $(MAKE) clean ; cd ..
	-rm -rf 32g 32opt 64g 64opt amd64
	-rm -f $(INSTALL_DIR)/bin/rstzip3 $(INSTALL_DIR)/bin/rstzip3-64 $(INSTALL_DIR)/bin/rstunzip3 $(INSTALL_DIR)/include/Rstzip.H
	for a in 32 64; do for b in o so; do rm -f $(INSTALL_DIR)/lib/$$a/librstzip3.$$b ; done; done


CCFILES = Rstzip.C rstzip.C
HFILES = Rstzip.H rz_insttypes.h
ALLSRCS = $(CCFILES) $(HFILES)

install: 32opt 64opt
	if test -d $(INSTALL_DIR)/include ; then true; else mkdir -m 0775 -p $(INSTALL_DIR)/include ; fi
	install -m 0664 -f $(INSTALL_DIR)/include Rstzip.H
	for a in 32 64; do for b in o so; do install -m 0664 -f $(INSTALL_DIR)/lib/$$a $${a}opt/librstzip3.$$b ; done; done
	install -m 0775 -f $(INSTALL_DIR)/bin 32opt/rstzip3
	cp -f 64opt/rstzip3 $(INSTALL_DIR)/bin/rstzip3-64 ; chmod 0775 $(INSTALL_DIR)/bin/rstzip3-64
	if test -L $(INSTALL_DIR)/bin/rstunzip3 ; then unlink $(INSTALL_DIR)/bin/rstunzip3; fi; ln -s rstzip3 $(INSTALL_DIR)/bin/rstunzip3


setup: FRC
	@echo make setup in rstzip3
	@if test -L Makefile.master ; then unlink Makefile.master ; fi
	@ln -s ../Makefile.master
	@for a in 32g 32opt 64g 64opt amd64; do \
	  if test -d $$a; then true; else mkdir $$a; fi; \
	  for f in $(ALLSRCS); do  if test -L $$a/$$f; then unlink $$a/$$f; fi; ln -s ../$$f $$a/$$f; done \
	done
#	@for a in rstzip_v3 rstzip_v2; do cd $$a; $(MAKE) setup; cd ..; done


INCLUDES += -I../rstzip_v3 -I../rstzip_v2

# use this version of ZLIB because it is built for large-file support in the 32-bit version
ZLIB = -L/import/archperf/local/lib/$(HOST3264) -lz
SPIXLIB = -L/import/archperf/lib/$(HOST3264) -lspix6plus -L$(SHADE_DIR)/lib -lspix_sparc
RSTZIP3_LIBS = $(SPIXLIB)

rstzip3: rstzip.o librstzip3.o
	$(CCC) $(CCFLAGS) -o rstzip3 rstzip.o librstzip3.o $(RSTZIP3_LIBS)

librstzip3.o: Rstzip.o FRC
	$(LD) -r -o $@ Rstzip.o ../rstzip_v3/$(BUILDTAG)/librz3.o ../rstzip_v2/$(BUILDTAG)/librstzip_v2.o $(ZLIB)

librstzip3.so: Rstzip.o FRC
	$(CCC) $(CCFLAGS) -G -o $@ Rstzip.o ../rstzip_v3/$(BUILDTAG)/librz3.o ../rstzip_v2/$(BUILDTAG)/librstzip_v2.o $(ZLIB)

FRC:

.KEEP_STATE:

