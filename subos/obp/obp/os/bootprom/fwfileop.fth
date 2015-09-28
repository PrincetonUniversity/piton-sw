\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: fwfileop.fth
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
id: @(#)fwfileop.fth 1.5 01/04/06
purpose: File I/O interface using Open Firmware
copyright: Copyright 1994 FirmWorks  All Rights Reserved
copyright: Copyright 1994-2001 Sun Microsystems, Inc.  All Rights Reserved

\ Closes an open file, freeing its descriptor for reuse.

headerless
: _ofclose  ( file# -- )
   bfbase @  bflimit @ over -  free-mem   \ Hack!  Hack!
   close-dev
;

\ Writes "count" bytes from the buffer at address "adr" to a file.
\ Returns the number of bytes actually written.

: _ofwrite  ( adr #bytes file# -- #written )  " write" rot $call-method  ;

\ Reads at most "count" bytes into the buffer at address "adr" from a file.
\ Returns the number of bytes actually read.

: _ofread  ( adr #bytes file# -- #read )  " read" rot $call-method  ;

\ Positions to byte number "l.byte#" in a file

: _ofseek  ( d.byte# file# -- )  " seek" rot $call-method  drop  ;

\ Returns the current size "l.size" of a file

: _ofsize  ( file# -- d.size )  " size" rot $call-method  ;

\ Prepares a file for later access.  Name is the pathname of the file
\ and mode is the mode (0 read, 1 write, 2 modify).  If the operation
\ succeeds, returns the addresses of routines to perform I/O on the
\ open file and true.  If the operation fails, returns false.

: _ofopen
   ( name mode -- [ fid mode sizeop alignop closeop writeop readop ] okay? )
   >r count open-dev
   dup 0=  if  r> 2drop  false exit  then   ( fid )
   r@   ['] _ofsize   ['] _dfalign   ['] _ofclose   ['] _ofseek
   r@ r/o  =  if  ['] nullwrite  else  ['] _ofwrite  then
   r> w/o  =  if  ['] nullread   else  ['] _ofread   then
   true
;

\ .( XXX fwfileop.fth: need ofmake ) cr

stand-init: Install do-fopen
   ['] _ofopen to do-fopen
;


