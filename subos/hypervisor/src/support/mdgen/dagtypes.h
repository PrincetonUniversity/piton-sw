/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: dagtypes.h
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
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 *
 */

#ifndef	_DAGTYPES_H
#define	_DAGTYPES_H

#pragma ident	"@(#)dagtypes.h	1.3	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DAG_NODE dag_node_t;
#define	MAX_DATALEN 	256

typedef struct {
	char	*namep;
	enum { PE_none, PE_string, PE_int, PE_arc, PE_noderef, PE_data } utype;

	void	*name_tmp;	/* used for output */

	union {
		char	*strp;	/* string & noderef */
		uint64_t val;
		dag_node_t *dnp;
		struct {
			int len;
			uint8_t buffer[MAX_DATALEN];
		} data;
	} u;

	void	*data_tmp;	/* used for output */
} pair_entry_t;


typedef struct {
	int	num;
	int	space;
	pair_entry_t *listp;
} pair_list_t;


struct DAG_NODE {
	char	*typep;
	char	*namep;
	int	idx;
	int	offset;	/* used when computing node links for output */
	bool_t	is_proto;

	void	*name_tmp;	/* used for output */

	pair_list_t properties;

	dag_node_t *prevp;
	dag_node_t *nextp;
};


	/*
	 * DAG globals
	 */

extern dag_node_t *dag_listp;
extern dag_node_t *dag_list_endp;

	/*
	 * Support functions
	 */

extern void validate_dag(void);
extern dag_node_t *new_dag_node(void);
extern pair_entry_t *add_pair_entry(pair_list_t *plp);
extern pair_entry_t *find_pair_by_name(pair_list_t *plp, char *namep);
extern dag_node_t *find_dag_node_by_type(char *namep);
extern dag_node_t *find_dag_node_by_name(char *namep);
extern dag_node_t *grab_node(char *message);
extern pair_entry_t *grab_prop(char *message, dag_node_t *node);
extern void dump_dag_nodes(FILE *fp);


#ifdef __cplusplus
}
#endif

#endif	/* _DAGTYPES_H */
