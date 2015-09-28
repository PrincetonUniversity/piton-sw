\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: hcd.fth
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
id: @(#)hcd.fth 1.1 07/01/04
purpose: Generic HCD Driver
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

hex

external
defer unstall-pipe  ( pipe -- )		' drop to unstall-pipe
headers

d#  50 constant nodata-timeout
d# 500 constant data-timeout

: int-property  ( n name$ -- )     rot encode-int  2swap property  ;
: str-property  ( str$ name$ -- )  2swap encode-string 2swap  property  ;

        " usb"             device-name

\ Sun note - per USB binding, must be one address cell
1       " #address-cells"  int-property
0       " #size-cells"     int-property

\ ---------------------------------------------------------------------------
\ Common variables
\ ---------------------------------------------------------------------------

0 instance value target
false value debug?

\ Setup and descriptor DMA data buffers
0 value setup-buf			\ SETUP packet buffer
0 value setup-buf-phys
0 value cfg-buf				\ Descriptor packet buffer
0 value cfg-buf-phys

: alloc-dma-buf  ( -- )
   setup-buf 0=  if
      /dr dma-alloc dup to setup-buf
      /dr true dma-map-in to setup-buf-phys
   then
   cfg-buf 0=  if
      /cfg dma-alloc dup to cfg-buf
      /cfg true dma-map-in to cfg-buf-phys
   then
;
: free-dma-buf  ( -- )
   setup-buf  if
      setup-buf setup-buf-phys /dr dma-map-out
      setup-buf /dr dma-free
      0 to setup-buf 0 to setup-buf-phys
   then
   cfg-buf  if
      cfg-buf cfg-buf-phys /cfg dma-map-out
      cfg-buf /cfg dma-free
      0 to cfg-buf 0 to cfg-buf-phys
   then
;

\ ---------------------------------------------------------------------------
\ Common routines
\ ---------------------------------------------------------------------------

: my-b@  ( offset -- b )  my-space +  " config-b@" $call-parent  ;
: my-b!  ( b offset -- )  my-space +  " config-b!" $call-parent  ;
: my-w@  ( offset -- w )  my-space +  " config-w@" $call-parent  ;
: my-w!  ( w offset -- )  my-space +  " config-w!" $call-parent  ;
: my-l@  ( offset -- l )  my-space +  " config-l@" $call-parent  ;
: my-l!  ( l offset -- )  my-space +  " config-l!" $call-parent  ;

: map-in   ( phys.lo,md,hi len -- vaddr )  " map-in"   $call-parent  ;
: map-out  ( vaddr size -- )               " map-out"  $call-parent  ;

\ XXX Room for improvement: keep tab of hcd-map-in's to improve performance.
: hcd-map-in   ( virt size -- phys )  false dma-map-in  ;
: hcd-map-out  ( virt phys size -- )  dma-map-out  ;


: $=  ( adr len adr len -- =? )
   rot tuck <> if    
      3drop false exit 
   then  comp 0= 
; 

: log2  ( n -- log2-of-n )
   0  begin        ( n log )
      swap  2/     ( log n' )
   ?dup  while     ( log n' )
      swap 1+      ( n' log' )
   repeat          ( log )
;
: exp2  ( n -- 2**n )  1 swap 0 ?do  2*  loop  ;
: interval  ( interval -- interval' )  log2 exp2  ;

: 3dup   ( n1 n2 n3 -- n1 n2 n3 n1 n2 n3 )  2 pick 2 pick 2 pick  ;
: 3drop  ( n1 n2 n3 -- )  2drop drop  ;

: 4dup   ( n1 n2 n3 n4 -- n1 n2 n3 n4 n1 n2 n3 n4 )  2over 2over  ;
: 4drop  ( n1 n2 n3 n4 -- )  2drop 2drop  ;

: 5dup   ( n1 n2 n3 n4 n5 -- n1 n2 n3 n4 n5 n1 n2 n3 n4 n5 )
   4 pick 4 pick 4 pick 4 pick 4 pick
;
: 5drop  ( n1 n2 n3 n4 n5 -- )  2drop 3drop  ;

\ ---------------------------------------------------------------------------
\ Exported methods
\ ---------------------------------------------------------------------------

external

: debug-on  ( -- )  true to debug?  ;

: set-target  ( target -- )  to target  ;

\ A usb device node defines an address space of the form
\ "port,interface".  port and interface are both integers.
\ parse-2int converts a text string (e.g. "3,1") into a pair of
\ binary integers.

\ : decode-unit  ( addr len -- interface port )  parse-2int  ;
\ : encode-unit  ( interface port -- adr len )
\    >r <# u#s drop ascii , hold r> u#s u#>	\ " port,interface"
\ ;

\ SUN note - per USB binding, single cell unit-address and single value in text
: decode-unit  ( addr len -- lun )  push-hex  $number  if  0  then  pop-base  ;
: encode-unit  ( lun -- adr len )   push-hex (u.) pop-base  ;

headers

: parse-my-args  ( -- )
   my-args  " debug" $=  if  debug-on  then
;

headers

\ LICENSE_BEGIN
\ Copyright (c) 2006 FirmWorks
\ 
\ Permission is hereby granted, free of charge, to any person obtaining
\ a copy of this software and associated documentation files (the
\ "Software"), to deal in the Software without restriction, including
\ without limitation the rights to use, copy, modify, merge, publish,
\ distribute, sublicense, and/or sell copies of the Software, and to
\ permit persons to whom the Software is furnished to do so, subject to
\ the following conditions:
\ 
\ The above copyright notice and this permission notice shall be
\ included in all copies or substantial portions of the Software.
\ 
\ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
\ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
\ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
\ NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
\ LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
\ OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
\ WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
\
\ LICENSE_END
