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
# top-level makefile for rst tools

include Makefile.master

TOP_DIR = $(PWD)

COMPONENTS = rstf trconv rstzip3

32g 32opt 64g 64opt: setup
	for a in $(COMPONENTS); do cd $$a ; CUR_DIR=$(PWD)/$$a ; export CUR_DIR; $(MAKE) $@ ; cd .. ; done
	cd rst-tools ; PWD=$(PWD)/rst-tools ; export PWD; $(MAKE) $@ ; cd ..

amd64: setup
	for a in $(COMPONENTS); do echo "make amd64 in $$a"; cd $$a ; CUR_DIR=$(PWD)/$$a ; export CUR_DIR; $(MAKE) $@ ; cd .. ; done

example: FRC
	cd example ; $(MAKE) RSTDIR=$(INSTALL_DIR)/ ; cd ..

clean: FRC
	for a in $(COMPONENTS); do cd $$a ; CUR_DIR=$(PWD)/$$a ; export CUR_DIR; $(MAKE) $@ ; cd .. ; done
	cd rst-tools ; PWD=$(PWD)/rst-tools ; export PWD; $(MAKE) $@ ; cd ..

test: FRC
	cd tests ; $(MAKE) ; cd ..

# in this version, rstzip2 is the standard rstzip
install: setup component_install rzsetup example
	install -m 0664 -f $(INSTALL_DIR) HISTORY
#	chmod -R g+w $(INSTALL_DIR)
	$(MAKE) test
	for f in Makefile README rstexample.C; do install -m 0664 -f $(INSTALL_DIR)/example example/$$f; done
	install -m 0775 -f $(INSTALL_DIR)/example example/rstexample

component_install:
	for a in $(COMPONENTS); do cd $$a ; CUR_DIR=$(PWD)/$$a ; export CUR_DIR; $(MAKE) install ; cd .. ; done
	cd rst-tools ; PWD=$(PWD)/rst-tools ; export PWD; $(MAKE) install ; cd ..

rzsetup:
	if test -L $(INSTALL_DIR)/bin/rstzip ; then unlink $(INSTALL_DIR)/bin/rstzip; fi; ln -s rstzip3 $(INSTALL_DIR)/bin/rstzip
	if test -L $(INSTALL_DIR)/bin/rstzip-64 ; then unlink $(INSTALL_DIR)/bin/rstzip-64; fi; ln -s rstzip3-64 $(INSTALL_DIR)/bin/rstzip-64
	if test -L $(INSTALL_DIR)/bin/rstunzip ; then unlink $(INSTALL_DIR)/bin/rstunzip; fi; ln -s rstzip $(INSTALL_DIR)/bin/rstunzip
	if test -L $(INSTALL_DIR)/include/rstzip ; then unlink $(INSTALL_DIR)/include/rstzip ; fi; ln -s . $(INSTALL_DIR)/include/rstzip
	if test -L $(INSTALL_DIR)/lib/32/librstzip.o ; then unlink $(INSTALL_DIR)/lib/32/librstzip.o ; fi; ln -s librstzip3.o $(INSTALL_DIR)/lib/32/librstzip.o
	if test -L $(INSTALL_DIR)/lib/64/librstzip.o ; then unlink $(INSTALL_DIR)/lib/64/librstzip.o ; fi; ln -s librstzip3.o $(INSTALL_DIR)/lib/64/librstzip.o
	if test -L $(INSTALL_DIR)/lib/32/librstzip.so ; then unlink $(INSTALL_DIR)/lib/32/librstzip.so ; fi; ln -s librstzip3.so $(INSTALL_DIR)/lib/32/librstzip.so
	if test -L $(INSTALL_DIR)/lib/64/librstzip.so ; then unlink $(INSTALL_DIR)/lib/64/librstzip.so ; fi; ln -s librstzip3.so $(INSTALL_DIR)/lib/64/librstzip.so

setup: FRC
	if test ! -L rstzip; then ln -s rstzip3 rstzip; fi;
	if test ! -d $(BUILD_DIR); then mkdir -m 0755 -p $(BUILD_DIR); fi;
	if test -d $(INSTALL_DIR)/bin ; then true; else mkdir -m 0775 -p $(INSTALL_DIR)/bin; fi;
	if test -d $(INSTALL_DIR)/include ; then true; else mkdir -m 0775 -p $(INSTALL_DIR)/include; fi;
	if test -d $(INSTALL_DIR)/lib/32 ; then true; else mkdir -m 0775 -p $(INSTALL_DIR)/lib/32; fi;
	if test -d $(INSTALL_DIR)/lib/64 ; then true; else mkdir -m 0775 -p $(INSTALL_DIR)/lib/64; fi;
	if test -d $(INSTALL_DIR)/example ; then true; else mkdir -m 0775 -p $(INSTALL_DIR)/example ; fi;

# dummy "force make" target
FRC:
