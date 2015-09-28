\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: ui-cvars.fth
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
id: @(#)ui-cvars.fth 1.9 07/02/07
purpose:  
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

unexported-words

: $find-option  ( adr len -- false | xt true )
   ['] options search-wordlist
;

: find-option  ( adr len -- false | xt true )
   2dup  $find-option  if            ( adr len xt )
      nip nip  true                  ( xt true )
   else                              ( adr len )
      ." Unknown option: " type cr   ( )
      false                          ( false )
   then
;

exported-headers

: getenv-default \ name ( -- )
   parse-word dup  if				( adr len )
      find-option  if				( acf )
         do-get-default				( str,len )
      then					( )
   else						( adr len )
      2drop  ." Usage: get-default option-name" cr  ( )
   then						( )
;

: set-default  \ name  ( -- )
   parse-word dup  if				( adr len )
      find-option  if				( acf )
         do-set-default				( -- )
      then					( )
   else						( adr len )
      2drop  ." Usage: set-default option-name" cr  ( )
   then						( )
;

: set-defaults  ( -- )
   ." Setting NVRAM parameters to default values."  cr
   (set-defaults)
;

unexported-words

: to-column:  \ name ( col# -- )  ( -- )
   create c,  does>  c@ to-column
;

d# 24 to-column: value-column
d# 55 to-column: default-column

: (type-entry)  ( adr,len  -- )
   2dup text?  if
      bounds  ?do
	 i c@  dup  newline =  if
	    drop cr value-column  exit? ?leave
	 else
	    emit
	 then
      loop
   else
      chdump
   then
;
: $type-entry  ( adr len -- )
   tuck 2dup text?  if  d# 24  else  8  then  ( len adr len len' )
   min rot over                               ( adr len' len len' )
   >  >r  (type-entry) r>  if ."  ..."  then   (  )
;
: $type-entry-long  ( adr len acf -- )  decode  (type-entry)  ;

\ XXX should be done using "string-property" or "driver" or something
\ create name " options" 1+ ",  does> count  ;  \ Include null byte in count

: show-config-entry  ( acf -- )
   >r
   r@ .name
   value-column  r@ get	r@ decode $type-entry
   r> do-get-default	default-column	$type-entry
   cr
;

: show-current-value ( acf -- )
   dup .name ." = "  value-column
   >r  r@ get  r> ( adr len acf )  $type-entry-long cr
;

: printenv-all  ( -- )
   ." Variable Name"  value-column  ." Value"
   default-column ." Default Value" cr cr

   0  ['] options  ( alf voc-acf )
   begin
      another-word?  exit?  if  if  3drop  then  false  then
   while                              ( alf' voc-acf anf )
      dup name>string " name" $=  if  ( alf' voc-acf anf )
	 \ Don't display the "name" property
         drop                         ( alf' voc-acf )
      else                            ( alf' voc-acf anf )
         name>  show-config-entry     ( alf' voc-acf )
      then                            ( alf' voc-acf )
   repeat                             (  )
   show-extra-env-vars                (  )
;

: (printenv)  ( adr len -- )
   2dup  $find-option  if
      nip nip show-current-value
   else
      show-extra-env-var
   then
;

: usage  ( -- )  ." Usage: setenv option-name value" cr  ;


: list  ( addr count -- )  \ a version of "type" used for displaying nvramrc
   bounds  ?do
      i c@ newline =  if  cr  else  i c@ emit  then
   loop
;

exported-headers

: $set-default ( name$ -- )
   $find-option if			( xt )
      do-set-default
   then
;

: $getenv  ( name$ -- true | value$ false )
   2dup  $find-option  if            ( name$ xt )
      nip nip                        ( xt )
      >r  r@ get  r> decode  false   ( value$ false )
   else                              ( value$ )
      get-env-var
   then
;

: printenv  \ [ option-name ]  ( -- )
   parse-word dup  if  (printenv)  else  2drop printenv-all  then
;

: $setenv  ( value$ name$ -- )
   2dup $find-option  if                             ( value$ name$ xt )
      nip nip

      >r r@  encode  if
         r> drop  ." Invalid value; previous value retained." cr
         exit
      then                                              ( value )

      \ We've passed all the error checks, now set the option value.

      r@ set  r> show-current-value                           ( )
   else
      put-extra-env-var
   then
;

\ Used to set nvram variables without the unabashed verbosity of $setenv
\ For example, when loading and setting ldom-variables from the MD
: $silent-setenv ( value$ name$ -- )
   2dup $find-option  if                             ( value$ name$ xt )
      nip nip

      >r r@  encode  if
         r> drop
         exit
      then                                              ( value )

      \ We've passed all the error checks, now set the option value.

      r@ set  r> drop
   else
      put-extra-env-var
   then
;

: $silent-change-default ( value$ name$ -- )
   $find-option  if                             ( value$ xt )
      >r r@  encode  if				(  ) ( R: xt )
         r> drop				(  ) ( R: )
         exit					(  ) ( R: )
      then					( value ) ( R: xt )
      \ We've passed all the error checks, now change the default value.
      r> 7 perform-action			(  ) ( R: )
   else						( value$ ) ( R: )
      2drop					(  ) ( R: )
   then
;

: setenv  \ name value  ( -- )
   parse-word  -1 parse strip-blanks             ( name$ value$ )
   ?dup 0=  if  3drop usage  exit  then  2swap   ( value$ name$ )
   2 pick over or  0=  if  2drop 2drop usage   exit  then  ( value$ name$ )
   $setenv
;

\ Note - the following code should really be in it's own file. Leaving it
\ here temporarily to avoid depend.mk problems.

\ Define handler to set keyboard layout for commodity keyboards

\ NVRAM variable to hold layout string - defaults to empty string
0 0 d# 32  config-string keyboard-layout

\ Working buffers. Concatenated length of all layout names should be under 512
h# 200 value keylayoutlen
keylayoutlen buffer: keylayouts
h# 10 value keyselectlen
keyselectlen buffer: keyselect

: callkbd stdin @ $call-method ;	( ??? -- ??? )

\ Routine called from <F1> keypress to ask for keyboard layout.

: (ask-layout)				( -- )

   \ Select US keyboard to guarantee numbers are in known location
   " US-English" " set-keyboard-layout" callkbd
   ?dup if
       dup 2 =			\ Layout will fail with code 2 if keyboard
       if			\   is hardware identifiable
         cr ." Keyboard has hardware country identification, "
         ." cannot select layout." cr exit
       then
       cr ." Unable to set default layout for prompt. Internal failure" cr exit
   then

   \ Get list of all layout names, so we can print them and ask for a
   \ selection by number (since alphabetic keys may be scrambled).

   keylayouts keylayoutlen " get-layout-names" callkbd
   dup 0 = if
      ." No keyboard layout names returned. Internal failure." cr exit
   then

   base @ d# 10 base ! swap dup		( base len len )

   \ Now that we have the list of layout names, parse them out of list
   \ (they are separated by nulls) and print them out.
   cr ." Please select a national keyboard layout:" cr ( base len len )
   keylayouts swap  			( base len buffer len )
   0 -rot				( base len count buffer len )
   begin				( base len count buffer len )
   dup while				( base len count buffer len )
     \ Print out names three to a line
     rot dup 3 mod 0= if cr then 	( base len buffer len count )
     1+ dup 2 u.r space -rot		( base len count' buffer len )
     0 left-parse-string		( base len count' buffer' len'
                                                           name namlen )
     \ Maximum length name is under 32 bytes - line 'em up.
     tuck type d# 20 swap - spaces 	( base len count' buffer' len' )
   repeat
   cr 3drop 				( base len )
   swap base !				( len )

   \ Loop asking for keyboard number
   begin true while
     base @ d# 10 base ! over		( len base len)
     cr ." Keyboard number: "		( len base len )
     keyselect keyselectlen accept	( len base len input-len )
     keyselect swap			( len base len keyselect input-len )
     $number				( len base len [ true| n false ] )
     if
	." Please type a number" cr 0
     then				( len base len n )

     rot base !				( len len n )

   \ User has typed a keyboard number. Walk keylayouts again to find it.

     0 rot keylayouts swap		( len n count buffer len )
     begin				( len n count buffer len )
     dup while				( len n count buffer len )
	0 left-parse-string		( len n count buffer len' name namlen )
	2>r 2swap 1+ 2dup = 2r> rot if	( len buffer len n count name namelen )

	   \ We've reached the keyboard number requested. Set it.
	   2dup " set-keyboard-layout" callkbd
	   if
	     ." Failed to set keyboard layout to " type cr
	   else
	     " keyboard-layout" $setenv	( len buffer len' n count )
	     3drop 2drop		( )
	     exit			( )
	   then

	else
           2drop 2swap			( len n count buffer len' )
	then
     repeat
     \ Ran out of buffer looking for that keyboard number. 
     3drop 
     ." Unrecognized keyboard number " .d cr
   repeat
;

['] (ask-layout) is (ask-layout

unexported-words

