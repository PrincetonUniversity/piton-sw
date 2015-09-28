/*
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _VDEV_SNET_H
#define	_VDEV_SNET_H

#ifdef T1_FPGA_SNET


#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASM


struct snet_info {
	uint64_t	pa;
	uint64_t        ino;
};


#endif /* ifndef _ASM */

#ifdef __cplusplus
}
#endif

#endif /* ifdef T1_FPGA_SNET */

#endif /* _VDEV_SNET_H */
