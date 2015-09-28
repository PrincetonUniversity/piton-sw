\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: classifier.fth
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
id: @(#)classifier.fth 1.1 07/01/23
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

d#  8 constant #rdc-tables
d# 16 constant #rdc-tbl-entries

\ Set all bits, including VPR0,1(,2,3), to 0 so that MAC/VLAN 
\ preference is in favor of MAC 
\
: init-vlan-tbl  ( -- )
   d# 4096 0 do 0 i enet-vlan-tbl-i! loop 
;

\ STAT will be set to 1 when read/write operation completes.
\
: wait-tcam-done ( -- flag ) 
   tcam-ctl@ stat-done and 0<> 
;

\ Clear four TCAM_KEY registers.  The 0 value in these registers 
\ will be written to TCAM.  (bits[194:0] of the TCAM do not matter 
\ because of our setting of the TCAM_MASK_i registers, but set them 
\ to 0 anyway.). 
\
: invalidate-tcam ( -- )
   d# 256 0 do
      0 tcam-key-0! 
      h# ffff.ffff tcam-key-mask-0!
      \ Write the value (0) in TCAM_KEY regs to location i of the
      \ TCAM. bit stat-start==0 causes HW to start writing. 
      rwc-write stat-start or i or tcam-ctl!   \ TCAM_CTL.LOC = i
      d# 100 ['] wait-tcam-done wait-status
      0= if 
         cmn-error[ " Tcam access failed" ]cmn-end drop unloop 
      then
   loop
;


\ There are 128 Rx DMA table (RDC_TBL) entries, 16 for each of 
\ 8 RDC tables.  We initialize the tables as follows:
\ ith RDC Table has the ith Rx channel for all 16 entires, 
\ including the first entry as the default channel for that 
\ table.  That is,
\ RDC Table 0  entry 0~15: {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0} 
\ RDC Table 1  entry 0~15: {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
\ RDC Table 2  entry 0~15: {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2} 
\ RDC Table 3  entry 0~15: {3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3} 
\   ... ...
\ RDC Table 7  entry 0~15: {7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7}
\
\ i = 0~127, for Table 0, i=  0 ~  15, i/16 ==> quot=0 
\            for Table 1, i= 16 ~  31, i/16 ==> quot=1 
\            for Table 7, i=112 ~ 127, i/16 ==> quot=7 
\
\ We have configured HOST_INFO register to indicate which RDC table should be
\ used for this port. ( We selected port-th RDC table for port ), when
\ there is a MAC address match, the HW will come here to find out the 
\ DMA channel to which the packet will be forward.
\
: select-channels-for-rdc-tables  ( -- )
   #rdc-tables #rdc-tbl-entries * 0 do
      chan# i rdc-tbl-i!
   loop
;

: set-default-rdc-for-my-port  ( -- )
   port case
      0 of chan# def-pt0-rdc! endof
      1 of chan# def-pt1-rdc! endof
      2 of chan# def-pt2-rdc! endof
      3 of chan# def-pt3-rdc! endof
   endcase
;

\ Layer 2 Classification
\   Set VLAN table so that preference is in favor of MAC match.  
\   Set MAC compare enable register so that only the comparison with
\ unique MAC and flow control frame (actually, these two types of
\ comparison can not be disabled in XMAC) are enabled but the
\ comparisons with alternative MAC addresses is disabled.
\   So if a incoming frame carries an MAC that matches the unique 
\ MAC, we will find the RDC table from the host-info register for 
\ the unique MAC ( We use p-th RDC table for port p). If there 
\ is an error in the frame or there is no match with the unique MAC, 
\ the frame will be directed to the default DMA associated with 
\ the port ( which is also set to p-th  Rx DMA channel).
\   Then the Neptune handles L2 classification as follows,
\   (1) If a frame carries unique MAC or a flow control frame comes 
\       through port p, it will have DMA channel p as the L2 
\       classification result. Then we do L234 classification
\       using  FFLP.
\   (2) If a frame coming through port p carries alternative MAC 
\       address or it is a frame expecting address filtering or 
\       hash-hit, classification will fail and terminate and the 
\       frame will be sent to the default RDC channel p.
\
: layer2-classification ( -- )
   set-default-rdc-for-my-port       
   select-channels-for-rdc-tables  
   init-vlan-tbl
   init-hostinfo
;

: classification ( -- )
   layer2-classification
   invalidate-tcam
;

\ Bit 26 (TCAM_DIS) of register FFLP_CFG_1 is set, so TCAM is
\ not disabled.
\
: init-fflp ( -- )
   tcam-dis camlat=4 or err-dis or llc-snap or fflp-cfg-1!  
;

headerless
