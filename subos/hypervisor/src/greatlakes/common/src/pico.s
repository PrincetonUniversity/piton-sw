#include <sys/asm_linkage.h>
#include <hypervisor.h>

#include <guest.h>
#include <offsets.h>
#include <util.h>
#include <debug.h>

#define PITON_INT_ADDR      0x9800000800
#define PITON_VINT_X_OFFSET 18
#define PITON_INT_RST_MSG   0x8000000000010001
#define PICO_START_ADDR 0x3F000000

#define PICO_DATA   0x41424344

/* arg1: %o0 physical address
 *
 */
ENTRY_NP(hcall_pico_start)
    PRINT("Entered pico hypercall\r\n")
    PRINT_REGISTER("Got physical address ", %o0)
    PRINT("\r\n")
  
    ! Load PC
    setx PICO_START_ADDR, %g1, %g3
    stw %o0, [%g3]
    

    setx PITON_INT_RST_MSG,%g1, %g3
    mov  1, %g1
    sll  %g1, PITON_VINT_X_OFFSET, %g1
    or   %g3, %g1, %g3
    setx PITON_INT_ADDR, %g1, %g2
    stx  %g3, [%g2]
    PRINT("Started pico\r\n")

    HCALL_RET(EOK)
SET_SIZE(hcall_pico_start)
 
