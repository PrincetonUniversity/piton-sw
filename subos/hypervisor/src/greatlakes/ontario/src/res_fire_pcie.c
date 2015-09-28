/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_fire_pcie.c
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
 * Copyright 2007 Sun Microsystems, Inc.	 All rights reserved.
 * Use is subject to license terms.
 */

/*
 * (re)-configuration code to handle HV Fire PCI-E resources
 */

#pragma ident	"@(#)res_fire_pcie.c	1.5	07/06/07 SMI"

#include <stdarg.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <traps.h>
#include <cache.h>
#include <mmu.h>
#include <sun4v/asi.h>
#include <sun4v/errs_defs.h>
#include <cpu_errs_defs.h>
#include <cpu_errs.h>
#include <vpci_errs_defs.h>
#include <vdev_intr.h>
#include <ncs.h>
#include <cyclic.h>
#include <support.h>
#include <strand.h>
#include <vcpu.h>
#include <guest.h>
#include <pcie.h>
#include <vdev_ops.h>
#include <fpga.h>
#include <ldc.h>
#include <config.h>
#include <offsets.h>
#include <hvctl.h>
#include <md.h>
#include <abort.h>
#include <hypervisor.h>
#include <proto.h>
#include <fire.h>

#ifdef CONFIG_PCIE

#define	PCIE_LEAF_A	FIRE_LEAF(A)
#define	PCIE_LEAF_B	FIRE_LEAF(B)

#define	MAX_RESETS	10


/*
 * resource processing support
 */
void config_a_guest_pcie_bus(pcie_device_t *pciep);
void unconfig_a_guest_pcie_bus(pcie_device_t *pciep);

void c_fire_leaf_soft_reset(const struct fire_cookie *, int root);

void
reset_platform_pcie_busses(guest_t *guestp, pcie_device_t *pciep)
{
	extern const struct fire_cookie fire_dev[];
	int i;

	for (i = 0; i < NUM_PCIE_BUSSES; i++) {

		DBG(c_printf("pcie 0x%x assigned to guest 0x%x\n",
		    &pciep[i], pciep[i].guestp));

		/* if bus is assigned to this guest, soft reset the bus */
		if (pciep[i].guestp == guestp) {
			DBG(c_printf("Soft Reset PCI leaf 0x%x\n", i));

			/* we dont care if this works really - if it fails */
			/* the bus is likely dead. The reset on guest restart */
			/* will likely set it up to function again ... */
			(void) pcie_bus_reset(i);

			/* regardless of the bus reset we shutdown Fire's */
			/* IOMMU and interrupt logic for this bus */
			c_fire_leaf_soft_reset(
			    (struct fire_cookie *)&fire_dev[i], i);
		}
	}
}


void
fire_map_tte(fire_dev_t *firep, uint64_t idx, uint64_t pa)
{
	uint64_t *ttep;

	ttep = &firep->iotsb[idx];
	*ttep = FIRE_IO_TTE(pa);
}

void
fire_set_eqbase(fire_dev_t *firep, bool_t bypass)
{
	volatile uint64_t *basep;
	uint64_t addr;

	basep = (uint64_t *)(firep->pcie + FIRE_DLC_IMU_EQS_EQ_BASE_ADDRESS);

	if (bypass)
		addr = (uint64_t)firep->msieqbase | MSI_EQ_BASE_BYPASS_ADDR;
	else
		addr = firep->guest_pci_va_limit;

	DBGEQ(c_printf("Setting eq base 0x%x, addr 0x%x\n", basep, addr));

	*basep = addr;

}

void
init_fire_msi_eq(int busnum)
{
	fire_dev_t *firep;
	uint64_t max_virtaddr, base_virtaddr;
	uint64_t offset_tte_idx, nttes;
	int i;

	DBGEQ(c_printf("Initializing MSI EQ mappings for bus 0x%x\n", busnum));

	ASSERT(busnum >= 0 && busnum < NFIRELEAVES);

	firep = (fire_dev_t *)&(fire_dev[busnum]);

	max_virtaddr = FIRE_DVMA_RANGE_MAX - IOMMU_EQ_RESERVE;
	base_virtaddr = FIRE_DVMA_RANGE_MAX - IOMMU_SPACE;

	firep->guest_pci_va_limit = max_virtaddr;

	DBGEQ(c_printf("Basevirtaddr 0x%x, max_virtaddr 0x%x, reserve 0x%x\n",
	    base_virtaddr, max_virtaddr, IOMMU_EQ_RESERVE));

	DBGEQ(c_printf("Guest  idx max 0x%x\n", IOTSB_INDEX_MAX));

	offset_tte_idx = (max_virtaddr - base_virtaddr) >> IOMMU_PAGESHIFT;
	nttes = EQ_MAX_SIZE >> IOMMU_PAGESHIFT;

	DBGEQ(c_printf("Offset idx  0x%x, nttes 0x%x\n",
	    offset_tte_idx, nttes));

	ASSERT((offset_tte_idx + nttes) <= FIRE_IOMMU_SIZE(FIRE_TSB_SIZE));

	for (i = 0; i < nttes; i++) {
		uint64_t pa;

		pa = (uint64_t)firep->msieqbase +
		    ((uint64_t)i << IOMMU_PAGESHIFT);

		fire_map_tte(firep, (uint64_t)(offset_tte_idx + i), pa);
	}
}

void
init_pcie_buses(void)
{
	DBGEQ(c_printf("initializing pcie buses\n"));
	init_fire_msi_eq(PCIE_LEAF_A);
	init_fire_msi_eq(PCIE_LEAF_B);
}

void
plat_config_pcie_bypass(pcie_device_t *pciep)
{
	int id;
	fire_dev_t *firep;

	id = pciep->id;
	firep = (fire_dev_t *)&fire_dev[id];

	fire_config_bypass(firep, pciep->allow_bypass);

	fire_set_eqbase(firep, pciep->allow_bypass);
}

#ifdef CONFIG_IOBYPASS
/*
 * For a guest which is allowed direct access to the I/O bridges (Tomatillo,
 * Fire), this sets up the segments for the I/O physical addresses.
 */
#define	AID_TO_PCIE_LEAF_A_BASE			0x800e000000
#define	AID_TO_PCIE_LEAF_A_LIMIT		0x8010000000
#define	AID_TO_PCIE_LEAF_B_BASE			0xc000000000
#define	AID_TO_PCIE_LEAF_B_LIMIT		0xff00000000

#define	ASSIGN_LEAFA_SEGMENTS(_guestp)	\
		assign_ra2pa_segments(_guestp, AID_TO_PCIE_LEAF_A_BASE, \
		    AID_TO_PCIE_LEAF_A_LIMIT - AID_TO_PCIE_LEAF_A_BASE, \
			0, IO_SEGMENT);

#define	ASSIGN_LEAFB_SEGMENTS(_guestp)	\
		assign_ra2pa_segments(_guestp, AID_TO_PCIE_LEAF_B_BASE, \
		    AID_TO_PCIE_LEAF_B_LIMIT - AID_TO_PCIE_LEAF_B_BASE, \
			0, IO_SEGMENT);

#define	UNASSIGN_LEAFA_SEGMENTS(_guestp)	\
		assign_ra2pa_segments(guestp, AID_TO_PCIE_LEAF_A_BASE, \
		    INVALID_SEGMENT_SIZE, 0, INVALID_SEGMENT);

#define	UNASSIGN_LEAFB_SEGMENTS(_guestp)	\
		assign_ra2pa_segments(guestp, AID_TO_PCIE_LEAF_B_BASE, \
		    INVALID_SEGMENT_SIZE, 0, INVALID_SEGMENT);
#else

#define	FIRE_IOBASE_A				0xe810000000
#define	FIRE_IOLIMIT_A				0xf000000000

#define	FIRE_IOBASE_B				0xf010000000
#define	FIRE_IOLIMIT_B				0xf800000000

#define	FIRE_EBUS_BASE				0xf820000000
#define	FIRE_EBUS_LIMIT				0xf828000000

#define	ASSIGN_LEAFA_SEGMENTS(_guestp)					\
		assign_ra2pa_segments(_guestp, FIRE_IOBASE_A,		\
		    FIRE_IOLIMIT_A - FIRE_IOBASE_A, 0, IO_SEGMENT);	\
		assign_ra2pa_segments(_guestp, FIRE_EBUS_BASE,		\
		    (FIRE_EBUS_LIMIT - FIRE_EBUS_BASE), 0, IO_SEGMENT);

#define	ASSIGN_LEAFB_SEGMENTS(_guestp)					\
		assign_ra2pa_segments(_guestp, FIRE_IOBASE_B,		\
		    FIRE_IOLIMIT_B - FIRE_IOBASE_B, 0, IO_SEGMENT);

#define	UNASSIGN_LEAFA_SEGMENTS(_guestp)				\
		assign_ra2pa_segments(_guestp, FIRE_IOBASE_A, 		\
		    INVALID_SEGMENT_SIZE, 0, INVALID_SEGMENT);		\
		assign_ra2pa_segments(_guestp, FIRE_EBUS_BASE,		\
		    INVALID_SEGMENT_SIZE, 0, INVALID_SEGMENT);

#define	UNASSIGN_LEAFB_SEGMENTS(_guestp)				\
		assign_ra2pa_segments(_guestp, FIRE_IOBASE_B, 		\
		    INVALID_SEGMENT_SIZE, 0, INVALID_SEGMENT);

#endif	/* !CONFIG_IOBYPASS */

void
config_a_guest_pcie_bus(pcie_device_t *pciep)
{
	guest_t *guestp;
	int id, vinobase, x;
	uint8_t devid;

	guestp = pciep->guestp;
	id = pciep->id;

	ASSERT(guestp != NULL);

	devid = (pciep->cfg_handle) >> DEVCFGPA_SHIFT;
	vinobase = pciep->cfg_handle;

	plat_config_pcie_bypass(pciep);

	switch (id) {
		case PCIE_LEAF_A:
			guestp->dev2inst[devid] = DEVOPS_FIRE_A;
			ASSIGN_LEAFA_SEGMENTS(guestp);
			DBG(c_printf("\tNOTICE pcie LEAF 0x%x "	\
			    "configured for guest 0x%x\n", id,
			    guestp->guestid));
			break;
		case PCIE_LEAF_B:
			guestp->dev2inst[devid] = DEVOPS_FIRE_B;
			ASSIGN_LEAFB_SEGMENTS(guestp);
			DBG(c_printf("\tNOTICE pcie LEAF 0x%x "	\
			    "configured for guest 0x%x\n", id,
			    guestp->guestid));
			break;
		default:
			DBG(c_printf("\tWARNING pcie 0x%x not "
			    "supported for guest 0x%x\n", id, guestp->guestid));
			/* should probably panic here */
			break;
	}

	for (x = 0; x < NINOSPERDEV; x++) {
		guestp->vino2inst.vino[vinobase + x] =
		    config_pcie_vinos.vino[id][x];
	}
}

void
unconfig_a_guest_pcie_bus(pcie_device_t *pciep)
{
	guest_t *guestp;
	int id, vinobase, x;
	uint8_t devid;

	guestp = pciep->guestp;
	id = pciep->id;

	ASSERT(guestp != NULL);

	devid = (pciep->cfg_handle) >> DEVCFGPA_SHIFT;
	vinobase = pciep->cfg_handle;

	guestp->dev2inst[devid] = DEVOPS_RESERVED;
	for (x = 0; x < NINOSPERDEV; x++) {
		guestp->vino2inst.vino[vinobase + x] = DEVOPS_RESERVED;
	}

	/*
	 * We clear out the PCI I/O address segments by setting their size
	 * to INVALID_SEGMENT_SIZE and flags to INVALID_SEGMENT.
	 */
	switch (id) {
	case (PCIE_LEAF_A):
		UNASSIGN_LEAFA_SEGMENTS(guestp);
		break;
	case (PCIE_LEAF_B):
		UNASSIGN_LEAFB_SEGMENTS(guestp);
		break;
	default:
		break;
	}
}



#define	CFGWR(_offset, _size, _val)					\
	do {								\
	if (!pci_config_put(firep, (_offset), _size, _val)) {		\
		DBGBR(c_printf("CFGWR fail "#_offset			\
			" ("#_size") <- "#_val"\n"));			\
		return (false);						\
	}								\
	} while (0)

static bool_t plx_8532_aa_reset(int busnum);
static bool_t plx_upstream_port_reset(fire_dev_t *firep);
static bool_t is_plx_downstream_port_ready(fire_dev_t *firep, int port);
static bool_t plx_set_elec_idle(int busnum, int port, bool_t on);
#define	NUM_PLX_PORTS	16
static void plx_port_check(fire_dev_t *firep, int port);
static void config_fire_pcie_bus(int busnum);

static bool_t ontario_southbridge_reset(fire_dev_t *firep);


/*
 * This function does an initial test of the PCI-E links attached to
 * Fire - primarily to determine if we have any PLX 8532 AA switches
 * directly attached ... if so, we need to determine which ports are
 * live so that we can guarantee a re-train in the event of a reset
 */

void
config_platform_pcie()
{
	config_fire_pcie_bus(0);
	config_fire_pcie_bus(1);
}


/*
 * This function examines the specified PCI-E bus on fire, and looks
 * for PLX 8532 AA switches ... and determines which downstream ports on
 * those switches are live.
 */

void
config_fire_pcie_bus(int busnum)
{
	uint64_t	res;
	fire_dev_t	*firep;

	firep = (fire_dev_t *)&fire_dev[busnum];

		/* Becomes true after bus is used, false after it is reset */
	firep->needs_warm_reset = false;
	firep->blacklist = false;

	DBGBR(c_printf("Probing Fire bus %d\n", busnum));

	/*
	 * If the link is down, we don't do anything
	 * since it may mean there is no HW on the bus.
	 */

	/*
	 * Just bail if nothing connected to the bus - Erie ?
	 * We indicate a failure on the bus in this case to ensure
	 * that we mark the bus to be ignored. Even though the link
	 * status is checked on each config write, we try to prevent the
	 * case where a link is down here and comes up later ... without
	 * the bus being properly reset. By returning a failure here we hope
	 * that the HV marks the bus as dead and prevents further
	 * guest accesses.
	 */
	if (!is_fire_port_link_up(firep))
		return;

	/*
	 * If we are dealing with something other than
	 * a PLX or bridge (network card, for example)
	 * we simply toggle the link down and up.
	 * Otherwise we have to do the full secondary
	 * reset technique
	 */

	/*
	 * We look for a bridge under fire.
	 * If the read fails, we have a problem ... abort for now, but
	 * need to handle this as simply the bus being inactive.
	 * We may need a fire reset to resolve this - i.e. power cycle.
	 */

	if (!pci_config_get(firep, UPST_CFG_BASE + CFG_CLASS_CODE, 4, &res)) {
		DBGBR(c_printf("Bridge read failed ... abandoning bus\n"));
		return;
	}

	DBGBR(c_printf("Bridge class code 0x%x\n", res));

	/*
	 * If the device class code indicates there is no bridge, then we
	 * simply stop here since we're not going to be doing a
	 * secondary reset.
	 */

	if ((res>>8) != BRIDGE_CLASS_CODE) {
		DBGBR(c_printf("Not a bridge ..."));
		return;
	}

		/*
		 * We discovered a bridge, but is it a PLX ? indicating
		 * ... if this read fails something bad
		 * has happened given that we already read from the device.
		 * In this case we abandon the bus !
		 */

	if (!pci_config_get(firep, UPST_CFG_BASE + 0, 4, &res)) {
		DBGBR(c_printf("Bridge vendor ID read failed !!\n"));
		return;
	}

	DBGBR(c_printf("1st bridge vendorid = 0x%x\n", res));

	if (res != PLX_8532_DEV_VEND_ID)
		return;

	/*
	 * Scan the downstream ports on the PLX parts to "discover"
	 * which ones are live.
	 */

	firep->live_port = 0;

	switch (busnum) {
	case 0:
		plx_port_check(firep, 1);
		plx_port_check(firep, 8);
		break;
	case 1:
		plx_port_check(firep, 1);
		plx_port_check(firep, 2);
		plx_port_check(firep, 8);
		plx_port_check(firep, 9);
		break;
	}

	DBGBR(c_printf("Done probing bus 0x%x\n", busnum));
}


void
plx_port_check(fire_dev_t *firep, int port)
{
	if (is_plx_downstream_port_ready(firep, port)) {
		DBGBR(c_printf("Leaf %d has port %d\n",
		    firep - (fire_dev_t *)&(fire_dev[0]), port));
		firep->live_port |= 1<<port;
	}
}


bool_t
toggle_fire_link(fire_dev_t *firep)
{
	DBGBR(c_printf("...toggle link\n"));

	if (!fire_link_down(firep))
		return (false);

	c_usleep(500000);

	if (!fire_link_up(firep))
		return (false);

	return (true);
}

/*
 * This function resets a given Fire leaf
 *
 * (It should be based on rsetting a given pci-e resource).
 *
 * Inputs:
 *
 *    bus  - root complex (0 = leaf A, 1 = leaf B)
 *
 * Returns true on success, false on failure.
 * Caller should mark bus unusable after failure.
 */


bool_t
pcie_bus_reset(int busnum)
{
	uint64_t	res, brcode;
	fire_dev_t *firep;

	firep = (fire_dev_t *)&fire_dev[busnum];

		/*
		 * If the bus just came out of a power on cycle
		 * then we don't need to reset it again here.
		 */
	if (!firep->needs_warm_reset) {
		firep->needs_warm_reset = true;
		return (true);
	}

	if (firep->blacklist)
		return (false);

	DBGBR(c_printf("Resetting bus %d (firep=0x%x)\n",
	    busnum, (uint64_t)firep));

	/*
	 * If the link is down, we don't do anything
	 * since it may mean there is no HW on the bus.
	 */

	/*
	 * Just bail if nothing connected to the bus - Erie ?
	 * We indicate a failure on the bus in this case to ensure
	 * that we mark the bus to be ignored. Even though the link
	 * status is checked on each config write, we try to prevent the
	 * case where a link is down here and comes up later ... without
	 * the bus being properly reset. By returning a failure here we hope
	 * that the HV marks the bus as dead and prevents further
	 * guest accesses.
	 */
	if (!is_fire_port_link_up(firep)) {
		goto fail;
	}

	/*
	 * If we are dealing with something other than
	 * a bridge (network card, for example)
	 * we simply toggle the link down and up.
	 * Otherwise we have to do the full secondary
	 * reset technique
	 */

	/*
	 * We look for a bridge under fire.
	 * If the read fails, we have a problem ... abort for now, but
	 * need to handle this as simply the bus being inactive.
	 * We may need a fire reset to resolve this - i.e. power cycle.
	 */

	if (!pci_config_get(firep, UPST_CFG_BASE + CFG_CLASS_CODE,
	    4, &brcode)) {
		DBGBR(c_printf("Bridge read failed ... abandoning bus\n"));
		goto fail;
	}

	DBGBR(c_printf("Bridge class code 0x%x\n", brcode));

	/*
	 * If the device class code indicates there is no bridge, then we
	 * simply reset the link by toggling it
	 */

	if ((brcode >> 8) != BRIDGE_CLASS_CODE) {
		DBGBR(c_printf("Not a bridge ..."));
		goto link_down_up;
	}

	/*
	 * We discovered a bridge, determine if it is a
	 * PLX 8532 also on Ontario we need to reset the south bridge.
	 * If the bridge is a PLX 8532 AA part we do a secondary bus reset.
	 * On other bridges and versions of PLX 8532 we just toggle
	 * the fire link.
	 */

	if (!pci_config_get(firep, UPST_CFG_BASE + 0, 4, &res)) {
		DBGBR(c_printf("Bridge vendor ID read failed !!\n"));
		goto fail;
	}

	DBGBR(c_printf("1st bridge vendorid = 0x%x\n", res));

	switch (res) {

		case PLX_8532_DEV_VEND_ID :

			/*
			 * Reset Southbridge if found.
			 */
			if ((busnum == 1) && firep->live_port & 0x2) {
				DBGBR(c_printf("Southbridge reset\n"));
				if (!ontario_southbridge_reset(firep)) {
					DBGBR(c_printf(
					    "Southbridge reset failed\n"));
					goto fail;
				}
			}

			if ((brcode & 0xff) == 0xaa) {
				/*
				 * Perform secondary reset.
				 */

				if (!plx_8532_aa_reset(busnum)) {
					DBGBR(c_printf(
					    "Failed PLX 8532 AA reset\n"));
					goto fail;
				}
			} else {
				DBGBR(c_printf(
				    "Found 0x%x PLX part toggling fire link.\n",
				    brcode &0xff));
				if (!toggle_fire_link(firep))
					goto fail;
				c_usleep(200000); /* 200ms */
			}
			break;
		default :
			goto link_down_up;
	};

	DBGBR(c_printf("Fire port reset\n"));

	return (true);

link_down_up:
	if (!toggle_fire_link(firep))
		goto fail;

	return (true);
fail:
	firep->blacklist = true;
	DBGBR(c_printf("Fire Leaf  reset FAILED BLACKLISTING\n"));
	return (false);
}


static bool_t
plx_8532_aa_reset(int busnum)
{
	int		reset_count;
	fire_dev_t	*firep;
	int		i;
	uint64_t	res;

	firep = (fire_dev_t *)&fire_dev[busnum];

	/*
	 * We discovered a bridge, but is it a PLX ? indicating
	 * ... if this read fails something bad
	 * has happened given that we already read from the device.
	 * In this case we abandon the bus !
	 */

	DBGBR(c_printf("Resetting with SBR\n"));
	if (!pci_config_get(firep, UPST_CFG_BASE + 0, 4, &res)) {
		DBGBR(c_printf("Bridge vendor ID read failed !!\n"));
		return (false);
	}

	DBGBR(c_printf("1st bridge vendorid = 0x%x\n", res));

	reset_count = 0;

	DBGBR(c_printf("\tdetect elect idle on station 0\n"));
	(void) plx_set_elec_idle(busnum, 0, false);
	DBGBR(c_printf("\tdetect elect idle on station 1\n"));
	(void) plx_set_elec_idle(busnum, 8, false);

reset_again:;

	c_usleep(500000);
	DBGBR(c_printf("Attempting PLX upstream reset for bus %d - try %d\n",
	    busnum, reset_count));

	if (!plx_upstream_port_reset(firep))
		return (false);

		/* wait for everything to settle/retrain */
	c_usleep(1500000);

	for (i = 0; i < NUM_PLX_PORTS; i++) {
		if (((firep->live_port >> i) & 1) == 0)
			continue;

			/* Enter here if port i requires resetting */

		DBGBR(c_printf("Secondary reset for leaf %d port %d\n",
		    busnum, i));

		if (is_plx_downstream_port_ready(firep, i))
			continue;

		/* Failed - we need another upstream reset */

		if (++reset_count < MAX_RESETS)
			goto reset_again;

		/* After max resets we'll blacklist the port instead */
	}

	DBGBR(c_printf("\tdont detect elect idle on station 0\n"));
	(void) plx_set_elec_idle(busnum, 0, true);
	DBGBR(c_printf("\tdont detect elect idle on station 1\n"));
	(void) plx_set_elec_idle(busnum, 8, true);


		/* initialize up stream port */
	CFGWR(UPST_CFG_BASE + CFG_CMD_REG, 2, 0x0);
	CFGWR(UPST_CFG_BASE + CFG_BAR0, 4, 0x0);
	CFGWR(UPST_CFG_BASE + CFG_BAR1, 4, 0x0);
	CFGWR(UPST_CFG_BASE + CFG_PS_BUS, 4, 0x0);
	CFGWR(UPST_CFG_BASE + CFG_IOBASE_LIM, 2, 0xff);
	CFGWR(UPST_CFG_BASE + CFG_MEMBASE, 2, 0xffff);
	CFGWR(UPST_CFG_BASE + CFG_MEMLIM, 2, 0x0);
	CFGWR(UPST_CFG_BASE + CFG_PFBASE, 2, 0xffff);
	CFGWR(UPST_CFG_BASE + CFG_PFLIM, 2, 0x0);
	CFGWR(UPST_CFG_BASE + CFG_PF_UBASE, 4, 0xffffffff);
	CFGWR(UPST_CFG_BASE + CFG_PF_ULIM, 4, 0x0);
	CFGWR(UPST_CFG_BASE + CFG_IO_UBASE, 2, 0xffff);
	CFGWR(UPST_CFG_BASE + CFG_IO_ULIM, 2, 0x0);

		/* Finally clear any accumulated errors */
	CFGWR(UPST_CFG_BASE + CFG_STAT_CTRL, 4, 0x000f0000);

	return (true);
}

static bool_t
plx_upstream_port_reset(fire_dev_t *firep)
{
	uint64_t res;

	DBGBR(c_printf("plx_upstream_port_reset\n"));
		/* If the loads and stores fail - abandon the bus */
	if (!pci_config_get(firep, UPST_CFG_BASE+CFG_SECONDARY_RESET,
	    4, &res)) {
		DBGBR(c_printf("SECONDARY_RESET set, read fail\n"));
		return (false);
	}

	if (!pci_config_put(firep, UPST_CFG_BASE+CFG_SECONDARY_RESET,
	    4, res | (1LL<<22))) {
		DBGBR(c_printf("SECONDARY_RESET set, write fail\n"));
#if 0 /* { FIXME: */
		return (false);
#endif /* } */
	}

	DBGBR(c_printf("\tBus down ... waiting 200ms\n"));

	c_usleep(200000);

	DBGBR(c_printf("\tWakeup bus\n"));

	if (!pci_config_get(firep, UPST_CFG_BASE+CFG_SECONDARY_RESET,
	    4, &res)) {
		DBGBR(c_printf("SECONDARY_RESET clear, read fail\n"));
		return (false);
	}

	DBGBR(c_printf("\tsecondary reset register status 0x%x\n", res));

	if (!pci_config_put(firep, UPST_CFG_BASE+CFG_SECONDARY_RESET,
	    4, res & ~(1LL<<22))) {
		DBGBR(c_printf("SECONDARY_RESET clear, write fail\n"));
		return (false);
	}

	DBGBR(c_printf("\tSecondary reset completed\n"));
	return (true);
}


static bool_t
is_plx_downstream_port_ready(fire_dev_t *firep, int port)
{
	uint64_t port_cfg_base;
	uint64_t res;

	port_cfg_base = DNST_CFG_PORT_BASE(port);

	DBGBR(c_printf("is_plx_downstream_port_ready : port %d\n", port));

		/* setup config access to the downstream port */
	CFGWR(UPST_CFG_BASE + CFG_PS_BUS, 4, UPST_CFG_PS_BUS_VAL);

	DBGBR(c_printf("\tChecking link up ..\n"));

	if (!pci_config_get(firep, port_cfg_base + CFG_VC0_STATUS,
	    4, &res)) {
		DBGBR(c_printf("VC0 status register read failed\n"));
		return (false);
	}

	DBGBR(c_printf("VC0 status = 0x%x\n", res));

	if ((res & CFG_VC0_STATUS_MASK) != 0) {
		DBGBR(c_printf("\n\nPLX link failed to train\n\n\n"));
		return (false);
	}

	return (true);
}


/*
 * On an Ontario, to reset the Southbridge we have to:
 *    - initiate secondary reset
 *    - program bus to allow Southbridge IO access
 *    - reset southbridge device
 *    - initiate secondary reset (again)
 */
static bool_t
ontario_southbridge_reset(fire_dev_t *firep)
{
	uint64_t res;

		/* setup config access */
	CFGWR(UPST_CFG_BASE + CFG_PS_BUS, 4, UPST_CFG_PS_BUS_VAL);

		/* I/O base and Limit : 0 - 1000 */
	CFGWR(UPST_CFG_BASE + CFG_IOBASE_LIM, 2, 0x0100);

		/* IO upper base */
	CFGWR(UPST_CFG_BASE + CFG_IO_UBASE, 4, 0x0);

		/* command register: allow IO access */
	CFGWR(UPST_CFG_BASE + CFG_CMD_REG, 4, 0x5);

		/* config downstream bus for Southbridge IO access  */
	CFGWR(DNST_CFG_BASE + CFG_PS_BUS, 4, DNST_CFG_PS_BUS_VAL);

		/* I/O base and Limit: 0 - 1000 */
	CFGWR(DNST_CFG_BASE + CFG_IOBASE_LIM, 2, 0x0100);

		/* IO upper base */
	CFGWR(DNST_CFG_BASE + CFG_IO_UBASE, 2, 0x0);

		/* command register: allow IO access */
	CFGWR(DNST_CFG_BASE + CFG_CMD_REG, 2, 0x5);

	/*
	 * Let's check and see if we have an Intel PCI-E -> PCI-X
	 * bridge .. if not, then we have no southbridge either
	 */

	if (!pci_config_get(firep, PE2X_CFG_BASE + 0x0, 4, &res)) {
		DBGBR(c_printf("Failed reading second bridge vendor id\n"));
		return (false);
	}

	/*
	 * If no Intel bridge, then we have no Southbridge to reset.
	 */
	if (res != INTEL_BRG_DEV_VEND_ID) {
		DBGBR(c_printf("No Intel bridge - ergo no southbridge\n"));
		return (true);
	}


	/*
	 * Now we do the south bridge clobber
	 */

	/*
	 * config PCIE->PCIX for Southbridge IO access
	 * setup config access
	 */
	CFGWR(PE2X_CFG_BASE + CFG_PS_BUS, 4, PE2X_CFG_PS_BUS_VAL);

	/* I/O base and Limit: 0 - 1000 */
	CFGWR(PE2X_CFG_BASE + CFG_IOBASE_LIM, 2, 0x0100);

	/* IO upper base */
	CFGWR(PE2X_CFG_BASE + CFG_IO_UBASE, 4, 0x0);

	/* command register: allow IO access */
	CFGWR(PE2X_CFG_BASE + CFG_CMD_REG, 2, 0x5);


	/*
	 * Check the vendor ID of the southbridge
	 */

	if (!pci_config_get(firep, SOUTHBRIDGE_CFG_BASE + 0x0, 4, &res)) {
		DBGBR(c_printf("Failed reading southbridge vendor ID\n"));
		return (false);
	}

	if (res != ALI_SB_DEV_VEND_ID) {
		DBGBR(c_printf("Success - no southbridge to reset\n"));
		return (true);
	}

	DBGBR(c_printf("Resetting southbridge NOW !\n"));


	/* Enable IO space access */
	CFGWR(SOUTHBRIDGE_CFG_BASE + SOUTHBRIDGE_CFG_RESET, 1, 1LL<<7);

#define	MB	* (1024LL*1024LL)	/* used by CFG_SIZE! */

	/* Now we do an IO write to the Southbridge */
	if (!pci_io_poke(firep, firep->cfg + CFG_SIZE + SOUTHBRIDGE_IO_RESET,
	    1, SOUTHBRIDGE_RESET_VAL, SOUTHBRIDGE_CFG_BASE)) {
		DBGBR(c_printf("Couldn't poke SB reset\n"));
	}

	/* Cleanup after ourselves */
	CFGWR(PE2X_CFG_BASE + CFG_PS_BUS, 4, 0x0);
	CFGWR(PE2X_CFG_BASE + CFG_IOBASE_LIM, 2, 0xff);
	CFGWR(PE2X_CFG_BASE + CFG_IO_UBASE, 4, 0xffff);
	CFGWR(PE2X_CFG_BASE + CFG_CMD_REG, 2, 0x0);
	CFGWR(DNST_CFG_BASE + CFG_PS_BUS, 4, 0x0);
	CFGWR(DNST_CFG_BASE + CFG_IOBASE_LIM, 2, 0xff);
	CFGWR(DNST_CFG_BASE + CFG_IO_UBASE, 2, 0xffff);
	CFGWR(DNST_CFG_BASE + CFG_CMD_REG, 2, 0x0);
	CFGWR(UPST_CFG_BASE + CFG_IOBASE_LIM, 2, 0xff);
	CFGWR(UPST_CFG_BASE + CFG_IO_UBASE, 4, 0xffff);
	CFGWR(UPST_CFG_BASE + CFG_CMD_REG, 4, 0x0);

	c_usleep(1000000);
	return (true);
}


/*
 * This function only works for PLX 8532 AA parts.
 */

static bool_t
plx_set_elec_idle(int busnum, int port, bool_t post_reset)
{
	uint64_t fire_membase, offset, res;
	uint64_t port_cfg_offset;
	fire_dev_t *firep;

	firep = (fire_dev_t *)&fire_dev[busnum];

	fire_membase = busnum ? FIRE_BAR(0xf200ull) :  FIRE_BAR(0xea00ull);

	offset = port * 4096 + 0x22C; /* electric idle bit offset */

	port_cfg_offset = (port == 0) ? UPST_CFG_BASE :
	    DNST_CFG_PORT_BASE(port);

	DBGBR(c_printf("Fire leaf 0x%x membase 0x%x offset 0x%x = 0x%x\n",
	    busnum, fire_membase, offset, fire_membase +offset));

	CFGWR(UPST_CFG_BASE + CFG_PS_BUS, 4, UPST_CFG_PS_BUS_VAL);
	CFGWR(UPST_CFG_BASE + CFG_CMD_REG, 2, 2);
	CFGWR(UPST_CFG_BASE + CFG_BAR0, 4, 0);
	if (!pci_io_peek(firep, fire_membase + offset, 4, &res)) {
		DBGBR(c_printf("Couldn't peek elec idle\n"));
	}

	DBGBR(c_printf("PHY elec idle reg 0x%x\n", res));

	if (!post_reset) {
		res &= ~0x10LL;
	} else {
		res |= 0x10LL;
	}

	DBGBR(c_printf("PHY elec idle reg after op %d 0x%x\n", post_reset,
	    res));
	if (!pci_io_poke(firep, fire_membase + offset,
	    4, res, port_cfg_offset)) {
		DBGBR(c_printf("Couldn't poke elec idle\n"));
	}

	return (true);
}

#endif
