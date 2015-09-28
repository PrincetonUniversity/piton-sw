copyright: Copyright 2007 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

headers
" char"     device-type

headerless


defer claim
defer release

external
\ Only open and close are defined. read and write are needed for network boot

: open  ( -- flag )
  true
;

: close  ( -- )
;

headerless
