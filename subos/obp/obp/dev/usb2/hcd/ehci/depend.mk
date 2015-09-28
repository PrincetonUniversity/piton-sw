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

ehci.fc: ${BP}/dev/pci/compatible-prop.fth
ehci.fc: ${BP}/dev/pci/compatible.fth
ehci.fc: ${BP}/dev/usb2/align.fth
ehci.fc: ${BP}/dev/usb2/device/vendor.fth
ehci.fc: ${BP}/dev/usb2/error.fth
ehci.fc: ${BP}/dev/usb2/hcd/control.fth
ehci.fc: ${BP}/dev/usb2/hcd/dev-info.fth
ehci.fc: ${BP}/dev/usb2/hcd/device.fth
ehci.fc: ${BP}/dev/usb2/hcd/ehci/bulk.fth
ehci.fc: ${BP}/dev/usb2/hcd/ehci/control.fth
ehci.fc: ${BP}/dev/usb2/hcd/ehci/ehci.fth
ehci.fc: ${BP}/dev/usb2/hcd/ehci/intr.fth
ehci.fc: ${BP}/dev/usb2/hcd/ehci/loadpkg.fth
ehci.fc: ${BP}/dev/usb2/hcd/ehci/probe.fth
ehci.fc: ${BP}/dev/usb2/hcd/ehci/probehub.fth
ehci.fc: ${BP}/dev/usb2/hcd/ehci/qhtd.fth
ehci.fc: ${BP}/dev/usb2/hcd/error.fth
ehci.fc: ${BP}/dev/usb2/hcd/fcode.fth
ehci.fc: ${BP}/dev/usb2/hcd/hcd.fth
ehci.fc: ${BP}/dev/usb2/hcd/probehub.fth
ehci.fc: ${BP}/dev/usb2/pkt-data.fth
ehci.fc: ${BP}/dev/usb2/pkt-func.fth
ehci.fc: ${BP}/dev/usb2/vendor.fth
ehci.fc: ${BP}/dev/utilities/misc.fth
ehci.fc: ${BP}/dev/usb2/hcd/ehci/ehci.tok
