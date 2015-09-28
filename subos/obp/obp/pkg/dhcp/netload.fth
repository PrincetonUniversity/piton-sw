\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: netload.fth
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
id: @(#)netload.fth 2.24 03/08/20
purpose: Network loading using TFTP.
copyright: Copyright 1990-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Use is subject to license terms.

\ DHCP/BOOTP syntax is
\ boot net:[bootp|dhcp][,server-ipaddr][,boot-filename][,client-ip-addr]
\            [,router-ip-addr][,boot-retries][,tftp-retries][,subnet-mask]

\ Network loading using TFTP. Loads one of
\ a) a named file using the "dload" command,
\ b) Or the default tftpboot file whose name is constructed from
\    the Internet address (derived from the Ethernet address with RARP)
\    and the CPU architecture type.
\ c) If using BOOTP/DHCP, loads the file specified on the command line, or
\    the default file specified by the BOOTP/DHCP server, or the file whose
\    name is constructed from the client class.

headerless

: (silent-mode? ( -- flag )
   false " silent-mode?" " /options" find-package  if
      get-package-property 0=  if
         nip
      then
   else
      2drop
   then
   diagnostic-mode?  and
;

create spinner$
   ascii | c,
   ascii / c,
   ascii - c,
   ascii \ c,

variable activity	\ packet counter
variable spinner
variable load-base

: show-status ( adr -- adr )
   activity @ 0= if  load-base @ u.  then
   1 activity tuck +! @ h# 3f and 0= if
       1 spinner tuck +! @ 3 and
       spinner$ + c@ emit bs emit
   then
;

: init-show-progress ( -- )
   (silent-mode?  if  ['] noop  else  ['] show-status  then  to show-progress
;

\ Construct the default file names for the second-stage boot program
\ Using the IP address and the architecture, if boot protocol is RARP
\ Using the client class identifier if boot protocol is DHCP/BOOTP

: (rarp-tftp-file  ( -- pstr )
   base @ >r hex
   my-ip-addr be-l@  <# u# u# u# u# u# u# u# u# u#>  2dup upper  ( adr len )
   r> base !
   tftp-file-buf pack drop
   tftp-file-buf
;

: (dhcp-tftp-file  ( -- pstr )   my-class-id   ;

: decimal-byte?  ( adr,len -- byte true -or- false )
   base @ >r  decimal  $number  r> base !
   if  false exit  then
   dup 0 d# 255 between  if  true  else  drop 0  then
;

: $ip#  ( ip-str -- ip# | 0 )
   0                            ( ip-str 0 )
   3 0 do                       ( ip-str 0 )
      >r                        ( ip-str )
      ascii . left-parse-string ( r-str l-str )
      decimal-byte?  if         ( r-str n )
         r> 8 << or             ( r-str n' )
      else                      ( r-str )
         r> drop 0 leave        ( r-str 0 )
      then                      ( r-str n' )
   loop                         ( r-str { n' | 0 } )
   dup  if                      ( r-str n' )
      -rot ?dup  if             ( n' r-str )
         decimal-byte?  if      ( n' byte )
            swap 8 << or        ( n" )
         else                   ( n' )
            drop 0              ( 0 )
         then                   ( n" | 0 )
      else                      ( n' adr )
         2drop 0                ( 0 )
      then                      ( n" | 0 )
   else                         ( r-str 0 )
      nip nip                   ( 0 )
   then                         ( ip# | 0 )
;

\ Split comma delimited string and strip leading & trailing blanks
: next-argument ( args$ -- rem$ first$ )
   ascii , left-parse-string  -trailing -leading
;

: parse-args  ( args$ -- )

   use-dhcp off                           ( args$ )
   tftp-file-buf off                      ( args$ )

   ?dup 0=  if  drop exit  then

   over dup  " bootp"  comp  0=
   swap  " dhcp"  comp  0=  or  if
      ascii , left-parse-string   2drop
      use-dhcp  on
   then
   ?dup 0=  if  drop exit  then           ( rem$ )

   next-argument ?dup  if                 ( rem$ server-ip$ )
      $ip# server-ip-addr be-l!
      server-ip-addr broadcast-ip-addr? 0=  to use-server?
   else
      drop
   then                                   ( rem$ )
   ?dup 0=  if  drop exit  then           ( rem$ )

   next-argument ?dup  if                 ( rem$ file$ )
      tftp-file-buf pack
      count bounds  ?do
         i c@ ascii | =  if  ascii / i c!  then
         i c@ ascii \ =  if  ascii / i c!  then
      loop
      ['] tftp-file-buf to tftp-file
   else
      drop
   then
   ?dup 0=  if  drop exit  then           ( rem$ )

   next-argument ?dup  if                 ( rem$ my-ip$ )
      $ip# my-ip-addr be-l!
   else
      drop
   then                                   ( rem$ )
   ?dup 0=  if  drop exit  then           ( rem$ )

   next-argument ?dup  if                 ( rem$ router-ip$ )
      $ip# router-ip-addr be-l!
      router-ip-addr broadcast-ip-addr? 0=  to use-router?
   else
      drop
   then                                   ( rem$ )
   ?dup 0=  if  drop exit  then           ( rem$ )

   next-argument ?dup  if                 ( rem$ dhcp-tries$ )
      $number 0=  if  ( .. boot-retry-count ) to dhcp-retries  then
   else
      drop
   then                                   ( rem$ )
   ?dup 0=  if  drop exit  then           ( rem$ )

   next-argument ?dup  if                 ( rem$ tftp-tries$ )
      $number 0=  if  ( .. tftp-retry-count ) to tftp-retries then
   else
      drop
   then                                   ( rem$ )
   ?dup 0=  if  drop exit  then           ( rem$ )

   next-argument ?dup  if                 ( rem$ subnet-mask$ )
      $ip# subnet-mask be-l!
   else
      drop
   then                                   ( rem$ )
   2drop                                  ( )
;

: init-net-params  ( -- )
   mac-address drop         my-en-addr   6  cmove
   0  my-ip-addr  be-l!
   broadcast-ip-addr server-ip-addr  4 cmove
   broadcast-en-addr his-en-addr     6 cmove
   broadcast-ip-addr subnet-mask     4 cmove
   broadcast-ip-addr router-ip-addr  4 cmove
;

: check-netconfig-params ( -- )
   server-ip-addr broadcast-ip-addr?  if
      ." TFTP server's IP address not known!"
      abort
   then
   need-router?  if
      router-ip-addr broadcast-ip-addr?  if
        ." Need router-ip to communicate with TFTP server"
        abort
      then
      router-ip-addr be-l@  on-my-net? 0=  if
         ." Router must be on network " my-netid .inetaddr
         abort
      then
   then
;

\ Get the next-hop routing information. If the server is on the 
\ connected network, the datagram is sent directly; otherwise,
\ it is routed to a gateway.
: set-dest-ip-en-addr ( -- )
   need-router?  if
      router-ip-addr his-ip-addr 4 cmove
      broadcast-en-addr his-en-addr 6 cmove
      do-arp
      server-ip-addr his-ip-addr 4 cmove
   else
      server-ip-addr his-ip-addr ip= 0=  if
         server-ip-addr his-ip-addr 4 cmove
         broadcast-en-addr his-en-addr 6 cmove
         do-arp
      then
   then
;

\ Show IP addresses of client, server and, if applicable, the gateway
: show-net-addresses  ( -- )
   ." Server IP address: " server-ip-addr be-l@  .inetaddr cr
   ." Client IP address: " my-ip-addr  be-l@  .inetaddr cr
   router-ip-addr broadcast-ip-addr?  0=  if
      ." Router IP address: "  router-ip-addr be-l@  .inetaddr cr
   then
   subnet-mask broadcast-ip-addr? 0=  if
      ." Subnet Mask      : " subnet-mask be-l@  .inetaddr cr
   then
;

external
\ Sun standard network package for booting support.

: read   ( buf len -- actual-len )  " read"  $call-parent  ;
: write  ( buf len -- actual-len )  " write" $call-parent  ;
: seek   ( offset-low offset-high -- okay? )  " seek" $call-parent  ;

: open   ( -- okay? )
   init-show-progress
   init-net-params
   my-args  ['] parse-args  catch  if
      2drop false
   else
      true
   then
;
: close  ( -- ) ;

: load  ( adr -- len )
   dup load-base ! activity off spinner off
   use-dhcp @  if
      ['] do-dhcp  catch  if  ." BOOTP/DHCP failed"  abort  then
      tftp-file-buf cstrlen  0=  if
         ['] (dhcp-tftp-file  to tftp-file
      then
   else
      do-rarp
      use-server? 0=  if  his-ip-addr server-ip-addr 4 cmove  then
      tftp-file-buf cstrlen  0=  if
         ['] (rarp-tftp-file  to  tftp-file
      then
   then

   \ It is legal for RARP replies to not contain the responder's IP address. 
   \ In this case, TFTP code will broadcast the tftpread request and lock 
   \ onto the server which responds. We validate configuration parameters 
   \ and determine next-hop information for all other cases.

   use-dhcp @ 0=  server-ip-addr broadcast-ip-addr?  and  0=  if
      check-netconfig-params  set-dest-ip-en-addr
   then

   tftp-file count tftpread
   diagnostic-mode?  if  cr show-net-addresses  then
;
