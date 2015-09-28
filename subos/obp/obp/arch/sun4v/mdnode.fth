\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: mdnode.fth
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
id: @(#)mdnode.fth 1.2 07/02/12
purpose:
copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headers

 0  value	guest-md		\ always points to the guest MD
 0  value	md-data			\ MD data (aligned)
 0  value	/md-data		\ MD data length

headerless

: unaligned-x@ ( addr -- value )
   dup unaligned-l@ swap 4 + unaligned-l@ swap lxjoin
;

\ Machine description header
struct
   /l  field  >mdhdr-version		\ Transport version
   /l  field  >mdhdr-nodeblk-sz		\ Size of node block (in bytes)
   /l  field  >mdhdr-nameblk-sz		\ Size of name block (in bytes)
   /l  field  >mdhdr-datablk-sz		\ Size of data block (in bytes)
constant /md-header

: md-nodeblk   ( -- adr )  md-data /md-header + ; 
: md-nodeblksz ( -- n )    md-data >mdhdr-nodeblk-sz unaligned-l@ ;
: md-nameblk   ( -- adr )  md-nodeblk md-nodeblksz + ;
: md-nameblksz ( -- n )    md-data >mdhdr-nameblk-sz unaligned-l@ ;
: md-datablk   ( -- adr )  md-nameblk md-nameblksz + ;
: md-datablksz ( -- n )    md-data >mdhdr-datablk-sz unaligned-l@ ;

\ Machine description element format
struct
   /c   field  >mde-tag			\ Element type
   /c   field  >mde-namelen		\ Name length 
   /w +					\ Reserved
   /l   field  >mde-nameoffset		\ Name (offset in name block)
   0    field  >mde-value		\ Data value for PROP_VAL
   0    field  >mde-index		\ Node Index and PROP_ARC
   0	field  >mde-next		\ Next Node for NODE
   /l   field  >mde-datalen		\ Data length (for STR and DATA)
   /l   field  >mde-dataoffset		\ Data (offset in data block)
constant /md-entry

\ Tag definitions
0        constant  MD_LIST_END		\ End of element list
ascii N  constant  MD_NODE		\ Start of node definition
ascii E  constant  MD_NODE_END		\ End of node definition
h# 20    constant  MD_NOOP		\ NOOP list element
ascii a  constant  MD_PROP_ARC		\ ARC to another node
ascii v  constant  MD_PROP_VAL		\ Data value
ascii s  constant  MD_PROP_STR		\ String value
ascii d  constant  MD_PROP_DATA		\ Data block

: mde-index>adr ( index -- adr )  md-nodeblk swap /md-entry * ca+ ;
: mde-adr>index ( adr -- index )  md-nodeblk -  /md-entry /  ;

\ Return element type
: mde-type ( mdentry -- n )  >mde-tag c@  ;

\ Return element name
: mde-name ( mdentry -- $name )
   md-nameblk  over >mde-nameoffset unaligned-l@ +  swap >mde-namelen c@
;

\ Return element data (for use by PROP_STR and PROP_DATA)
: mde-data ( mdentry -- data len )
   md-datablk  over >mde-dataoffset unaligned-l@ +
   swap >mde-datalen unaligned-l@
;

\ Return element value
: mde-value ( mdentry -- n ) >mde-value unaligned-x@ ;

: md-noops-skip ( mdentry -- mdentry' )
   begin  dup mde-type MD_NOOP =  while  /md-entry +  repeat
;

: mde-nametag@ ( mdentry -- nametag )  unaligned-x@  ;

headerless

