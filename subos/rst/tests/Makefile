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
# Makefile for rst/tests
include ../Makefile.master

# make tests should be run only after install (or installdbg)


CFLAGS = $(CFLAGS_BASE) $(CFLAGS32) $(CFLAGSOPT)

# The first group of tests generates a simple rst file and runs it through trconv and rstzip
test1: test1.rst
	../pkg/bin/trconv test1.rst | tail +2 > test1.out
	@echo +++ test1.rst created
	cmp test1.out test1.ref.out
	@echo +++ test1.rst file matches reference
	@-rm -rf test1.out
	../pkg/bin/rstzip -o test1.rz3.gz test1.rst
	@echo +++ rstzip compressed test1.rst to test1.rz3.gz
	../pkg/bin/rstunzip test1.rz3.gz | ../pkg/bin/trconv | tail +2 > test1_a.out
	@echo +++ rstunzip decompressed test1.rz3.gz
	cmp test1_a.out test1.ref.out
	@echo +++ decompressed file matches reference
	@-rm -rf test1_a.out test1.rz3.gz
	@echo +++ test1 complete

gen_test1: gen_test1.o
	$(CCC) $(CFLAGS) -o gen_test1 gen_test1.o

test1.rst: gen_test1
	./gen_test1 > test1.rst

.KEEP_STATE:
