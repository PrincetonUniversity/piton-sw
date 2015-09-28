/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: malloc.c
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
/*	Copyright (c) 1988 AT&T	*/
/*	  All Rights Reserved  	*/

/*	THIS IS UNPUBLISHED PROPRIETARY SOURCE CODE OF AT&T	*/
/*	The copyright notice above does not evidence any   	*/
/*	actual or intended publication of such source code.	*/

#pragma	ident	"@(#)malloc.c	1.17	98/07/23 SMI"	/* SVr4.0 1.12  */

/*LINTLIBRARY*/
#include <sys/types.h>

#ifndef debug
#define	NDEBUG
#endif

#include <stdlib.h>
#include <string.h>
#include <thread.h>
#include <synch.h>
#include <assert.h>
#include <malloc.h>
#include "mallint.h"
#include <unistd.h>
#include <limits.h>

static mutex_t mlock = DEFAULTMUTEX;
static ssize_t freespace(struct holdblk *);
static void *malloc_unlocked(size_t);
static void *realloc_unlocked(void *, size_t);
static void free_unlocked(void *);
static void *morecore(size_t);

/*
 * use level memory allocater (malloc, free, realloc)
 *
 *	-malloc, free, realloc and mallopt form a memory allocator
 *	similar to malloc, free, and realloc.  The routines
 *	here are much faster than the original, with slightly worse
 *	space usage (a few percent difference on most input).  They
 *	do not have the property that data in freed blocks is left
 *	untouched until the space is reallocated.
 *
 *	-Memory is kept in the "arena", a singly linked list of blocks.
 *	These blocks are of 3 types.
 *		1. A free block.  This is a block not in use by the
 *		   user.  It has a 3 word header. (See description
 *		   of the free queue.)
 *		2. An allocated block.  This is a block the user has
 *		   requested.  It has only a 1 word header, pointing
 *		   to the next block of any sort.
 *		3. A permanently allocated block.  This covers space
 *		   aquired by the user directly through sbrk().  It
 *		   has a 1 word header, as does 2.
 *	Blocks of type 1 have the lower bit of the pointer to the
 *	nextblock = 0.  Blocks of type 2 and 3 have that bit set,
 *	to mark them busy.
 *
 *	-Unallocated blocks are kept on an unsorted doubly linked
 *	free list.
 *
 *	-Memory is allocated in blocks, with sizes specified by the
 *	user.  A circular first-fit startegy is used, with a roving
 *	head of the free queue, which prevents bunching of small
 *	blocks at the head of the queue.
 *
 *	-Compaction is performed at free time of any blocks immediately
 *	following the freed block.  The freed block will be combined
 *	with a preceding block during the search phase of malloc.
 *	Since a freed block is added at the front of the free queue,
 *	which is moved to the end of the queue if considered and
 *	rejected during the search, fragmentation only occurs if
 *	a block with a contiguious preceding block that is free is
 *	freed and reallocated on the next call to malloc.  The
 *	time savings of this strategy is judged to be worth the
 *	occasional waste of memory.
 *
 *	-Small blocks (of size < MAXSIZE)  are not allocated directly.
 *	A large "holding" block is allocated via a recursive call to
 *	malloc.  This block contains a header and ?????? small blocks.
 *	Holding blocks for a given size of small block (rounded to the
 *	nearest ALIGNSZ bytes) are kept on a queue with the property that any
 *	holding block with an unused small block is in front of any without.
 *	A list of free blocks is kept within the holding block.
 */

/*
 *	description of arena, free queue, holding blocks etc.
 *
 * New compiler and linker does not guarentee order of initialized data.
 * Define freeptr as arena[2-3] to guarentee it follows arena in memory.
 * Later code depends on this order.
 */

static struct header arena[4] = {
	    {0, 0, 0},
	    {0, 0, 0},
	    {0, 0, 0},
	    {0, 0, 0}
	};
				/*
				 * the second word is a minimal block to
				 * start the arena. The first is a busy
				 * block to be pointed to by the last block.
				 */

#define	freeptr (arena + 2)
				/* first and last entry in free list */
static struct header *arenaend;	/* ptr to block marking high end of arena */
static struct header *lastblk;	/* the highest block in the arena */
static struct holdblk **holdhead;   /* pointer to array of head pointers */
				    /* to holding block chains */
/*
 * In order to save time calculating indices, the array is 1 too
 * large, and the first element is unused
 *
 * Variables controlling algorithm, esp. how holding blocs are used
 */
static int numlblks = NUMLBLKS;
static int minhead = MINHEAD;
static int change = 0;	/* != 0, once param changes are no longer allowed */
static int fastct = FASTCT;
static unsigned int maxfast = MAXFAST;
/* number of small block sizes to map to one size */

static int grain = ALIGNSZ;

#ifdef debug
static int case1count = 0;

static
checkq(void)
{
	register struct header *p;

	p = &freeptr[0];

	/* check forward */
	/*CSTYLED*/
	while (p != &freeptr[1]) {
		p = p->nextfree;
		assert(p->prevfree->nextfree == p);
	}

	/* check backward */
	/*CSTYLED*/
	while (p != &freeptr[0]) {
		p = p->prevfree;
		assert(p->nextfree->prevfree == p);
	}
}
#endif


/*
 * malloc(nbytes) - give a user nbytes to use
 */

void *
malloc(size_t nbytes)
{
	void *ret;

	mutex_lock(&mlock);
	ret = malloc_unlocked(nbytes);
	mutex_unlock(&mlock);
	return (ret);
}


/*
 * malloc_unlocked(nbytes) - Do the real work for malloc
 */

static void *
malloc_unlocked(size_t nbytes)
{
	struct header *blk;
	size_t nb;	/* size of entire block we need */

	/* on first call, initialize */
	if (freeptr[0].nextfree == GROUND) {
		/* initialize arena */
		arena[1].nextblk = (struct header *)BUSY;
		arena[0].nextblk = (struct header *)BUSY;
		lastblk = arenaend = &(arena[1]);
		/* initialize free queue */
		freeptr[0].nextfree = &(freeptr[1]);
		freeptr[1].nextblk = &(arena[0]);
		freeptr[1].prevfree = &(freeptr[0]);
		/* mark that small blocks not init yet */
	}
	if (nbytes == 0)
		return (NULL);

	if (nbytes <= maxfast) {
		/*
		 * We can allocate out of a holding block
		 */
		struct holdblk *holdblk; /* head of right sized queue */
		struct lblk *lblk;	 /* pointer to a little block */
		struct holdblk *newhold;

		if (!change) {
			int i;
			/*
			 * This allocates space for hold block
			 * pointers by calling malloc recursively.
			 * Maxfast is temporarily set to 0, to
			 * avoid infinite recursion.  allocate
			 * space for an extra ptr so that an index
			 * is just ->blksz/grain, with the first
			 * ptr unused.
			 */
			change = 1;	/* change to algorithm params */
					/* no longer allowed */
			/*
			 * temporarily alter maxfast, to avoid
			 * infinite recursion
			 */
			maxfast = 0;
			holdhead = (struct holdblk **)
			    malloc_unlocked(sizeof (struct holdblk *) *
			    (fastct + 1));
			if (holdhead == NULL)
				return (malloc_unlocked(nbytes));
			for (i = 1; i <= fastct; i++) {
				holdhead[i] = HGROUND;
			}
			maxfast = fastct * grain;
		}
		/*
		 * Note that this uses the absolute min header size (MINHEAD)
		 * unlike the large block case which uses minhead
		 *
		 * round up to nearest multiple of grain
		 * code assumes grain is a multiple of MINHEAD
		*/
		/* round up to grain */
		nb = (nbytes + grain - 1) / grain * grain;
		holdblk = holdhead[nb / grain];
		nb = nb + MINHEAD;
		/*
		 * look for space in the holding block.  Blocks with
		 * space will be in front of those without
		 */
		if ((holdblk != HGROUND) && (holdblk->lfreeq != LGROUND))  {
			/* there is space */
			lblk = holdblk->lfreeq;

			/*
			 * Now make lfreeq point to a free block.
			 * If lblk has been previously allocated and
			 * freed, it has a valid pointer to use.
			 * Otherwise, lblk is at the beginning of
			 * the unallocated blocks at the end of
			 * the holding block, so, if there is room, take
			 * the next space.  If not, mark holdblk full,
			 * and move holdblk to the end of the queue
			 */
			if (lblk < holdblk->unused) {
				/* move to next holdblk, if this one full */
				if ((holdblk->lfreeq =
				    CLRSMAL(lblk->header.nextfree)) ==
				    LGROUND) {
					holdhead[(nb-MINHEAD) / grain] =
					    holdblk->nexthblk;
				}
			} else if (((char *)holdblk->unused + nb) <
			    ((char *)holdblk + HOLDSZ(nb))) {
				holdblk->unused = (struct lblk *)
				    ((char *)holdblk->unused+nb);
				holdblk->lfreeq = holdblk->unused;
			} else {
				holdblk->unused = (struct lblk *)
				    ((char *)holdblk->unused+nb);
				holdblk->lfreeq = LGROUND;
				holdhead[(nb-MINHEAD)/grain] =
				    holdblk->nexthblk;
			}
			/* mark as busy and small */
			lblk->header.holder = (struct holdblk *)SETALL(holdblk);
		} else {
			/* we need a new holding block */
			newhold = (struct holdblk *)
			    malloc_unlocked(HOLDSZ(nb));
			if ((char *)newhold == NULL) {
				return (NULL);
			}
			/* add to head of free queue */
			if (holdblk != HGROUND) {
				newhold->nexthblk = holdblk;
				newhold->prevhblk = holdblk->prevhblk;
				holdblk->prevhblk = newhold;
				newhold->prevhblk->nexthblk = newhold;
			} else {
				newhold->nexthblk = newhold->prevhblk = newhold;
			}
			holdhead[(nb-MINHEAD)/grain] = newhold;
			/* set up newhold */
			lblk = (struct lblk *)(newhold->space);
			newhold->lfreeq = newhold->unused =
			    (struct lblk *)((char *)newhold->space+nb);
			lblk->header.holder = (struct holdblk *)SETALL(newhold);
			newhold->blksz = nb-MINHEAD;
		}
#ifdef debug
		assert(((struct holdblk *)CLRALL(lblk->header.holder))->blksz >=
		    nbytes);
#endif /* debug */
		return ((char *)lblk + MINHEAD);
	} else {
		/*
		 * We need an ordinary block
		 */
		struct header *newblk;	/* used for creating a block */

		/* get number of bytes we need */
		nb = nbytes + minhead;
		nb = (nb + ALIGNSZ - 1) / ALIGNSZ * ALIGNSZ;	/* align */
		nb = (nb > MINBLKSZ) ? nb : MINBLKSZ;
		/*
		 * see if there is a big enough block
		 * If none exists, you will get to freeptr[1].
		 * freeptr[1].next = &arena[0], so when you do the test,
		 * the result is a large positive number, since arena[0]
		 * comes before all blocks.  Arena[0] is marked busy so
		 * that it will not be compacted.  This kludge is for the
		 * sake of the almighty efficiency.
		 */
		/* check that a very large request won't cause an inf. loop */

		if ((freeptr[1].nextblk-&(freeptr[1])) < nb) {
			return (NULL);
		} else {
			struct header *next;		/* following block */
			struct header *nextnext;	/* block after next */

			blk = freeptr;
			do {
				blk = blk->nextfree;
				/* see if we can compact */
				next = blk->nextblk;
				if (!TESTBUSY(nextnext = next->nextblk)) {
					do {
						DELFREEQ(next);
						next = nextnext;
						nextnext = next->nextblk;
					} while (!TESTBUSY(nextnext));
					/*
					 * next will be at most == to lastblk,
					 * but I think the >= test is faster
					 */
					if (next >= arenaend)
						lastblk = blk;
					blk->nextblk = next;
				}
			} while (((char *)(next) - (char *)blk) < nb);
		}
		/*
		 * if we didn't find a block, get more memory
		 */
		if (blk == &(freeptr[1])) {
			/*
			 * careful coding could likely replace
			 * newend with arenaend
			 */
			struct header *newend;	/* new end of arena */
			ssize_t nget;	/* number of words to get */

			/*
			 * Three cases - 1. There is space between arenaend
			 *		    and the break value that will become
			 *		    a permanently allocated block.
			 *		 2. Case 1 is not true, and the last
			 *		    block is allocated.
			 *		 3. Case 1 is not true, and the last
			 *		    block is free
			 */
			if ((newblk = (struct header *)sbrk(0)) !=
			    (struct header *)((char *)arenaend + HEADSZ)) {
				/* case 1 */
#ifdef debug
				if (case1count++ > 0)
				    write(2, "Case 1 hit more that once. "
					"brk or sbrk?\n", 41);
#endif
				/* get size to fetch */
				nget = nb + HEADSZ;
				/* round up to a block */
				nget = (nget + BLOCKSZ - 1)/BLOCKSZ * BLOCKSZ;
				assert((int)newblk % ALIGNSZ == 0);
				/* get memory */
				if (morecore(nget) == (void *)-1)
					return (NULL);
				/* add to arena */
				newend = (struct header *)((char *)newblk + nget
				    - HEADSZ);
				assert((int)newblk % ALIGNSZ == 0);
				newend->nextblk = SETBUSY(&(arena[1]));
/* ???  newblk ?? */
				newblk->nextblk = newend;

				/*
				 * space becomes a permanently allocated block.
				 * This is likely not mt-safe as lock is not
				 * shared with brk or sbrk
				 */
				arenaend->nextblk = SETBUSY(newblk);
				/* adjust other pointers */
				arenaend = newend;
				lastblk = newblk;
				blk = newblk;
			} else if (TESTBUSY(lastblk->nextblk)) {
				/* case 2 */
				nget = (nb + BLOCKSZ - 1) / BLOCKSZ * BLOCKSZ;
				if (morecore(nget) == (void *)-1)
					return (NULL);
				/* block must be word aligned */
				assert(((int)newblk%ALIGNSZ) == 0);
				/*
				 * stub at old arenaend becomes first word
				 * in blk
				 */
/* ???  	newblk = arenaend; */

				newend =
				    (struct header *)((char *)arenaend+nget);
				newend->nextblk = SETBUSY(&(arena[1]));
				arenaend->nextblk = newend;
				lastblk = blk = arenaend;
				arenaend = newend;
			} else {
				/* case 3 */
				/*
				 * last block in arena is at end of memory and
				 * is free
				 */
				/* 1.7 had this backward without cast */
				nget = nb -
				    ((char *)arenaend - (char *)lastblk);
				nget = (nget + (BLOCKSZ - 1)) /
				    BLOCKSZ * BLOCKSZ;
				assert(((int)newblk % ALIGNSZ) == 0);
				if (morecore(nget) == (void *)-1)
					return (NULL);
				/* combine with last block, put in arena */
				newend = (struct header *)
				    ((char *)arenaend + nget);
				arenaend = lastblk->nextblk = newend;
				newend->nextblk = SETBUSY(&(arena[1]));
				/* set which block to use */
				blk = lastblk;
				DELFREEQ(blk);
			}
		} else {
			struct header *nblk;	/* next block */

			/* take block found of free queue */
			DELFREEQ(blk);
			/*
			 * make head of free queue immediately follow blk,
			 * unless blk was at the end of the queue
			 */
			nblk = blk->nextfree;
			if (nblk != &(freeptr[1])) {
				MOVEHEAD(nblk);
			}
		}
		/* blk now points to an adequate block */
		if (((char *)blk->nextblk - (char *)blk) - nb >= MINBLKSZ) {
			/* carve out the right size block */
			/* newblk will be the remainder */
			newblk = (struct header *)((char *)blk + nb);
			newblk->nextblk = blk->nextblk;
			/* mark the block busy */
			blk->nextblk = SETBUSY(newblk);
			ADDFREEQ(newblk);
			/* if blk was lastblk, make newblk lastblk */
			if (blk == lastblk)
				lastblk = newblk;
		} else {
			/* just mark the block busy */
			blk->nextblk = SETBUSY(blk->nextblk);
		}
	}
	CHECKQ;
	assert((char *)CLRALL(blk->nextblk) -
	    ((char *)blk + minhead) >= nbytes);
	assert((char *)CLRALL(blk->nextblk) -
	    ((char *)blk + minhead) < nbytes + MINBLKSZ);
	return ((char *)blk + minhead);
}

/*
 * free(ptr) - free block that user thinks starts at ptr
 *
 *	input - ptr-1 contains the block header.
 *		If the header points forward, we have a normal
 *			block pointing to the next block
 *		if the header points backward, we have a small
 *			block from a holding block.
 *		In both cases, the busy bit must be set
 */

void
free(void *ptr)
{
	mutex_lock(&mlock);
	free_unlocked(ptr);
	mutex_unlock(&mlock);
}

/*
 * free_unlocked(ptr) - Do the real work for free()
 */

void
free_unlocked(void *ptr)
{
	struct holdblk *holdblk;	/* block holding blk */
	struct holdblk *oldhead;	/* former head of the hold block */
					/* queue containing blk's holder */

	if (ptr == NULL)
		return;
	if (TESTSMAL(((struct header *)((char *)ptr - MINHEAD))->nextblk)) {
		struct lblk	*lblk;	/* pointer to freed block */
		ssize_t		offset;	/* choice of header lists */

		lblk = (struct lblk *)CLRBUSY((char *)ptr - MINHEAD);
		assert((struct header *)lblk < arenaend);
		assert((struct header *)lblk > arena);
		/* allow twits (e.g. awk) to free a block twice */
		holdblk = lblk->header.holder;
		if (!TESTBUSY(holdblk))
			return;
		holdblk = (struct holdblk *)CLRALL(holdblk);
		/* put lblk on its hold block's free list */
		lblk->header.nextfree = SETSMAL(holdblk->lfreeq);
		holdblk->lfreeq = lblk;
		/* move holdblk to head of queue, if its not already there */
		offset = holdblk->blksz / grain;
		oldhead = holdhead[offset];
		if (oldhead != holdblk) {
			/* first take out of current spot */
			holdhead[offset] = holdblk;
			holdblk->nexthblk->prevhblk = holdblk->prevhblk;
			holdblk->prevhblk->nexthblk = holdblk->nexthblk;
			/* now add at front */
			holdblk->nexthblk = oldhead;
			holdblk->prevhblk = oldhead->prevhblk;
			oldhead->prevhblk = holdblk;
			holdblk->prevhblk->nexthblk = holdblk;
		}
	} else {
		struct header *blk;	/* real start of block */
		struct header *next;	/* next = blk->nextblk */
		struct header *nextnext;	/* block after next */

		blk = (struct header *)((char *)ptr - minhead);
		next = blk->nextblk;
		/* take care of twits (e.g. awk) who return blocks twice */
		if (!TESTBUSY(next))
			return;
		blk->nextblk = next = CLRBUSY(next);
		ADDFREEQ(blk);
		/* see if we can compact */
		if (!TESTBUSY(nextnext = next->nextblk)) {
			do {
				DELFREEQ(next);
				next = nextnext;
			} while (!TESTBUSY(nextnext = next->nextblk));
			if (next == arenaend) lastblk = blk;
			blk->nextblk = next;
		}
	}
	CHECKQ
}


/*
 * realloc(ptr, size) - give the user a block of size "size", with
 *			    the contents pointed to by ptr.  Free ptr.
 */

void *
realloc(void *ptr, size_t size)
{
	void	*retval;

	mutex_lock(&mlock);
	retval = realloc_unlocked(ptr, size);
	mutex_unlock(&mlock);
	return (retval);
}


/*
 * realloc_unlocked(ptr) - Do the real work for realloc()
 */

static void *
realloc_unlocked(void *ptr, size_t size)
{
	struct header *blk;	/* block ptr is contained in */
	size_t trusize;	/* block size as allocater sees it */
	char *newptr;			/* pointer to user's new block */
	size_t cpysize;	/* amount to copy */
	struct header *next;	/* block after blk */

	if (ptr == NULL)
		return (malloc_unlocked(size));

	if (size == 0) {
		free_unlocked(ptr);
		return (NULL);
	}

	if (TESTSMAL(((struct lblk *)((char *)ptr - MINHEAD))->
	    header.holder)) {
		/*
		 * we have a special small block which can't be expanded
		 *
		 * This makes the assumption that even if the user is
		 * reallocating a free block, malloc doesn't alter the contents
		 * of small blocks
		 */
		newptr = malloc_unlocked(size);
		if (newptr == NULL)
			return (NULL);
		/* this isn't to save time--its to protect the twits */
		if ((char *)ptr != newptr) {
			struct lblk *lblk;
			lblk = (struct lblk *)((char *)ptr - MINHEAD);
			cpysize = ((struct holdblk *)
			    CLRALL(lblk->header.holder))->blksz;
			cpysize = (size > cpysize) ? cpysize : size;
			(void) memcpy(newptr, ptr, cpysize);
			free_unlocked(ptr);
		}
	} else {
		blk = (struct header *)((char *)ptr - minhead);
		next = blk->nextblk;
		/*
		 * deal with twits who reallocate free blocks
		 *
		 * if they haven't reset minblk via getopt, that's
		 * their problem
		 */
		if (!TESTBUSY(next)) {
			DELFREEQ(blk);
			blk->nextblk = SETBUSY(next);
		}
		next = CLRBUSY(next);
		/* make blk as big as possible */
		if (!TESTBUSY(next->nextblk)) {
			do {
				DELFREEQ(next);
				next = next->nextblk;
			} while (!TESTBUSY(next->nextblk));
			blk->nextblk = SETBUSY(next);
			if (next >= arenaend) lastblk = blk;
		}
		/* get size we really need */
		trusize = size+minhead;
		trusize = (trusize + ALIGNSZ - 1)/ALIGNSZ*ALIGNSZ;
		trusize = (trusize >= MINBLKSZ) ? trusize : MINBLKSZ;
		/* see if we have enough */
		/* this isn't really the copy size, but I need a register */
		cpysize = (char *)next - (char *)blk;
		if (cpysize >= trusize) {
			/* carve out the size we need */
			struct header *newblk;	/* remainder */

			if (cpysize - trusize >= MINBLKSZ) {
				/*
				 * carve out the right size block
				 * newblk will be the remainder
				 */
				newblk = (struct header *)((char *)blk +
				    trusize);
				newblk->nextblk = next;
				blk->nextblk = SETBUSY(newblk);
				/* at this point, next is invalid */
				ADDFREEQ(newblk);
				/* if blk was lastblk, make newblk lastblk */
				if (blk == lastblk)
					lastblk = newblk;
			}
			newptr = ptr;
		} else {
			/* bite the bullet, and call malloc */
			cpysize = (size > cpysize) ? cpysize : size;
			newptr = malloc_unlocked(size);
			if (newptr == NULL)
				return (NULL);
			(void) memcpy(newptr, ptr, cpysize);
			free_unlocked(ptr);
		}
	}
	return (newptr);
}


/* LINTLIBRARY */
/*
 * calloc - allocate and clear memory block
 */

void *
calloc(size_t num, size_t size)
{
	char *mp;

	num *= size;
	mp = malloc(num);
	if (mp == NULL)
		return (NULL);
	(void) memset(mp, 0, num);
	return (mp);
}


/*
 * Mallopt - set options for allocation
 *
 *	Mallopt provides for control over the allocation algorithm.
 *	The cmds available are:
 *
 *	M_MXFAST Set maxfast to value.  Maxfast is the size of the
 *		 largest small, quickly allocated block.  Maxfast
 *		 may be set to 0 to disable fast allocation entirely.
 *
 *	M_NLBLKS Set numlblks to value.  Numlblks is the number of
 *		 small blocks per holding block.  Value must be
 *		 greater than 0.
 *
 *	M_GRAIN  Set grain to value.  The sizes of all blocks
 *		 smaller than maxfast are considered to be rounded
 *		 up to the nearest multiple of grain. The default
 *		 value of grain is the smallest number of bytes
 *		 which will allow alignment of any data type.    Grain
 *		 will be rounded up to a multiple of its default,
 *		 and maxsize will be rounded up to a multiple of
 *		 grain.  Value must be greater than 0.
 *
 *	M_KEEP   Retain data in freed block until the next malloc,
 *		 realloc, or calloc.  Value is ignored.
 *		 This option is provided only for compatibility with
 *		 the old version of malloc, and is not recommended.
 *
 *	returns - 0, upon successful completion
 *		 1, if malloc has previously been called or
 *		    if value or cmd have illegal values
 */

int
_mallopt(int cmd, int value)
{
	/* disallow changes once a small block is allocated */
	mutex_lock(&mlock);
	if (change) {
		mutex_unlock(&mlock);
		return (1);
	}
	switch (cmd) {
	case M_MXFAST:
		if (value < 0) {
			mutex_unlock(&mlock);
			return (1);
		}
		fastct = (value + grain - 1) / grain;
		maxfast = grain*fastct;
		break;
	case M_NLBLKS:
		if (value <= 1) {
			mutex_unlock(&mlock);
			return (1);
		}
		numlblks = value;
		break;
	case M_GRAIN:
		if (value <= 0) {
			mutex_unlock(&mlock);
			return (1);
		}

		/* round grain up to a multiple of ALIGNSZ */
		grain = (value + ALIGNSZ - 1)/ALIGNSZ*ALIGNSZ;

		/* reduce fastct appropriately */
		fastct = (maxfast + grain - 1) / grain;
		maxfast = grain * fastct;
		break;
	case M_KEEP:
		if (change && holdhead != NULL) {
			mutex_unlock(&mlock);
			return (1);
		}
		minhead = HEADSZ;
		break;
	default:
		mutex_unlock(&mlock);
		return (1);
	}
	mutex_unlock(&mlock);
	return (0);
}

/*
 * mallinfo-provide information about space usage
 *
 *	input - max; mallinfo will return the size of the
 *		largest block < max.
 *
 *	output - a structure containing a description of
 *		 of space usage, defined in malloc.h
 */

struct mallinfo
_mallinfo(void)
{
	struct header *blk, *next;	/* ptr to ordinary blocks */
	struct holdblk *hblk;		/* ptr to holding blocks */
	struct mallinfo inf;		/* return value */
	int	i;			/* the ubiquitous counter */
	ssize_t size;			/* size of a block */
	ssize_t fsp;			/* free space in 1 hold block */

	mutex_lock(&mlock);
	(void) memset(&inf, 0, sizeof (struct mallinfo));
	if (freeptr[0].nextfree == GROUND) {
		mutex_unlock(&mlock);
		return (inf);
	}
	blk = CLRBUSY(arena[1].nextblk);
	/* return total space used */
	inf.arena = (char *)arenaend - (char *)blk;

	/*
	 * loop through arena, counting # of blocks, and
	 * and space used by blocks
	 */
	next = CLRBUSY(blk->nextblk);
	while (next != &(arena[1])) {
		inf.ordblks++;
		size = (char *)next - (char *)blk;
		if (TESTBUSY(blk->nextblk)) {
			inf.uordblks += size;
			inf.keepcost += HEADSZ-MINHEAD;
		} else {
			inf.fordblks += size;
		}
		blk = next;
		next = CLRBUSY(blk->nextblk);
	}

	/*
	 * if any holding block have been allocated
	 * then examine space in holding blks
	 */
	if (change && holdhead != NULL) {
		for (i = fastct; i > 0; i--) {	/* loop thru ea. chain */
			hblk = holdhead[i];
			/* do only if chain not empty */
			if (hblk != HGROUND) {
				size = hblk->blksz +
				    sizeof (struct lblk) - sizeof (int);
				do {	/* loop thru 1 hold blk chain */
					inf.hblks++;
					fsp = freespace(hblk);
					inf.fsmblks += fsp;
					inf.usmblks += numlblks*size - fsp;
					inf.smblks += numlblks;
					hblk = hblk->nexthblk;
				} while (hblk != holdhead[i]);
			}
		}
	}
	inf.hblkhd = (inf.smblks / numlblks) * sizeof (struct holdblk);
	/* holding block were counted in ordblks, so subtract off */
	inf.ordblks -= inf.hblks;
	inf.uordblks -= inf.hblkhd + inf.usmblks + inf.fsmblks;
	inf.keepcost -= inf.hblks*(HEADSZ - MINHEAD);
	mutex_unlock(&mlock);
	return (inf);
}


/*
 * freespace - calc. how much space is used in the free
 *		    small blocks in a given holding block
 *
 *	input - hblk = given holding block
 *
 *	returns space used in free small blocks of hblk
 */

static ssize_t
freespace(struct holdblk *holdblk)
{
	struct lblk *lblk;
	ssize_t space = 0;
	ssize_t size;
	struct lblk *unused;

	lblk = CLRSMAL(holdblk->lfreeq);
	size = holdblk->blksz + sizeof (struct lblk) - sizeof (int);
	unused = CLRSMAL(holdblk->unused);
	/* follow free chain */
	while ((lblk != LGROUND) && (lblk != unused)) {
		space += size;
		lblk = CLRSMAL(lblk->header.nextfree);
	}
	space += ((char *)holdblk + HOLDSZ(size)) - (char *)unused;
	return (space);
}

static void *
morecore(size_t bytes)
{
	void * ret;

	if (bytes > LONG_MAX) {
		intptr_t wad;
		/*
		 * The request size is too big. We need to do this in
		 * chunks. Sbrk only takes an int for an arg.
		 */
		if (bytes == ULONG_MAX)
			return ((void *)-1);

		ret = sbrk(0);
		wad = LONG_MAX;
		while (wad > 0) {
			if (sbrk(wad) == (void *)-1) {
				if (ret != sbrk(0))
					(void) sbrk(-LONG_MAX);
				return ((void *)-1);
			}
			bytes -= LONG_MAX;
			wad = bytes;
		}
	} else
		ret = sbrk(bytes);

	return (ret);
}

#ifdef debug
int
check_arena(void)
{
	unsigned bsize;
	struct header *blk, *prev, *next;	/* ptr to ordinary blocks */

	(void) mutex_lock(&mlock);
	if (freeptr[0].nextfree == GROUND) {
		(void) mutex_unlock(&mlock);
		return (-1);
	}
	blk = arena + 1;

	/* loop through arena, checking */
	blk = (struct header *)CLRALL(blk->nextblk);
	next = (struct header *)CLRALL(blk->nextblk);
	while (next != arena + 1) {
		assert(blk >= arena + 1);
		assert(blk <= lastblk);
		assert(next >= blk + 1);
		assert(((unsigned)((struct header *)blk->nextblk) &
		    (4 | SMAL)) == 0);

		if (TESTBUSY(blk->nextblk) == 0) {
			assert(blk->nextfree >= freeptr);
			assert(blk->prevfree >= freeptr);
			assert(blk->nextfree <= lastblk);
			assert(blk->prevfree <= lastblk);
			assert(((unsigned)((struct header *)blk->nextfree) &
			    7) == 0);
			assert(((unsigned)((struct header *)blk->prevfree) &
			    7) == 0 || blk->prevfree == freeptr);
		}
		blk = next;
		next = CLRBUSY(blk->nextblk);
	}
	(void) mutex_unlock(&mlock);
	return (0);
}

#define	RSTALLOC	1
#endif

#ifdef RSTALLOC
/*
 * rstalloc - reset alloc routines
 *
 *	description -	return allocated memory and reset
 *			allocation pointers.
 *
 *	Warning - This is for debugging purposes only.
 *		  It will return all memory allocated after
 *		  the first call to malloc, even if some
 *		  of it was fetched by a user's sbrk().
 */

void
rstalloc(void)
{
	(void) mutex_lock(&mlock);
	minhead = MINHEAD;
	grain = ALIGNSZ;
	numlblks = NUMLBLKS;
	fastct = FASTCT;
	maxfast = MAXFAST;
	change = 0;
	if (freeptr[0].nextfree == GROUND) {
		(void) mutex_unlock(&mlock);
		return;
	}
	brk(CLRBUSY(arena[1].nextblk));
	freeptr[0].nextfree = GROUND;
#ifdef debug
	case1count = 0;
#endif
	(void) mutex_unlock(&mlock);
}
#endif	/* RSTALLOC */

/*
 * cfree is an undocumented, obsolete function
 */

/* ARGSUSED */
void
_cfree(char *p, unsigned num, unsigned size)
{
	free(p);
}
