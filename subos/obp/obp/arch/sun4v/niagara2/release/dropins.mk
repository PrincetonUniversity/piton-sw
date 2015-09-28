# ========== Copyright Header Begin ==========================================
# 
# Hypervisor Software File: dropins.mk
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

bootprom.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src bootprom.bin
	${MAKEDI} bootprom.bin bootprom
#
# Warning this is a machine generated file
# Changes made here will go away
#

include ${BP}/dev/sun4v-devices/vnexus/depend.mk

vnexus.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src vnexus.fc
	${MAKEDI} vnexus.fc SUNW,vnexus

include ${BP}/pkg/termemu/fonts.mk

include ${BP}/pkg/sunlogo/logo.mk

include ${BP}/pkg/dhcp/obptftp.mk

include ${BP}/dev/sun4v-devices/legion-disk/depend.mk

sim-disk.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src sim-disk.fc
	${MAKEDI} sim-disk.fc legion-disk

include ${BP}/dev/sun4v-devices/legion-nvram/depend.mk

sim-nvram.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src sim-nvram.fc
	${MAKEDI} sim-nvram.fc legion-nvram

include ${BP}/dev/sun4v-devices/flashprom/depend.mk

flashprom.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src flashprom.fc
	${MAKEDI} flashprom.fc sun4v-flashprom

include ${BP}/dev/sun4v-devices/console/depend.mk

console.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src console.fc
	${MAKEDI} console.fc sun4v-console

include ${BP}/dev/sun4v-devices/vchannel/depend.mk

vchannel.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src vchannel.fc
	${MAKEDI} vchannel.fc sun4v-chan-dev

include ${BP}/dev/sun4v-devices/vnet/depend.mk

vnet.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src vnet.fc
	${MAKEDI} vnet.fc sun4v-vnet

include ${BP}/dev/sun4v-devices/vdisk/depend.mk

vdisk.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src vdisk.fc
	${MAKEDI} vdisk.fc sun4v-vdisk

include ${BP}/dev/sun4v-devices/tod/depend.mk

tod.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src tod.fc
	${MAKEDI} tod.fc sun4v-tod

include ${BP}/dev/sun4v-devices/vpci/depend.mk

vpci.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src vpci.fc
	${MAKEDI} vpci.fc sun4v-vpci

vpci.fc:=	FTHFLAGS += [define] 64BIT-ASSIGNED?
include ${BP}/dev/sun4v-devices/n2/perf-cntr/depend.mk

perf-cntr.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src perf-cntr.fc
	${MAKEDI} perf-cntr.fc sun4v-perf-cnt

include ${BP}/dev/sun4v-devices/niu-nexus/depend.mk

niu-nexus.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src niu-nexus.fc
	${MAKEDI} niu-nexus.fc niu-nexus

include ${BP}/dev/network/neptune/niu/depend.mk

niu.di: ../../../../../obp/arch/sun4v/niagara2/release/dropins.src niu.fc
	${MAKEDI} niu.fc niu-network

builtin.di: bootprom.di vnexus.di font.di sun-logo.di obptftp.di sim-disk.di sim-nvram.di flashprom.di console.di vchannel.di vnet.di vdisk.di tod.di vpci.di perf-cntr.di niu-nexus.di niu.di 
