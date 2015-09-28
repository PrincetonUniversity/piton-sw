# id: @(#)Makefile 1.1 06/02/16
# purpose: 
# copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
# Use is subject to license terms.

ROOT		= ../../../../..
BP		= ${ROOT}/obp
SUN4V		= ${BP}/arch/sun4v
PLATFORM	= ${SUN4V}/niagara
RESET		= ${PLATFORM}/reset.fth

PLATFLAGS	+= -D SUN4V

all:	openboot.bin

include ${SUN4V}/common.mk
include ../depend.mk
include ../reset.mk

FORCE:
