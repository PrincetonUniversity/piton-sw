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
# ident	"@(#)Makefile	1.4	07/05/03 SMI"
#

VARIANT = debug

include ../Makefile.platform

########################################

OPTIONS = $(PLAT_OPTIONS)
OPTIONS += -DDEBUG
OPTIONS += -DDEBUG_VINTR
OPTIONS += -USTRICT_API
OPTIONS += -DNIAGARA_BRINGUP
OPTIONS += -UCONFIG_DISK	# Simulated disk support
OPTIONS += -DCONFIG_PCIE	# Initialize and configure PCIE
OPTIONS += -DCONFIG_FIRE	# Initialize and configure Fire
OPTIONS += -DCONFIG_FIRE_EBUS	# Initialize and configure Fire EBus
OPTIONS += -UCONFIG_IOBYPASS	# Guest I/O bypass access
OPTIONS += -DCONFIG_SVC
OPTIONS += -DCONFIG_VBSC_SVC	# VBSC comm channel
OPTIONS += -DCONFIG_FPGA	# hardware fpga present
OPTIONS += -UCONFIG_STATICTOD	# Time does not move - pending FPGA support
OPTIONS += -UDEBUG_LEGION	# Legion-specific debugging aids
OPTIONS += -UCONFIG_LEGIONBCOPY # Legion has physical bcopy magic trap
OPTIONS += -UCONFIG_SAS	# Compile without copies for PPG simulation
OPTIONS += -DCONFIG_HVUART
OPTIONS += -UCONFIG_CN_UART	# UART console capability for a guest
OPTIONS += -DCONFIG_VERSION_TEST
OPTIONS += -DCONFIG_CRYPTO       # Crypto support

########################################

OPTIONS += $(EXTRA_OPTIONS)
OPTIONS += -DCONFIG_BRINGUP		# Force-enable helpful bringup aids

########################################

$(PROTO_PLAT)/q: q

all :: q.bin

install :: $(PROTO_PLAT)/q $(PROTO_PLAT)/q.bin
