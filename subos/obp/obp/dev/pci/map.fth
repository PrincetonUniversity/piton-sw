\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: map.fth
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
id: @(#)map.fth 1.18 07/06/22
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

\
\ probe-state is a flag that notifies the map words to relocate a BAR if
\ the requested size is greater than the currently allocated size.
\ if probe-state? is true then the contents of the BAR storage array is also
\ valid and we make use of that fact.
\

: is-enabled? ( phys.hi -- flag )  h# ff invert and 4 + self-w@ 7 and 0<>  ;
: expansion-rom?  ( phys.hi -- flag )
   h# ff and dup h# 30 = swap h# 38 = or
;

: probe-state-relocate ( p.lo p.mid p.hi len -- p.lo p.hi len )
   2swap drop -rot				( p.lo p.hi len )
   over expansion-rom?  if  exit  then		( p.lo p.hi len )
   over is-enabled?	 			( p.lo p.hi len flag )
   probe-state? 0= or if  exit  then		( p.lo p.hi len )
   over get-bar# >bar-struct			( p.lo p.hi len barstr )
   dup >bar.implemented? @  if			( p.lo p.hi len barstr )
      \ the element >bar.size is bumped to 64 bit
      \ to take care of 64 bit pci address.
      dup >r >bar.size x@			( p.lo p.hi len size )
      over x< if				( p.lo p.hi len )
	 over release-bar-resources		( p.lo p.hi len )
	 dup r@ >bar.size x!			( p.lo p.hi len )
	 over reassign-bar-resources		( p.lo p.hi len )
      then					( p.lo p.hi len )
      r> drop					( p.lo p.hi len )
   else						( p.lo p.hi len barstr )
      drop
   then
;

: (pci-map-cfg) ( p.low p.mid p.hi len -- vaddr )
   2swap 2drop					( p.hi len )
   bus-map-cfg					( vadr )
;

: (pci-map-io) ( p.low p.mid p.hi len -- vaddr )
   probe-state-relocate >r			( p.lo p.hi )
   tuck self-l@ 3 invert and + 0 rot r>		( p.lo p.mid p.hi len )
   bus-map-io					( vaddr )
;

: (pci-map-mem) ( p.low p.mid p.hi len incr -- vaddr )
   >r probe-state-relocate >r			( p.lo p.hi )
   tuck self-l@	h# f invert and + swap r>	( p.lo p.hi len )
   r@ if					( p.lo p.hi len )
      over r> + self-l@ -rot			( p.lo p.mid p.hi len )
   else						( p.lo p.hi len )
      r> drop 2>r 0 2r>				( p.lo p.mid p.hi len )
   then						( p.lo p.hi len )
   bus-map-mem					( vaddr )
;

: map-bar64-in-mem32 ( p.low p.mid p.hi len -- vaddr )
   4 (pci-map-mem)                      ( vaddr )
;
 
defer (pci-map-mem64) ' map-bar64-in-mem32 is (pci-map-mem64)

: $map-type ( n -- str-len )
   case
      01 of " I/O" endof
      02 of " 32 bit memory" endof
      03 of " 64 bit memory" endof
   h# 43 of " 64 bit prefetchable memory" endof
      \ Default
      " unknown address space" rot
   endcase
;

: .whine ( ss ss' -- ss' )
   diagnostic-mode? if		( ss ss' )
      cmn-warn[ 
         swap $map-type 2 pick $map-type ( ss' str-len str-len' ) 
         " FCODE map-in doesn't match decoded register type; Requested: %s, Decoded: %s" 
      ]cmn-end			( ss' )
   else				( ss ss' )
      nip			( ss' )
   then				( ss' )
;

: verify-pci-map-in ( p.hi -- ss )
   dup self-l@ 0=  if				( p.hi )
      \ BAR is not implemented
      \ Just accept it
      cfg>ss#  exit
   then

   dup cfg>ss# dup if				( p.hi ss )
      over get-bar# 5 <= if			( p.hi ss )
         \ A memory/IO bar
         swap self-l@				( ss pa )
         dup 1 and if				( ss pa )
            \ IO bar..
            1 7					( ss pa type mask ) 
         else					( ss pa )
            \ Memory bar, convert
            dup 1 >> 3 and case                 ( ss pa )
               0  of  h# 02  endof
               1  of  h# 82  endof
               2  of 				( ss pa ) 
                  \ check if prefetchable
                  dup 8 and if			( ss pa )
                     h# 43			( ss pa type )
                  else
                     h# 03			( ss pa type )
                  then
               endof
               3  of  cmn-error[ " BAR has reserved bits set" ]cmn-end  abort endof
            endcase                             ( ss pa type )
            h# f                                ( ss pa type mask )
         then                                   ( ss pa type mask )
      else					( p.hi ss )
         \ ROMBARs are always memory mapped.
         swap self-l@  h# 02  h# f		( ss pa type mask )
      then					( ss pa type mask )
      rot and if				( ss type )
	 \ Note that for mem32 bar the lower 4-bits are zero
	 \ and hence this code does not get executed. This oversight
	 \ has been there for many years and changing that behaviour 
	 \ now might introduce regression in some of the vendor fcodes. 
         2dup swap h# 7f and 			( ss type type ss' )
	 <> if  .whine  exit  then		( type )
      then					( ss type )
   then						( ss type )
   nip						( type )
;

: pci-map-in ( p.low p.mid p.hi len -- vaddr )
   over verify-pci-map-in
   h# 7f and case
      0 of    (pci-map-cfg)  endof
      1 of    (pci-map-io)   endof
      2 of  0 (pci-map-mem)  endof
      3 of  4 (pci-map-mem)  endof
      h# 43 of (pci-map-mem64) endof
   endcase
;
