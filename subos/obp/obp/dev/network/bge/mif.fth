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
id: @(#)mif.fth 1.1 02/09/06
purpose: 
copyright: Copyright 2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.


headers

\ Routines to access the phy using the MDIO Auto-access method

1 value phy-adr	       \ Internal phy address

: phy-cmd-complete?  ( -- error? )
   d# 5000
   begin					( loops )
      1- dup 0>					( loops notimeout? )
      h# 44c breg@ h# 2000.0000 and		( loops notimeout? !complete? )
      and 0=					( loops not-done? )
   until					( loops )
   drop h# 44c breg@ h# 1000.0000 and		( error? )
;

: phy@  ( reg-adr -- data error? )	\ 16 bits
   phy-cmd-complete? drop
   h# 1f and d# 16 <<				\ shift in reg adr
   phy-adr h# 1f and d# 21 << or		\ shift in phy adr
   1 d# 29 << or				\ set start bit
   2 d# 26 << or h# 44c breg!			\ read transaction
   phy-cmd-complete?				( timeout? )
   h# 44c breg@ dup h# ffff and			( timeout? reg data )
   -rot h# 10000000 and or drop			( data error? )
;

: phy!  ( data reg-adr --  error? )	\ 16 bits
   phy-cmd-complete? drop
   h# 1f and d# 16 <<				\ shift in reg adr
   phy-adr h# 1f and d# 21 << or		\ shift in phy adr
   swap h# ffff and or				\ data
   1 d# 29 << or				\ set start bit
   1 d# 26 << or h# 44c breg!			\ write transaction
   phy-cmd-complete? drop
;
