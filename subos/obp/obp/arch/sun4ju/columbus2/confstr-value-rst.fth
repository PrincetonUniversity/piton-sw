\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: confstr-value-rst.fth
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
id: @(#)confstr-value-rst.fth 1.1 06/07/14
purpose: 
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved.
copyright: Copyright 2006 Fujitsu Limited.  All Rights Reserved.
copyright: Use is subject to license terms.

\ config-string-with-value-reset creates a config-variable like as 
\ config-string.
\ Additionally, setting value into the created config-variable results in
\ resetting a value specified by the config-variable definition.
\ 
\ e.g.
\
\  ' #faults " disk net" d# 256 config-string-with-value-reset boot-device
\
\  In this case, boot-device setting results in resetting #faults.

also nvdevice definitions

unexported-words

7 actions
action: ( apf -- adr,len ) config-string@ ;		\ get
action: ( adr,len apf -- )				\ set
   dup >r config-string!        ( r: apf )
   r> /token /l + + count 1+ + #align round-up token@   ( val-acf )
   0 swap do-is                 (  )
;
action: ( apf -- adr ) config-adr ;			\ addr
action: ( adr,len apf -- adr,len ) drop ;		\ decode(getenv)
action: ( adr,len apf -- adr,len ) drop ;		\ encode(setenv)
action: ( apf -- ) nodefault? ;				\ nodefault?
action: ( apf -- adr,len ) >config-default count ;	\ get-default

exported-headers

: config-string-with-value-reset  \ name ( val-acf default-value-adr default-value-len maxlen -- )
   2+ config-create  ",  align
   token,
   use-actions
;

unexported-words

previous definitions

