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
# ident	"@(#)Makefile	1.5	07/06/27 SMI"
#

VARIANT = release
include ../Makefile.platform

########################################

OPTIONS = $(PLAT_OPTIONS)
OPTIONS += -UDEBUG
OPTIONS += -DSTRICT_API
OPTIONS += -UCONFIG_DISK	# Simulated disk support
OPTIONS += -DCONFIG_PCIE
OPTIONS += -DCONFIG_PIU
OPTIONS += -UCONFIG_IOBYPASS
OPTIONS += -UCONFIG_STATICTOD	# Time does not move - pending FPGA support
OPTIONS += -UDEBUG_LEGION	# Legion-specific debugging aids
OPTIONS += -UCONFIG_LEGIONBCOPY	# Legion has physical bcopy magic trap
OPTIONS += -DCONFIG_HVUART
OPTIONS += -DCONFIG_CLEANSER	# L2$ cache cleanser cyclic
OPTIONS += -UCONFIG_VERSION_TEST
OPTIONS += -DCONFIG_FPGA
OPTIONS += -DCONFIG_FPGA_UART
OPTIONS += -DFALLS_FPGA
OPTIONS += -DCONFIG_SVC
OPTIONS += -DCONFIG_VBSC_SVC
OPTIONS += -DRESETCONFIG_ENABLEHWSCRUBBERS
OPTIONS += -DCONFIG_CRYPTO
OPTIONS += -DCONFIG_CN_UART    # UART console capability for a guest
OPTIONS += -DCONFIG_CRYPTO
OPTIONS += -DCONFIG_SPLIT_SRAM
OPTIONS += -DSTANDALONE_NET_DEVICES
#
# The domain manager doesn't know about the SP LDC SRAM queues.
# We require a new MD from the SP for the HV which will contain
# platform-specific implementation details which are of no
# interest to the domain manager. Until we implement this, we
# use a hard-coded table
OPTIONS += -DCONFIG_SPLIT_SRAM_ERRATUM

########################################

OPTIONS += $(EXTRA_OPTIONS)
OPTIONS += -UCONFIG_BRINGUP

########################################

$(PROTO_PLAT)/q: q
$(PROTO_PLAT)/reset: reset

install :: $(PROTO_PLAT)/q $(PROTO_PLAT)/q.bin $(PROTO_PLAT)/reset $(PROTO_PLAT)/reset.bin
