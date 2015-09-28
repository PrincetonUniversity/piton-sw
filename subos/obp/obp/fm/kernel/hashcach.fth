\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: hashcach.fth
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
\ hashcach.fth 3.6 01/05/18
\ Copyright 1985-1994 Bradley Forthware
\ Copyright 1994-2001 Sun Microsystems, Inc.  All Rights Reserved

\ Dictionary cache to speed up "find".  Only the Forth vocabulary is
\ cached; this eliminates a lot of cache flushing and is simpler than
\ caching all vocabularies.

hex

headerless
100 /link * constant /hashcache
/hashcache buffer: hashcache


: link+  ( adr index -- adr' )
\t16 wa+
\t32 la+
;
: vhash  ( adr,len -- cache-adr )
   7 and  swap c@ 1f and  3 <<  +  hashcache swap  link+
;
: match?  ( adr len cache-adr  -- flag )
   another-link?   if     ( adr len acf )
      >name name>string   ( adr len adr2,len2 )
      2swap               ( nameadr,len stradr,len )
      rot                 ( nameadr stradr slen nlen )
      over =  if          ( nadr sadr slen )
	 comp 0=
      else                ( nadr sadr slen )
	 3drop false
      then
   else                   ( adr len )
      2drop false
   then
;

headers
: clear-hashcache  ( -- )
   hashcache  /hashcache bounds  ?do  i !null-link  /link +loop
;
headerless
clear-hashcache
chain: init  ( -- )  clear-hashcache  ;

: probe-cache  ( adr len voc-acf -- find-results )
   dup ['] forth =  if               ( adr len voc-acf )
      drop 2dup vhash                ( adr len cache-adr )
      3dup match?  if                ( adr len cache-adr )
	 link@ >link true            ( adr len alf true )
      else                           ( adr len adr2 )
	 >r                          ( adr len )
	 ['] forth >threads  $find-next  if   ( adr len alf )
	    r> over link> swap link!  true    ( adr len alf true)
	 else                                 ( adr len )
	    r> drop false                     ( adr len false )
	 then                            ( adr len false | adr len alf true )
      then
      find-fixup                              ( find-results )
      r> drop exit
   then
   >first                                     ( find-results )
;

: forth?  ( -- flag )  current-voc  ['] forth =  ;

: replace-entry  ( -- )  last @ name>  last @ name>string vhash  link!  ;
: clear-entry  ( -- )  last @ name>string vhash  !null-link  ;

: cached-make  ( adr len voc-acf -- )
   $create-word   forth? if  replace-entry  then
;

: cached-hide  ( -- voc-acf )  forth? if  clear-entry  then  current-voc  ;

: cached-reveal  ( -- )
   hidden-voc get-token?  if  drop forth? if  replace-entry  then  then
   hidden-voc
;

: cached-remove  ( alf acf -- alf prev-link )
   over l>name name>string vhash  !null-link  >threads
;


[ifexist] patch
patch cached-hide current-voc hide		\ fm/kernel/voccom
patch cached-reveal hidden-voc reveal		\ fm/kernel/voccom
patch cached-make $create-word ($header)	\ fm/kernel/voccom
patch cached-remove >threads remove-word	\ fm/kernel/tagvoc
patch probe-cache >first $find-word		\ fm/kernel/tagvoc
[else]
where ." WARNING: Falling back to unsafe code patching" cr
' cached-hide ' hide >body token!
' cached-reveal ' reveal >body token!
' cached-make ' ($header) >body /token + token!
' cached-remove ' remove-word >body token!
' probe-cache ' $find-word >body token!
[then]

headers
