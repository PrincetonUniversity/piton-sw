/*
 * Copyright 2016 Princeton University.
 * Use is subject to license terms.
 */

#ifndef _MITTS_H
#define	_MITTS_H

#define	MITTS_REG1_ADDR	0xBA00000200
#define	MITTS_REG2_ADDR	0xBA00000500

#define DISABLE_MITTS(R1, R2)			 \
	setx	MITTS_REG1_ADDR, R1, R2		;\
	ldx	[R2], R1			;\
	srlx	R1, 2, R1			;\
	sllx	R1, 2, R1			;\
	stx	R1, [R2]			;\

#endif /* _MITTS_H */
