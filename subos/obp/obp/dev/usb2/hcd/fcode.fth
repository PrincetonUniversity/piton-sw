\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: fcode.fth
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
id: @(#)fcode.fth 1.1 07/01/22
purpose: Load USB device fcode driver
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

hex
headers

false value probemsg?	\ Optional probing messages

\ Find FCode in Sun Microsystems PROM. See dropins.src for your platform.

: find-fcode  ( adr1 len1 -- true | false )
   " SUNW,builtin-drivers" find-package  drop	\ Ignore return code
   find-method  if
      h# 1.0000 dup alloc-mem swap 2dup 2>r rot ( addr 1.0000 xt )
      execute 2r> rot if 2dup byte-load then free-mem true
   else
      false
   then
;

\ >tmp$ copies the string to allocated memory.  This is necessary because
\ the loading of a hub driver may cause another driver to be loaded,
\ thus re-entering load-fcodedriver .  The string that class$ returns
\ is in a static area that is overwritten on each call, so it must
\ be copied to a dynamically-allocated place.  It's tempting to
\ apply >tmp$ only to class$, but then the "free-mem" would have
\ to be omitted for strings from super$ and driver$

: >tmp$  ( $1 -- $2 )
   >r r@ alloc-mem    ( name-adr adr r: len )
   tuck r@ move       ( adr r: len )
   r>                 ( adr len )
;

\ $load-driver executes an FCode driver that is stored somewhere
\ other than on the device itself.  This should be defined outside
\ the FCode driver...

\ any-drop-ins? and do-drop-in are fcode driver loading methods in
\ FirmWorks' OpenFirmware implementation.
\ The following code may have to be changed for other OpenFirmware
\ implementation, provided they have a special way of loading fcode
\ driver from system ROM.

\ If any-drop-ins? or do-drop-in is missing, eval will throw an error
\ that will be caught in $load-driver.

: did-drop-in?  ( name$ -- flag )
   2dup  " any-drop-ins?" eval      ( name$ flag )
   0=  if  2drop false  exit  then  ( name$ )

   probemsg?  if                                  ( name$ )
      ." Matched dropin driver "  2dup type  cr   ( name$ )
   then                                           ( name$ )

   " do-drop-in" eval  true
;

: $load-driver  ( name$ -- done? )
   >tmp$            ( name$' )

\ Replace firmworks-invoking code with SUN-invoking code
\   2dup ['] did-drop-in?  catch  if  2drop false  then  ( name$' done? )
    2dup ['] find-fcode catch if ." Fatal error in find-fcode" cr false then
   -rot  free-mem   ( done? )
;

\ Words to get my (as a child) properties

: get-int-property  ( name$ -- n )
   get-my-property 0=  if  decode-int nip nip  else  0  then
;
: get-class-properties  ( -- class subclass protocol )
   " class"    get-int-property
   " subclass" get-int-property
   " protocol" get-int-property
;
: get-vendor-properties  ( -- vendor product release )
   " vendor-id" get-int-property
   " device-id" get-int-property
   " release"   get-int-property
;

\ Some little pieces for easy formatting of USB name strings

: $hold  ( adr len -- )
   dup  if  bounds swap 1-  ?do  i c@ hold  -1 +loop  else  2drop  then
;

: usb#>   ( n -- )  " usb" $hold  0 u#> ;     \ Prepends: usb
: #usb#>  ( n -- )  u#s drop  usb#>  ;        \ Prepends: usbN
: #,      ( n -- )  u#s drop ascii , hold  ;  \ Prepends: ,N
: #.      ( n -- )  u#s drop ascii . hold  ;  \ Prepends: .N

: ?#,  ( n level test-level -- )   \ Prepends: ,N  if levels match
   >=  if  #,  else  drop  then
;

: device$  ( -- adr len )
   get-vendor-properties drop  		( vendor-id device-id )
   push-hex
   <# #, #usb#>
   pop-base
;

\ Return a string of the form usb,classC[,S[,P]] depending on level
\ Level: 0 -> C   1 -> C,S   2 -> C,S,P
: class$  ( level -- name$ )  
   >r  get-class-properties  r>	      ( class subclass protocol level )
   push-hex                           ( class subclass protocol level )
   <#                                 ( class subclass protocol level )
      tuck                            ( class subclass level protocol level )
      2 ?#,                           ( class subclass level )
      1 ?#,                           ( class )
      u#s " usb,class" $hold          ( )
   u#>
   pop-base
;

: load-fcode-driver  ( -- )
   " compatible" get-my-property 0= if		( adr len )
      begin
         ?dup while				( adr len )
         decode-string				( adr len adr' len' )
         $load-driver  if 2drop exit then
      repeat drop
   then
;

\ LICENSE_BEGIN
\ Copyright (c) 2006 FirmWorks
\ 
\ Permission is hereby granted, free of charge, to any person obtaining
\ a copy of this software and associated documentation files (the
\ "Software"), to deal in the Software without restriction, including
\ without limitation the rights to use, copy, modify, merge, publish,
\ distribute, sublicense, and/or sell copies of the Software, and to
\ permit persons to whom the Software is furnished to do so, subject to
\ the following conditions:
\ 
\ The above copyright notice and this permission notice shall be
\ included in all copies or substantial portions of the Software.
\ 
\ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
\ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
\ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
\ NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
\ LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
\ OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
\ WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
\
\ LICENSE_END
