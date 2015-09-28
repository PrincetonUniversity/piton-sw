#!/bin/csh -f
# ========== Copyright Header Begin ==========================================
# 
# OpenSPARC T2 Processor File: build_legion.sh
# Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
# 
# The above named program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public
# License version 2 as published by the Free Software Foundation.
# 
# The above named program is distributed in the hope that it will be 
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public
# License along with this work; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
# 
# ========== Copyright Header End ============================================

if ($1 == "") then 
    setenv TARG all
else if (($1 != "all") && ($1 != "clean")) then
    echo "Usage: $0 type"
    echo "Where type = all or clean"
    echo "e.g. $0 all"
    exit
else
    setenv TARG $1
endif

if ("`env | grep SIM_ROOT`" == "" ) then
  echo "$0 : SIM_ROOT not defined."
  echo "  Please define SIM_ROOT and then re-run $0"
  exit
endif

setenv OS `uname -s`
setenv CPU `uname -p`

if ($OS == "SunOS") then
  if ("`env | grep SUN_STUDIO`" == "" ) then
    echo "$0 : SUN_STUDIO not defined."
    echo "  Please define SUN_STUDIO and then re-run $0"
    exit
  endif
endif

setenv SRC_DIR $SIM_ROOT/legion

if ( -e $SRC_DIR/build ) then
    echo $SRC_DIR/build exists.
else
    echo Creating $SRC_DIR/build directory.
    mkdir $SRC_DIR/build
endif

cd $SRC_DIR/build
set path = (/pkg/gnu/bin $path)
sh ../src/configure.opensparc
gmake $TARG



