# ========== Copyright Header Begin ==========================================
# 
# Hypervisor Software File: depend.mk
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
# id: @(#)depend.mk  1.3  07/06/22
# purpose: 
# copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# copyright: Use is subject to license terms.
# This is a machine generated file
# DO NOT EDIT IT BY HAND

ophir.fc: ${BP}/dev/network/common/devargs.fth
ophir.fc: ${BP}/dev/network/common/link-params.fth
ophir.fc: ${BP}/dev/network/common/mif/gmii-h.fth
ophir.fc: ${BP}/dev/network/common/mif/mii-h.fth
ophir.fc: ${BP}/dev/network/ophir/core.fth
ophir.fc: ${BP}/dev/network/ophir/eeprom.fth
ophir.fc: ${BP}/dev/network/ophir/load.fth
ophir.fc: ${BP}/dev/network/ophir/map.fth
ophir.fc: ${BP}/dev/network/ophir/mif.fth
ophir.fc: ${BP}/dev/network/ophir/phy.fth
ophir.fc: ${BP}/dev/network/ophir/pkg.fth
ophir.fc: ${BP}/dev/network/ophir/test.fth
ophir.fc: ${BP}/dev/network/ophir/util.fth
ophir.fc: ${BP}/dev/pci/cfgio.fth
ophir.fc: ${BP}/dev/pci/compatible-prop.fth
ophir.fc: ${BP}/dev/pci/compatible.fth
ophir.fc: ${BP}/dev/pci/config-access.fth
ophir.fc: ${BP}/dev/sun4v-devices/utilities/md-parse.fth
ophir.fc: ${BP}/dev/utilities/cif.fth
ophir.fc: ${BP}/dev/utilities/strings.fth
ophir.fc: ${BP}/dev/network/ophir/ophir.tok
