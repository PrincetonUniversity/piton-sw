\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: reboot-info.fth
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
id: @(#)reboot-info.fth 1.2 07/02/22
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless

d# 255 3 wa+ constant /reboot-info-buf
/reboot-info-buf buffer: reboot-info-buf
false value reboot-info-loaded?

: reboot-command-set  ( $value -- )  " reboot-command" $silent-setenv ;

: ldv-save-reboot-info  ( bootpath,len line# column# -- )
   2drop reboot-command-set
;

\ By the time we look for the reboot-command, the LDOMs variables 
\ (and any associated updates) have been extracted from the MD. 
\ It is sufficient to check the NVRAM variable.
: ldv-get-reboot-info ( -- bootpath,len line# column# )
   reboot-info-loaded? if			(  )
      \ Only read the NVRAM variable on the first pass, since we clear it 
      \ after reading.
      reboot-info-buf count			( bootpath,len )
   else						(  )
      " reboot-command" $getenv	0= if		( bootpath,len )
         2dup reboot-info-buf 2dup c!		( bootpath,len bootpath,len buf )
         1+ swap move				( bootpath,len )
         " " reboot-command-set			( bootpath,len )
         true to reboot-info-loaded?		( bootpath,len )
      else					(  )
         0 0					( bootpath,len )
      then					( bootpath,len )
   then						( bootpath,len )
   0 0						( bootpath,len line# column# )
;

' ldv-save-reboot-info is save-reboot-info
' ldv-get-reboot-info is get-reboot-info
