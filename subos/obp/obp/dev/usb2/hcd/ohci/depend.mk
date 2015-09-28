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
# id: @(#)depend.mk  1.1  07/01/22
# purpose: 
# copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
# copyright: Use is subject to license terms.
# This is a machine generated file
# DO NOT EDIT IT BY HAND

ohci.fc: ${BP}/dev/pci/compatible-prop.fth
ohci.fc: ${BP}/dev/pci/compatible.fth
ohci.fc: ${BP}/dev/usb2/align.fth
ohci.fc: ${BP}/dev/usb2/device/vendor.fth
ohci.fc: ${BP}/dev/usb2/error.fth
ohci.fc: ${BP}/dev/usb2/hcd/control.fth
ohci.fc: ${BP}/dev/usb2/hcd/dev-info.fth
ohci.fc: ${BP}/dev/usb2/hcd/device.fth
ohci.fc: ${BP}/dev/usb2/hcd/error.fth
ohci.fc: ${BP}/dev/usb2/hcd/fcode.fth
ohci.fc: ${BP}/dev/usb2/hcd/hcd.fth
ohci.fc: ${BP}/dev/usb2/hcd/ohci/bulk.fth
ohci.fc: ${BP}/dev/usb2/hcd/ohci/control.fth
ohci.fc: ${BP}/dev/usb2/hcd/ohci/edtd.fth
ohci.fc: ${BP}/dev/usb2/hcd/ohci/intr.fth
ohci.fc: ${BP}/dev/usb2/hcd/ohci/loadpkg.fth
ohci.fc: ${BP}/dev/usb2/hcd/ohci/ohci.fth
ohci.fc: ${BP}/dev/usb2/hcd/ohci/probe.fth
ohci.fc: ${BP}/dev/usb2/hcd/probehub.fth
ohci.fc: ${BP}/dev/usb2/pkt-data.fth
ohci.fc: ${BP}/dev/usb2/pkt-func.fth
ohci.fc: ${BP}/dev/usb2/vendor.fth
ohci.fc: ${BP}/dev/utilities/misc.fth
ohci.fc: ${BP}/dev/usb2/hcd/ohci/ohci.tok
