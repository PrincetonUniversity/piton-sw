/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: byteswap.h
* Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
* DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
* 
* The above named program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License version 2 as published by the Free Software Foundation.
* 
* The above named program is distributed in the hope that it will be 
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
* 
* You should have received a copy of the GNU General Public
* License along with this work; if not, write to the Free Software
* Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
* 
* ========== Copyright Header End ============================================
*/
#ifndef _BYTESWAP_H
#define _BYTESWAP_H

#if defined(ARCH_AMD64)

#include <sys/types.h>
extern "C" uint16_t byteswap16( uint16_t v );
extern "C" uint32_t byteswap32(uint32_t v);
extern "C" uint64_t byteswap64(uint64_t v);

#define flip_endian16(a) byteswap16(a)
#define flip_endian32(a) byteswap32(a)
#define flip_endian64(a) byteswap64(a)

#else

#define flip_endian16(a) a
#define flip_endian32(a) a
#define flip_endian64(a) a

#endif

#endif
