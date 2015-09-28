\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: core.fth
\ 
\ Copyright (c) 2006 Sun Microsystems, Inc. All Rights Reserved.
\ 
\  - Do no alter or remove copyright notices
\ 
\  - Redistribution and use of this software in source and binary forms, with 
\    or without modification, are permitted provided that the following 
\    conditions are met: 
\ 
\  - Redistribution of source code must retain the above copyright notice, 
\    this list of conditions and the following disclaimer.
\ 
\  - Redistribution in binary form must reproduce the above copyright notice,
\    this list of conditions and the following disclaimer in the
\    documentation and/or other materials provided with the distribution. 
\ 
\    Neither the name of Sun Microsystems, Inc. or the names of contributors 
\ may be used to endorse or promote products derived from this software 
\ without specific prior written permission. 
\ 
\     This software is provided "AS IS," without a warranty of any kind. 
\ ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, 
\ INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A 
\ PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY EXCLUDED. SUN 
\ MICROSYSTEMS, INC. ("SUN") AND ITS LICENSORS SHALL NOT BE LIABLE FOR 
\ ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR 
\ DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES. IN NO EVENT WILL SUN 
\ OR ITS LICENSORS BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA, OR 
\ FOR DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE 
\ DAMAGES, HOWEVER CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, 
\ ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF 
\ SUN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
\ 
\ You acknowledge that this software is not designed, licensed or
\ intended for use in the design, construction, operation or maintenance of
\ any nuclear facility. 
\ 
\ ========== Copyright Header End ============================================
id: @(#)core.fth 1.2 07/03/13
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless

\ Possible vables of PKTBUFSZ field of the Receive Completion Ring Entry
b# 00  constant bufsz0
b# 01  constant bufsz1
b# 10  constant bufsz2
b# 11  constant singleblk

\ Neptune Tx packet descriptor structure.  Flags occupies bits [63:44]
h#    1 d# 63 lshift constant sof         \ Start of Frame
h#    1 d# 62 lshift constant mark        \ Interrupt after pkt is transmitted
h#    1 d# 58 lshift constant num-ptr=1   \ # of gather pointers of this pkt=1
h# 1fff d# 44 lshift constant tr-len-mask \ Mask for TR_LEN (bits[56:44])

\ SW must toggle this bit every time the tail wraps around the ring.
h# 8.0000 constant wrap=1
0         constant wrap=0
wrap=0 value wrap

0 value last-rmd-idx

\ Get the HEAD field of register TX_RING_HDL to check which descriptor
\ has been processed by the hardware
\
\ In Neptune, software appends packets to be transmitted to the tail
\ of the TX descriptor ring; HW hammers the packet at the head of
\ the TX ring to the medium. When we transmit one packet at a time,
\ the head will follow the tail!  Packets have been sent out when
\ head matches tail.
\
: tx-head@      ( chan -- head ) tx-ring-hdl-i@  3 xrshift h# ffff and ;
: tx-hdr-wrap@  ( chan -- wrap ) tx-ring-hdl-i@  d# 44 lshift d# 63 xrshift ;
: tx-tail@      ( chan -- tail ) tx-ring-kick-i@ 3 xrshift h# ffff and ;
: tx-tail-wrap@ ( chan -- wrap ) tx-ring-kick-i@ d# 44 lshift d# 63 xrshift ;

false instance value restart?   \ To flag serious errors

\ Words to access the 64-bit message descriptors.
\ xbflip takes care of SPARC's big endianess
\
: descriptor64@ ( addr -- x )  x@ xbflip ;
: descriptor64! ( x addr -- )  >r xbflip r> x! ;

: descriptor32@ ( addr -- x )  l@ lbflip ;
: descriptor32! ( x addr -- )  >r lbflip r> l! ;

\ RX descriptor ring address calculations
: rmd#>rmdaddr ( n -- addr )  /rmd *  rmd0 + ;
: rmdaddr>rmd# ( addr -- n )  rmd0 - /rmd /  ;

\ TX descriptor ring address calculations
\ /tmd=8 (bytes), which is the size of tx descriptor
: tmd#>tmdaddr ( n -- addr )  #tmds mod /tmd *  tmd0 +  ;
: tmdaddr>tmd# ( addr -- n )  tmd0 - /tmd / #tmds mod ;

\ RX completion ring address calculations
: rcd#>rcdaddr  ( n -- addr )  #rcds mod /rcd * rcd0 + ;
: rcdaddr>rcd#  ( addr -- n )  rcd0 - /rcd / #rcds mod ;

\ RX buffer address calculations
\ #rbufs is the total number of Rx buffers = 60 = 64-4 
\ /rbuf is the size of Rx data block, 8K each
: rbuf#>rbuf-io-adr ( n -- addr )  #rbufs mod /rbuf * io-rbuf0 +  ;

\ Convert rcd-cpu-addr to rcd-io-addr
: rcd-cpu-addr>rcd-io-addr ( rcd-cpu-addr -- rcd-io-addr )
   rcd0 - io-rcd0 +
; 
   
: tmdheader@ ( tmdaddr -- len )
   descriptor64@
   d# 44 xrshift d# 44 lshift     \ Clear the lower 44 bits of 
;                                 \ descriptor contents 

\ Pointer to the shared 4K Tx data buffer is the lower 44 bits
\ of the descriptor. This word gets the contents of the descriptor
\ then mask off the top 20 bits of the 64 bits descriptor.
\
: txbufptr@ ( tmdaddr -- addr ) 
   descriptor64@
   d# 20 lshift d# 20 xrshift     
;                                

\ Get current tmd entry, clear bits 63:44, OR the addr of 
\ block buffer with new flags including len.  Must use xrshift 
\ to avoid truncating.
\ 
: tmdheader! ( hdr tmdaddr -- )    
   dup            ( hdr tmdaddr tmdaddr )
   txbufptr@      ( hdr tmdaddr low44_cur_tmd )
   rot            ( tmdaddr low44_cur_tmd hdr ) 
   or             ( tmdaddr lenORlow44_cur_tmd ) 
   swap           ( new_tmd tmdaddr )  \ new_tmd = len OR low44bits_cur_tmd 
   descriptor64!
;

\ The TX descriptor has two parts, the leading 20 bits are flags and 
\ the length of data, the remaining 44 bits are address of the data
\ buffer. This word only puts the address of a data buffer to the 
\ lower 44 bits of the descriptor without changing the leadring 
\ 20 bits, which are set by tmdheader!
\
: txbufptr! ( bufptr tmdaddr -- ) 
   >r             ( bufptr ) ( r: tmdaddr ) 
   d# 20 lshift d# 20 xrshift      \ Clear the top 20 bits of bufptr 
   r>             ( low44_bufptr tmdaddr )      
   dup            ( low44_bufptr tmdaddr tmdaddr )
   tmdheader@     ( low44_bufptr tmdaddr top20bits_cur_tmd )
   rot            ( tmdaddr top20bits_cur_tmd low44_bufptr ) 
   or             ( tmdaddr top20bits_cur_tmd-OR-low44_bufptr ) 
   swap           ( new_tmd tmdaddr )  \ new_tmd=top20bits_cur_tmd OR low44_bufptr
   descriptor64!
;

\ RX descriptor fields
\
: rxbufptr! ( bufptr rmdaddr -- )  
   swap      ( rmdaddr bufptr )
   d# 12 xrshift d# 12 lshift   \ Clear the low 12 bits
   swap 
   descriptor64! 
;

: rxbufptr@ ( rmdaddr -- bufptr )
   descriptor64@ 
   \ What we read from the descriptor is bits[43:12] of addr
   d# 12 lshift    \ now append 12 0s to bits[43:12]
;

: synciopb    ( cpu-addr size -- )
   over       ( cpu-addr size cpu-addr )
   cpu>io-adr ( cpu-addr size dev-addr )
   swap       ( cpu-addr io-addr size )
   dma-sync   ( )
;

\ Set logic device group 0 to include Channel0 RxDMA (logic devie 0), 
\ Channel0 TxDMA (logic device 32) and port-th MAC (logic device 64,65,66,67).
\ Set logic device group 63 for Device Error (logic device 68)
\
\ Notice that these registers are blocked off in NIU and must be accessed
\ via Hypervisor APIs.
\ 
    0 constant ld-rx-dma0
d# 32 constant ld-tx-dma0
d# 64 constant ld-mac0
d# 68 constant ld-sys-err

: set-ldg   ( -- ) 
   ld-rx-dma0     ldg0  ldg-num-i!
   ld-tx-dma0     ldg0  ldg-num-i!
   ld-mac0 port + ldg0  ldg-num-i!
   ld-sys-err     ldg63 ldg-num-i!
;


\ RX descriptor Initialization
\ rbuf-io-adr: io addr of a 8K data block buffer for hw to use.
\ rmd-cpu-adr: cpu addr of a Rx descriptor entry for driver to use.
\  Before lshift
\  63		43			0
\  +-----------+------------------------+
\  |xxxxxxxxxxx|   high addr   low-adr	|
\  +-----------+------------------------+
\  After lshift 20 then xrshift 32
\  63			31		0
\  +------------------+-----------------+
\  |000000000000000000|	  high addr	|000low-adr00
\  +------------------+-----------------+
\			43	       12	    0
\ After this word is called, we should see initialized rx 
\ descriptors at cpu memory location rmd-cpu-adr
\ which is the result of 
\     i rmd#>rmdaddr     
\ where rmd#>rmdaddr ( n -- addr ) is defined as
\          /rmd *  rmd0 + ;
\ Do dump rmd0 to see the contents

: rmd-init        ( rbuf-io-adr rmd-cpu-adr -- )
   dup		  ( rbuf-io-adr rmd-cpu-adr  rmd-cpu-adr )
   rot		  ( rmd-cpu-adr  rmd-cpu-adr  rbuf-io-adr )
   d# 20 lshift d# 32 xrshift \ Clear bits[63:44] & bits[11:0] of rbuf-io-adr
   swap	  ( rmd-cpu-adr  rbuf-io-adr' rmd-cpu-adr )
   descriptor32! ( rmd-cpu-adr ) \ Store rbuf-io-adr' in cpu-rmaddr
                                 \ rmd is 32 bits!
   /rmd synciopb \ dma sync using a cpu address
;

\ RX completion descriptor initialization
\ Fill deadbeef to rcd entry. HW will fill in meaningful values after
\ receiving packets.
\
: rcd-init             ( rcd-cpu-adr -- )
   h# dead.beef over   ( rcd-cpu-adr deadbeef rcd-cpu-adr )
   descriptor64!       ( rcd-cpu-adr )
   /rcd synciopb      \ sunc so that HW will get the newest data
;

\ TX descriptor initialization called by transmit.
\ o "Transfer length" (TR_LEN, bits[56:44]) of Neptune Tx Packet
\   descriptor is 13 bit long , so the TR_LEN mask is 0x1FFF.
\ o Mark bit is never set, so we do not request interrust after Tx.
\ o Here we store header with tmdheader! and store pointer to data
\   buffer with txbufptr! We could have combined them into one. Actually 
\   we do not need to make Tx descriptor point to the shared Tx data
\   buffer before each time we use it because doing it once at
\   initialization is enough. 
\ o Although the MARK bit of the descriptor will cause an interrupt 
\   after the packet is transmitted only if interrupt is enabled, 
\   we still set it hoping that it will still cause the MK bit of 
\   the TX_CS register to be turned on.  In send-wait we will 
\   check that bit to make sure that the packet has indeed been
\   transmitted. 
\
: tmd-init         ( txbuf len tmdaddr -- )
   swap            ( txbuf tmdaddr len ) 

   \ First Check len
   dup tr-len-mask d# 44 xrshift  ( txbuf tmdaddr len len 0x1fff)
   > if cmn-error[ " Application data too long" ]cmn-end
      true to restart?  \ Set flag, will restart at the end of transmit
   then 
   d# 44 lshift    \ Shift TR_LEN(len) of appl data to bits[56:44]
   tr-len-mask and ( txbuf tmdaddr len )     \ bits[56:44] is len
   sof or          ( txbuf tmdaddr len|SOF ) \ Every packet is sof 
   mark or         ( txbuf tmdaddr len|SOF|MARK ) 
   num-ptr=1 or    ( txbuf tmdaddr len|SOF|MARK|NUM_PTR ) 
   over            ( txbuf tmdaddr value tmdaddr )  
   tmdheader!      ( txbuf tmdaddr )
   swap            ( tmdaddr txbuf )
   cpu>io-adr      ( tmdaddr txbuf-io-adr )
   over            ( tmdaddr txbuf-io-adr tmdaddr )
   txbufptr!       \ store the txbuf-io-addr into the pointer part of tmd
   /tmd synciopb   \ dma sync the tmd entry
;


\ 14 bits L2_LEN is bit[53:40] of Rx completion ring entry.
\ Do shifts so that the 64 bit values contains only the packet length
\
: rcdaddr>pkt-len ( rcdaddr -- pkt-len )
   descriptor64@ d# 10 lshift d# 50 xrshift
;

\ With the cpu address of a Rx Completion Ring descriptor, read the
\ contents of the descriptor with descriptor64@, then shift out 
\ PKTBUFSZ (bits[39:38] of the descriptor entry), which indicates the
\ partition of the 8K block buffer. 00=BUFSZ0, b01=BUFSZ1, b10=BUFSZ2
\ b11=single block=8K
\
: rcdaddr>pbuf-size ( rcdaddr -- pbuf-len )
   descriptor64@ d# 24 lshift d# 63 xrshift
;

\ With the cpu address of a Rx Completion Ring descriptor, read the
\ contents of the descriptor with descriptor64@, then shift out 
\ PKT_BUF_ADDR (bits[37:0] of the descriptor entry)
\
: rcdaddr>pbuf-addr ( rcdaddr -- pbuf-addr )
   descriptor64@ d# 26 lshift d# 26 xrshift
;


\ It is easy to figure out rcd# from the (cpu) address of rcd.
\ Inside rcd we can find the io-adr of the rx block buffer and
\ the offset of the packet inside that block buffer.  With 
\ these two pieces of info, we can find the io-addr of the packet.
\ Finally we conver the io-adr of the packet to its cpu-adr
\                          43                       6     0 ( real io adr)
\ RCR  63                  37                       0       ( RCR bits )
\      | flags            |<----- packet-io-addr----|----->|
\                                                    bits[5:0]=0 implied

: rcdaddr>pkt-cpu-adr ( rcd-cpu-addr -- pkt-cpu-adr )
   descriptor64@ d# 26 lshift d# 20 xrshift   \ Get rid of flags
   io>cpu-adr         ( pkt-adr )
;

: rcd#>skip ( n -- #skip )
   rcd#>rcdaddr descriptor64@ d# 55 xrshift 3 and
;
                                                           
\ Sync buffer contents
: sync-buf        ( buf-cpu-adr len -- )
   over          ( buf-cpu-adr len buf-cpu-adr )   
   cpu>io-adr    ( buf-cpu-adr len buf-io-adr ) 
   swap          ( buf-cpu-adr buf-io-adr len ) 
   dma-sync      ( )
;

variable nextrcd
variable nexttmd

\ Get current rx completion descriptor ring pointer in CPU address space. 
: nextrcd@  ( -- rcd-cpu-addr )  nextrcd x@ ;

\ Get current tx message descriptor ring pointer in CPU address space. 
: nexttmd@  ( -- tmd-cpu-addr )  nexttmd x@ ;

\ Save current rx completion/tx message descriptor ring pointer in
\ CPU address space.
\ Note that we write a rcd address to nextrcd variable, not contents of
\ a rcd to nextrcd
\
: nextrcd! ( rcdaddr -- )  nextrcd x! ;

: nexttmd! ( tmdaddr -- )  nexttmd x! ;

: tx-config ( chan -- )
   0 tx-addr-md!    \ Use 64 bit addressing mode

   niu? 0= if
      \ Define only page0, page1 will not be checked.  
      \ Set the FUNC field (bits[3:2]) of register TX_LOG_PAGE_VLD to 
      \ port (it equals PCI function number) which will "be used when 
      \ sending request across PCI bus". 
      port 2 lshift page0 or     ( chan# val )  \ val = FUNC|PAGE0
      over tx-log-page-vld-i!    \ Use only chan#-th Rx DMA channel

      \ All mask bits are set to 0 so there is no relocation. 
      0 over tx-log-mask1-i!      
      0 over tx-log-value1-i!  
      0 over tx-log-mask2-i!     
      0 over tx-log-value2-i!      
      0 over tx-log-page-relo1-i!  \ Since mask=0, this doesn't matter 
      0 over tx-log-page-relo2-i!  \ Since mask=0, this doesn't matter 
      0 over tx-log-page-hdl-i!    \ Assume no need to extend to 64 bits
   then
   drop

   \ Weight of Deficit Round Robin for multiple Tx DMA chan to share a port.
   h# 2710 chan# txc-dma-max-i!  

   \ Do not inject parity error to any of the 24 DMA 
   0 tdmc-inj-par-err! 

   \ Debug select register, set to initial value
   0 tdmc-dbg-sel!

   \ TDMC training vector register, set to default value
   0 tdmc-training-vector!
;


: rx-config  ( chan -- )
   \ System clock divider, granularity for dma timeout.
   h# 1d4c rx-dma-ck-div! 

   set-default-rdc-for-my-port

   \ Use 64 bit addressing mode. But test shows that bit0 = 1 (MODE32) 
   \ also works.
   0 rx-addr-md!

   \ Weights of Deficit Round Robin (DRR) for 4 ports
   h# 400 pt-drr-wt0!
   h# 400 pt-drr-wt1!
   h#  66 pt-drr-wt2!
   h#  66 pt-drr-wt3!

   niu? 0= if
      \ Logic pages related registers. All mask bits are set to 0 
      \ so there is no relocation. Only page0 is defined so page1 will 
      \ not be checked.  Bits[3:2] of register RX_LOG_PAGE_VLD (FUNC)
      \ is set to the PCI function number (which is equal to the port 
      \ number). The FUNC field is used when we make PCI request
      port 2 lshift page0 or		( chan x1 ) 
      over rx-log-page-vld-i!  

      0 over rx-log-mask1-i!      
      0 over rx-log-val1-i!      
      0 over rx-log-mask2-i!     
      0 over rx-log-val2-i!     
      0 over rx-log-page-relo1-i! \ Since mask=0, this doesn't matter 
      0 over rx-log-page-relo2-i! \ Since mask=0, this doesn't matter 
      0 over rx-log-page-hdl-i!   \ Assume no need for 64 bits

      \ Set MBADDR_L=0, OFFSET=no, FULL_HDR  
      full-hdr over rxdma-cfig2-i!
   else
      io-rmbox xlsplit nip		( chan addr.lo )
      over rxdma-cfig1-i!		( chan )

      \ RXMAC configuration2
      io-rmbox xlsplit drop		( chan addr.hi )
      full-hdr or			( chan addr.hi' )
      over rxdma-cfig2-i!		( chan )
   then					( chan )
 
   \ Disable mailbox
   dup rx-dma-ctl-stat-i@ mex invert and ( chan x1 )
   swap rx-dma-ctl-stat-i!		(  )
;

: wait-sng-state ( -- flag )
   chan# tx-cs-i@ sng-state and 0<>  \ SNG_STATE=1 if reset is done
;

: wait-for-dma-engine-to-stop ( -- ok? )
   d# 3000 ['] wait-sng-state wait-status
   dup 0= if
      cmn-error[ " SNG_STATE did not reset" ]cmn-end
   then
;

\ Check if RST is cleared by HW and if QST is 1 which
\ incidates all state machines are in initial state
: wait-rx-dma-reset ( chan# -- flag ) 
   dup  rxdma-cfig1-i@ rxdma-rst and 0=         \ RST = 0 ? 
   swap rxdma-cfig1-i@ rxdma-qst and 0<> and    \ QST = 1 ? 
;

\ PRM: "First set EN bit to zero, and then set RST bit to 1.  
\ After RST bit is cleared by hardware and the QST bit is set
\ to 1, software may then start configuring the DMA channel. 
\ After configuration, software may then set the EN bit to 1 
\ to enable the DMA.
\ 
\ First disable Rx DMA by setting EN bit of RXDMA_CFG1 to 0
\ then set RST bit and poll it until hardware clears it. 
\ After this call, we can start configuring the DMA channel.
\ We will enable the Rx DMA in enable-tx-dma-channel which is
\ called at the end of (setup-link).
\
: reset-rx-dma-channel        ( chan# -- ok? )
    dup dup         
    rxdma-cfig1-i@            ( chan# chan# val ) 
    rxdma-en invert and swap  ( chan# val&[~EN] chan# )
    rxdma-cfig1-i!            ( chan# )  
    dup                       ( chan# chan# ) 
    \ Just set RST bit, do not read first
    rxdma-rst swap            ( chan# val|RST chan# ) 
    rxdma-cfig1-i!            ( chan# ) 
    d# 100 swap               ( 100 chan# )
    ['] wait-rx-dma-reset wait-status-with-arg
    dup 0= if                     ( ok? )
       cmn-error[ " reset-rx-dmc-channel failed" ]cmn-end
    then 
;

\ The PRM states:
\ "The DMA channel may be reset by writing a 1 to the RST bit. When
\ reset is completed, hardware will set the RST_STATE bit to 1." 
\ In the description of the RST bit of the TX_CS register, PRM also 
\ mentions "Hardware will clear this bit after reset is completed."
\ We check the completion of DMA reset by checking both RST=0 and 
\ RST_STATE=1. 
\
: wait-tx-dma-reset  ( chan# -- flag ) 
   dup  tx-cs-i@ rst       and 0=
   swap tx-cs-i@ rst-state and 0<> and 
;

: cleanup-tx-dma-channel ( chan# -- )
   \ Must clear TAIL because the HW will not clear it.  If driver 
   \ does not clear TAIL, HEAD will follow TAIL to the non-zero value
   \ when enable-tx-dma-channel is called and that will cause trouble. 
   0 swap                    ( 0 chan ) 
   tx-ring-kick-i!           (  ) 

   \ Must clear WRAP so that both sw and hw start with WRAP=0
   wrap=0 to wrap
;

\ First sets the RST bit of TX_CS to 1 and poll RST and RST_STATE 
\ until HW clears RST and sets RST_STATE.  RST_STATE=1 indicates that 
\ the DMA channel is in a stall state and is waiting for the driver 
\ to do configuration. We will bring the DMA channel out of stall 
\ state later by clearing RST_STATE in word "enable-tdma" after DMA 
\ configuration is done.
\
: reset-tx-dma-channel            ( chan -- ok? )
   dup                            ( chan chan )  
   tx-cs-i@                       ( chan val )
   rst-state and if               ( chan )   \ Already in reset state
      true                        ( chan true )    
   else                           ( chan )
      stop-n-go over              ( chan STOP_N_GO chan ) 
      tx-cs-i!                    ( chan )
      wait-for-dma-engine-to-stop ( chan ok? )
      0= if  			  ( chan )
         cmn-error[ " TX DMA engine did not stop" ]cmn-end
         false                    ( chan false )
      else  
         dup tx-cs-i@             ( chan val )
         rst-state                ( chan val RST_STATE ) 
         and 0= if                ( chan ) \ Reset if not in reset state 
            RST over              ( chan RST chan )
            tx-cs-i!              ( chan )
         then                     ( chan )
         dup wait-tx-dma-reset    ( chan ok? )  
         dup 0= if cmn-error[ " TX DMA engine did not reset" ]cmn-end then
      then                        ( chan ok? ) 
   then                           ( ok? )
   swap cleanup-tx-dma-channel    ( ok? )
;

: reset-dma-channel            ( chan -- ok? )
   niu? if
      cleanup-tx-dma-channel true ( ok? )
   else                           ( chan )
      dup  reset-tx-dma-channel   ( chan ok1? ) 
      swap reset-rx-dma-channel   ( ok1? ok2? )
      and                 
   then
;

\ Initialize RX descriptor and completion rings for one DMA channel
\
: init-rxrings   ( -- )
   #rmds 4 - 0 do          
      \ Prepare args for rmd-init  ( rbug-io-adr rmd-cpu-adr -- ) 
      i rbuf#>rbuf-io-adr          \ dev addr of ith 8K data block  
      i rmd#>rmdaddr               \ cpu addr of ith Rx Descriptor     
      rmd-init   
   loop

   #rcds 0 do         
      i rcd#>rcdaddr  \ Prepare arg for rcd-init 
      rcd-init        \ Fill 0 to each of 256 rcd entry 
   loop

   rcd0 nextrcd!        
;

\ Initialize a Tx descriptor ring for one DMA channel. 
\ Use only one Tx buffer.  
\ The address stored in the Tx packet descriptors is io address.
\
: init-txring  ( -- )
   #tmds 0 do         
      io-tbuf0         \ Addr of the 4K Tx data buffer 
      i tmd#>tmdaddr   \ Starting addr of i-th descriptor 
      txbufptr!        \ Store io-tbuf0 in the 2nd 8bytes of tmd  
   loop                \ All 64 tmds point to the same 4K data buffer
   tmd0 nexttmd!
;


\ These "cached" Rx errors are updated in update-rx-err-status.
\ This word set fatal rx error flag if any of the cached error
\ is non-zero. 
\
: fatal-rx-errors? ( -- flag )
   rx-dma-err-status   
   rdmc-pre-err-status    or
   rdmc-sha-err-status    or 
   rx-ctl-dat-fifo-status or
   ipp-int-err-status     or 
;

: fatal-tx-errors? ( -- glag )
   tx-dma-err-status     
;

0 value txerr-status   \ TX MAC Error status bits
0 value rxerr-status   \ RX MAC Error status bits

defer restart-net  ( -- ok? )   
['] true to restart-net                                     

: update-tx-err-status   ( -- )
   \ Fatal Tx DMA errors
   chan# tx-cs-i@ tx-dma-fatal-errs and
   tx-dma-err-status or to tx-dma-err-status

   \ MAC Tx errors
   update-mac-tx-err-stat

   \ XPCS, PCS also have error registers, but they
   \ are not listed as fatal by the PRM.
;

: update-rx-err-status  ( chan -- )
   \ Fatal Rx DMA errors 
   rx-dma-ctl-stat-i@ rx-dma-fatal-errs-mask and	( stat )
   rx-dma-err-status or dup 0<> if 			( stat )
      cmn-error[ dup " rx-dma-fatal-errs = %x" ]cmn-end then
   to rx-dma-err-status					(  )
   
   rdmc-pre-par-err@ rdmc-pre-par-errs-mask and		( stat )
   rdmc-pre-err-status or dup 0<> if 			( stat )
      cmn-error[ dup " rdmc-pre-par-errs = %x" ]cmn-end then
   to rdmc-pre-err-status				(  )

   rdmc-sha-par-err@ rdmc-sha-par-errs-mask and 	( stat )
   rdmc-sha-err-status or dup 0<> if 			( stat )
      cmn-error[ " rdmc-sha-par-errs = %x" ]cmn-end then
   to rdmc-sha-err-status				(  )

   \ bits[3:0] of RX_CTL_DAT_FIFO_STAT are IPP_EOP_ERR for port3:0
   \ bits[7:4] of RX_CTL_DAT_FIFO_STAT are ZCP_EOP_ERR for port3:0
   \ Since we do not initialize other ports, we should care about 
   \ our own port only. For example, if we are using port 1, we
   \ should only care about bit1 and bit 4.  
   \ Bit 8 (h# 80) is for ID mismatch. Bits[63:9] are RSVD
   h# 11 port lshift h# 80 or		( mask )
   rx-ctl-dat-fifo-stat@ and		( stat )
   rx-ctl-dat-fifo-errs-mask and	( stat' )
   rx-ctl-dat-fifo-status or		( stat'' )
   dup 0<> if 				( stat'' )
      cmn-error[ " rx-ctl-dat-fifo-errs = %x" ]cmn-end
   then					( stat'' )
   to rx-ctl-dat-fifo-status		(  )

   \ Fatal IPP errors
   port ipp-int-stat-p@  		( stat )
   ipp-int-stat-errs-mask and		( stat' )
   ipp-int-err-status or dup 0<> if	( stat'' )
      cmn-error[ " ipp-int-stat-errs = %x" ]cmn-end then
   to ipp-int-err-status		(  )

   \ Serious XMAC or BMAC errors, but we do not set the restart? flag.
   update-mac-rx-err-stat 		(  )

   \ XPCS, PCS also have error registers, but
   \ none of them are fatal so we do not count them 
;

\ Display transmit errors.
: .transmit-errors ( -- )
   \ Fatal Tx DMA errors 
   tx-dma-err-status tx-ring-oflow       and 0<> if ." TX_RING_OFLOW"    cr then
   tx-dma-err-status pref-buf-par-err    and 0<> if ." PREF_BUF_PAR_ERR" cr then
   tx-dma-err-status nack-pref           and 0<> if ." NACK_PREF"        cr then
   tx-dma-err-status nack-pkt-rd         and 0<> if ." NACK_PKT_RD"      cr then
   tx-dma-err-status conf-part-err       and 0<> if ." CONF_PART_ERR"    cr then
   tx-dma-err-status pkt-prt-err         and 0<> if ." PKT_PRT_ERR"      cr then
   .mac-tx-err
;

\ Display receive errors.
: .receive-errors  ( -- )
   ." Rx Error: " cr
   \ Fatal DMA Error 
   rx-dma-err-status      rbr-tmout    and 0<> if ." BR_TMOUT"    cr then
   rx-dma-err-status      rsp-cnt-err  and 0<> if ." RSP_CNT_ERR" cr then 
   rx-dma-err-status      byte-en-bus  and 0<> if ." BYTE_EN_BUS" cr then 
   rx-dma-err-status      rsp-dat-err  and 0<> if ." RSP_DAT_ERR" cr then 
   rx-dma-err-status      rcr-ack-err  and 0<> if ." RCR_ACK_ERR" cr then 
   rx-dma-err-status      dc-fifo-err  and 0<> if ." DC_FIFO_ERR" cr then 
   rx-dma-err-status      rcr-sha-par  and 0<> if ." RCR_SHA_PAR" cr then 
   rx-dma-err-status      rbr-pre-par  and 0<> if ." RBR_PRE_PAR" cr then 
   rx-dma-err-status      config-err   and 0<> if ." CONFIG_ERR"  cr then 
   rx-dma-err-status      rcrincon     and 0<> if ." CRINCON"     cr then
   rx-dma-err-status      rcrfull      and 0<> if ." RCRFULL"     cr then 
   rx-dma-err-status      rbrfull      and 0<> if ." RBRFULL"     cr then 
   rx-dma-err-status      rbrlogpage   and 0<> if ." RBRLOGPAGE"  cr then 
   rx-dma-err-status      cfiglogpage  and 0<> if ." CFIGLOGPAGE" cr then 
   rdmc-pre-err-status    pre-par-err  and 0<> if ." RDMC_PRE_PAR.ERR"  cr then
   rdmc-pre-err-status    pre-par-merr and 0<> if ." RDMC_PRE_PAR.MERR" cr then
   rdmc-sha-err-status    sha-par-err  and 0<> if ." RDMC_SHA_PAR.ERR"  cr then
   rdmc-sha-err-status    sha-par-merr and 0<> if ." RDMC_SHA_PAR.MERR" cr then
   rx-ctl-dat-fifo-status id-mismatch  and 0<> if ." ID_MISMATCH" cr then
   rx-ctl-dat-fifo-status zcp-eop-err  and 0<> if ." ZCP_EOP_ERR" cr then
   rx-ctl-dat-fifo-status ipp-eop-err  and 0<> if ." IPP_EOP_ERR" cr then
   \ Fatal IPP errors
   ipp-int-err-status     sop-miss     and 0<> if ." SOP_MISS"  cr then
   ipp-int-err-status     eop-miss     and 0<> if ." EOP_MISS"  cr then
   ipp-int-err-status     pfifo-und    and 0<> if ." PFIFO_UND" cr then
   \ Serious XMAC or BMAC errors
   .mac-rx-err
;

: transmit-errors?  ( -- flag )
   update-tx-err-status 
 
   \ Set restart? flag if update-tx-err-status has detected fatal error
   fatal-tx-errors? dup if   
      true to restart? 
   then

   \ Following error does not trigger restart. Simply report to caller 
   mactype xmac = if 
      tx-xmac-err-status or 
   else 
      tx-bmac-err-status or
   then
;

: receive-errors? ( chan -- err|0 )
   update-rx-err-status   ( -- )

   \ fatal-rx-errors? returns true if update-rx-err-status has recorded
   \ a fatal error
   fatal-rx-errors? if  
      true to restart? 
   then

   \ The following errors are also cached by update-rx-err-status  
   \ but we simply report them to the caller instead of treating them
   \ as fatal. 
   mactype xmac = if
      rx-xmac-err-status ( err )   \ 0 if no error 
   else
      rx-bmac-err-status
   then
;

\ Clear TX error bits in cached values.
: clear-tx-errors ( -- )
   tx-dma-err-status tx-dma-fatal-errs invert and 
   to tx-dma-err-status
   clear-mac-tx-err
;


\ Clear RX error bits in cached values.
: clear-rx-errors ( -- )
   rx-dma-err-status      rx-dma-fatal-errs-mask    invert and to 
   rx-dma-err-status
   rdmc-pre-err-status    rdmc-pre-par-errs-mask    invert and to 
   rdmc-pre-err-status
   rdmc-sha-err-status    rdmc-sha-par-errs-mask    invert and to 
   rdmc-sha-err-status 
   rx-ctl-dat-fifo-status rx-ctl-dat-fifo-errs-mask invert and to 
   rx-ctl-dat-fifo-status
   ipp-int-err-status	  ipp-int-stat-errs-mask    invert and to 
   ipp-int-err-status
   clear-mac-rx-err
;

\ Clear the rst-state bit to start 
\ the dma after we have done configuration.
\
: enable-tx-dma-channel   ( chan -- )
   dup  tx-cs-i@ rst-state invert and   ( chan mod_val )
   swap tx-cs-i! 
;

: enable-rx-dma-channel   ( chan -- )
   dup rxdma-cfig1-i@ rxdma-en or swap rxdma-cfig1-i!
;


\ We have a tx descriptor ring constructed already, now tell the 
\ Neptune about it. 
\
: init-tx-regs  ( chan -- )
   \ Set length of ring to 64 and set STADDE_BASE:STADDR to the
   \ the IO address of the Tx ring
   len=64 io-tmd0 or 		( chan x1 )
   over tx-rng-cfig-i!		( chan )

   \ Disable events that may trigger interrrups.
   tx-dma-ent-dis-msk swap tx-ent-msk-i!
;

\ last-partition-of-rbuf? depends on how we partion the 8K 
\ Rx block buffer.  We divide it into 4K and 2K
\
: init-rx-regs  ( chan -- )
   \ Initialize rmd related config registers. Tell Neptune that 
   \ rmd has #rmds entries.  Its base addr is io-rmd0
   #rmds d# 48 lshift io-rmd0 or 	( chan x1 )
   over rbr-cfig-a-i! 			( chan )

   \ Tell Neptune that each block is 8K, and it should partition 
   \ the blocks into 4K, 4K and 2K sub-blocks.  2K is always greater 
   \ than the size of non-jumbo Ethernet frames.
   bksize=8k    			( chan x2 )
   vld2 or bufsz2=4k or			( chan x2' )
   vld1 or bufsz1=2k or			( chan x2'' )
   vld0 or bufsz0=2k or 		( chan x2''' )
   over rbr-cfig-b-i!      		( chan )

   \ Initialize rcd related config registers
   \ Tell Neptune where the RCR is and the number of RCR entries 
   \ in the ring.

   #rcds d# 48 lshift io-rcd0 or	( chan x3 )
   over rcrcfig-a-i! 			( chan )
   
   pthres=1 entout or timeout=1 or 	( chan x4 )
   over rcrcfig-b-i!			( chan )

   \ Disable events that may trigger interrups.
   rx-dma-ent-disable-mask over rx-dma-ent-msk-i!  

   \ Enable Weighted Random Early Discard (WRED) to prevent the rings 
   \ from overflow when there is an attack targeting at the Neptune's 
   \ MAC address.
   #rcds 2 / shift-thre-syn lshift	( chan x5 )
   0         shift-win-syn  lshift or	( chan x5' )
   #rcds 2 / shift-thre     lshift or	( chan x5'' )
   0         shift-win      lshift or	( chan x5''' )
   chan# rdc-red-para-i!  		( chan )

   \ Set OPMODE bit to enable WRED for all DMA. But we have set 
   \ parameters for channel 0 only. other channel will not be able
   \ to receive because the default value of RDC_RED_PARA causes 
   \ the WRED to drop all packets.  Init value 0x3456 is an arbitrary
   \ number that is known to have worked.
   h# 3456 opmode=1 or red-ran-init! 	( chan )

   #rmds 4 - dup to last-rmd-idx 	( chan x6 )
   over rbr-kick-i!  \ Kick some to begin

   \ As advised by PRM, write to RX_DMA_CTL_STAT to clear bit 35 
   \ so that RBR_EMPTY is cleared.
   over rx-dma-ctl-stat-i@ rbr-empty or over rx-dma-ctl-stat-i! 

   \ Disable mailbox update.
   dup rx-dma-ctl-stat-i@ MEX invert and swap rx-dma-ctl-stat-i!
;

\ Neptune has 69 (LD) interrupt sources and 64 (LDG) logic groups for
\ generating interrupts. set-ldg has set LDGs as follows, 
\ LDG0 for Rx DMA0 (LD0), Tx DMA0 (LD32) and  port-th-MAC (LD64,65,66,67).
\ LDG 63  LD68 Device Error.  After calling this word, events from these
\ two logic groups will not be able to trigger interrupt 
\
: disable-all-intrs ( -- )
   ldg0  ldgimgn-i@ arm invert and ldg0  ldgimgn-i!
   ldg63 ldgimgn-i@ arm invert and ldg63 ldgimgn-i!

   disable-mac-intr
;

: init-dma-channel ( chan -- )  
   dup tx-config  		( chan )
   dup rx-config   		( chan )
   init-txring      		( chan )
   init-rxrings      		( chan )
   dup init-tx-regs  		( chan )
   dup init-rx-regs   		( chan )
   dup enable-tx-dma-channel	( chan )
   enable-rx-dma-channel	(  )
   disable-all-intrs   		(  )
;

 
\ Tell the HW that we have received a packet so that the HW will
\ update its ring head. Update nextrcd which is a software copy 
\ of the addr of next rcd  (Rx Completion-ring Descriptor)
\
: sync-and-update-nextrcd ( -- )
   \ Free current completion descriptor
   nextrcd@ rcd-init		(  )

   \ Update completion ring info, clear low 32 bits
   chan# rx-dma-ctl-stat-i@	( x1 )
   d# 31 lshift d# 31 xrshift	( x1' )
   ptrread=1 or pktread=1 or 	( x1'' )
   chan# rx-dma-ctl-stat-i!	(  )

   \ Update pointer to next completion descriptor
   nextrcd@ rcdaddr>rcd# 1 +	( x2 )
   rcd#>rcdaddr nextrcd!	(  )
;


\ If an 8K block buffer has been used up, then we reclaim  
\ it  kick it back to the Neptune. We can get the starting 
\ address of the 8K block buffer a pakcet belongs to by clearing 
\ the lower 13 bits of the the packet address (rcdaddr). Note that 
\ since the rmd omits the lower 12 bit for 4K boundary, bit 12 
\ is the LSB in rmd, which MUST be 0 in order to use 8K block buffers.
\ Original content of rcd:
\  63	 RCD		 37		   6	 0
\  +--------------------+-----------------+-------+
\  |	 flags		|  bits[43:6] of pkt adr  | 
\  +--------------------+-----------------+-------+
\	    actual addr: 43		  12	 6 (bits[5:0]=0 for 
\                                                  64B alignment)
\ Above io address of the packet reported by the hardware via
\ RCR may not be the same as the starting io address of the 
\ 8K block buffer (because the packet may not be the first 
\ partition in that block buffer). So we need to clear bits[12:6] 
\ in addition to the implied zero bits[5:0] to make a 8K aligned 
\ address. That is the starting address of the 8K block buffer
\ to be reclaimed and kicked back to the hardware.
\ We xrshift 7 bits then lshift 13 bits to clear the lowest 13 bits.

\  63	 	  43		         	 0
\  +-------------+--------------------------------+
\  |	         | addr bits[43:13]  0000000000000|   
\  +-------------+--------------------------------+
\ 
: reclaim-rx-buffer  ( nextrcdaddr -- )
   descriptor64@   \ Got contents of a Rx completion ring entry 

   \ Shift to get the starting address of the 8K block buffer 
   \ which the packet is in.
   7 xrshift d# 13 lshift  ( rbuf-io-adr )
   last-rmd-idx	   ( rbuf-io-adr rmd# ) \ Get recorded kicked rmd
                                        \ index (Its initial value  
                                        \ is #rmds - 4)
   rmd#>rmdaddr	   ( rbuf-io-adr rmd-cpu-adr )
   rmd-init	   ( )  \ Puts rbuf-io-adr in a rmd in cpu addr

   \ Update soft kick state and kick register
   last-rmd-idx 1+     \ New last-kicked-rmd-idx 
  
   1 chan# rbr-kick-i! \ Different from Cassini which kicks 
                       \ the rmd index, here we kick BKADD, which
                       \ stands for "number of BlocK buffer ADDed.

   \ If rmd index is greater than #rmds, wrap it back to 0
   #rmds mod 
   to last-rmd-idx     \ Even if we did not kick a rmd, still record it 
;                     


\ last-partition-of-rbuf? checks if the packet just received 
\ took the last partition of the 8K block buffer. If yes,
\ then we recycle the whole 8K block buffer; if not, then we
\ wait until all the partitions in the 8K block buffer
\ have been used by the hardware.
\
\ Neptune's Rx completion ring entry carries the addr of
\ a packet buffer inside a 8K block buffer. We can figure out
\ if a packet is the last packet in the block buffer by checking
\ its address. For 8K block buffers, the address of the last
\ packet has the following bits as 1s
\ 8K block buffer
\ If pkt uses size 0(1K) and if bits[12:10] ==111 --> last packet
\ If pkt uses size 1(2K) and if bits[12:11] ==11  --> last packet
\ If pkt uses size 2(4K) and if bits[12]    ==1   --> last packet
\
\ For example, below is a Rx completion ring entry for a packet
\ that uses a 1K partition inside the 8K buffer block. If bits[12:10]
\ of a size0 partition are 111 (which are bits[8:6] of the RCR entry), 
\ then this packet has taken the last 1K sub-block of the 8K buffer. 
\ (Bits[5:0] of the packet address are outside of the RCR entry 
\ because the the address is 64B aligned)
\ 
\  63	 		 37		   6	 0
\  +--------------------+-----------------+-------+
\  |	 flags		|   high addr	  |111XXXX|xxxxxx
\  +--------------------+-----------------+-------+
\			 43		  12  9  6 543210
\
: last-partition-of-rbuf? ( nextrcdaddr -- need-to-release? )
   dup rcdaddr>pbuf-addr swap ( pktbuf-addr nextrcdaddr )
   rcdaddr>pbuf-size      \ return 0,1,2 represent size0,1,2

   \ Switch based on the PKTBUFSZ field of the Receive 
   \ Completion Ring Entry
   case
      \ If bits[39:38] (PKTBUFSZ) are zero, it means this packet
      \ was put in a BUFSZ0(set to 2K) partition. The partition
      \ is the last one in the 8K block buffer if bits[12:10] of
      \ the RCR descriptor are 11. Therefore we must release the 
      \ whole 8K buffer. 
      bufsz0 of 
         d# 57 lshift d# 62 xrshift b# 11 =   \ bufsz0=2k 
      endof  

      \ If bits[39:38] (PKTBUFSZ) are b01, this packet was 
      \ put in a BUFSZ1(was also set to 2K) partition. The partition
      \ is the last one in the 8K block buffer if bits[12:11]
      \ of the RCD are 11.  
      bufsz1 of 
	 d# 57 lshift d# 62 xrshift b#  11 =  
      endof

      \ If bits[39:38] (PKTBUFSZ) are b10, this packet was 
      \ put in a BUFSZ2(set to 4K) partition. The partition
      \ is the last one in the 8K block buffer if bit12 of the 
      \ RCD is 1.
      bufsz2 of 
         d# 57 lshift d# 63 xrshift b#   1 =
      endof

      singleblk of 
         \ If packet takes whole 8K block, then set need-to-release? = true
         drop true 
      endof   

      \ drop the contents of descriptor
      dup cmn-error[ " Bad packet size: 0x%x " ]cmn-end
   endcase
;

: return-rx-buffer ( rcd-cpu-addr -- )
    dup last-partition-of-rbuf?     ( rcd-cpu-addr last-partion-in-8K-block? ) 
    if                      ( rcd-cpu-addr )
       reclaim-rx-buffer    ( )  \ Reclaim one 8K data block
    else 
       drop
    then
    sync-and-update-nextrcd  \ Clear curr rcd, syncronize with HW by
                             \ telling HW the pkt and the rcd we just read
                             \ and move to next rcd regardless reclaim or not
;


\ Do nothing if receive-errors?  reports false
\
: process-receive-errors  ( chan -- )
    receive-errors? if      \ chan is consumed by receive-errors?
       .receive-errors  
       restart? if          \ restart? is set in receive-errors?  if we
           restart-net drop \ see any fatal or serious error. Note that 
       then                 \ MAC Rx overflow error does not set restart? 
       clear-rx-errors      \ flag, we only print and clear it here.
    then
;

\ Before driver reads data received by the HW, it first polls to see 
\ if there is any packet ready to be read by SW by checking the contents
\ of the next RCR, if its packet address is not the initialized value 0,
\ then HW has something for us.  To check the contents of the next
\ RCR entry, we first call synciopb to make sure that device will do
\ a DMA sync to putback the latest data into the dma memory before we
\ read it.  After synciopb, we can confidently read the contents of
\ the next RCR entry to check if there is any packet for us. 
\
: rcr-has-pkt? ( -- pkt-waiting? )
   chan# process-receive-errors 

   1 chan# rcr-flsh-i!   \ Force HW to flash latest info to DRAM
                         \ But test shows that we do not have to flush.

   chan# rcrstat-a-i@ 
;

\ Check where the packet is and how long the packet is.
\
: get-pkt-addr&len-from-rcr ( -- nextrcdaddr pkt-cpu-adr pktlen )
   \ Get packet address and length
   nextrcd@             ( nextrcd-cpu-addr ) 
   dup dup               
   \ In the rcd what we get is the RBR(pkt)'s io addr.  
   \ rcdaddr>pkt-cpu-adr converts the io address to cpu address
   rcdaddr>pkt-cpu-adr  ( nextrcd-cpu-addr nextrcd-cpu-addr pkt-cpu-adr )   
   swap                 ( nextrcd-cpu-addr pkt-cpu-adr nextrcd-cpu-addr )
   rcdaddr>pkt-len      ( nextrcd-cpu-addr pkt-cpu-adr pkt-len ) 

   \ Sync contents of Rx packet buffer before looking at it   
   \ Note that this DMA sync is for packet buffer (whose address was obtained
   \ from RCR entry) rather than for the RCR entry itself.  rcr-has-pkt? has
   \ done DMA sync for RCR entry with synciopb. 
   2dup                 ( nextrcd-cpu-addr pkt-cpu-adr pkt-len pkt-cpu-adr pkt-len ) 
   sync-buf             ( nextrcd-cpu-addr pkt-cpu-adr pkt-len )
;

: send-wait  ( chan -- ok? )
   d# 4000 get-msecs + false ( chan out-time false )
   begin
      over                   ( chan out-time f out-time ) 
      timed-out?             ( chan out-time f T/F )
      0=                     ( chan out-time f F/T ) 
      over                   ( chan out-time f F/T f )
      0=                     ( chan out-time f F/T t ) 
      and                    ( chan out-time f F/T ) \ F/T=F if TO
      \ Enter while only if true ( not TO and f has not been replace by T ) 
   while                     ( chan out-time f )
      >r over                ( chan out-time chan ) ( r: false )
      r> swap                ( chan out-time false chan )
      dup tx-head@           ( chan out-time false chan head )
      over tx-tail@          ( chan out-time false chan head tail ) 
      = if                   ( chan out-time false chan ) 
         dup tx-hdr-wrap@ over tx-tail-wrap@ = if  ( same as above )
            \ Check the MK bit of TX_CS register to double 
            \ check that the packet whose descriptor has the 
            \ MARK bit on has really been transmitted. This 
            \ read will set the MK bit to 0
            tx-cs-i@ mk and if         ( chan out-time false )
               drop true               ( chan out-time true )
            else
               ." MK bit is not on" cr ( chan out-time false )
            then
         else 
            . " Wrap mismatch" cr 
            drop       \ Drop chan before going to begin 
         then
      else                  ( chan out-time false chan )
         drop               ( chan out-time false ) 
      then
   repeat                   ( chan out-time f/t )
   -rot 2drop               ( f/t ) 
   dup 0= if                ( f/t ) 
      cmn-warn[ " Timeout waiting for Tx completion" ]cmn-end
      true to restart?
   then
;


\ When this word is called, the application data has been copied 
\ from application data buffer to the 4K Tx block buffer.
\
: transmit ( tbuf-cpu-adr len -- ok? )
   \ Sync contents of the TX buffer first
   2dup sync-buf    ( tbuf-cpu-adr len ) 

   \ Initialize TX message descriptor (tmd). The tmd has two 
   \ parts, Bits above bit43 are for "header", which contain info
   \ such as the length of the application data, start-of-frame
   \ (SOF) indicator, etc.  Bits[43:0] is for storing the io 
   \ address of the 4K Tx block buffer.  tmd-init constructs 
   \ the tmd.   
   nexttmd@    ( tbuf-cpu-adr len tmdaddr )
   tmd-init    ( len ) 

   \ Calculate TAIL for kick.
   \ in the PRM, TAIL of TX_RING_KICK register is specified as 
   \ an offset, in number of entries, from the staring address. 
   \ The following two lines figure out the offset.  
   nexttmd@ tmdaddr>tmd# 1 +  ( len tmd#+1 ) 
   #tmds mod                  ( len tail ) \ tail=(tmd#+1)mod64

   \ Because TAIL occupies bits[18:3] of TX_RING_KICK, left 
   \ shift the offset by 3.
   dup dup                    ( len tail tail tail ) 
   d# 3 lshift swap           ( len tail tail<<3 tail ) 

   \ PRM requires that if we wrap around Tx Ring, we should turn
   \ on the WRAP bit of TX_RING_KICK register
   0=                         ( len tail tail<<3 tail=0? )
   if                         ( len tail tail<<3 )
      wrap wrap=1 xor         ( len tail tail<<3 WRAP )
      dup to wrap             \ Save WRAP value for this round
   else
      wrap
   then                        
   or                         ( len tail WRAP||TAIL<<3 )   
   \ Now kick the descriptor to chan#-th DMA channel to start 
   \ transmission.

   chan# tx-ring-kick-i!       ( tail )

   \ "tail" on top of the stack is actually the tmd index.
   \ Convert it to tmdaddr (in cpu space) and save it in 
   \ nexttmd
   tmd#>tmdaddr nexttmd!      ( Empty ) \ Update nexttmd

   \ Wait for transmit completion 
   chan# send-wait             ( ok? )

   \ Check for transmit errors
   transmit-errors? if
      .transmit-errors clear-tx-errors drop false
   then

   restart? if restart-net 2drop false then
;

\ ASIC group endorsed IPP init sequence:
\   o Set interrupt mask
\   o Configure IPP (Enable/Disable ECC Correct/CRC Drop/Cksum...)
\   o Set max packet size IPP can handle
\   o Initialize IPP counters
\   o Enble IPP
\
: init-ipp ( -- )
   soft-rst port ipp-cfig-p!
   \ ipp-intr-msk port ipp-msk-p!   \ Mask off IPP interrupts

   \ Clear IPP counters by reading them
   port ipp-pkt-dis-p@ drop
   port ipp-bad-cs-cnt-p@ drop
   port ipp-ecc-p@ drop

   \ Enable IPP
   \ port ipp-cfig-p@
   ipp-max-pkt-default ipp-enable  or
   \ dfifo-ecc-en or      \ Enable ecc detection and correction
   \ drop-bad-crc or
   \ chksum-en    or      \ Enable tcp/ip udp checksum
   \ dfifo-pio-w  or
   \ pfifo-pio-w  or
   port ipp-cfig-p!
;

: (setup-link)    ( -- link-up? )
   chan# reset-dma-channel 0= if
      false exit			( flag )
   then

   init-ipp   \ IPP is between MAC and DMA, it is used by MAC loopback

   portmode 1g-copper = if 
      mac-mode normal =			( flag )
      mac-mode qgc-ext-loopback = or if (  )
         \ 1G copper has no serdes to init. 
         \ ASIC engr said there is no need to setup xcvr for 1G copper 
         setup-transceiver 		( flag )
         0= if false exit then		( flag )
         link-up?  0= if 		(  )
            cmn-note[ " Link is down." ]cmn-end false exit 
         then 				(  )
      then				(  )
   then					(  )

   portmode 10g-fiber = if		(  )
      mac-mode normal = 		( flag )
      mac-mode 2xgf-ext-loopback = or if (  )
         init-internal-serdes		(  )
         setup-transceiver 0= if	(  )
            false exit			( flag )
         then				(  )
         link-up?  0= if 		(  )
            cmn-note[ " Link is down." ]cmn-end false exit 
         then 				(  )
      then				(  )
      mac-mode serdes-ewrap-loopback = 	( flag )
      mac-mode serdes-pad-loopback = or if (  )
         init-internal-serdes		(  )
      then    				(  )
   then					(  )

   init-xif  \ Set xmac mode (10G 1G, loopback etc) 
   init-pcs  0= if cmn-error[ " PCS block init failed." ]cmn-end false exit then 

   \ PRM: "MAC software reset to clean up clock line glitches"
   reset-mac 0= if cmn-error[ " MAC block reset failed." ]cmn-end false exit then 
   init-mac 

   \ classification must be called after reset-mac. Otherwise 
   \ the hostinfo set by this function will be cleared by reset-mac.
   classification   

   chan# init-dma-channel   

   enable-mac
   enable-pcs
   true
;

\ If (setup-link) does not throw, then ['] (setup-link) catch 
\ returns a false (consider it as NO error) on top of the return value 
\ of (setup-link), which is the link-up? flag. 
\ If there is a throw (the only reason for (setup-link) to throw is
\ that the user has specified a parameter that is not supported by the
\ 1G-copper transceiver), then (setup-link) will gracefully abort 
\ and put a non-zero error code on top of the stack. The caller will
\ quit after seeing a non-zero error code. 
\
: setup-link ( -- [ link-status ] error? ) 
   ['] (setup-link) catch
;


: (restart-net) ( -- link-up? )
   false to restart?
   clear-tx-errors clear-rx-errors
   setup-link if  \ A non-zero value returned by setup-link means it has
      false       \ caught a throw from check-phy-capability. In that 
                  \ case, the link will never be up because the throw
                  \ implies that the user desired speed or duplex 
                  \ is not supported.  
   then           \ If setup-link has returned a 0, then just forward 
;                 \ the link-up? value (could be true or false) 
                  \ returned by (setup-link) to the caller.

['] (restart-net) to restart-net

: bringup-link ( -- ok? )
   d# 20000 get-msecs +	 false
   begin
      over timed-out? 0=  over 0=  and
   while
      setup-link if	   \ setup-link returns ( -- link-up? 0 ) if OK.
         2drop false exit  \ If there is a throw, which implies that
                           \ bringing up the link is impossible,
                           \ then drop the top 2 data (which are the 
                           \ expire time and the false) put on the stack
                           \ by this word and exit
      then    ( link-up? ) 

      \ Check the link-up? flag put on the stack by setup-link
      if
         drop true	   \ link-up? is true, so we are done.
      else		   \ link is not up yet, keep waiting
	 cmn-type[ " Retrying network initialization" ]cmn-end
      then
   repeat nip		   \ Nip the timeout value.
;


\ Neptune does not have global reset. This word resets sub blocks one by one. 
\ 
: resetall  ( -- )
   reset-transceiver       drop
   reset-mac               drop
   chan# reset-dma-channel drop
   niu? if
      chan# reset-tx-dma-channel drop
      chan# reset-rx-dma-channel drop
   then
   disable-all-intrs
;

headerless
   

