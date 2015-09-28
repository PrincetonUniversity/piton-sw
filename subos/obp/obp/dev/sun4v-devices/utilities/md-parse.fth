\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: md-parse.fth
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
id: @(#)md-parse.fth 1.1 07/06/22
purpose: 
copyright: Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
copyright: Use is subject to license terms.

headerless

: $=  ( adr,len adr2,len -- same? )
   rot tuck <> if  3drop false exit  then  comp 0=
;

\ Search for ldc id that can be used for net boot

: md-next-fwd  ( node fwd|0 -- entry|0 )
   begin
      over swap md-next-prop dup        ( node next next )
   while				( node next )
      dup md-prop-type ascii a = if     ( node next )
         dup md-prop-name " fwd" $= if  ( node next )
            nip exit                    ( entry )
         then                           ( node next )
      then                              ( node next )
   repeat				( node next )
   nip                                  ( 0 )
;

: md-applyto-fwds  ( ??? acf node -- ??? )
   0                                    ( ?? acf node 0 )
   begin
      2dup md-next-fwd nip dup          ( ?? acf node next-fwd|0 next-fwd|0 )
   while
      dup md-decode-prop drop           ( ?? acf node next-fwd fwd-node )
      -rot >r >r swap >r r@             ( ?? fwd-node acf )
      catch ?dup if
         r> r> r> 3drop throw           (  )
      then
      r> r> r>                          ( acf node next-fwd )
   repeat
   3drop                                (  )
;

: md-get-required-prop  ( node $name -- [val type] | [buf len type] )
   3dup -1 md-find-prop ?dup if
      nip nip nip md-decode-prop		( [val type] | [buf len type] )
   else
      rot md-node-name 2swap			( $name $prop )
      cmn-fatal[ " Missing required property: %s " cmn-append
                 " in node %s"			   ]cmn-end
   then
;

\ Integers in MD are stored in arrays of 64 bits, encode-int wants 32 bits.
: encode-md-prop-data ( data,len -- prop,len )
   0 0 encode-bytes rot 0 ?do		( data prop,len )
      2 pick i + x@ encode-int encode+	( data prop,len' )
   /x +loop				( data prop,len' )
   rot drop				( prop,len' )
;
