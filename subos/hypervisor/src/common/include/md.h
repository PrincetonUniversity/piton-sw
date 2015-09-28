/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: md.h
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

#ifndef _MD_H
#define	_MD_H

#pragma ident	"@(#)md.h	1.5	06/12/05 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <md/md_impl.h>

#ifndef _ASM

#define	MDNAME(name)	(config.hdnametable.hdname_##name)

#define	MDARC(_name)	((_name)|(((uint64_t)MDET_PROP_ARC)<<56))
#define	MDVAL(_name)	((_name)|(((uint64_t)MDET_PROP_VAL)<<56))
#define	MDSTR(_name)	((_name)|(((uint64_t)MDET_PROP_STR)<<56))
#define	MDDAT(_name)	((_name)|(((uint64_t)MDET_PROP_DAT)<<56))
#define	MDNODE(_name)	((_name)|(((uint64_t)MDET_NODE)<<56))
#define	MD_UNKNOWN_NAME	(0LL)

#define	TR_MAJOR(x)	(((x)>>16) & 0xffff)
#define	TR_MINOR(x)	((x) & 0xffff)

uint64_t	md_find_name_tag(bin_md_t *mdp, char *namep);

md_element_t	*md_next_node_elem(bin_md_t *mdp, md_element_t *,
			uint64_t token);

md_element_t	*md_find_node(bin_md_t *mdp, md_element_t *startp,
			uint64_t token);

md_element_t	*md_find_node_by_arc(bin_md_t *mdp, md_element_t *elemp,
			uint64_t arc_token, uint64_t node_token,
			md_element_t **nodep);

int		md_node_get_val(bin_md_t *mdp, md_element_t *nodep,
			uint64_t token, uint64_t *valp);

#ifdef DEBUG /* { */
void md_dump_node(bin_md_t *mdp, md_element_t *mdep);
#endif /* } */

void reloc_hvmd_names();
hvctl_status_t	preparse_hvmd(bin_md_t *mdp);
void accept_hvmd();

#endif	/* !_ASM */



#ifdef __cplusplus
}
#endif

#endif /* _MD_H */
