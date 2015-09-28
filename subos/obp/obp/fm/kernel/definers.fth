\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: definers.fth
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
id: @(#)definers.fth 3.11 03/12/08 13:21:59
purpose: 
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 1985-1994 Bradley Forthware
copyright: Use is subject to license terms.

\ Extensible Layer            Defining Words

headers

defer $header

defer header		\ Create a new word

: (header)  \ name  ( -- )
   safe-parse-word $header
;

' (header) is header

: $create  ( adr len -- )  $header  create-cf  ;

: create  \ name  ( -- )
   header create-cf
;

nuser csp          \ for stack position error checking
: !csp   ( -- )   sp@ csp !   ;
: ?csp   ( -- )   sp@ csp @ <>   ( -22 ) abort" Stack Changed "  ;

: (;code)   ( -- )  ip>  aligned acf-aligned  used   ;
: (does>)   ( -- )  ip>  acf-aligned  used   ;

defer do-entercode
' noop is do-entercode

: code  \ name  ( -- )
   header  code-cf  !csp  do-entercode
;

defer do-exitcode
' noop is do-exitcode

: end-code  ( -- )
   do-exitcode  ?csp
;
: c;  ( -- )  next  end-code  ;

: ;code     ( -- )
   ?csp   compile  (;code)  align acf-align  place-;code
   [compile] [   reveal   do-entercode
; immediate

: does>   ( -- )
   state @  if
     compile (does>)
   else
     here  aligned acf-aligned  used  !csp not-hidden  ]
   then
   align acf-align  place-does
; immediate

: :        ( -- )  ?exec  !csp   header  hide   ]  colon-cf  ;
: :noname  ( -- )  ?exec  !csp   not-hidden     ]  colon-cf  ;
: ;        ( -- )
   ?comp  ?csp   compile unnest   reveal   [compile] [
; immediate

: recursive  ( -- )   reveal  ; immediate

: constant  \ name  ( n -- )
   header constant-cf  ,
;
: user  \ name  ( user# -- )
   header user-cf
\t32  l,
\t16  w,
;
: value  \ name  ( value -- )
   header value-cf  /n user#,  !
;
\  In-dictionary variables are a leftover from the earliest FORTH
\  implementations.  They have no place in a ROMable target-system
\  and we are deprecating support for them; but Just In Case you
\  ever want to restore support for them, define the command-line
\  symbol:   in-dictionary-variables
[ifdef] in-dictionary-variables
   : variable  \ name  ( -- )
      header variable-cf  0 ,
   ;
   : wvariable  \ name  ( -- )
      create variable-cf 0 w,
   ;
   : lvariable  \ name  ( -- )
      create variable-cf 0 l,
   ;
[else]
: variable  \ name  ( -- )
   nuser
;
: wvariable  \ name  ( -- )
   /w ualloc user
;
: lvariable  \ name  ( -- )
   /l ualloc user
;
[then]

\ defer (is is
\ Also known as execution vectors.
\ Usage:   defer bar
\ : foo ." Hello" ;  ' foo is bar
\ Alternatively: ' foo ' bar (is

\ Since the execution of an execution vector doesn't leave around
\ information about which deferred word was used, we have to try
\ to find it by looking on the return stack
\ if the vector was EXECUTE'd, we don't know what it was.  This
\ will be the case if the deferred word was interpreted from the
\ input stream

: crash ( -- )  \ unitialized execution vector routine
   \ The following line may not always work right for token-threaded code
   \ with variable-length tokens
   ip@ /token - token@         \ use the return stack to see who called us
   dup ['] execute =  if   'word count type space else   .name  then
   ." <--deferred word not initialized" abort
;

\ Allocates a user area location to hold the vector
: defer  \ name  ( -- )
   header  defer-cf
   ['] crash   /token user#,   token!	\ Allocate user location
;

: 2constant  \ name  ( d# -- )
   header 2constant-cf  swap  , ,
;

\ buffer:  \ name  ( size -- )
\   Defines a word that returns the address of a buffer of the
\   requested size.  The buffer is allocated at initialization
\   time from free memory, not from the dictionary.
\
\   The parameter field contains three items as follows:
\   -- Location 	Name		  (  Size )
\        pfa:		  user#		(  /user# , which is either  /l )
\					(     or, in the \t16 model, /w )
\        pfa+/user#:	  buffer-size	(  /n , which is way too large!)
\        pfa+/user#+/n:	  buffer-link	(  /a , which is either   /l )
\					(  or, in the \t16 model, /w )
\
\   When the buffer is defined, a single cell is allocated in user space,
\   which holds the address of the allocated block of memory.

headerless
auser buffer-link
0   is buffer-link

: make-buffer  ( size -- )

   0 /n user#,  !      ( size ) 	\  Cell in user space; initlz to zero.
   ,                   (  )
   buffer-link link@  link,
   lastacf buffer-link link!
;
\  Return the buffer-size field of the buffer whose PFA is on the stack
: /buffer ( buff-pfa -- size )
   /user# + @
;
: init-buffer ( pfa usr-adr -- buff-adr )
   >r				( apf ) 	   ( R: usr-adr )
   /buffer	 		( size )	   ( R: usr-adr )
   dup alloc-mem		( size buff-adr )  ( R: usr-adr )
   tuck tuck r> !		( buff-adr buff-adr size )
   erase			( buff-adr )
;
: do-buffer ( pfa -- buff-adr )
   dup >user dup @ ?dup if	( apf usr-adr [ buff-adr ] )
      nip nip			( buff-adr )
   else				( apf usr-adr )
      init-buffer		( buff-adr )
   then
;
: (buffer:)  ( size -- )
   create-cf  make-buffer  does> do-buffer
;

headers
: buffer:  \ name  ( size -- )
   header (buffer:)
;

headerless
: >buffer-link ( acf -- link-adr )  >body /user# + na1+  ;

: clear-buffer:s ( -- )
   buffer-link                         ( next-buffer-word )
   begin  another-link?  while         ( acf )
      dup >body  >user  off            ( acf )
      >buffer-link                     ( prev-buffer:-acf )
   repeat                              ( )
;

chain: init  ( -- ) clear-buffer:s  ;
headers
