ioport: equ 020h
tot_bytes: equ 32768
printbanner: equ 0

; Jump to the real code on reset, this code will be overwritten by the stack so we should never jump back here
org 040h
_base:
; print startup banner
	ld sp, stack
if printbanner
	ld HL, banner_string
	call print
; Print bytes free
	ld HL, tot_bytes
	ld BC, heap
	xor A	; clear carry
	sbc HL, BC
	call DispHL
	ld HL, bytes_free_string
	call print
endif
; compute slots free
; a slot is 124 bytes plus 4 bytes for a slot in the keytable
	ld HL, tot_bytes
	ld BC, heap
	xor A	; clear carry
	sbc HL, BC
	ld A, L		; backup the low byte which we'll clobber
	; shift HL right by 8, (divide by 256)
	ld L,H		
	ld H,0
	sla A		; but MSb in carry
	adc HL, HL	; shift left by 1 and add 1 if odd slots fit
	ld (keyslots), HL
; print how many slots we have free
if printbanner
	call DispHL
	ld HL, slots_free_string
	call print
endif
	jp _start

; Welcome strings go first and are part of the stack
banner_string: defb "Welcome to 8-bit KeyDB! v0.9\r\n", 0
bytes_free_string: defb " bytes free\r\n", 0
slots_free_string: defb " keys free\r\n", 0

stack_empty:
	defs 300 - (stack_empty)	; Note up to 256 bytes are used for our query buffer
stack:

arg1: defs 2
arg2: defs 2

; Above the stack are important strings no to be overwritten
;str_err: db "-ERR\r\n", 0
str_ok: db "+OK",0
str_whitespace: db " \t"	; fallthrough
str_newline: db "\r\n", 0
str_err_notthere: db "-ERR not found", 0
str_syntax_error: db "-ERR unknown command", 0
str_syntax_error_arg: db "-ERR Invalid arg", 0
str_pong: db "+PONG", 0
config_response_string: defb "*2\r\n$0\r\n\r\n$0\r\n\r\n", 0

include "commands.asm"

; Next we have helper functions
print:
	; HL: string address
	ld A, (HL)
	and A
	ret Z
	call putch
	inc HL
	jp print

println:
	call print
	ld HL, str_newline
	jp print

config_command:
	ld HL, config_response_string
	jp print
	ret
	
strequal:
strcmp:
	; HL: string A
	; DE: string B
	; zflag is set if equal
	ld A, (DE)
	cp (HL)
	inc DE
	inc HL
	ret NZ		; leave early if strings don't match
	or A
	jp NZ, strcmp
	ret
	
;Number in hl to decimal ASCII
;Thanks to z80 Bits
;inputs:	hl = number to ASCII
;example: hl=300 outputs '00300'
;destroys: af, bc, hl, de used
DispHL:
	ld 	d, '0'
	ld	bc,-10000
	call	Num1
	ld	bc,-1000
	call	Num1
	ld	bc,-100
	call	Num1
	ld	c,-10
	call	Num1
	ld	c,-1
Num1:	ld	a,'0'-1
Num2:	inc	a
	add	hl,bc
	jr	c,Num2
	sbc	hl,bc
	cp 	d
	ret 	z
	ld	d, 0		; BUGBUG is it worth trying to only write this once?
	call putch
	ret 

; strlen
;	IN: HL - pointer to string
;	OUT: HL count of chars
;	CLOBBERS: A, HL, BC
strlen:
	xor A
	ld B, A
	ld C, A
	cpir	; loop inc cp (HL), inc HL, dec BC
	ld HL, -1
	sbc HL, BC
	ret

getch:
	in A, (ioport+5)
	and 1
	jp z, getch
	in A, (ioport)
	ret

putch:
	push AF
putch_loop:
	in A, (ioport+5)
	and 20h
	jp z, putch_loop
	pop AF
	out (ioport), A
	ret
	
gets:
	; HL is buffer
	; c is max count
	;in A, (ioport)
	call getch
	ld (HL), A
	inc HL
	dec c
	jp Z, gets_done
	sub '\n'
	jp NZ, gets
gets_done:
	ld (HL), 0	; zero the last byte to be sure
	ret

getbulk:
	; Inputs: HL - The buffer to write to
	; 	  B - The amount to read
	; clobbers a and c
	call getch
	ld (HL), A
	inc HL
	dec b
	jp nz, getbulk
getbulk_loopln:
	; now wait for the \r\n
	call getch
	cp '\n'
	ret z
	jp getbulk_loopln

Mul10:
	; Multiplies A by 10
	; clobbers c
	sla A	; a*2
	ld C, A ; save
	sla A	; a*4
	sla A	; a*8
	add C	; (a*8)+(a*2)
	ret

atoi:
	; HL points to the number
	; stops when a non numeric character is found
	; result in B
	ld b, 0
atoi_loop:
	; on entry our count is in A
	ld A, (HL)	; get a potential new value
	sub '0'		; is it below '0', and leave ASCII
	ret C		; break
	cp 10		; is it above 10?
	ret NC		; break
	inc HL
	ld d, a		; temp store this new numer in d
	ld a, b		; we need our count in a
	call Mul10	; a *= 10
	add d		; add the new value
	ld b, a		; put our count back in b
	jp atoi_loop
	
eatnewln:
	ld A, (HL)
	cp '\n'
	inc HL
	jp nz, eatnewln
	ret

appendbulkarg:
	; First load in the length string
	push HL
	ld c, 16
	call gets
	pop HL
	; Validate it
	ld A, (HL)
	cp '$'	; if its not a dollar sign then its not a length and we're lost
	jp nz, syntax_error
	; Parse the length
	push HL			; we're going to overwrite this length integer later
	inc HL			; skip past the '$'
	; now the length integer should be pointed to by HL
	call atoi
	; length is in B
	pop HL			; overwrite the length with getbulk
	call getbulk		; load in the bulk string
	ret

processMultibulk:
	;	HL is pointing to the multibulk length string
	;	e.g. *3\r\n
	inc HL		; skip the star
	call atoi
	call eatnewln
	; B has the number of strings we expect
	ld HL, _base	; set our input buffer start
loop_arg:
	push BC ; save for later
	
	call appendbulkarg
	ld (HL), ' '
	inc HL
		
	pop BC
	dec b
	jp nz, loop_arg
loop_args_loaded:
	ld (HL), 0	; terminate the string
	ld HL, _base
	call parse_command
	ret
	

parse_command:
	; HL is the command buffer
	ld (arg1), HL	; we can use this slot because we know a command hasn't been called yet

	ld BC, str_whitespace
	call strtok	; zero our token char
	push HL		; copy HL to stack
	pop BC		; store the parameter string in BC
	ld HL, (arg1)
	ld DE, command_table
parse_command_next:
	ld A, (DE)
	and A
	jp z, syntax_error
	push DE		; save DE since strcmp will clobber it
	call strcmp
	jp z, parse_command_found
	ld HL, (arg1)
	pop DE
parse_command_eatcmdch:
	ld A, (DE)
	inc DE
	and A, A
	jp NZ, parse_command_eatcmdch
	inc DE
	inc DE	; skip the 2-byte jump vector
	jp parse_command_next
parse_command_found:
	pop af		; balance the stack (ignore value)
	ld A, (DE)	; load the address in memory pointed at by (DE)
	ld L, A
	inc DE
	ld A, (DE)
	ld H, A
	ld (arg1), BC
	jp (HL)		; jump to the command vector

hash_string:
	; DE contains string
	; ret HL hash
	; BC is clobbered as a zero register
; zero HL
	xor A, A
	ld H, A
	ld L, A
	ld B, A
	ld C, A
hash_string_loop:
	ld A, (DE)	
	or A
	ret Z
	add L
	xor H
	ld H, A
	inc DE
	add HL, HL	; shift HL left by one
	adc HL, BC	; add in the carry bit to make it a rotate
	or A		; did we read the terminating NULL?
	jp hash_string_loop	; if not loop

strtok:
	; BC contains a pointer to the token list/string
	; HL contains the string
	; we return HL pointing at the NULL we write for the tok
	push BC 		; backup the token string on the stack
	pop IX			; put it in IX
strtok_loop:
	ld A, (HL)
	or A			; is it zero?
	jp Z, strtok_done	; if so bail
	xor A, A
	ld (strtok_tok_loop+2), A
strtok_tok_loop:
	ld A, (IX+0)		; note the +0 is self modifying code
	or A			; is this the end of the tok list?
	jp Z, strtok_tok_done	; if so break this inner loop
	sub A, (HL) 		; compare our token with the character
	jp Z, strtok_tok_found	; if its a match handle it
	ld A, (strtok_tok_loop+2)	; load the offset for the token string index
	inc A			; get the next char
	ld (strtok_tok_loop+2), A 	; modify the instruction
	jp strtok_tok_loop      ; start the loop
strtok_tok_done:
	inc HL
	jp strtok_loop		; loop if not a token
strtok_tok_found:
	ld (HL), 0		; terminate the string
	inc HL			; point to next string
strtok_done:
	ret

div_ac_de:
	ld	hl, 0
	ld	b, 16
_loop:
	sli	c
	rla
	adc	hl, hl
	sbc	hl, de
	jr	nc, $+4
	add	hl, de
	dec	c
	djnz	_loop 
	ret

syntax_error:
	ld HL, str_syntax_error
	call println
	ret

hash2slotptr:
	; Input: HL with our hash
	; Output: HL with our slot pointer
	; Clobbers: A, BC, DE, HL
	ld A, H
        ld C, L
        ld DE, (keyslots)
        call div_ac_de
        ; HL now contains our index in the heap
        ;       Multiply by 128 to get our slot
        ld A, 1
        ld H, L
        and L
        srl H
        rrc A
        ld L, A
        ; HL now contains the offset to our slot
        ;       offset to our heap
        ld BC, heap
        add HL, BC
        ; HL now contains a pointer to our slot
	ret

strncpy:
	; Input: HL - Destination
	;	 DE - Source
	; 	 C  - max count
	; Clobber: A, C, DE, HL
	ld a, (DE)
	ld (HL), a
	inc DE
	inc HL
	or A		; did we load the zero terminator?
	ret z		; done
	dec c
	ret z		; also done if c is zero
	jp strncpy

validate_arg:
	; First ensure there is an argument (not empty string)
	ld A, (HL)
	or A
	jp Z, validate_err
	; tokenize the argument
        ld BC, str_whitespace
        call strtok     ; HL contains pointer to our next arg
	ret
validate_err:
	ld HL, str_syntax_error_arg
	call println
	pop HL	; pop the return address of the command (so syntax err returns to the main loop)
	ret

set_command:
	ld HL, (arg1)
	call validate_arg
	; check if there is a second arg
	ld (arg2), HL
	call validate_arg
	
	ld DE, (arg1)
	call hash_string
	push HL			; save our hash
	call hash2slotptr
	pop DE
	ld (HL), E		; the slot header contains the hash
	inc HL
	ld (HL), D
	inc HL			; jump past the slot header
	ld DE, (arg2)
	ld c, 126
	call strncpy

	ld HL, str_ok
	call println
	ret

get_command:
	; handle our argument
	ld HL, (arg1)
	call validate_arg
	
	; hash it
	ld DE, (arg1)
	call hash_string
	ld (arg2), HL		; store the hash temporarily
	call hash2slotptr	; get the hash
	; validate the slot stores our hash
	ld DE, (arg2)
	ld A, (HL)
	xor E
	jp nz,get_notavail
	inc HL
	ld A, (HL)
	inc HL
	xor D
	jp nz,get_notavail

	;At this point HL points to our value, but we have to print
	; protocol boiler plate first
	ld (arg2), HL		; backup our pointer
	call strlen
	ld A, '$'
	call putch
	call DispHL
	ld HL, str_newline
	call print		; "$n\r\n

	ld HL, (arg2)
	call println		; "value"
	ret
get_notavail:
	ld HL, str_err_notthere
	call println
	ret

ping_command:
	ld HL, str_pong
	call println
	ret

_start:
	ld HL, _base
	ld c, 255
	call gets
	ld HL, _base
	ld A, (HL)
	cp '*'
	jp z, multibulk
	call parse_command
	jp _start
multibulk:
	call processMultibulk
	jp _start

keyslots:
	defs 2	; two bytes store the max keys we can hold

heap:
	
