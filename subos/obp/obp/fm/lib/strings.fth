\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: strings.fth
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
\ strings.fth 2.10 96/07/25
\ Copyright 1985-1994 Bradley Forthware

\ Primitives to concatenate ( "cat ), and print ( ". ) strings.
decimal
headerless

h# 260 buffer: string2

headerless0

: save-string  ( pstr1 -- pstr2 )  string2 "copy string2  ;

headers
: $number  ( adr len -- true | n false )
   $dnumber?  case
      0 of  true        endof
      1 of  false       endof
      2 of  drop false  endof
   endcase
;

headerless
: $hnumber  ( adr len -- true | n false )  push-hex  $number  pop-base  ;
headers

\ Here is a direct implementation of $number, except that it doesn't handle
\ DPL, and it allows , in addition to . for number punctuation
\ : $number  ( adr len -- n false | true )
\    1 0 2swap                    ( sign n adr len )
\    bounds  ?do                  ( sign n )
\       i c@  base @ digit  if    ( sign n digit )
\        swap base @ ul* +        ( sign n' )
\       else                      ( sign n char )
\          case                   ( sign n )
\             ascii -  of  swap negate swap  endof    ( -sign n )
\             ascii .  of                    endof    ( sign n )
\             ascii ,  of                    endof    ( sign n )
\           ( sign n char ) drop nip 0 swap leave     ( 0 n )
\          endcase
\       then
\    loop                         ( sign|0 n )
\    over  if                     ( sign n )
\       * false                   ( n' false )
\    else                         ( 0 n )
\       2drop true                ( true )
\    then
\ ;
