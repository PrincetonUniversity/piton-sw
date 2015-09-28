\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: siftdevs.fth
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
id: @(#)siftdevs.fth 1.5 00/09/15
purpose: Sift through the device-tree, using the enhanced display format.
copyright: Copyright 1994 FirmWorks  All Rights Reserved
copyright: Copyright 1995-1999 Sun Microsystems, Inc.  All Rights Reserved

only forth also hidden also definitions

headerless

\  Plug this in to the "hook" for showing a name only once.
\	Show the name of the device being sifted.
: .dev ( -- )   .in ." device  " pwd  ['] noop is .voc ;

\  Sift through the given node,
\      using the sift-string packed into  pad .
\	Control the display with  exit?
: (sift-node?) ( node-acf -- exit? )
    ['] .dev is .voc
    pad count rot
    vsift?
;


\  Sift through the current device-node,
\      using the sift-string packed into  pad .
\      and controlling the display with  exit?
: (sift-dev?) ( -- exit? )
    context-voc (sift-node?)
;

\  Do the actual work, using the sift-string given
\      on the stack as  addr,len  and the ACF of
\      either  sift-dev  or  sift-props (also given)
: $sift-nodes ( addr len ACF -- )
   >r
   pad place
   current-voc also			\  Save current search-order
      root-node r@ execute 0= if	\  Search root-device as well!
	 r@ ['] (search-preorder) catch 2drop
      then r> drop
   previous current token!		\  Restore old search-order
;


headers
forth definitions

\  Sift through all the device-nodes for the string given on the stack
: $sift-devs ( addr len -- )
   ['] (sift-dev?) $sift-nodes
;

\  Sift through all the device-nodes for the string given in the input stream.
: sift-devs  \ name  ( -- )
   safe-parse-word $sift-devs
;

only forth also definitions
