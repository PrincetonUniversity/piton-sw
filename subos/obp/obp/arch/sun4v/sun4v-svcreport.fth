\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: sun4v-svcreport.fth
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
id: @(#)sun4v-svcreport.fth 1.1 06/12/21
purpose:
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headerless

\ Sun4v non-resumable error report
struct
   /x    field   >ehdl         \ Error handle EHDL#
   /x    field   >sun4v-stick  \ STICK register
   /l    field   >desc         \ Error Descriptor
   /l    field   >attr         \ Error Attribute
   /x    field   >ra           \ Real Address
   /l    field   >siz          \ Size
   /w    field   >cpuid        \ CPU id
   /w    field   >pad-bytes    \ aligned bytes
constant /sun4v-error-report

\ Get to the correct buffer of the trap entry.
: get-non-resumable-errbuf  ( -- errbuf ) scratch7@ >nonreserr-shadowbuf ;

headers

: .nonresumable-errinfo   ( -- )
   cpu-state >nonreserr-count x@                              ( count )
   cmn-type[ " Total Number of Non-resumable traps = "        ( count )
   cmn-append (.h) ]cmn-end                                   ( )
   cmn-type[ " Non-resumable Error service report: " ]cmn-end ( )
   get-non-resumable-errbuf                                   ( pa )
   dup >ehdl memory-asi spacex@                               ( pa ehdl )
   cmn-type[ " EHDL:  " cmn-append (.h) ]cmn-end              ( pa )
   dup >sun4v-stick memory-asi spacex@                        ( pa stick )
   cmn-type[ " STICK: " cmn-append (.h) ]cmn-end              ( pa )
   dup >desc memory-asi spacel@                               ( pa desc )
   cmn-type[ " EDESC: " cmn-append (.h) ]cmn-end              ( pa )
   dup >attr memory-asi spacel@                               ( pa attr )
   cmn-type[ " EATTR: " cmn-append (.h) ]cmn-end              ( pa )
   dup >ra memory-asi spacex@                                 ( pa ra )
   cmn-type[ " RA:    " cmn-append (.h) ]cmn-end              ( pa )
   dup >siz memory-asi spacel@                                ( pa siz )
   cmn-type[ " SIZ:   " cmn-append (.h) ]cmn-end              ( pa )
   >cpuid memory-asi spacew@                                  ( cpuid )
   cmn-type[ " CPUID: " cmn-append (.h) ]cmn-end              ( )
   cr 0 scratch7@ >nonreserr-bflag memory-asi spacex!         ( )
;

: .resumable-count ( -- n ) cpu-state >reserr-count x@ . cr ;

headerless
