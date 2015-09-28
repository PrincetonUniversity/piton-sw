\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: suspend.fth
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
\ suspend.fth 2.7 99/05/04
\ Copyright 1985-1994 Bradley Forthware

\ Smart keyboard driven exit
\ Type q to abort the listing, anything else to pause it.
\ While it's paused, type q to abort, anything else to resume.

decimal

only forth also hidden also
hidden definitions

headerless
variable 1-more-line?  1-more-line? off
true value page-mode?

forth definitions
headers
: no-page    ( -- )  false is page-mode?  ;
: page-mode  ( -- )  true  is page-mode?  ;
headerless
: (reset-page)  #line off  1-more-line? off  ;
' (reset-page)  is reset-page
: suspend  ( -- flag )
   #line off
   ??cr dark  ."  More [<space>,<cr>,q,n,p,c] ? "  light
   key  #out @  (cr  spaces  (cr  #out off
   dup  ascii q  =   if  drop true  exit  then
   dup  ascii n  =   if  drop true  exit  then
   dup  ascii p  =   if  drop page-mode  false  exit  then
   dup  ascii c  =   if  drop no-page  false  exit  then
   dup  linefeed =  swap carret =  or  if  1-more-line? on  then
   false
;
d# 24 value default-#lines
headers

defer lines/page  ' default-#lines is lines/page

headerless
: (exit?)  ( -- flag )  \ True if the listing should be stopped
   interactive?  0=  if  false  exit  then

   \ In case we start with lines/page already too large, we clear it out
   page-mode?  if  #line @ lines/page u>=  if  suspend exit  then  then
   1-more-line? @  if  1-more-line? off  suspend  exit  then
   page-mode?  if  #line @ 1+  lines/page =  if  suspend exit  then  then
   key?  if
      key ascii q =  if   #line off  true  else  suspend  then
   else
      false
   then
;
headers
defer exit?
' (exit?) is exit?
only forth also definitions
