/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mdsup.c
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
 */

#pragma ident	"@(#)mdsup.c	1.14	07/07/18 SMI"

/*
 * Support functions for MD scanning
 */
#include <sys/htypes.h>
#include <vdev_intr.h>
#include <support.h>
#include <hvctl.h>
#include <config.h>
#include <md.h>

#define	HDN(_name)	{	\
	(((uint64_t)&config.hdnametable.hdname_##_name) -	\
		((uint64_t)&config.hdnametable)), #_name	\
	}

#define	HDN_X(_names, _offsetx)	{	\
	(((uint64_t)&config.hdnametable.hdname_##_offsetx) -	\
		((uint64_t)&config.hdnametable)),	\
	_names	\
	}

struct {
	uint64_t	offset;
	char		*strp;
} inittable[] = {
	HDN(root),
	HDN(fwd),
	HDN(back),
	HDN(id),
	HDN(hvuart),
	HDN(guest),
	HDN(guests),
	HDN(cpu),
	HDN(cpus),
#ifdef CONFIG_CRYPTO
	HDN(mau),
	HDN(maus),
	HDN(cwq),
	HDN(cwqs),
#endif
	HDN(pid),
	HDN(vid),
	HDN(strandid),
	HDN(uartbase),
	HDN(rombase),
	HDN(romsize),
#ifdef CONFIG_DISK
	HDN(diskpa),
#endif
#ifdef T1_FPGA_SNET
	HDN(snet),
	HDN(snet_ino),
	HDN(snet_pa),
#endif
	HDN(membase),
	HDN(memsize),
	HDN(memoffset),
	HDN(realbase),
	HDN(base),
	HDN(size),
	HDN(ino),
	HDN(xid),
	HDN(sid),
	HDN(memory),
	HDN(mblock),
	HDN(hypervisor),
	HDN(vpcidevice),
	HDN(cfghandle),
	HDN(ign),
	HDN(cfgbase),
	HDN(iobase),
	HDN(pciregs),
	HDN(tod),
	HDN(devices),
	HDN(device),
	HDN(services),
	HDN(service),
	HDN(flags),
	HDN(mtu),
	HDN(link),
	HDN(perfctraccess),
	HDN(diagpriv),
	HDN(rngctlaccessible),
	HDN(perfctrhtaccess),
	HDN(debugprintflags),
	HDN(memscrubmax),
	HDN(ldc_endpoints),
	HDN(sp_ldc_endpoints),
	HDN(ldc_endpoint),
	HDN(channel),
	HDN(target_type),
	HDN(target_guest),
	HDN(target_channel),
	HDN(svc_id),
	HDN(svc_arg),
	HDN(svc_vino),
	HDN(private_svc),
	HDN(ldc_mapinrabase),
	HDN(ldc_mapinsize),
#ifdef CONFIG_SPLIT_SRAM /* { */
	HDN(sram_ptrs),
	HDN(inq_offset),
	HDN(inq_data_offset),
	HDN(inq_num_pkts),
	HDN(outq_offset),
	HDN(outq_data_offset),
	HDN(outq_num_pkts),
#endif	/* } */
	HDN(virtual_devices),
	HDN(channel_devices),
#ifdef	CONFIG_PCIE /* { */
	HDN(pcie_bus),
	HDN(allow_bypass),
#endif /* } */
#ifdef STANDALONE_NET_DEVICES
	HDN(network_device),
#endif
	HDN(resource_id),
	HDN(idx),
	HDN(unbind),
	HDN(mdpa),
	HDN(consoles),
	HDN(console),
	HDN(sys_hwtw_mode),
#ifdef CONFIG_CLEANSER
	HDN(l2scrub_interval),
	HDN(l2scrub_entries),
#endif
	HDN_X("virtualdevices", vdevs),
	HDN_X("partid", parttag),
	HDN_X("tod-frequency", todfrequency),
	HDN_X("tod-offset", todoffset),
	HDN_X("stick-frequency", stickfrequency),
	HDN_X("ce-blackout-sec", ceblackoutsec),
	HDN_X("ce-poll-sec", cepollsec),
	HDN_X("erpt-pa", erpt_pa),
	HDN_X("erpt-size", erpt_size),
	HDN_X("reset-reason", reset_reason),
	HDN_X("tx-ino", tx_ino),
	HDN_X("rx-ino", rx_ino),
	HDN_X("content-version", content_version),
#ifdef PLX_ERRATUM_LINK_HACK
	HDN_X("ignore-plx-link-hack", ignore_plx_link_hack),
#endif
	{ 0, 0 }
};


void
reloc_hvmd_names()
{
	int64_t		namereloc;
	int		i;

	/* -KPIC doesnt relocate preinitialized structure pointers */
	namereloc = (-config.reloc);

	for (i = 0; inittable[i].strp != NULL; i++) {
		inittable[i].strp += namereloc;
	}
}


hvctl_status_t
preparse_hvmd(bin_md_t *mdp)
{
	uint64_t	basep;
	int		i;

	config.parse_hvmd = mdp;	/* stash it */

	if (TR_MAJOR(ntoh32(mdp->hdr.transport_version)) !=
	    TR_MAJOR(MD_TRANSPORT_VERSION)) {
		DBG(c_printf("Hypervisor MD major version mismatch\n"));
		return (HVctl_st_badmd);
	}

	basep = (uint64_t)&config.hdnametable;
	for (i = 0; inittable[i].strp != NULL; i++) {
		uint64_t tag;
		tag = md_find_name_tag(mdp, inittable[i].strp);
		*((uint64_t *)(basep + inittable[i].offset)) = tag;
	}

	return (HVctl_st_ok);
}


/*
 * The HVMD update process is effectively double buffered we check the
 * new one first, if there are any problems we fail it without making the
 * configuration change which means we can roll back to the currently active
 * HVMD on a (re)config failure and it is as if nothing ever happened.
 */
void
accept_hvmd()
{
	config.active_hvmd = config.parse_hvmd;
}


/*
 * Primitive scan to look for a matching string.
 * If not found, then we return -1
 */
uint64_t
md_find_name_tag(bin_md_t *mdp, char *namep)
{
	char	*str_tablep;
	int	start_idx;
	int	size;

	/* Find the address of the string table */
	str_tablep = (char *)(((uint64_t)&(mdp->elem[0])) +
	    ntoh32(mdp->hdr.node_blk_sz));

	size = ntoh32(mdp->hdr.name_blk_sz);

	/*
	 * Dumb linear scan looking for the string in the
	 * string table.
	 */
	for (start_idx = 0; start_idx < size; ) {
		int	i;
		char	*str_basep;

		str_basep = str_tablep + start_idx;

		/* Brute force match current and test string */
		for (i = 0; ; i++) {
			int ch1, ch2;

			ch1 = namep[i];
			ch2 = str_basep[i];

			if (ch1 != ch2) goto miss;
			if (ch1 == '\0') {
				/* Match */
				return ((((uint64_t)i)<<48) |
				    ((uint64_t)start_idx));
			}
		}
miss:;
		while (str_basep[i] != '\0') i++;
		start_idx += i+1;	/* start of next string */
	}

	return ((uint64_t)-1);
}


md_element_t *
md_find_node(bin_md_t *mdp, md_element_t *startp, uint64_t token)
{
	int		size;
	md_element_t	*elemp;
	md_element_t	*limp;
	int	namelen = (token>>48) & 0xff;
	int	nameoff = (token & 0xffffffff);

	size = mdp->hdr.node_blk_sz / MD_ELEMENT_SIZE;

	elemp = (startp == NULL) ? &(mdp->elem[0]) : startp;
	limp = &(mdp->elem[size]);

	do {
		switch (elemp->tag) {
		int idx;
		case MDET_LIST_END:	goto done;
		case MDET_NODE:
			if (ntoh32(elemp->name) == nameoff &&
			    ntoh8(elemp->namelen) == namelen) {
				return (elemp);
			}
			idx = ntoh32(elemp->d.prop_idx);	/* next node */
			elemp = &(mdp->elem[idx]);
			break;
		case MDET_NULL:
			elemp ++;	/* skip to next element */
			break;
		default:
			DBG(c_printf(
			    "Encountered elem type 0x%x in node search\n",
			    elemp->tag));
			return (NULL);
		}
	} while (elemp >= mdp->elem && elemp < limp);

done:;
	return (NULL);
}


/*
 * From a given element in a node, look for and follow an arc of the
 * given token, check if the arc points to a node of the given
 * token ... return both the arc pointer and the node pointed to if
 * there is a match ... else return null.
 */
md_element_t	*
md_find_node_by_arc(bin_md_t *mdp, md_element_t *elemp,
	uint64_t arc_token, uint64_t node_token, md_element_t **nodep)
{

	if (elemp == NULL)
		return (NULL);

again:
	elemp = md_next_node_elem(mdp, elemp, arc_token);
	if (elemp != NULL) {
		md_element_t	*mdep;
		uint64_t	*rawp;

		mdep = &mdp->elem[ntoh64(elemp->d.prop_idx)];
		rawp = (uint64_t *)mdep;

		if (*rawp != node_token)
				goto again;

		*nodep = mdep;
		return (elemp);
	}
	return (NULL);
}


int
md_node_get_val(bin_md_t *mdp, md_element_t *nodep,
	uint64_t name_token, uint64_t *valp)
{
	md_element_t *elemp;
	uint64_t	token;

	token = MDVAL(name_token);

	elemp = md_next_node_elem(mdp, nodep, token);
	if (elemp != NULL) {
		*valp = ntoh64(elemp->d.prop_val);
		return (1);
	}
	return (0);
}

md_element_t *
md_next_node_elem(bin_md_t *mdp, md_element_t *mdep, uint64_t token)
{
	while (mdep->tag != MDET_LIST_END && mdep->tag != MDET_NODE_END) {
		uint64_t	*rawp;

		mdep++;
		rawp = (uint64_t *)mdep;

		if (*rawp == token)
			return (mdep);
	}

	return (NULL);
}


void
md_dump_node(bin_md_t *mdp, md_element_t *mdep)
{
#ifdef DEBUG
	char	*strp;
	uint8_t	*datap;

	strp = (char *)&(mdp->elem[0]);
	strp += mdp->hdr.node_blk_sz;
	datap = (uint8_t *)(strp + mdp->hdr.name_blk_sz);

	do {
		switch (mdep->tag) {
		case MDET_NULL:	break;
		case MDET_NODE:
			c_printf("node %s node_0x%x {\n",
			    strp + mdep->name,
			    mdep - mdp->elem);
			break;
		case MDET_NODE_END:
			c_printf("}\n");
			return;
		case MDET_LIST_END:
			c_printf("}\nENDOFMD\n");
			return;
		case MDET_PROP_ARC:
			c_printf("\t%s -> node_0x%x ;\n",
			    strp + mdep->name,
			    mdep->d.prop_idx);
			break;
		case MDET_PROP_VAL:
			c_printf("\t%s = 0x%x ;\n",
			    strp + mdep->name,
			    mdep->d.prop_val);
			break;
		case MDET_PROP_STR:
			c_printf("\t%s = 0x%x ;\n",
			    strp + mdep->name,
			    datap + mdep->d.prop_data.offset);
			break;
		case MDET_PROP_DAT:
			c_printf("\t%s = { ... } /* len = 0x%x */ ;\n",
			    strp + mdep->name,
			    datap + mdep->d.prop_data.len);
			break;
		default:
			c_printf("\tillegal MD tag 0x%x at elem index 0x%x\n",
			    mdep->tag,
			    mdep - mdp->elem);
		}
		mdep ++;
	} while (1);
#endif
}
