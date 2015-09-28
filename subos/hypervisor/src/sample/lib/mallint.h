/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mallint.h
* 
* Copyright (c) 2006 Sun Microsystems, Inc. All Rights Reserved.
* 
*  - Do no alter or remove copyright notices
* 
*  - Redistribution and use of this software in source and binary forms, with 
*    or without modification, are permitted provided that the following 
*    conditions are met: 
* 
*  - Redistribution of source code must retain the above copyright notice, 
*    this list of conditions and the following disclaimer.
* 
*  - Redistribution in binary form must reproduce the above copyright notice,
*    this list of conditions and the following disclaimer in the
*    documentation and/or other materials provided with the distribution. 
* 
*    Neither the name of Sun Microsystems, Inc. or the names of contributors 
* may be used to endorse or promote products derived from this software 
* without specific prior written permission. 
* 
*     This software is provided "AS IS," without a warranty of any kind. 
* ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, 
* INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A 
* PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY EXCLUDED. SUN 
* MICROSYSTEMS, INC. ("SUN") AND ITS LICENSORS SHALL NOT BE LIABLE FOR 
* ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR 
* DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES. IN NO EVENT WILL SUN 
* OR ITS LICENSORS BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA, OR 
* FOR DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE 
* DAMAGES, HOWEVER CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, 
* ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF 
* SUN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
* 
* You acknowledge that this software is not designed, licensed or
* intended for use in the design, construction, operation or maintenance of
* any nuclear facility. 
* 
* ========== Copyright Header End ============================================
*/
/*
 * Copyright 2003 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident	"@(#)mallint.h	1.2	03/11/10 SMI"

#include <sys/types.h>
#ifdef _LP64
#define	ALIGNSZ	16
#else
#define	ALIGNSZ	8
#endif

/*
 *	template for the header
 */

struct header {
	struct header *nextblk;
	struct header *nextfree;
	struct header *prevfree;
	struct header *__Pad;	/* pad to a multiple of ALIGNSZ */
};

/*
 *	template for a small block
 */

struct lblk  {
	union {
		/*
		 * the next free little block in this holding block.
		 * This field is used when the block is free
		 */
		struct lblk *nextfree;
		/*
		 * the holding block containing this little block.
		 * This field is used when the block is allocated
		 */
		struct holdblk *holder;
		/*
		 * Insure over head is multiple of ALIGNSZ
		 * assumes  ALIGNSZ >= sizeof pointer
		 */
		char __Overhead[ALIGNSZ];
	}  header;
	/* There is no telling how big this field really is.  */
	/* This must be on a ALIGNSZ  boundary */
	char byte;
};

/*
 *	template for holding block
 */
struct holdblk {
	struct holdblk *nexthblk;   /* next holding block */
	struct holdblk *prevhblk;   /* previous holding block */
	struct lblk *lfreeq;	/* head of free queue within block */
	struct lblk *unused;	/* pointer to 1st little block never used */
	long blksz;		/* size of little blocks contained */
	struct lblk *__Pad;	/* pad to a multiple of ALIGNSZ */
	char space[1];		/* start of space to allocate. */
				/* This must be on a ALIGNSZ boundary */
};

/*
 *	 The following manipulate the free queue
 *
 *		DELFREEQ will remove x from the free queue
 *		ADDFREEQ will add an element to the head
 *			 of the free queue.
 *		MOVEHEAD will move the free pointers so that
 *			 x is at the front of the queue
 */
#define	ADDFREEQ(x)	(x)->prevfree = &(freeptr[0]);\
				(x)->nextfree = freeptr[0].nextfree;\
				freeptr[0].nextfree->prevfree = (x);\
				freeptr[0].nextfree = (x);\
				assert((x)->nextfree != (x));\
				assert((x)->prevfree != (x));
#define	DELFREEQ(x)	(x)->prevfree->nextfree = (x)->nextfree;\
				(x)->nextfree->prevfree = (x)->prevfree;\
				assert((x)->nextfree != (x));\
				assert((x)->prevfree != (x));
#define	MOVEHEAD(x)	freeptr[1].prevfree->nextfree = freeptr[0].nextfree;\
				freeptr[0].nextfree->prevfree = \
				    freeptr[1].prevfree;\
				(x)->prevfree->nextfree = &(freeptr[1]);\
				freeptr[1].prevfree = (x)->prevfree;\
				(x)->prevfree = &(freeptr[0]);\
				freeptr[0].nextfree = (x);\
				assert((x)->nextfree != (x));\
				assert((x)->prevfree != (x));
/*
 *	The following manipulate the busy flag
 */
#define	BUSY	1L
#define	SETBUSY(x)	((struct header *)((long)(x) | BUSY))
#define	CLRBUSY(x)	((struct header *)((long)(x) & ~BUSY))
#define	TESTBUSY(x)	((long)(x) & BUSY)
/*
 *	The following manipulate the small block flag
 */
#define	SMAL	2L
#define	SETSMAL(x)	((struct lblk *)((long)(x) | SMAL))
#define	CLRSMAL(x)	((struct lblk *)((long)(x) & ~SMAL))
#define	TESTSMAL(x)	((long)(x) & SMAL)
/*
 *	The following manipulate both flags.  They must be
 *	type coerced
 */
#define	SETALL(x)	((long)(x) | (SMAL | BUSY))
#define	CLRALL(x)	((long)(x) & ~(SMAL | BUSY))
/*
 *	Other useful constants
 */
#define	TRUE	1
#define	FALSE	0
#define	HEADSZ	sizeof (struct header)	/* size of unallocated block header */

/* MINHEAD is the minimum size of an allocated block header */
#define	MINHEAD	ALIGNSZ

/* min. block size must as big as HEADSZ */
#define	MINBLKSZ	HEADSZ

/* memory is gotten from sbrk in multiples of BLOCKSZ */
#define	BLOCKSZ		2048	/* ??? Too Small, ?? pagesize? */

#define	GROUND	(struct header *)0
#define	LGROUND	(struct lblk *)0
#define	HGROUND	(struct holdblk *)0	/* ground for the holding block queue */
#ifndef	NULL
#define	NULL	(char *)0
#endif
/*
 *	Structures and constants describing the holding blocks
 */
/* default number of small blocks per holding block */
#define	NUMLBLKS	100

/* size of a holding block with small blocks of size blksz */
#define	HOLDSZ(blksz)	\
	    (sizeof (struct holdblk) - sizeof (struct lblk *) + blksz*numlblks)
#define	FASTCT	6	/* number of blocks that can be allocated quickly */

/* default maximum size block for fast allocation */
/* assumes initial value of grain == ALIGNSZ */
#define	MAXFAST	ALIGNSZ*FASTCT

#ifdef	debug
#define	CHECKQ	checkq();
#else
#define	CHECKQ
#endif

#ifdef	_REENTRANT

#define	mutex_lock(m)			_mutex_lock(m)
#define	mutex_unlock(m)			_mutex_unlock(m)

#else

#define	mutex_lock(m)
#define	mutex_unlock(m)

#endif	_REENTRANT
