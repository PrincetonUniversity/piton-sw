/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: res_piu_pcie.c
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


#pragma ident	"@(#)res_piu_pcie.c	1.6	07/06/07 SMI"

#include <stdarg.h>

#include <sys/htypes.h>
#include <hypervisor.h>
#include <traps.h>
#include <sun4v/asi.h>
#include <sun4v/errs_defs.h>
#include <vdev_ops.h>
#include <vdev_intr.h>
#include <config.h>
#include <ncs.h>
#include <mmu.h>
#include <cyclic.h>
#include <vcpu.h>
#include <strand.h>
#include <guest.h>
#include <segments.h>
#include <memory.h>
#include <pcie.h>
#include <support.h>
#include <md.h>
#include <abort.h>
#include <proto.h>
#include <piu.h>
#include <fpga.h>

#ifdef CONFIG_PCIE

#ifdef CONFIG_PIU
extern const struct piu_cookie piu_dev[];
void c_piu_leaf_soft_reset(const struct piu_cookie *, int root);
#endif

void plat_config_pcie_bypass(pcie_device_t *pciep);
static void config_pcie_bypass(guest_t *guestp, int bus_id);
static void setup_bypass_mappings(int bus_id, uint64_t base_pa, uint64_t size);
static void clear_pcie_bypass(int bus_id);

/*
 * (re)-configuration code to handle HV PIU PCI-E resources
 */

#define	MAX_RESETS	10

void
config_platform_pcie()
{
	DBG(c_printf("config_piu()\n"));
}

void
reset_platform_pcie_busses(guest_t *guestp, pcie_device_t *pciep)
{
	extern const struct piu_cookie piu_dev[];
	int	i;

	/* reset attached devices like the PCI busses */
	pciep = config.pcie_busses;
	for (i = 0; i < NUM_PCIE_BUSSES; i++) {

		DBGBR(c_printf("pcie 0x%x assigned to guest 0x%x\n",
		    &pciep[i], pciep[i].guestp));

		/* if bus is assigned to this guest, soft reset the bus */
		if (pciep[i].guestp == guestp) {
			DBGBR(c_printf("Soft Reset PCI leaf 0x%x cookie 0x%x\n",
			    i, piu_dev[i].pcie));

#if 0
			/*
			 * we dont care if this works really - if it fails
			 * the bus is likely dead. The reset on guest restart
			 * will likely set it up to function again ...
			 */
			(void) pcie_bus_reset(i);
#endif

			/*
			 * regardless of the bus reset we shutdown PIU's
			 * IOMMU and interrupt logic for this bus
			 */
			c_piu_leaf_soft_reset(
			    (struct piu_cookie *)&piu_dev[i], i);
		}
	}
}

#ifdef CONFIG_IOBYPASS

/*
 * For a guest which is allowed direct access to the I/O bridges
 * this sets up the segments for the I/O physical addresses.
 */

#define	BASE_1				0x8800000000
#define	LIMIT_1				0x8900000000
#define	BASE_2				0xc000000000
#define	LIMIT_2				0xff00000000

#define	ASSIGN_PIU_SEGMENTS(_guestp)					\
		assign_ra2pa_segments(_guestp, BASE_1,			\
		    LIMIT_1 - BASE_1, 0, IO_SEGMENT);			\
		assign_ra2pa_segments(_guestp, BASE_2,			\
		    LIMIT_2 - BASE_2, 0, IO_SEGMENT);			\
		assign_ra2pa_segments(guestp, FPGA_UART_BASE,		\
		    FPGA_UART_LIMIT - FPGA_UART_BASE, 0, IO_SEGMENT);

#define	UNASSIGN_PIU_SEGMENTS(_guestp)					\
		assign_ra2pa_segments(_guestp, BASE_1,			\
		    INVALID_SEGMENT_SIZE, 0, INVALID_SEGMENT);		\
		assign_ra2pa_segments(_guestp, BASE_2,			\
		    INVALID_SEGMENT_SIZE, 0, INVALID_SEGMENT);		\
		assign_ra2pa_segments(guestp, FPGA_UART_BASE,		\
		    FPGA_UART_LIMIT - FPGA_UART_BASE, 0, INVALID_SEGMENT);
#else

#define	PIU_BASE			(0xc810000000)
#define	PIU_LIMIT			(0xd000000000)

#define	ASSIGN_PIU_SEGMENTS(_guestp)					\
		assign_ra2pa_segments(_guestp, PIU_BASE,		\
		    PIU_LIMIT - PIU_BASE, 0, IO_SEGMENT);		\
		assign_ra2pa_segments(guestp, FPGA_UART_BASE,		\
		    FPGA_UART_LIMIT - FPGA_UART_BASE, 0, IO_SEGMENT);

#define	UNASSIGN_PIU_SEGMENTS(_guestp)					\
		assign_ra2pa_segments(_guestp, PIU_BASE,		\
		    INVALID_SEGMENT_SIZE, 0, INVALID_SEGMENT);		\
		assign_ra2pa_segments(guestp, FPGA_UART_BASE,		\
		    FPGA_UART_LIMIT - FPGA_UART_BASE, 0, INVALID_SEGMENT);

#endif	/* CONFIG_IOBYPASS */

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
		case (0):
			guestp->dev2inst[devid] = DEVOPS_PIU(0);
			ASSIGN_PIU_SEGMENTS(guestp);
			DBGBR(c_printf("\tNOTICE pcie LEAF 0x%x "	\
			    "configured for guest 0x%x\n", id,
			    guestp->guestid));
			break;
		default:
			DBGBR(c_printf("\tWARNING pcie 0x%x not "
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
	case (0):
		UNASSIGN_PIU_SEGMENTS(guestp);
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


static void config_piu_pcie_bus(int busnum);

/*
 * This function does an initial test of the PCI-E links attached to
 * PIU - primarily to determine if we have any PLX 8532 AA switches
 * directly attached ... if so, we need to determine which ports are
 * live so that we can guarantee a re-train in the event of a reset
 */
void
config_pcie()
{

}

/*
 * This function examines the specified PCI-E bus on PIU, and looks
 * for PLX 8532 AA switches ... and determines which downstream ports on
 * those switches are live.
 */

void
config_piu_pcie_bus(int busnum)
{
	uint64_t	res;
	piu_dev_t	*piup;

	ASSERT(busnum == 0);

	piup = (piu_dev_t *)&piu_dev[busnum];

	/* Becomes true after bus is used, false after it is reset */
	piup->needs_warm_reset = false;
	piup->blacklist = false;

	DBGBR(c_printf("Probing PIU bus %d\n", busnum));

	/*
	 * If the link is down, we don't do anything
	 * since it may mean there is no HW on the bus.
	 */

	/*
	 * Just bail if nothing connected to the bus
	 * We indicate a failure on the bus in this case to ensure
	 * that we mark the bus to be ignored. Even though the link
	 * status is checked on each config write, we try to prevent the
	 * case where a link is down here and comes up later ... without
	 * the bus being properly reset. By returning a failure here we hope
	 * that the HV marks the bus as dead and prevents further
	 * guest accesses.
	 */
	if (!is_piu_port_link_up(piup))
		return;

	/*
	 * If we are dealing with something other than
	 * a PLX or bridge (network card, for example)
	 * we simply toggle the link down and up.
	 * Otherwise we have to do the full secondary
	 * reset technique
	 */

	/*
	 * We look for a bridge under PIU.
	 * If the read fails, we have a problem ... abort for now, but
	 * need to handle this as simply the bus being inactive.
	 * We may need a PIU reset to resolve this - i.e. power cycle.
	 */

	if (!pci_config_get(piup, UPST_CFG_BASE + CFG_CLASS_CODE, 4, &res)) {
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

	if (!pci_config_get(piup, UPST_CFG_BASE + 0, 4, &res)) {
		DBGBR(c_printf("Bridge vendor ID read failed !!\n"));
		return;
	}

	DBGBR(c_printf("1st bridge vendorid = 0x%x\n", res));
	DBGBR(c_printf("Done probing bus 0x%x\n", busnum));
}

/*
 * This function resets a given PIU leaf
 *
 * (It should be based on resetting a given pci-e resource).
 *
 * Inputs:
 *
 *    bus  - root complex (0 = leaf A)
 *
 * Returns true on success, false on failure.
 * Caller should mark bus unusable after failure.
 */
bool_t
pcie_bus_reset(int busnum)
{
	uint64_t	brcode;
	piu_dev_t	*piup;

	piup = (piu_dev_t *)&piu_dev[busnum];

	/*
	 * If the bus just came out of a power on cycle
	 * then we don't need to reset it again here.
	 */
	if (!piup->needs_warm_reset) {
		piup->needs_warm_reset = true;
		DBGBR(c_printf("PCI-E warm reset not required\r\n"));
		return (true);
	}

	if (piup->blacklist) {
		DBGBR(c_printf("PCI-E bus 0x%x blacklisted \r\n", busnum));
		return (false);
	}

	DBGBR(c_printf("Resetting bus %d (piup=0x%x)\n",
	    busnum, (uint64_t)piup));

	/*
	 * If the link is down, we don't do anything
	 * since it may mean there is no HW on the bus.
	 */
	/*
	 * Just bail if nothing connected to the bus
	 * We indicate a failure on the bus in this case to ensure
	 * that we mark the bus to be ignored. Even though the link
	 * status is checked on each config write, we try to prevent the
	 * case where a link is down here and comes up later ... without
	 * the bus being properly reset. By returning a failure here we hope
	 * that the HV marks the bus as dead and prevents further
	 * guest accesses.
	 */
	if (!is_piu_port_link_up(piup)) {
		DBGBR(c_printf("PCI-E bus 0x%x link down \r\n", busnum));
		goto fail;
	}

	DBGBR(c_printf("PCI-E bus 0x%x link is up \r\n", busnum));


	/*
	 * If we are dealing with something other than
	 * a bridge (network card, for example)
	 * we simply toggle the link down and up.
	 * Otherwise we have to do the full secondary
	 * reset technique
	 */

	/*
	 * We look for a bridge under PIU.
	 * If the read fails, we have a problem ... abort for now, but
	 * need to handle this as simply the bus being inactive.
	 * We may need a fire reset to resolve this - i.e. power cycle.
	 */

	if (!pci_config_get(piup, UPST_CFG_BASE + CFG_CLASS_CODE,
	    4, &brcode)) {
		DBGBR(c_printf("Bridge read failed ... abandoning bus\n"));
		goto fail;
	}

	DBGBR(c_printf("Bridge class code 0x%x\n", brcode));

	/*
	 * If the device class code indicates there is no bridge, then we
	 * simply reset the link by toggling it
	 */

	if ((brcode>>8) != BRIDGE_CLASS_CODE) {
		DBGBR(c_printf("Not a bridge ..."));
		DBGBR(c_printf("...toggle link\n"));

		if (!piu_link_down(piup))
			goto fail;

		piu_reset_onboard_devices();

		if (!piu_link_up(piup))
			goto fail;
	}

	return (true);

fail:
	piup->blacklist = true;
	c_hvabort(-1);
	return (false);
}

void
piu_reset_onboard_devices(void)
{
#ifdef CONFIG_FPGA
	volatile uint16_t	*fpga_device_id = (uint16_t *)FPGA_DEVICE_ID;
	volatile uint8_t	*fpga_reset_control =
	    (uint8_t *)FPGA_LDOM_RESET_CONTROL;
	volatile uint8_t	*fpga_slot_reset_control =
	    (uint8_t *)FPGA_LDOM_SLOT_RESET_CONTROL;
	volatile uint8_t	*fpga_device_present =
	    (uint8_t *)FPGA_DEVICE_PRESENT;
	volatile uint16_t	fpga_major_version;
	volatile uint8_t	fpga_devices;

	/*
	 * GPIO reset support
	 * If FPGA has GPIO reset support(checked with major revision
	 * ID), then twiddle the reset pins for the onboard devices
	 * and pcie slots.  Hold reset for 200 msec, then wait for
	 * 1 second.
	 */
	fpga_major_version = (*fpga_device_id >> FPGA_ID_MAJOR_ID_SHIFT)
	    & FPGA_ID_MAJOR_ID_MASK;
	if (fpga_major_version >= FPGA_MIN_MAJOR_ID_RESET_SUPPORT) {
		DBGBR(c_printf("link toggled down\n"));
		fpga_devices = *fpga_device_present;
		*fpga_reset_control = FPGA_LDOM_RESET_CONTROL_MASK;
		*fpga_slot_reset_control = fpga_devices;
		c_usleep(200000); /* 200ms */
		*fpga_reset_control = 0;
		*fpga_slot_reset_control = 0;
		c_usleep(1000000); /* 1sec */

		DBGBR(c_printf("PCI-E bus has devices "	\
		    "present at slots 0x%x\r\n", fpga_devices));
	}
#endif /* CONFIG_FPGA */
}

void
init_pcie_buses(void)
{
	DBGPE(c_printf("initializing pcie buses\n"));
}

static void
setup_bypass_mappings(int bus_id, uint64_t bypass_pa, uint64_t size)
{
	extern const uint64_t piu_iotsb1;

	piu_dev_t 	*piup;
	uint64_t	*ttep;
	uint64_t	nttes;
	int 		i;

	ASSERT(bus_id == 0);
	piup = (piu_dev_t *)&(piu_dev[bus_id]);

	nttes = size >> IOTSB1_PAGESHIFT;

	DBGPE(c_printf("PA 0x%x size 0x%x shift 0x%x nttes 0x%x max 0x%x\n",
	    bypass_pa, size, IOTSB1_PAGESHIFT, nttes, IOTSB1_TSB_SIZE));

	ASSERT(nttes <= IOMMU_SIZE(IOTSB1_TSB_SIZE));

	ttep = piup->iotsb1;

	/*
	 * Set up a 4MB mapping for each page in the guests address space
	 */
	for (i = 0; i < nttes; i++) {
		*ttep++ = PIU_IOTTE(bypass_pa + (i << IOTSB1_PAGESHIFT));
	}
}

static void
clear_pcie_bypass(int bus_id)
{
	piu_dev_t 	*piup;

	/*
	 * Invalidate all entries in the large page IOSTB
	 */
	ASSERT(bus_id == 0);
	piup = (piu_dev_t *)&(piu_dev[bus_id]);
	c_bzero(piup->iotsb1, IOTSB1_SIZE);
}

static void
config_pcie_bypass(guest_t *guestp, int bus_id)
{
	uint64_t	segment_idx;
	uint64_t	bypass_pa;
	uint64_t	bypass_size;

	DBGPE(c_printf("initializing pcie IO TSB1 RA 0x%x limit 0x%x\n",
	    guestp->real_base, guestp->real_limit));
	DBGPE(c_printf("initializing pcie IO TSB1 PA 0x%x len 0x%x\n",
	    guestp->real_base + guestp->mem_offset,
	    guestp->real_limit - guestp->real_base));

	segment_idx = guestp->real_base >> RA2PA_SHIFT;
	ASSERT((guestp->ra2pa_segment[segment_idx].flags &
	    MEM_SEGMENT) == MEM_SEGMENT);

	/*
	 * Get the base PA of the guests memory segment. The
	 * size of the bypass address space allocated is the
	 * total real memory allocated to the guest. As with HWTW,
	 * this will break if the guests memory has holes.
	 *
	 * Also, do we really need to OR in PIU_IOMMU_BYPASS_BASE,
	 * this will be masked out of the PA used in the IOTSB.
	 */
	bypass_pa = (guestp->ra2pa_segment[segment_idx].base +
	    guestp->ra2pa_segment[segment_idx].offset) |
	    PIU_IOMMU_BYPASS_BASE;
	bypass_size = guestp->real_limit - guestp->real_base;

	DBGPE(c_printf("PCI Bypass Address 0x%x size 0x%x\n",
	    bypass_pa, bypass_size));

	/*
	 * bypass_pa must be aligned on the TSB page size
	 */
	if (bypass_pa & IOTSB1_PAGE_MASK) {
		DBGPE(c_printf("Misaligned Guest PCI Bypass Address 0x%llx \n",
		    bypass_pa));
		c_hvabort(-1);
	}

	/*
	 * bypass_size must be a multiple of the TSB page size
	 */
	if (bypass_size & IOTSB1_PAGE_MASK) {
		DBGPE(c_printf("Invalid Guest PCI Bypass Size 0x%llx \n",
		    bypass_pa));
		c_hvabort(-1);
	}

	DBGPE(c_printf("Create IO TSB1 mappings\n"));

	setup_bypass_mappings(bus_id, bypass_pa, bypass_size);
}

/*
 * N2 PIU does not have functionality equivalent to N1 Fire Bypass Mode
 * but some drivers rely on this so we need to provide a similar
 * feature for PIU. What we do is allocate a second IOTSB which maps
 * all of the guests memory using 4MB pages. This imposes the constraint
 * that the guests address space is 4MB aligned and a multiple of 4MB.
 *
 * It would be better to just make the second IOTSB available to the
 * guest for it to create large page mappings itself.
 */
void
plat_config_pcie_bypass(pcie_device_t *pciep)
{
	int id;

	id = pciep->id;
	ASSERT(id == 0);

	if (pciep->allow_bypass) {
		DBGPE(c_printf("PCI-E Bypass Mode allowed for guest 0x%x\n",
		    pciep->guestp->guestid));
		config_pcie_bypass(pciep->guestp, id);
	} else {
		DBGPE(c_printf("PCI-E Bypass not allowed for guest 0x%x\n",
		    pciep->guestp->guestid));
		DBGPE(c_printf("invalidating pcie IOTSB1\n"));
		clear_pcie_bypass(id);
	}
}

#endif	/* CONFIG_PIU */
