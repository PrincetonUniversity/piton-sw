\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: fixvoc.fth
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
\ fixvoc.fth 2.3 93/11/01
\ Copyright 1985-1990 Bradley Forthware

only forth meta also forth also definitions
\ Nasty kludge to resolve the to pointer to the does> clause of vocabulary
\ within "forth".  The problem is that the code field of "forth" contains
\ a call instruction to the does> clause of vocabulary.  This call is a 
\ forward reference which cannot be resolved in the same way as compiled
\ addresses.

: used-t  ( definer-acf child-acf -- )
\t32-t  \ Construct a call instruction to the definer acf
\t32-t  2dup - n->l 2 >> h# 4000.0000 or       ( definer-acf child-acf call-instr )
\t32-t  swap [ also meta ] l!-t [ previous ]   ( definer-acf )  drop
\t16-t  [ also meta ] token!-t [ previous ]
;

: fix-vocabularies  ( -- )
   [""] <vocabulary>  also symbols  find   previous  ( acf true | str false )
   0= abort" Can't find <vocabulary> in symbols"
   dup resolution@ >r               ( acf )  ( RS: <vocabulary>-adr )
   dup first-occurrence@                     ( acf occurrence )
   \ Don't let fixall muck with this entry later
   0 rot first-occurrence!		     ( occurrence )
   begin  another-occurrence?  while         ( occurrence )
      dup [ meta ] rlink@-t [ forth ] swap   ( next-occurrence occurrence )
      r@ swap used-t
   repeat
   r> drop
;
