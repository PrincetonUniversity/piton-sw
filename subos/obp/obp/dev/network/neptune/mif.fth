\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: mif.fth
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
id: @(#)mif.fth 1.1 07/01/23
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

h# 1.0000 constant data-valid-bit     \ bit 16 of Clause 45 frame

\ TA field of IEEE802.3ae clause45 frame has two bits. When a clause45
\ frame operation is done, the lower bit of TA (named data-valid)
\ changes from 0 to 1.  We poll this bit for the completion of the
\ operation.
\    Note that the low 16 bits returned by mif-frame-output-reg@
\ are the register value if mdio-wait is called by mdio-read.
\    If mdio-wait is called by mdio-write, then the value
\ returned by mif-frame-output-reg@ will only be used
\ by mdio-write for error checking purpose. (See mdio-write)
\
: mdio-wait ( -- [ value true ] | false )
   d# 2000 get-msecs + false  ( end-time flag)
   h# abcd -rot               ( abcd end-time flag )
                              \ abcd is a place holder, to be replaced
                              \ by read back value.
   \ abcd and f below are value of the first loop 
   begin                      ( abcd end-time flag )
      over                    ( abcd end-time flag end-time )
      timed-out?              ( abcd end-time flag flag )
      0=                      ( abcd end-time flag flag )
      over                    ( abcd end-time flag flag flag )
      0=                      ( abcd end-time flag flag flag )
      and                     ( abcd end-time flag flag )
   while
      mif-frame-output-reg@   ( abcd end-time flag data )
      dup data-valid-bit      ( abcd end-time flag data data valid-bit-mask )
      and                     ( abcd end-time flag data valid? )
      0<> if                  ( abcd end-time flag data )
         h# ffff and          ( abcd end-time flag val )
         nip -rot             ( val abcd end-time )
         nip true             ( val end-time flag )
      else                    ( abcd end-time flag data )
         drop                 ( abcd end-time flag )
      then                    ( abcd end-time flag )
   repeat                     ( abcd end-time flag )
   nip dup 0= if nip then     ( val true | false )  
;

\ mdio-write is used to write an address or a data to a MDIO 
\ Manageable Device (MMD).
\
\ When it is used to write an address, the OP field of the clause45
\ frame is b'00, the data field (low 16bits) are the register addr.
\ When it is used to write a data, the OP field of the frame is
\ b'10, the data field contains the 16 bit data.
\ 
\ mdio-write calls mif-frame-outout-reg! to tell the serdes
\ the register address or data, then it calls mdio-wait which
\ in turn calls mif-frame-output-reg@ to check the data-valid bit 
\ to see if the write operation has succeeded (and also get the 
\ written data back for checking)
\
: mdio-write  ( frame -- )
   dup                      ( frame frame ) 
   mif-frame-output-reg!    ( frame )
   mdio-wait                ( frame [[value true] | false] )
   0= if                    ( frame [value | ] )
      cmn-error[ " mdio-write timed out." ]cmn-end
      drop                  ( )
   else                     ( frame value ) 
      \ When we call mdio-wait to check the data-valid bit, the 
      \ data portion (lower 16bit of the frame) should contain
      \ the same data we just wrote to the device. Here we check
      \ they indeed match, print an error message if not.
      h# ffff and           ( frame value&0xFFFF ) 
      swap h# ffff and      ( value&0xFFFF frame&0xFFFF )
      <> if cmn-error[ " mdio-write failed." ]cmn-end then
   then
;

\ mdio-read calls mif-frame-outout-reg! to tell the serdes
\ the address of the register which we will read data from,
\ then it calls mdio-wait which in turn calls mif-frame-output-reg@
\ to check the data-valid bit and get the data from the serdes
\
: mdio-read  ( frame -- value )
   mif-frame-output-reg!    ( )
   mdio-wait                ( value true | false )
   0= if cmn-error[ " mdio-read timed out." ]cmn-end false then
;


\ --------------------Clause45 Frame------------------------------
\ IEEE 802.3 Clause45 MDIO Frame Reg Fields
\   ST:    Start of Frame, ST=00 for Clause45, ST=01 for Clause22
\   OP:    Operation Code,
\   PRTAD: Port Addr
\   DEVAD: Device Addr
\   TA:    Turnaround(time)
\
\ Frame     ST     OP      PRTAD  DEVAD    TA     ADDRESS/DATA
\        [31:30] [29:28] [27:23] [22:18] [17:16] [15:0]
\ Address   00     00      PPPPP  EEEEE    10   aaaaaaaaaaaaaaaa
\ Write     00     01      PPPPP  EEEEE    10   dddddddddddddddd
\ Read      00     11      PPPPP  EEEEE    Z0   dddddddddddddddd
\ Post-read 00     10      PPPPP  EEEEE    Z0   dddddddddddddddd
\
\ DEVAD for LSIL serdes is 0x1E
\ PRTAD for LSIL serdes is 8 for port0 and 9 for port1
\ So
\           ST     OP      PRTAD  DEVAD
\  Addr-P0  00     00      01000  11110    10 = 047a.AAAA
\  Addr-P1  00     00      01001  11110    10 = 04Fa.AAAA
\ Write-P0  00     01      01000  11110    10 = 147a.DDDD
\ Write-P1  00     01      01001  11110    10 = 14Fa.DDDD
\  Read-P0  00     11      01000  11110    10 = 347a.DDDD
\  Read-P1  00     11      01001  11110    10 = 34Fa.DDDD
\

\ clause45-write assembles two clause45 frames based on the 4 
\ arguments on the stack and calls mdio-write twice, first for 
\ specifying reg address and second for actual data writing.
\ 
: clause45-write       ( data reg-addr PRTAD DEVAD -- )
   d# 18 lshift swap   ( data reg-addr DEVAD' PRTAD )
   d# 23 lshift ta=10  ( data reg-addr DEVAD' PRTAD' TA )
   or or tuck or       ( data frame frame' ) 
   mdio-write          ( data frame )
   or op=write or      ( frame'')
   mdio-write          (  )
;

\ clause45-read assembles two clause45 frames based on the 3 
\ arguments on the stack and calls mdio-write to specify the register
\ address and calls mdio-read to read the register data.
\ 
: clause45-read ( PRTAD DEVAD reg-addr -- value )
   -rot                ( reg-addr PRTAD DEVAD ) 
   d# 18 lshift swap   ( reg-addr DEVAD' PRTAD )
   d# 23 lshift TA=10  ( reg-addr DEVAD' PRTAD' TA )
   or or swap          ( frame[27:16]=PRTAD'|DEVAD'|TA reg-addr ) 
   or dup              ( frame[27:0] frame[27:0] ) \ OP=WR is implied 
   mdio-write          ( frame[27:0] )  
   op=read45 or        ( frame[29:0] ) \ bits[15:0] are don't care
   mdio-read           ( value ) 
;
