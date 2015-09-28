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
# ident	"@(#)Makefile	1.3	07/09/20 SMI"
#

VARIANT = legion
include ../Makefile.platform

########################################

OPTIONS = $(PLAT_OPTIONS)
OPTIONS += -DDEBUG
OPTIONS += -DSTRICT_API
OPTIONS += -DCONFIG_DISK	# Simulated disk support
OPTIONS += -DCONFIG_PCIE
OPTIONS += -DCONFIG_PIU
OPTIONS += -DCONFIG_IOBYPASS
OPTIONS += -DCONFIG_STATICTOD	# Time does not move - pending FPGA support
OPTIONS += -DDEBUG_LEGION	# Legion-specific debugging aids
OPTIONS += -DCONFIG_LEGIONBCOPY	# Legion has physical bcopy magic trap
OPTIONS += -DCONFIG_HVUART
OPTIONS += -DCONFIG_CLEANSER	# L2$ cache cleanser cyclic
OPTIONS += -DCONFIG_VERSION_TEST
OPTIONS += -DSIMULATION
OPTIONS += -UCONFIG_LDC_BRIDGE   # Compile with support for XDC Bridge
OPTIONS += -DCONFIG_CRYPTO       # Crypto support
OPTIONS += -DCONFIG_SVC
OPTIONS += -UCONFIG_FPGA                # hardware fpga present
OPTIONS += -UCONFIG_VBSC_SVC    # VBSC comm channel
OPTIONS += -DCONFIG_CN_UART    # UART console capability for a guest
OPTIONS += -DFOR_ZEUS
OPTIONS += -UFALLS_FPGA

########################################

OPTIONS += $(EXTRA_OPTIONS)
OPTIONS += -DCONFIG_BRINGUP

########################################


$(PROTO_PLAT)/q: q
$(PROTO_PLAT)/reset: reset

install :: $(PROTO_PLAT)/q $(PROTO_PLAT)/q.bin $(PROTO_PLAT)/reset $(PROTO_PLAT)/reset.bin
