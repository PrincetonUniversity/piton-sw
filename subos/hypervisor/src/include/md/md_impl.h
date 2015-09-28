/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: md_impl.h
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
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _MD_MD_IMPL_H
#define	_MD_MD_IMPL_H

#pragma ident	"@(#)md_impl.h	1.5	06/10/26 SMI"

#ifdef __cplusplus
extern "C" {
#endif

	/*
	 * Each logical domain is detailed via a (Virtual) Machine Description
	 * available to each guest Operating System courtesy of a
	 * Hypervisor service.
	 *
	 * A complete Machine Description (MD) is built from a very
	 * simple list of descriptor table (DT) elements.
	 *
	 */


#define	MD_TRANSPORT_VERSION	0x10000 /* the version this library generates */

#define	MD_ILLEGAL_NODEIDX	(-1)

#define	DT_LIST_END	0x0
#define	DT_NULL		' '
#define	DT_NODE		'N'
#define	DT_NODE_END	'E'
#define	DT_PROP_ARC	'a'
#define	DT_PROP_VAL	'v'
#define	DT_PROP_STR	's'
#define	DT_PROP_DAT	'd'
#define	MDET_NULL	DT_NULL
#define	MDET_NODE	DT_NODE
#define	MDET_NODE_END	DT_NODE_END
#define	MDET_PROP_ARC	DT_PROP_ARC
#define	MDET_PROP_VAL	DT_PROP_VAL
#define	MDET_PROP_STR	DT_PROP_STR
#define	MDET_PROP_DAT	DT_PROP_DAT
#define	MDET_LIST_END	DT_LIST_END

#ifndef _ASM

typedef struct md_header md_hdr_t;
typedef struct md_header md_header_t;
	/* FIXME: dtnode_t to be renamed as md_element_t */
typedef struct md_element dtnode_t;
typedef struct md_element md_element_t;

/*
 * Each MD has the following header to
 * provide information about each section of the MD.
 *
 * The header fields are actually written in network
 * byte order.
 */

struct md_header {
	uint32_t	transport_version;
	uint32_t	node_blk_sz;	/* size in bytes of the node block */
	uint32_t	name_blk_sz;	/* size in bytes of the name block */
	uint32_t	data_blk_sz;	/* size in bytes of the data block */
};

/*
 * This is the handle that represents the description
 *
 * While we are building the nodes the data and name tags in the nodes
 * are in fact indexes into the table arrays.
 *
 * When we 'end nodes' the dtheader is added, and the data rewritten
 * into the binary form.
 *
 */
struct dthandle {
	char		**nametable;
	uint8_t		**datatable;
	int		namesize;
	int		datasize;
	int		nodesize;
	int		nameidx;
	int		dataidx;
	int		namebytes;
	int		databytes;
	int		nodeentries;
	int		preload;
	struct dtnode 	*root;
	int 		lastnode;
};
typedef struct dthandle dthandle_t;

/*
 * With this model there are 3 sections
 * the description, the name table and the data blocks.
 * the name and data entries are offsets from the
 * base of their blocks, this makes it possible to extend the segments.
 *
 * For 'node' tags, the data is the index to the next node, not a data
 * offset.
 *
 * All values are stored in network byte order.
 * The namelen field holds the storage length of a ASCIIZ name, NOT the strlen.
 */

struct md_element {
	uint8_t 	tag;
	uint8_t		namelen;
	uint32_t	name;
	union {
		struct	{
			uint32_t	len;
			uint32_t	offset;
		} prop_data;		/* for PROP_DATA and PROP_STR */
		uint64_t prop_val;	/* for PROP_VAL */
		uint64_t prop_idx;	/* for PROP_ARC and NODE */
	} d;
};



typedef struct {
	md_header_t	hdr;
	md_element_t	elem[];
} bin_md_t;

#define	MD_ELEMENT_SIZE	16

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _MD_MD_IMPL_H */
