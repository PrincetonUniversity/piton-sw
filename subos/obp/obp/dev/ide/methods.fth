\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: methods.fth
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
id: @(#)methods.fth 1.6 06/07/14
purpose: 
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved.
copyright: Use is subject to license terms.

headerless
\ Encode-unit/decode-unit for IDE need to be defined to handle:
\	[dev][,LUN]
: (decode-unit)  ( adr len -- lo hi )  decode-2int ;

: $hxnumber ( adr,len -- n false | true )
   dup  if
      base @ >r  hex  $number  r> base !
   else
      2drop 0 false
   then
;

\ Encode-unit/decode-unit for SATA need to be defined to handle:
\	[dev][,pPORT][,LUN]
: (decode-sata-unit)  ( adr len -- lo hi )
   ascii , left-parse-string	( after-str before-str )
   $hxnumber throw >r		( after-str )
   ?dup 0=  if  drop 0 r> exit  then
   over c@ ascii p = if
      swap 1+ swap 1-		( after-str' )	\ 1 /string
      ascii , left-parse-string	( after-str'' before-str'' )
      $hxnumber throw		( after-str port )
      8 << r> or >r		( after-str )
   then
   $hxnumber throw r>		( lo hi )
;


external
defer decode-unit ' (decode-unit) to decode-unit
: encode-unit ( l h -- adr,len )
   swap				( h l )
   <# u#s drop ascii , hold	( h )
   dup 8 >> ?dup if
      \ We have a port#!
      u#s drop ascii p hold ascii , hold
   then
   h# 3 and u#s u#>
;

: dma-alloc ( n -- v ) " dma-alloc" $call-parent ;
: dma-free ( vaddr bytes -- ) " dma-free" $call-parent ;
: dma-map-in  ( vaddr n cache? -- devaddr )  " dma-map-in" $call-parent  ;
: dma-map-out  ( vaddr devaddr n -- )        " dma-map-out" $call-parent  ;

: disk-block-size ( bytes -- ) is blocksize ;

: run-command ( pkt -- error? )
   dup >xfer-type l@ case
     0 of run-ata endof
     1 of run-atapi endof
     ( pkttype ) >r drop true r>
   endcase
   timeout? if false  (reset)  drop  then
;

: identify ( target lun -- )
  set-address if
    h# EC id-cmd c!				( -- )
    id-buf id-cmd d# 2000 id-pkt		( buffer cmd timeout pkt )
    set-pkt-data run-ata if			( -- )
      id-pkt >status l@ h# 1 and if		( -- )
        false (reset) drop			( -- )
        h# A1 id-cmd c!				( -- )
        id-buf id-cmd d# 2000 id-pkt		( buffer cmd timeout pkt )
        set-pkt-data run-ata if			( -- )
          .not-present				( false )
        else					( -- )
          true					( true )
        then					( data? )
      else					( -- )
        .not-present				( -- false )
      then					( data? )
    else					( -- )
      true					( true )
    then					( data? )
    if                                          ( -- )
      id-buf w@ dup 4 spaces
      h# 80 bitset? if ." Removable" then space
      ." ATA" h# 8000 bitset? if ." PI" then space
      Model-#
    then
  then cr
;

: device-present? ( target -- present? )
   present 1 rot << and        
;

: reset&check ( -- )
  secondary? if 4 else 2 then 0 do
     i 0 set-address if
      true (reset)  if 
         reset-bsy-timeout wait-!busy?  if 
            present h# 10 and 0=  if
               present  3 i << or is present 
            then
         then
      then
     then
  2 +loop
  present h# 10 and 0=  if  present h# 10 or is present  then
  
;

: reset ( -- )
   map-regs
   secondary? if 4 else 2 then 0 do 
      i 0 set-address if  false (reset) drop  then
   2 +loop
   unmap-regs
;

: open	( -- flag )
  map-regs reset&check			\ reset primary
  true
;

: close	 ( -- )
  unmap-regs
;

: show-children ( -- )
   open 0= if exit then
   secondary? if 4 else 2 then 0 do
      ."   Device " i . 
      i 1 and i 1 >>
      ."  ( " if  .secondary else .primary then
      if .slave  else  .master  then ." ) " cr
      5 spaces 
      present 1 i << and  if 
         i 0 identify 
      else 
         .not-present cr drop 
      then cr
   loop
   close
;

reset
