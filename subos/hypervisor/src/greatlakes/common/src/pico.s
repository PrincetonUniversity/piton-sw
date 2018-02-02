#include <sys/asm_linkage.h>
#include <hypervisor.h>

#include <guest.h>
#include <offsets.h>
#include <util.h>
#include <debug.h>

#define PITON_INT_ADDR      0x9800000800
#define PITON_VINT_X_OFFSET 18
#define PITON_INT_RST_MSG   0x8000000000010001

#define PICO_STATUS 0x3F000000

ENTRY_NP(hcall_pico_start)
    mov %g7, %g3
    PRINT("Entered pico hypercall\r\n")
    mov %g3, %g7
    setx PITON_INT_RST_MSG,%g1, %g3
    mov  1, %g1
    sll  %g1, PITON_VINT_X_OFFSET, %g1
    or   %g3, %g1, %g3
    setx PITON_INT_ADDR, %g1, %g2
    stx  %g3, [%g2]

    setx PICO_STATUS, %g1, %g2
poll_loop:
    ldub [%g2], %g3
    cmp  %g3, 0xff
    bne  poll_loop
    
    PRINT_REGISTER("Got value: ", %g3)
    PRINT("\r\n")
    HCALL_RET(EOK)
SET_SIZE(hcall_pico_start)
 
