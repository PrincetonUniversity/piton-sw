/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: dis.c
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

#pragma ident	"@(#)dis.c	1.2	03/11/10 SMI"

#include <stdio.h>
#include <sys/types.h>

#define RD(inst)	(((inst) >> 25) & 0x1f)
#define RS1(inst)	(((inst) >> 14) & 0x1f)
#define RS2(inst)	(((inst)      ) & 0x1f)
#define OP(inst)	(((inst) >> 30) & 0x3)
#define OP2(inst)	(((inst) >> 22) & 0x7)
#define OP3(inst)	(((inst) >> 19) & 0x3f)
#define IMM22(inst)	(((inst) << 10) >> 10)
#define IMM(inst)	(((inst) >> 13) & 1)
#define SIMM13(inst)	(int64_t)(((((int32_t)(inst) << 19)) >> 19))
#define X(inst)		(((inst) >> 12) & 1)
#define SHIFT32(inst)	((inst) & 0x1f)
#define SHIFT64(inst)	((inst) & 0x3f)
#define CMASK(inst)	(((inst) >> 4) & 0x7)
#define MMASK(inst)	((inst) & 0xf)
#define A(inst)		(((inst) >> 29) & 1)
#define CC(inst)	(((inst) >> 20) & 3)
#define TCC(inst)	(((inst) >> 10) & 3)
#define DISP19(inst)	(int64_t)(((((int32_t)(inst) << 13)) >> 11))
#define DISP22(inst)	(int64_t)(((((int32_t)(inst) << 10)) >> 8))
#define COND(inst)	(((inst) >> 25) & 0xf)
#define PT(inst)	(((inst) >> 19) & 1)
#define FCN(inst)	(((inst) >> 25) & 0x1f)
#define IMMASI(inst)	(((inst) >> 5) & 0xff)
#define SWTRAP(inst)	((inst) & 0x3f)
#define HT(inst)	(((inst) >> 7) & 0x1)
#define ILLEGAL		\
	(void)printf("%p:\tIllegal instruction %08x\n", (void *)pc, inst);\
	return 0
#define OK	0
#define ERR	-1
#define DELAY	1

static char *sregs[] = {
	"%g0", "%g1", "%g2", "%g3", "%g4", "%g5", "%g6", "%g7",
	"%o0", "%o1", "%o2", "%o3", "%o4", "%o5", "%o6", "%i7",
	"%l0", "%l1", "%l2", "%l3", "%l4", "%l5", "%l6", "%l7",
	"%i0", "%i1", "%i2", "%i3", "%i4", "%i5", "%i6", "%i7"
};
static int dis_format2(uint32_t *, uint32_t);
static int dis_class2(uint32_t *, uint32_t);
static int dis_class3(uint32_t *, uint32_t);
static int dis_bpcc(uint32_t *, uint32_t);
static int dis_bpr(uint32_t *, uint32_t);
static int dis_tcc(uint32_t *, uint32_t);
static int dis_fbfcc(uint32_t *, uint32_t);
static int dis_fbpfcc(uint32_t *, uint32_t);
static int dis_bicc(uint32_t *, uint32_t);
static int dis_rdasr(uint32_t *, uint32_t);
static int dis_rdpr(uint32_t *, uint32_t);
static int dis_wrasr(uint32_t *, uint32_t);
static int dis_wrpr(uint32_t *, uint32_t);

int
disasm(uint32_t *pc)
{
	uint32_t inst = *pc;
	int op = OP(inst);

	switch(op) {
	case 0:
		return dis_format2(pc, inst);
	case 1: {
		int64_t label = (inst << 2) + (int64_t) pc;
		(void)printf("%p:\tcall\t0x%lx\n", (void *)pc, label);
		return DELAY;
	}
	case 2:
		return dis_class2(pc, inst);
	case 3:
		return dis_class3(pc, inst);
	}
	return ERR;
}

static int
dis_format2(uint32_t *pc, uint32_t inst)
{
	int op2 = OP2(inst);
	switch(op2) {
	case 0:
		(void)printf("%p:\tilltrap\n", (void *)pc);
		return OK;
	case 1:
		return dis_bpcc(pc, inst);
	case 2:
		return dis_bicc(pc, inst);
	case 3:
		return dis_bpr(pc, inst);
	case 4:
		if ((RD(inst) == 0) && (IMM22(inst) == 0)) {
			(void)printf("%p:\tnop\n", (void *)pc);
			return OK;
		}
		(void)printf("%p:\tsethi\t0x%x, %s\n", (void *)pc,
		       IMM22(inst) << 10, sregs[RD(inst)]);
		return OK;
	case 5:
		return dis_fbpfcc(pc, inst);
	case 6:
		return dis_fbfcc(pc, inst);
	case 7:
		ILLEGAL;
	}
	return ERR;
}
static int
dis_class2(uint32_t *pc, uint32_t inst)
{
	int op3 = OP3(inst);
	char *opc[] = {
		"add",    "and",    "or",       "xor",
		"sub",    "andn",   "orn",      "xnor",
		"addc",   "mulx",   "umul",     "smul",
		"subc",   "udivx",  "udiv",     "sdiv",
		"addcc",  "andcc",  "orcc",     "xorcc",
		"subcc",  "andncc", "orncc",    "xnorcc",
		"addccc", "-",      "umulcc",   "smulcc",
		"subccc", "-",      "udivcc",   "sdivcc",
		"taddcc", "tsubcc", "taddcctv", "tsubcctv",
		"mulscc", "sll",    "srl",      "sra",
		"rdy",    "-",      "rdpr",     "flushw",
		"movcc",  "sdivx",  "popc",     "movr",
		"wry",    "saved",  "wrpr",     "-",
		"fpop1",  "fpop2",  "impldep1", "impldep2",
		"jmpl",   "return", "tcc",      "flush",
		"save",   "restore", "done",     "-"
	};

	switch(op3) {
	case 0x00: /* ADD */
	case 0x01: /* AND */
	case 0x02: /* OR */
	case 0x03: /* XOR */
	case 0x04: /* SUB */
	case 0x05: /* ANDN */
	case 0x06: /* ORN */
	case 0x07: /* XNOR */
	case 0x08: /* ADDC */
	case 0x09: /* MULX */
	case 0x0a: /* UMUL */
	case 0x0b: /* SMUL */
	case 0x0c: /* SUBC */
	case 0x0d: /* UDIVX */
	case 0x0e: /* UDIV */
	case 0x0f: /* SDIV */

	case 0x10: /* ADDcc */
	case 0x11: /* ANDcc */
	case 0x12: /* ORcc */
	case 0x13: /* XORcc */
	case 0x14: /* SUBcc */
	case 0x15: /* ANDNcc */
	case 0x16: /* ORNcc */
	case 0x17: /* XNORcc */
	case 0x18: /* ANDCcc */
	case 0x1a: /* UMULcc */
	case 0x1b: /* SMULcc */
	case 0x1c: /* SUBCcc */
	case 0x1e: /* UDIVcc */
	case 0x1f: /* SDIVcc */

	case 0x20: /* TADDcc */
	case 0x21: /* TSUBcc */
	case 0x22: /* TADDccTV */
	case 0x23: /* TSUBccTV */
	case 0x24: /* MULScc */
	case 0x2c: /* MOVcc */
	case 0x2d: /* SDIVX */
	case 0x2f: /* MOVr */
	case 0x38: /* JMPL */
	case 0x3c: /* SAVE */
	case 0x3d: /* RESTORE */
		(void)printf("%p:\t%s\t%s, ", (void *)pc, 
			     opc[op3], sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%ld, ", SIMM13(inst));
		else
			(void)printf("%s, ", sregs[RS2(inst)]);
		(void)printf("%s\n", sregs[RD(inst)]);
		return (op3 == 0x38) ? DELAY : OK;

	case 0x2b: /* FLUSHW */
		if ((RD(inst) == 0) && (RS1(inst) == 0)
		    && (IMM(inst) == 0) && (SIMM13(inst) == 0)) {
			(void)printf("%p:\t%s\n", (void *)pc, opc[op3]);
			return OK;
		}
		ILLEGAL;
	case 0x39: /* RETURN */
	case 0x3b: /* FLUSH */
		if (RD(inst)) {
			ILLEGAL;
		}
		(void)printf("%p:\t%s\t%s + ", (void *)pc, opc[op3], sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%ld\n", SIMM13(inst));
		else
			(void)printf("%s\n", sregs[RS2(inst)]);
		return OK;
	case 0x19:
	case 0x1d:
	case 0x29:
	case 0x33:
	case 0x3f:
		ILLEGAL;
	case 0x25: /* SLL/SLLX */
	case 0x26: /* SRL/SRLX */
	case 0x27: /* SRA/SRAX */
		(void)printf("%p:\t%s%s\t%s, ", (void *)pc,
		       opc[op3], X(inst) ? "x" : "", sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%d, ",
			       X(inst) ? SHIFT64(inst) : SHIFT32(inst));
		else
			(void)printf("%s, ", sregs[RS2(inst)]);
		(void)printf("%s\n", sregs[RD(inst)]);
		return OK;
	case 0x28: /* RDASR */
		return dis_rdasr(pc, inst);
	case 0x2a: /* RDPR */
		return dis_rdpr(pc, inst);
	case 0x30: /* WRASR */
		return dis_wrasr(pc, inst);
	case 0x31: /* SAVED/RESTORED */
		if(FCN(inst) == 0) {
			(void)printf("%p:\tsaved\n", (void *)pc);
			return OK;
		}
		if(FCN(inst) == 1) {
			(void)printf("%p:\trestored\n", (void *)pc);
			return OK;
		}
		ILLEGAL;
	case 0x32: /* WRPR */
		return dis_wrpr(pc, inst);
	case 0x3a: /* Tcc */
		return dis_tcc(pc, inst);
	case 0x3e: /* DONE/RETRY */
		if(FCN(inst) == 0) {
			(void)printf("%p:\tdone\n", (void *)pc);
			return OK;
		}
		if(FCN(inst) == 1) {
			(void)printf("%p:\tretry\n", (void *)pc);
			return OK;
		}
		ILLEGAL;
	case 0x36: /* IMPDEP1 */
		(void)printf("XXXX %p:\timpldep1\n", (void *)pc );
		return ERR;
	case 0x37: /* IMPLDEP2 */
		(void)printf("XXXX %p:\timpldep2\n", (void *)pc);
		return ERR;
	default:
		(void)printf("XXXX dis_class2 op3=%x\n", op3);
		return ERR;
	}
}

static int dis_rdpr(uint32_t *pc, uint32_t inst)
{
	char *prs[] = {
		"%tpc",      "%tnpc",     "%tstate",  "%tt",
		"%tick",     "%tba",      "%pstate",  "%tl",
		"%pil",      "%cwp",      "%cansave", "%canrestore",
		"%cleanwin", "%otherwin", "%wstate",  "%fq",
		"-",         "-",         "-",        "-",
		"-",         "-",         "-",        "-",
		"-",         "-",         "-",        "-",
		"-",         "-",         "-",        "%ver"
	};
	if ((SIMM13(inst)) || (RS1(inst) >= 16 && RS1(inst) <=30)) {
		ILLEGAL;
	}
	(void)printf("%p:\trdpr\t%s,%s\n", (void *)pc, prs[RS1(inst)], sregs[RD(inst)]);
	return OK;
}

static int dis_wrpr(uint32_t *pc, uint32_t inst)
{
	char *prs[] = {
		"%tpc",      "%tnpc",     "%tstate",  "%tt",
		"%tick",     "%tba",      "%pstate",  "%tl",
		"%pil",      "%cwp",      "%cansave", "%canrestore",
		"%cleanwin", "%otherwin", "%wstate",  "%fq",
		"-",         "-",         "-",        "-",
		"-",         "-",         "-",        "-",
		"-",         "-",         "-",        "-",
		"-",         "-",         "-",        "-"
	};
	if (RD(inst) >= 15) {
		ILLEGAL;
	}
	(void)printf("%p:\twrpr\t%s,%s, ", (void *)pc, prs[RD(inst)], sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%ld, ", SIMM13(inst));
		else
			(void)printf("%s, ", sregs[RS2(inst)]);
		(void)printf("%s\n", sregs[RD(inst)]);
	return OK;
}

static int dis_wrasr(uint32_t *pc, uint32_t inst)
{
	char *asrs[] = {
		"wry",    "-",    "wrccr",  "wrasi",
		"wrtick", "-",    "wrfprs", "-",
		"-",      "-",    "-",      "-",
		"-",      "-",    "-",      "sir",
	};

	if ((RD(inst) == 0xf) && (RS1(inst) != 0) && (IMM(inst) == 0)) {
		ILLEGAL;
	}
	switch(RD(inst)) {
	case 0x01:
		ILLEGAL;
	case 0x0f: /* SIR */
	case 0x00: /* WRY */
	case 0x02: /* WRCCR */
	case 0x03: /* WRASI */
	case 0x06: /* WRFPRS */
		(void)printf("%p:\t%s\t%s,", (void *)pc, asrs[RD(inst)], sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%ld, ", SIMM13(inst));
		else
			(void)printf("%s, ", sregs[RS2(inst)]);
		(void)printf("\n");
		return OK;
	case 0x04:
	case 0x05:
	case 0x07:
	case 0x08:
	case 0x09:
	case 0x0a:
	case 0x0b:
	case 0x0c:
	case 0x0d:
	case 0x0e:
		ILLEGAL;
	case 0x10:
	case 0x11:
	case 0x12:
	case 0x13:
	case 0x14:
	case 0x15:
	case 0x16:
	case 0x17:
	case 0x18:
	case 0x19:
	case 0x1a:
	case 0x1b:
	case 0x1c:
	case 0x1d:
	case 0x1e:
	case 0x1f:
		(void)printf("%p:\twr\t%s, ", (void *)pc, sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%ld, ", SIMM13(inst));
		else
			(void)printf("%s, ", sregs[RS2(inst)]);
		(void)printf("%%asr%d\n", RD(inst));
		return ERR;
	default:
		(void)printf("XXXX wrasr %d\n", RD(inst));
		return ERR;
	}
}

static int dis_rdasr(uint32_t *pc, uint32_t inst)
{
	char *asrs[32] = {
		"rdy",    "-",    "rdccr",  "rdasi",
		"rdtick", "rdpc", "rdfprs", "-",
		"-",      "-",    "-",      "-",
		"-",      "-",    "-",      "-",
		"-",      "-",    "-",      "-",
		"-",      "-",    "-",      "-",
		"-",      "-",    "-",      "-",
		"-",      "-",    "-",      "-",
	};
	switch(RS1(inst)) {
	case 0x01:
	case 0x07:
	case 0x08:
	case 0x09:
	case 0x0a:
	case 0x0b:
	case 0x0c:
	case 0x0d:
	case 0x0e:
		ILLEGAL;
	case 0x0:
	case 0x2:
	case 0x3:
	case 0x4:
	case 0x5:
	case 0x6:
		(void)printf("%p:\t%s\t%s\n", (void *)pc, asrs[RS1(inst)],
		       sregs[RD(inst)]);
		return OK;
	case 0xf: /* MEMBAR / STBAR */
		if (RD(inst) == 0) {
			if (IMM(inst)) {
				(void)printf("%p\tmembar\t", (void *)pc);
				if ((CMASK(inst) & 1))
					(void)printf("#Lookaside ");
				if ((CMASK(inst) & 2))
					(void)printf("#MemIssue ");
				if ((CMASK(inst) & 4))
					(void)printf("#Sync ");
				if ((MMASK(inst) & 1))
					(void)printf("#LoadLoad ");
				if ((MMASK(inst) & 2))
					(void)printf("#StoreLoad ");
				if ((MMASK(inst) & 4))
					(void)printf("#LoadStore ");
					if ((MMASK(inst) & 8))
						(void)printf("#StoreStore");
					(void)printf("\n");
				} else {
					(void)printf("%p:\tstbar\n", (void *)pc);
				}
			return OK;
		} else {
			ILLEGAL;
		}
	case 0x10:
	case 0x11:
	case 0x12:
	case 0x13:
	case 0x14:
	case 0x15:
	case 0x16:
	case 0x17:
	case 0x18:
	case 0x19:
	case 0x1a:
	case 0x1b:
	case 0x1c:
	case 0x1d:
	case 0x1e:
	case 0x1f:
	default:
		(void)printf("%p:\trd\t%%asr%d, %s\n", (void *)pc, RS1(inst), sregs[RD(inst)]);
		return OK;
	}
}

static int
dis_class3(uint32_t *pc, uint32_t inst)
{
	int op3 = OP3(inst);
	char *opc[0x40] = {
		"lduw",  "ldub",      "lduh",  "ldd",
		"stw",   "stb",       "sth",   "std",
		"ldsw",  "ldsb",      "ldsh",  "ldx",
		"-",     "ldstub",    "stx",   "swap",
		"lduwa", "lduba",     "lduha", "ldda",
		"stwa",  "stba",      "stha",  "stda",
		"ldswa", "ldsba",     "ldsha", "ldxa",
		"-",     "ldstuba",   "stxa",  "swapa",
		"ldf",   "ldfsr",     "ldqf",  "lddf"
		"stf",   "stfsr",     "stqf",  "stdf",
		"-",     "-",         "-",     "-",
		"-",     "prefetch",  "-",     "-",
		"ldfa",  "-",         "ldqfa", "lddfa",
		"stfa",  "-",         "stqfa", "stdfa",
		"-",     "-",         "-",     "-",
		"casa",  "prefetcha", "casxa", "-"
	};

	switch(op3) {
	case 0x0c:
	case 0x1c:
	case 0x28:
	case 0x29:
	case 0x2a:
	case 0x2b:
	case 0x2c:
	case 0x2e:
	case 0x31:
	case 0x35:
	case 0x38:
	case 0x39:
	case 0x3a:
	case 0x3b:
	case 0x3f:
		ILLEGAL;
	case 0x00: /* LDUW */
	case 0x01: /* LDUB */
	case 0x02: /* LDUH */
	case 0x03: /* LDD  */
	case 0x08: /* LDSW */
	case 0x09: /* LDSB */
	case 0x0a: /* LDSH */
	case 0x0b: /* LDX */
	case 0x0d: /* LDSTUB */
	case 0x1f: /* SWAP */
		(void)printf("%p:\t%s\t[%s + ", (void *)pc, opc[op3], sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%ld], ", SIMM13(inst));
		else
			(void)printf("%s], ", sregs[RS2(inst)]);
		(void)printf("%s\n", sregs[RD(inst)]);
		return OK;
	case 0x04: /* STW  */
	case 0x05: /* STB  */
	case 0x06: /* STH  */
	case 0x07: /* STD  */
	case 0x0e: /* STX  */
		(void)printf("%p:\t%s\t%s, ", (void *)pc, opc[op3], sregs[RD(inst)]);
		(void)printf("[%s + ", sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%ld]\n", SIMM13(inst));
		else
			(void)printf("%s]\n", sregs[RS2(inst)]);
		return OK;

	case 0x10: /* LDUWA */
	case 0x11: /* LDUBA */
	case 0x12: /* LDUHA */
	case 0x13: /* LDDA  */
	case 0x18: /* LDSWA */
	case 0x19: /* LDSBA */
	case 0x1a: /* LDSHA */
	case 0x1b: /* LDXA  */
	case 0x1d: /* LDSTUBA */
	case 0x2f: /* SWAPA */
	case 0x3c: /* CASA */
	case 0x3e: /* CASXA */
		(void)printf("%p:\t%s\t[%s + ", (void *)pc, opc[op3], sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%ld] %%asi, ", SIMM13(inst));
		else
			(void)printf("%s] 0x%x, ", sregs[RS2(inst)], IMMASI(inst));
		(void)printf("%s\n", sregs[RD(inst)]);
		return OK;

	case 0x14: /* STWA  */
	case 0x15: /* STBA  */
	case 0x16: /* STHA  */
	case 0x17: /* STDA  */
	case 0x1e: /* STXA  */
		(void)printf("%p:\t%s\t%s, ", (void *)pc, opc[op3], sregs[RD(inst)]);
		(void)printf("[%s + ", sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%ld] %%asi\n", SIMM13(inst));
		else
			(void)printf("%s] 0x%x\n", sregs[RS2(inst)], IMMASI(inst));
		return OK;

	case 0x2d: /* PREFETCH */
		if ((RD(inst) >=5) && (RD(inst) <= 15)) {
			ILLEGAL;
		}
		(void)printf("%p:\t%s\t[%s + ", (void *)pc, opc[op3], sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%ld], ", SIMM13(inst));
		else
			(void)printf("%s], ", sregs[RS2(inst)]);
		(void)printf("%d\n", RD(inst));
		return OK;

	case 0x3d: /* PREFETCHA */
		if ((RD(inst) >=5) && (RD(inst) <= 15)) {
			ILLEGAL;
		}
		(void)printf("%p:\t%s\t[%s + ", (void *)pc, opc[op3], sregs[RS1(inst)]);
		if (IMM(inst))
			(void)printf("%ld] %%asi, ", SIMM13(inst));
		else
			(void)printf("%s] 0x%x, ", sregs[RS2(inst)], IMMASI(inst));
		(void)printf("%d\n", RD(inst));
		return OK;

	case 0x20:
	case 0x21:
	case 0x22:
	case 0x23:
	case 0x30:
	case 0x32:
	case 0x33:
		(void)printf("XXXX %p:\tLDF XXX op3=%x\n", (void *)pc, OP3(inst));
		return ERR;
	case 0x24:
	case 0x25:
	case 0x26:
	case 0x27:
	case 0x34:
	case 0x36:
	case 0x37:
		(void)printf("XXXX %p:\tSTF XXX op3=%x\n", (void *)pc, OP3(inst));
		return ERR;
	default:
		(void)printf("XXXX dis_class3 op3=%x\n", OP3(inst));
		return ERR;
	}
}

static int dis_bpcc(uint32_t *pc, uint32_t inst)
{
	char *bpcc[0x10] = {
		"bpn",	 "bpe",  "bple",  "bpl",
		"bpleu", "bpcs", "bpneg", "bpvs"
		"bpa",   "bpne", "bpg",   "bpge",
		"bpgu",  "bpcc", "bppos", "bpvc"
	};
	if ((CC(inst) != 0) && (CC(inst) != 2)) {
		ILLEGAL;
	}
	(void)printf("%p:\t%s%s%s\t%s,0x%lx\n", (void *)pc,
	       bpcc[COND(inst)],
	       A(inst) ? ",a" : "",
	       PT(inst) ? ",pt" : ",pn",
	       CC(inst) ? "%xcc" : "%icc",
	       DISP19(inst) + (int64_t)pc);
	return DELAY;
}

static int dis_bpr(uint32_t *pc, uint32_t inst)
{
	(void)printf("%p:\tXXXX dis_bpr 0x%x\n", (void *)pc, inst);
	return ERR;
}

static int dis_bicc(uint32_t *pc, uint32_t inst)
{
	char *bcc[0x10] = {
		"bn",   "be",  "ble",  "bl",
		"bleu", "bcs", "bneg", "bvs"
		"ba",   "bne", "bg",   "bge",
		"bgu",  "bcc", "bpos", "bvc"
	};
	(void)printf("%p:\t%s%s\t0x%lx\n", (void *)pc,
	       bcc[COND(inst)],
	       A(inst) ? ",a" : "",
	       DISP22(inst) + (int64_t)pc);
	return DELAY;
}
static int dis_tcc(uint32_t *pc, uint32_t inst)
{
	char *tcc[0x10] = {
		"tn",   "te",  "tle",  "tl",
		"tleu", "tcs", "tneg", "tvs",
		"ta",   "tne", "tg",   "tge",
		"tgu",  "tcc", "tpos", "tvc"
	};
	(void)printf("%p:\t%s%s\t%s, ", (void *)pc, HT(inst) ? "h" : "", tcc[COND(inst)],
	       TCC(inst) ? "%xcc" : "%icc");
	if (IMM(inst))
		(void)printf("0x%x\n", SWTRAP(inst));
	else
		(void)printf("%s\n", sregs[RS2(inst)]);
	return OK;
}

static int dis_fbfcc(uint32_t *pc, uint32_t inst)
{
	(void)printf("%p:\tXXXX dis_fbfcc 0x%x\n", (void *)pc, inst);
	return ERR;
}
static int dis_fbpfcc(uint32_t *pc, uint32_t inst)
{
	(void)printf("%p:\tXXXX dis_fbpfcc 0x%x\n", (void *)pc, inst);
	return ERR;
}

