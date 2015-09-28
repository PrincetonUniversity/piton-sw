# ========== Copyright Header Begin ==========================================
# 
# Hypervisor Software File: Makefile
# 
# Copyright (c) 2006 Sun Microsystems, Inc. All Rights Reserved.
# 
#  - Do no alter or remove copyright notices
# 
#  - Redistribution and use of this software in source and binary forms, with 
#    or without modification, are permitted provided that the following 
#    conditions are met: 
# 
#  - Redistribution of source code must retain the above copyright notice, 
#    this list of conditions and the following disclaimer.
# 
#  - Redistribution in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution. 
# 
#    Neither the name of Sun Microsystems, Inc. or the names of contributors 
# may be used to endorse or promote products derived from this software 
# without specific prior written permission. 
# 
#     This software is provided "AS IS," without a warranty of any kind. 
# ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, 
# INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A 
# PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY EXCLUDED. SUN 
# MICROSYSTEMS, INC. ("SUN") AND ITS LICENSORS SHALL NOT BE LIABLE FOR 
# ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR 
# DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES. IN NO EVENT WILL SUN 
# OR ITS LICENSORS BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA, OR 
# FOR DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE 
# DAMAGES, HOWEVER CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, 
# ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF 
# SUN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
# 
# You acknowledge that this software is not designed, licensed or
# intended for use in the design, construction, operation or maintenance of
# any nuclear facility. 
# 
# ========== Copyright Header End ============================================
#
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)Makefile	1.19	07/06/07 SMI"
#

TOP = ..

SUBDIRS = lib

include $(TOP)/Makefile.master

INCFLAGS=-I$(SUN_INC) -I$(COMMON_INC) -I/usr/include/v9 -I/usr/include
CFLAGS=-v -xarch=v9 -xO3 ${INCFLAGS} -D_HV_SAMPLE
ASFLAGS=-xarch=v9d -xregsym=no -P -D_ASM -D_HV_SAMPLE ${INCFLAGS}
LDFLAGS=-dn -M mapfile -e start lib/libsa.a

OBJS  = traptable.o srt0.o main.o hcalls.o traps.o  badtrap.o mmuinit.o mmu.o
OBJS += subr.o  hv.o

all :: sample.bin

install :: $(PROTO_GUEST_BIN)/sample.bin

p: p.o string.o
	$(CC) -xarch=v9 -o p p.o string.o

sample: $(OBJS) mapfile
	$(LD) -o $@ $(OBJS) $(LDFLAGS)

sample.bin: sample
	$(OBJCOPY) -O binary sample sample.bin

clean ::
	$(RM) $(OBJS)

clobber ::
	$(RM) sample sample.bin

lint::
	$(LINT) $(LINT_FLAGS) $(INCFLAGS) *.c

	$(LINT) -Xarch=v9 -Xc99 -I/usr/include/v9 -I/usr/include -I. $(LINTERRS) *.s
