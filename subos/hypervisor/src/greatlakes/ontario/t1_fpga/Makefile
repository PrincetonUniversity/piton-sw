#
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

VARIANT = t1_fpga

include ../Makefile.platform

CP = /bin/cp -f

########################################

OPTIONS = $(PLAT_OPTIONS)

OPTIONS += -DT1_FPGA                 # OpenSPARC T1 implementation in FPGA
OPTIONS += -DT1_FPGA_SNET            # net support
OPTIONS += -DT1_FPGA_MEMORY_PREINIT  # memory pre-initialized


OPTIONS += -DDEBUG
OPTIONS += -UFOR_ZEUS
OPTIONS += -DSIMULATION
OPTIONS += -DSTRICT_API
OPTIONS += -UNIAGARA_BRINGUP
OPTIONS += -DCONFIG_DISK	# Simulated disk support
OPTIONS += -UCONFIG_PCIE	
OPTIONS += -UCONFIG_FIRE		# Initialize and configure Fire
OPTIONS += -UCONFIG_FIRE_EBUS	# Initialize and configure Fire EBus
OPTIONS += -UCONFIG_IOBYPASS	# Guest I/O bypass access
OPTIONS += -UCONFIG_VBSC_SVC	# VBSC comm channel
OPTIONS += -DCONFIG_SVC
OPTIONS += -UCONFIG_FPGA		# hardware fpga present
OPTIONS += -DCONFIG_STATICTOD	# Time does not move - pending FPGA support
OPTIONS += -UDEBUG_LEGION	# Legion-specific debugging aids
OPTIONS += -UCONFIG_LEGIONBCOPY	# Legion has physical bcopy magic trap
OPTIONS += -UCONFIG_SAS		# Compile without copies for PPG simulation
OPTIONS += -DCONFIG_HVUART
OPTIONS += -DCONFIG_CN_UART	# UART console capability for a guest
OPTIONS += -UCONFIG_VERSION_TEST
OPTIONS += -UCONFIG_LDC_BRIDGE   # Compile with support for XDC Bridge
OPTIONS += -DCONFIG_CRYPTO       # Crypto support
OPTIONS += -DSIMULATION
OPTIONS += -UFOR_ZEUS

########################################

OPTIONS += $(EXTRA_OPTIONS)
OPTIONS += -UCONFIG_BRINGUP		# Force-enable helpful bringup aids

########################################


$(PROTO_PLAT)/q: q

all :: q.bin

install :: $(PROTO_PLAT)/q  $(PROTO_PLAT)/q.bin
