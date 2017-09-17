/*
* ========== Copyright Header Begin ==========================================
*
* OpenSPARC T2 Processor File: xilinx_t1_system_config.h
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
/*
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _XILINX_T1_SYSTEM_CONFIG_H
#define _XILINX_T1_SYSTEM_CONFIG_H



#define T1_FPGA_PROM_BASE_ADDR            0xfff0000000
#define T1_FPGA_RAM_DISK_ADDR             0xf001000000

#define T1_FPGA_UART_BASE                 0xfff0c2c000

/*
 * OpenSPARC T1 frequency as reported to OS. A higher frequency is reported so that one second of time
 * in the FPGA system (running at 50Mhz) is 10 seconds of wall clock time. There are assumptions made in
 * OS (kernel as well as user) that certain activity will be completed in X amount of time. Otherwise
 * OS will timeout and/or panic. Since the FPGA system is slow, the timeout is effectively raised by
 * 10 times to prevent timeouts and/or panics.
 */

#define T1_FPGA_STICK_FREQ                66666667  /* OpenSPARC T1 frequency as reported to OS */

#define T1_FPGA_SNET_BASE                 0xfff0c2c050
#define T1_FPGA_SNET_INO                  0x3F



#define T1_FPGA_HV_MEMBASE	          0x00000000
#define T1_FPGA_HV_MEMSIZE	          0x01000000

/*
 * Linux needs memory size to be a multiple of 4MB.
 */
#define T1_FPGA_TOTAL_MEMSIZE	          0x40000000  /* OpenSPARC T1 DRAM size */


#define T1_FPGA_GUEST_MEMBASE             (T1_FPGA_HV_MEMBASE + T1_FPGA_HV_MEMSIZE)
#define T1_FPGA_GUEST_MEMSIZE             (T1_FPGA_TOTAL_MEMSIZE - T1_FPGA_HV_MEMSIZE)
#define T1_FPGA_GUEST_REALBASE            T1_FPGA_GUEST_MEMBASE


#define PITON_IO_MEMBASE             0xfff0c00000
#define PITON_IO_MEMSIZE             0x400000
#define PITON_IO_REALBASE            PITON_IO_MEMBASE


/*
 * Offsets of various binaries stored in PROM. The first three
 * binaries are reset, hypervisor (q) and openboot (OBP) executables.
 * The executables are followed by machine descriptions of guest and
 * hypervisor. The machine description is followed by NVRAM
 */

#define T1_FPGA_PROM_RESET_OFFSET         0x00000
#define T1_FPGA_PROM_MAX_RESET_SIZE       0x20000

#define T1_FPGA_PROM_HV_OFFSET            (T1_FPGA_PROM_RESET_OFFSET + T1_FPGA_PROM_MAX_RESET_SIZE)
#define T1_FPGA_PROM_MAX_HV_SIZE          0x60000

#define T1_FPGA_PROM_OPENBOOT_OFFSET      (T1_FPGA_PROM_HV_OFFSET + T1_FPGA_PROM_MAX_HV_SIZE)
#define T1_FPGA_PROM_MAX_OPENBOOT_SIZE    0x70000

#define T1_FPGA_PROM_GUEST_MD_OFFSET      (T1_FPGA_PROM_OPENBOOT_OFFSET + T1_FPGA_PROM_MAX_OPENBOOT_SIZE)
#define T1_FPGA_PROM_MAX_GUEST_MD_SIZE    0x08000

#define T1_FPGA_PROM_HV_MD_OFFSET         (T1_FPGA_PROM_GUEST_MD_OFFSET + T1_FPGA_PROM_MAX_GUEST_MD_SIZE)
#define T1_FPGA_PROM_MAX_HV_MD_SIZE       0x04000

#define T1_FPGA_PROM_NVRAM_OFFSET         (T1_FPGA_PROM_HV_MD_OFFSET + T1_FPGA_PROM_MAX_HV_MD_SIZE)
#define T1_FPGA_PROM_MAX_NVRAM_SIZE       0x02000
#define T1_FPGA_NVRAM_SIZE                T1_FPGA_PROM_MAX_NVRAM_SIZE

#define T1_FPGA_PROM_BIN_FILE_SIZE        0x100000


#define T1_FPGA_GUEST_MD_ADDR             (T1_FPGA_PROM_BASE_ADDR + T1_FPGA_PROM_GUEST_MD_OFFSET)
#define T1_FPGA_HV_MD_ADDR                (T1_FPGA_PROM_BASE_ADDR + T1_FPGA_PROM_HV_MD_OFFSET)
#define T1_FPGA_NVRAM_ADDR                (T1_FPGA_PROM_BASE_ADDR + T1_FPGA_PROM_NVRAM_OFFSET)


#define T1_FPGA_PROM_HV_START_OFFSET      (T1_FPGA_PROM_HV_OFFSET + 0x20)



#ifdef T1_FPGA_1C2T
#define STRAND_STARTSET   0x3   /* 1c2t configuration */
#elif defined T1_FPGA_1C4T
#define STRAND_STARTSET   0xf   /* 1c4t configuration */
#elif defined T1_FPGA_2C1T
#define STRAND_STARTSET   0x5   /* 2c1t configuration */
#elif defined T1_FPGA_2C4T
#define STRAND_STARTSET   0xff   /* 2c4t configuration */
#elif defined T1_FPGA_4C1T
#define STRAND_STARTSET   0x55   /* 4c1t configuration */
#else
#define STRAND_STARTSET   0x1
#endif



/*
 * In Stand-alone mode, the guest executable image is picked up from
 * RAM disk addr. A stand-alone static executable program can be loaded
 * instead of OBP.
 */

#ifdef T1_FPGA_STAND_ALONE

#define ROMBASE        T1_FPGA_RAM_DISK_ADDR
#define ROMSIZE        0x400000

#else /* ifdef T1_FPGA_STAND_ALONE */

#define ROMBASE        (T1_FPGA_PROM_BASE_ADDR + T1_FPGA_PROM_OPENBOOT_OFFSET)
#define ROMSIZE        T1_FPGA_PROM_MAX_OPENBOOT_SIZE

#endif /* ifdef T1_FPGA_STAND_ALONE */



#endif /* ifndef _XILINX_T1_SYSTEM_CONFIG_H */
