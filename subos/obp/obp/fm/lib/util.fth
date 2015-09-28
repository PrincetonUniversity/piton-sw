\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: util.fth
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
id: @(#)util.fth 2.26 03/12/08 13:22:26
purpose: 
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 1985-1994 Bradley Forthware
copyright: Use is subject to license terms.

hex
headerless0

alias (s (

: >user#  ( acf -- user# )   >body >user up@ -  ;
: 'user#  \ name  ( -- user# )
   '  ( acf-of-user-variable )   >user#
;
headers
\ : tr  ( token-bits -- adr )      \ Token relocate
\ \t16   tshift <<
\    origin+
\ ;
: x  ( adr -- )  execute  ;             \ Convenience word
\ : .cstr  ( adr -- )             \ Display C string
\   begin  dup c@ ?dup  while
\      dup newline =  if  drop cr  else  emit  then
\      1+
\   repeat
\   drop
\ ;

: .h  ( n -- )   push-hex     .  pop-base  ;
: .x  ( u -- )   push-hex    u.  pop-base  ;
: .d  ( n -- )   push-decimal .  pop-base  ;

defer lo-segment-base	' origin  is  lo-segment-base
defer lo-segment-limit	' origin  is  lo-segment-limit
defer hi-segment-base	' first-code-word  is  hi-segment-base
\   XXX  Later, we may change  first-code-word  to  low-dictionary-adr
defer hi-segment-limit	' here    is  hi-segment-limit

: dictionary-size  ( -- n )  here origin-  ;

headerless

: #!  ( -- )  [compile] \  ; immediate  \ For use with script files
alias >is >data		\ Backwards compatibility

: strip-blanks ( adr,len -- adr',len' )  -leading -trailing  ;
: optional-arg$  ( -- adr len )  0 parse  strip-blanks  ;

headers

alias not invert
alias eval evaluate

: c?  ( adr -- )  c@  u.  ;
: w?  ( adr -- )  w@  u.  ;
: l?  ( adr -- )  l@  u.  ;
64\ : x?  ( adr -- )  x@  u.  ;
: d?  ( adr -- )  d@ swap u. u.  ;

\ : behavior  ( xt1 -- xt2 )  >body >user token@  ;

: showstack    ( -- )  ['] (.s  is status  ;
: noshowstack  ( -- )  ['] noop is status  ;

\ Default value is yes
: confirmed?  ( adr len -- yes? )
   type  ."  [y/n]? "  key dup emit cr  upc ascii N  <>
;

: lowmask  ( #bits -- mask )  1 swap lshift 1-  ;
: lowbits  ( n #bits -- bits )  lowmask and  ;

\ : many   ( -- )   key? 0=  if  0 >in !  then  ;

: .lx  ( n -- )  push-hex [ /l 2* 1+ ] literal u.r  pop-base ;
: .nx  ( l -- )  push-hex [ /n 2* 1+ ] literal u.r  pop-base ;
: .ndump ( adr n -- )   /n* bounds  ?do  i @ .nx  /n +loop  ;

: .buffers ( -- )
   buffer-link				( next-buffer-word )
   begin  another-link?  while		( acf )
      dup .name				( acf )
      dup >body				( acf apf )
      dup >user @  .x			( acf apf )  \  Show buffer-addr
      /buffer .x			( acf )      \  Show buffer-size
      cr
      exit?  if  drop exit  then	( acf )
      >buffer-link			( prev-buffer:-acf )
   repeat				(  )
;

[ifnexist] bits 	\  Might be defined in code
: bits ( N #bits -- N' bits )
   2dup >> -rot			( N' N #bits )
   1 swap << 1- 		( N' N bitmask )
   and				( N' bits )
;
[then]

\ Keep the "flip" words here.
\ We want them in the desktop FORTH as well...
alias wbflip  flip
alias lwflip wflip

: wbflips  ( adr len -- )
   bounds  ?do
      i unaligned-w@  wbflip  i unaligned-w!
   /w +loop
;
: lwflips  ( adr len -- )
   bounds  ?do
      i unaligned-l@  lwflip  i unaligned-l!
   /l +loop
;
: lbflip  ( n1 -- n2 )  lwsplit wbflip swap wbflip wljoin  ;
: lbflips  ( adr len -- )
   bounds  ?do
      i unaligned-l@  lbflip  i unaligned-l!
   /l +loop
;

false
64\ drop true
[if]
: xbflip  ( x -- x' )  xlsplit lbflip swap lbflip lxjoin  ;
: xlflip  ( x -- x' )  xlsplit swap lxjoin  ;
: xwflip  ( x -- x' )  xlsplit lwflip swap lwflip lxjoin  ;

: xbflips ( adr,len -- )
   bounds  ?do
     i unaligned-@ xbflip i unaligned-!
  /x +loop
;
: xlflips ( adr,len -- )
   bounds  ?do
      i unaligned-@ xlflip i unaligned-!
   /x +loop
;
: xwflips ( adr,len -- )
   bounds  ?do
      i unaligned-@ xwflip i unaligned-!
   /x +loop
;
[then]
