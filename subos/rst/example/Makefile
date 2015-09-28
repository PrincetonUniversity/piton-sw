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
# Makefile for rst/example

# CCC = /import/datools/vendor/forte/s1s8/SUNWspro/bin/CC

# point this next variable to the location of the rst package
RSTDIR=../pkg

INCLUDES = -I$(RSTDIR)/include

LFSFLAGS:sh = getconf LFS_CFLAGS

CFLAGS = $(INCLUDES) $(LFSFLAGS)
CCFLAGS = $(CFLAGS)

# When building a 32-bit version, make sure to use a libz that supports large files
# this is not an issue for 64-bit files, or for reading/writing files < 4GB in size
LIBS = -R$(RSTDIR)/lib/32 -L $(RSTDIR)/lib/32 -lrstzip

rstexample: rstexample.o
	$(CCC) $(CFLAGS) -o rstexample rstexample.o $(LIBS)

clean::
	-rm -rf rstexample rstexample.o

