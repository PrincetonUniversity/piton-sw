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
# Makefile for rst/rstf
include ../Makefile.master

TOP_DIR = ..
TARG = rstf_objs

$(TARG)-32g: $(TARG)
$(TARG)-64g: $(TARG)
$(TARG)-32opt: $(TARG)
$(TARG)-64opt: $(TARG)
$(TARG)-amd64: $(TARG)

CFILES = rstf.c vercheck.c
HFILES = rstf.h rstf_deprecated.h vercheck.h
ALLSRCS = $(CFILES) $(HFILES)
OBJS = $(CFILES:%.c=%.o)

$(TARG): $(OBJS)

32g 32opt 64g 64opt amd64: setup
	cd $(OBJ_DIR)/$(BUILDTAG); $(MAKE) -f ../Makefile $(TARG)-$(BUILDTAG); cd $(CUR_DIR)

clean:
	-rm -rf $(OBJ_DIR)
	for a in 32 64; do for b in $(OBJS); do  \
	  rm -f $(INSTALL_DIR)/lib/$$a/$$b; \
	done; done

clean-obj::
	-rm -rf $(OBJ_DIR)

install: 32opt 64opt
	if test ! -d $(INSTALL_DIR)/include/rstf ; then mkdir -m 0775 -p $(INSTALL_DIR)/include/rstf ; fi
	install -m 0664 -f $(INSTALL_DIR)/include/rstf rstf.h
	for a in 32 64; do for b in $(OBJS); do  \
	  if test ! -d $(INSTALL_DIR)/lib/$$a ; then mkdir -m 0775 -p $(INSTALL_DIR)/lib/$$a ; fi; \
	  install -m 0664 -f $(INSTALL_DIR)/lib/$$a $(OBJ_DIR)/$${a}opt/$$b; \
	done; done

setup: FRC
	@echo making setup...
	if test ! -d $(OBJ_DIR); then mkdir -m 0775 -p $(OBJ_DIR); cp $(TOP_DIR)/Makefile.master $(OBJ_DIR); ln -s $(CUR_DIR)/Makefile $(OBJ_DIR); fi;
	if test ! -d $(INSTALL_DIR)/bin; then mkdir -m 0775 -p $(INSTALL_DIR)/bin; fi;
	@for a in 32g 32opt 64g 64opt amd64; do \
	  if test ! -d $(OBJ_DIR)/$$a; then mkdir -m 0775 -p $(OBJ_DIR)/$$a; fi; \
	  for f in $(ALLSRCS); do if test -L $(OBJ_DIR)/$$a/$$f; then unlink $(OBJ_DIR)/$$a/$$f; fi; ln -s $(CUR_DIR)/$$f $(OBJ_DIR)/$$a; done \
	done
FRC:

.KEEP_STATE:
