\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: kbd.fth
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
id: @(#)kbd.fth 1.1 07/01/24
purpose: USB boot keyboard driver
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

hex
headers

" keyboard" device-type

\ Code copied from Sun's old keyboard driver
headerless

0 instance value kbd-package

\ We didn't use interpose so we use call-methods instead.
\ This sucks.. but until the pathname part of interpose works
\ properly we need to live with this ick.
\
: .call-kbd ( str,len -- XXX? ) kbd-package $call-method ;

:  kbd-convert ( key# alt shft -- entry )
    " convert" .call-kbd
;

: init-kbd-package  ( -- okay? )
   my-args " kbd-translator" $open-package to kbd-package
   kbd-package  if
      true
   else
     ." Can't open USB keyboard package"  cr  false
   then
;

external

\ Interfaces into keyboard translator package for setting keyboard layouts
: set-keyboard-layout ( $layout-name -- failure?)
  kbd-package if
    " set-keyboard-layout" .call-kbd
  else
    2drop true
  then
;

: get-layout-names ( buffer size -- size )
  kbd-package if
     " get-layout-names" .call-kbd
  else
     2drop 0
  then
;

: kbd-dropin&id ( -- magic$ dropin$ layoutid )
   " UKBD" " usbkbds" get-kbd-cntry-id
;

headerless

\ End code copied from Sun's old keyboard driver

true  constant normal-op?

variable kbd-refcount  0 kbd-refcount !
: +refcnt  ( n -- )  kbd-refcount +!  ;

: /string  ( adr len n -- adr' len' )  tuck - -rot + swap  ;

false value check-abort?	\ True to abort on CTRL-BREAK
false value locked?		\ Interrupt lockout for get-scan

: lock    ( -- )  true  to locked?  ;
: unlock  ( -- )  false to locked?  ;

\
\ Scan code queue: raw data from USB keyboard (see later comment on entry detail)
\ 
\ q is a circular queue:
\    head is index to the start of queue to deque
\    tail is index to the last entry enqued
\
\ Each entry is a tuple of (mm xx kc kc kc kc kc kc)
\ where mm is modifier (bit mask of the gui, alt, shift, ctrl keys)
\       xx is don't care
\       kc are the raw scan codes, 0 meaning null
\
\ A new-entry is enqued iff the last-entry is not the same as the new-entry
\ to avoid duplicate entries.  This is an effort not to duplicate raw data
\ from the keyboard.
\
\ Except where BREAK is concerned, the get-scan code does not really interpret
\ the content of the raw data.
\ 

h# 11 constant mm-mask-ctrl
h# 22 constant mm-mask-shift
h# 44 constant mm-mask-alt
h# 88 constant mm-mask-gui

\ Constants and variables for typematic
0      value    last-ts			\ Last timestamp
false  value    typematic?
d# 500 constant repeat-delay		\ Typematic begins after x ms, repeat key
d#  30 constant repeat-rate		\ Repeat key after y ms in typematic mode
d#   4 constant idle-rate		\ Parameter for set-idle

\ Scan code queue
/kbd-buf    constant /qe
d# 200      constant #qe
/qe #qe *   constant /q

variable    head  0  head !		\ Index into q
variable    tail  0  tail !		\ Index into q
/q          buffer:  q			\ #qe entries of length /qe each
#qe 1-      value    q-end		\ Index into q

/qe         buffer:  last-entry		\ Buffer to hold the last entry (from kbd)
/qe         buffer:  new-entry		\ Buffer to hold the new entry (from kbd)
/qe         buffer:  cur-entry		\ Buffer to hold the current entry being
					\ examined by getkey (to application)
/qe         buffer:  null-entry		\ Buffer to hold a null entry

: init-q  ( -- )  0 head !  0 tail !   #qe 1- to q-end  ;
: inc-q-ptr  ( pointer-addr -- )
   dup @ q-end >=  if  0 swap !  else  1 swap +!  then
;
: q-adr  ( pointer-addr -- adr )  @ /qe * q +  ;

: enque  ( entry$ -- )
   tail @  head @  2dup >  if  - q-end  else  1-  then  ( new-entry$ tail head )
   <>  if  tail q-adr swap move  tail inc-q-ptr  else  2drop  then
;

: deque?  ( -- false | entry$ true )
   lock
   head @  tail @  <>  if
      cur-entry /qe 2dup head q-adr -rot move   head inc-q-ptr  true
   else
      false
   then
   unlock
;

\ We enque the new-entry if one of the following is true:
\ 1.  It is different from the last-entry.  Update last-ts and
\     set typematic? to false.
\ 2.  It is the same as the last-entry and it is non-zero and
\     typematic? is false and repeat-delay has expired.
\     In this case, set typematic? true and update last-ts.
\ 3.  It is the same as the last-entry and typematic? is true
\     and repeat-rate has expired.
\     In this case, update last-ts.
: key-pressed?  ( entry$ -- flag )  dup 4 + l@ swap l@ or 0<>  ;
: ok-to-enque?  ( entry$ -- flag )
[ifdef] use-single-rate
   last-entry swap comp
[else]
   last-entry swap comp  if		\ new-entry <> last-entry
      get-msecs to last-ts		\ Update last-ts
      false to typematic?		\ End any auto-repeat
      true				\ Enque the new-entry
   else					\ new-entry = last-entry
      typematic?  if
         get-msecs dup last-ts - repeat-rate u>=  if
            to last-ts			\ Update last-ts
            null-entry /qe enque
            true			\ In auto-repeat, enque the new-entry
         else
            drop false			\ Don't auto-repeat yet
         then
      else
         last-entry key-pressed?  if
            get-msecs dup last-ts - repeat-delay u>=  if
               to last-ts		\ Update last-ts
               true dup to typematic?	\ Start auto-repeat
               null-entry /qe enque
            else
               drop false		\ Don't auto-repeat yet
            then
         else
            false			\ No key pressed
         then
      then
   then
[then]
;

\ Check for L1-a sequence (sun-specific)
: l1-a? ( entry$ -- flag )
  2 /string 2dup				( entry$' entry$' )

  \ Check for "L1/STOP"
  false -rot bounds ?do				( entry$' flag )
    i c@ h# 78 = if drop true leave then	( entry$' flag )
  loop

  \ If we found an l1, see if we have an "a" as well
  if false -rot bounds ?do			( flag )
      i c@ h# 4 = if drop true leave then	( flag )
    loop					( flag )
  else						( entry$' )
    2drop false
  then
;

\ Check for shift-pause/break (sun-specific, firmworks uses control-break)

: shift-pause/break?  ( entry$ -- flag )
  over c@ mm-mask-shift and  if
    2 /string					( entry$' )
    false -rot bounds  ?do			( flag )
       i c@ h# 48 = if  drop true leave  then	\ Pause/Break key
    loop  					( flag )
  else
    2drop false
  then
;

: check-abort  ( entry$ -- flag ) 	\ L1-A or shift-break pressed?
   check-abort?  if
      2dup				( entry$ entry$ )
      l1-a? if				( entry$ )
	 2drop true			( flag ) \ L1-a was pressed
      else				( entry$ )
	 shift-pause/break?		( flag )
      then
   else					( entry$ )
      2drop false			( flag )
   then					( flag )
;

: get-scan  ( -- )
   locked?  if  exit  then

   lock
   begin
      new-entry /qe get-data?		     ( actual )
   while                                     ( )
      new-entry /qe ok-to-enque?  if         ( )
         new-entry /qe 2dup last-entry swap move		\ Update last-entry
					     ( new-entry$ )
         2dup 	 			     ( new-entry$ new-entry$ )
         \ In the following code, we must be careful to unlock the
         \ queue before calling user-abort, because a timer interrupt
         \ can occur at any time after user-abort is executed.
         check-abort  if
            2drop
            unlock  user-abort
            \ Wait here for long enough to ensure that an alarm timer tick
            \ will happen if it is going to happen.  This is the safest
            \ solution I have found to the following problem: If the abort
            \ sequence is detected while polling the keyboard from the
            \ application level (i.e. not from the alarm handler), then
            \ the alarm handler is likely to sense it a little later,
            \ perhaps in the middle of deque? .  Aborting in the middle of
            \ of deque? is bad, because it leaves the lock set and potentially
            \ leaves the queue pointers and/or stateful hardware in an
            \ inconsistent state.  One solution would be to avoid calling
            \ deque after calling user-abort, but that would hang the driver
            \ if the alarm tick is turned off.
            d# 20 ms
            exit
         then
	 enque	\ If no abort, then enqueue the character
      then
   repeat
   unlock
;

\
\ Process entries in the scan code queue.
\
\ For simplicity, the following process usesa key-state buffer which
\ is indexed by kc.  Each kc has a byte stating its state.  The states
\ are:
\   00 not pressed at all
\   01 currently pressed
\   -1 previously pressed
\
\ For each raw data entry from q,
\    scan key-state: 
\       for each kc,     if key-state[kc]==01, set to -1     \ make current previous
\                   else if key-state[kc]==-1, set to 0      \ make old previous null
\    scan raw data entry:
\       for each kc found, if key-state[kc]==0, process kc   \ queue if ascii
\                          key-state[kc]=1                   \ mark it currently pressed
\
\ There's plenty of room of performance/space fine tuning.
\

false value shift?		\ True if the shift key is down
false value ctrl?	  	\ True if the ctrl key is down
false value alt-gr?		\ True if the AltGr key is down

0 value #queued
d# 12 constant /aq
/aq buffer: ascii-queue

: #queued++  ( -- )  #queued 1+ to #queued  ;
: enque-ascii  ( char -- )
   #queued /aq =  if  drop exit  then
   ( char ) ascii-queue #queued + c!
   #queued++
;

: ?ctrl  ( char -- char' )
   ctrl?  if                                ( char )
      dup  h# 40 h# 7f between  if  h# 1f and  then
   then
;

: modifier?  ( scan-code -- true | scan-code false )
   case 
      39  of  scroll-lock?  if			\ If ScrollLock is on ...
                 true to ctrl?			\ ... treat the CapsLock key like Ctrl
              else				\ Otherwise give it ...
                 led-mask-caps-lock toggle-leds	\ ... the normal CapsLock function
              then  true                               endof   \ Caps Lock
      53  of  led-mask-num-lock     toggle-leds  true  endof   \ Num Lock
      47  of  led-mask-scroll-lock  toggle-leds  true  endof   \ Scroll Lock
      ( otherwise ) dup false rot
   endcase				( true | scan-code false )
;

: process-scancode  ( modifer scan-code -- )
   \ Handle modifiers: alt, shift, ctrl
   swap 					( scan-code modifier )
   dup mm-mask-ctrl  and  0<> to ctrl?
   dup mm-mask-shift and  0<> to shift?
       mm-mask-alt   and  0<> to alt-gr?

   \ Handle modifier: NumLock, CapsLock, ShiftLock
   modifier?  if  exit  then		( scan-code )

\ Call Sun's translator code instead of using firmwork's
\   get-ascii  if  enque-ascii  then		( )

   alt-gr? shift? kbd-convert ?ctrl	( ascii-value )
   ?dup if enque-ascii then
;

h# 100     constant /key-state		\ Can probably be optimized to A5
/key-state buffer:  key-state

00 constant ks-none			\ Not pressed
01 constant ks-curr			\ Currently pressed
ff constant ks-prev			\ Previously pressed

: update-key-state  ( -- )
   key-state /key-state bounds 1+  do
      i c@ case
         ks-curr  of  ks-prev i c!  endof
         ks-prev  of  ks-none i c!  endof
      endcase
   loop
;
: entry->char  ( entry$ -- false | ASCII-code true )
   update-key-state			( entry$ )
   over c@ -rot 2 /string		( mm entry$' )
   bounds  ?do				( mm )
      i c@ ?dup  if			( mm kc )
         over swap			( mm mm kc )
         dup key-state + dup c@		( mm mm kc 'ks ks )
         ks-curr rot c! 		( mm mm kc ks )	\ Update key-state[kc]
         ks-none =  if  process-scancode  else  2drop  then	( mm )
      then				( mm )
   loop  drop				( )
   #queued  if  #queued 1- dup to #queued  ascii-queue + c@  true  else  false  then
;

: getkey  ( -- ASCII-char true | false )
   #queued  if  #queued 1- dup to #queued  ascii-queue + c@  true exit  then
   begin
      get-scan  deque?  0=  if  false exit  then   ( entry$ )
   entry->char  until                              ( ASCII-char )
   true
;

external

: install-abort  ( -- )  true to check-abort?   ;   \ Check for break
: remove-abort   ( -- )  false to check-abort?  ;

\ Read at most "len" characters into the buffer at adr, stopping when
\ no more characters are immediately available.
: read  ( adr len -- #read )   \ -2 for none available right now
   \ Poll the keyboard even if len is 0, as extra insurance against overrun
   get-scan                                   ( adr len )
   tuck                                       ( len adr len )
   begin                                      ( len adr' len' )
      dup 0<>  if  getkey  else  false  then  ( len adr' len' [ char ] flag )
   while                                      ( len adr' len' char )
      2 pick c!                               ( len adr' len' )
      1 /string                               ( len adr'' len'' )
   repeat                                     ( len adr' len' )
   nip -                                      ( #read )
   dup  0=  if  drop -2  then                 ( #read | -2 )
;

: open  ( -- flag )
   kbd-refcount @  if  1 +refcnt true exit  then
   device set-target
   init-kbd-buf
   noop					\ Add noop so I can patch it before open
   normal-op?  if
      unlock
      begin-scan
      get-msecs to last-ts		\ Initialize auto-repeat timestamp
      false to typematic?		\ Not in auto-repeat mode yet
      ['] get-scan d# 10 alarm
   then
   1 +refcnt

   init-kbd-package			\ Bring in keyboard translator
   true
;
: close  ( -- )
   -1 +refcnt  kbd-refcount @  if  exit  then
   normal-op?  if
      ['] get-scan 0 alarm
      end-scan
   then
   free-kbd-buf
;

variable test-char
: selftest  ( -- 0 )  kbd-refcount @ 0<>  if  0  else  -1  then  ;

: init  ( -- )
   init
   init-kbd-buf
   null-entry /qe erase
   key-state /key-state erase
   device set-target
   configuration set-config  if  ." Failed to set keyboard configuration" cr  then
   set-boot-protocol         if  ." Failed to set boot protocol" cr  then
   idle-rate set-idle        if  ." Failed to set idle" cr  then
   0 set-leds
   free-kbd-buf
;

headers

init


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
