\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: security.fth
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
id: @(#)security.fth 1.4 06/10/11
purpose: Implements Open Boot security feature (passwords)
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

unexported-words resident


6 actions

\ With the addition of LDOM variables, the concept of "fixed" nvram
\ variables is lost, since there is no backing store.  All variables
\ are therefore converted to their config- equivalents

[ifdef] SUN4V

action: config-string@	;
action: config-string!	;
action: config-adr ;
action: drop  2drop  0 0 ;	\ Decode action returns null string
action: drop ;			\ Null encode action
action: drop true ;		\ No default value

exported-headers transient 

: config-password:  \ name  ( maxlen -- )
   dup nodefault-string c,  use-actions
;

[else]

action: fixed-string@ ;
action: fixed-string! ;		\ Similar to config-bytes
action: fixed-adr ;		\ Standard address action
action: drop  2drop  0 0 ;	\ Decode action returns null string
action: drop ;			\ Null encode action
action: drop true ;		\ No default value

exported-headers transient 

: config-password:  \ name  ( maxlen -- )
   dup nodefault-fixed-string c,  use-actions
;

[then]

resident headers
vocabulary security-mode-voc also security-mode-voc definitions

h# 00 byte-keyword none
h# 01 byte-keyword command
h# 02 byte-keyword full

previous definitions headerless

: config-security: ['] security-mode-voc nodefault-fixed-vocab-variable ; 

unexported-words  resident

