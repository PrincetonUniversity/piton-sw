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
# Makefile for rst/trconv
include ../Makefile.master

TOP_DIR = ..
TARG = trconv

$(TARG)-32g: $(TARG)
$(TARG)-64g: $(TARG)
$(TARG)-32opt: $(TARG)
$(TARG)-64opt: $(TARG)

CFILES = main.C trconv.C
HFILES = trconv.H
ALLSRCS = $(CFILES) $(HFILES)
OBJS = $(CFILES:%.C=%.o)

SPIX_DIR = /import/archperf/pkgs/spix/1.1
READSYMBOLS_DIR = /import/archperf/pkgs/readsymbols/1.0
INCLUDES += -I$(READSYMBOLS_DIR)/inc -I$(SPIX_DIR)/inc

LIBS = $(SPIX_DIR)/$(HOST3264)/lib/libspix_sparc.a $(READSYMBOLS_DIR)/$(HOST3264)/lib/read_symbols.a

%amd64 := LIBS=$(SPIX_DIR)/x64/lib/libspix_sparc.a $(READSYMBOLS_DIR)/amd64/lib/read_symbols.a

EXTRAFLAGS += -D_PRINT_PA -D_VALUE_TRACE
CFLAGS += $(EXTRAFLAGS)
CCFLAGS += $(EXTRAFLAGS)
CXXFLAGS += $(EXTRAFLAGS)

$(TARG)-amd64: byteswap.o $(OBJS) 
	$(CCC) $(CFLAGS) -o $(TARG) byteswap.o $(OBJS) $(LIBS)

trconv: $(OBJS)
	$(CCC) $(CFLAGS) -o $@ $^ $(LIBS)

byteswap.o: byteswap.s
	$(AS) -P -xarch=amd64 -DARCH_AMD64 byteswap.s

32g 32opt 64g 64opt amd64: setup
	cd $(OBJ_DIR)/$(BUILDTAG); $(MAKE) -f ../Makefile $(TARG)-$(BUILDTAG); cd $(CUR_DIR)


clean:
	-rm -rf $(OBJ_DIR)
	-rm -f $(INSTALL_DIR)/bin/$(TARG)

clean-obj::
	-rm -rf $(OBJ_DIR)

install: $(INSTALL_TARG)
	install -m 0775 -f $(INSTALL_DIR)/bin $(OBJ_DIR)/$(INSTALL_TARG)/$(TARG)

setup: FRC
	@echo making setup...
	if test ! -d $(OBJ_DIR); then mkdir -m 0775 -p $(OBJ_DIR); cp $(TOP_DIR)/Makefile.master $(OBJ_DIR); ln -s $(CUR_DIR)/Makefile $(OBJ_DIR); fi;
	if test ! -d $(INSTALL_DIR)/bin; then mkdir -m 0775 -p $(INSTALL_DIR)/bin; fi;
	@for a in 32g 32opt 64g 64opt amd64; do \
	  if test ! -d $(OBJ_DIR)/$$a; then mkdir -m 0775 -p $(OBJ_DIR)/$$a; fi; \
	  for f in $(ALLSRCS); do if test -L $(OBJ_DIR)/$$a/$$f; then unlink $(OBJ_DIR)/$$a/$$f; fi; ln -s $(CUR_DIR)/$$f $(OBJ_DIR)/$$a; done; \
	  if [ "amd64" -eq "$$a" ]; then if test -L $(OBJ_DIR)/$$a/byteswap.s; then unlink $(OBJ_DIR)/$$a/byteswap.s; fi; ln -s $(CUR_DIR)/../rstf/byteswap.s $(OBJ_DIR)/$$a; fi; \
	done
FRC:

.KEEP_STATE:

