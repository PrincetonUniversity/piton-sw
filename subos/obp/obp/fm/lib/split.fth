\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: split.fth
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
id: @(#)split.fth 2.3 95/04/19
purpose: 
copyright: Copyright 1995 Sun Microsystems, Inc.  All Rights Reserved
\ Copyright 1985-1990 Bradley Forthware

headers
: lbsplit ( l -- b.lo b.1 b.2 b.hi )  lwsplit >r wbsplit r> wbsplit  ;
: bljoin  ( b.lo b.1 b.2 b.hi -- l )  bwjoin  >r bwjoin  r> wljoin   ;

64\ : xwsplit ( x -- w.lo w.2 w.3 w.hi )  xlsplit >r lwsplit r> lwsplit  ;
64\ : wxjoin  ( w.lo w.2 w.3 w.hi -- x )  wljoin  >r wljoin  r> lxjoin   ;

64\ : xbsplit ( x -- b.lo b.2 b.3 b.4 b.5 b.6 b.7 b.hi )
64\    xlsplit >r lbsplit r> lbsplit
64\ ;
64\ : bxjoin ( b.lo b.2 b.3 b.4 b.5 b.6 b.7 b.hi -- x )
64\    bljoin  >r bljoin  r> lxjoin
64\ ;
