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
# @(#)depend.mk 1.1 07/01/23
# purpose: 
# copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
# copyright: Use is subject to license terms.
# This is a machine generated file
# DO NOT EDIT IT BY HAND

niu.fc: ${BP}/dev/network/common/devargs.fth
niu.fc: ${BP}/dev/network/common/link-params.fth
niu.fc: ${BP}/dev/network/common/mif/gmii-h.fth
niu.fc: ${BP}/dev/network/common/mif/mii-h.fth
niu.fc: ${BP}/dev/network/neptune/bcm8704.fth
niu.fc: ${BP}/dev/network/neptune/classifier.fth
niu.fc: ${BP}/dev/network/neptune/core.fth
niu.fc: ${BP}/dev/network/neptune/global.fth
niu.fc: ${BP}/dev/network/neptune/mif.fth
niu.fc: ${BP}/dev/network/neptune/niu/debug.fth
niu.fc: ${BP}/dev/network/neptune/niu/map.fth
niu.fc: ${BP}/dev/network/neptune/niu/md-access.fth
niu.fc: ${BP}/dev/network/neptune/niu/redirect.fth
niu.fc: ${BP}/dev/network/neptune/niu/ti.fth
niu.fc: ${BP}/dev/network/neptune/niu/util.fth
niu.fc: ${BP}/dev/network/neptune/pkg.fth
niu.fc: ${BP}/dev/network/neptune/reg-defs.fth
niu.fc: ${BP}/dev/network/neptune/util.fth
niu.fc: ${BP}/dev/network/neptune/xmac.fth
niu.fc: ${BP}/dev/utilities/misc.fth
niu.fc: ${BP}/dev/network/neptune/niu/niu.tok
