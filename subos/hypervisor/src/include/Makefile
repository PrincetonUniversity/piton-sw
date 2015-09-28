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
# ident	"@(#)Makefile	1.5	07/07/17 SMI"
#

TOP = ../

PLATFORM = sun4v

include $(TOP)/Makefile.master

# Headers we install into the proto area
HDRS =	hypervisor.h ncs_api.h \
	sun4v/asi.h sun4v/instr.h sun4v/mmu.h sun4v/queue.h sun4v/traps.h \
	sun4v/vpci.h sys/asm_linkage.h sys/htypes.h \
	sample/sample.h \
	md/md_impl.h

$(PROTO_INC)/sun4v $(PROTO_INC)/md $(PROTO_INC)/sys $(PROTO_INC)/sample:
	$(INS.dir)

$(PROTO_INC)/sun4v/%: % $(PROTO_INC)/sun4v
	$(INS.file)

$(PROTO_INC)/md/%: % $(PROTO_INC)/md
	$(INS.file)

$(PROTO_INC)/sys/%: % $(PROTO_INC)/sys
	$(INS.file)

$(PROTO_INC)/sample/%: % $(PROTO_INC)/sample
	$(INS.file)

install :: $(PROTO_INC)/sun4v $(PROTO_INC)/md $(PROTO_INC)/sys $(PROTO_INC)/sample $(HDRS:%=$(PROTO_INC)/%)
