; MSX BASIC JSON Parser
; by Ricardo Bittencourt 2017

        output  json.bin

        org     0D000h - 7

; ----------------------------------------------------------------
; MSX bios

usrtab          equ     0F39Ah  ; Callbacks for USR functions
valtyp          equ     0F663h  ; Type of argument in DAC
dac             equ     0F7F6h  ; Accumulator for MSX BASIC
type_mismatch   equ     0406Dh  ; Type mismatch error handler
error_handler   equ     0406Fh  ; Generic BASIC error handler
illegal_fcall   equ     00005h  ; Error code for Illegal function call

; ----------------------------------------------------------------
; BIN header

        db      0FEh
        dw      start_bin
        dw      end_bin - 1
        dw      start_bin

; ----------------------------------------------------------------
; Initialization.

start_bin:
        ld      hl, set_json_start
        ld      (usrtab + 0), hl
        ld      hl, get_json_type
        ld      (usrtab + 2), hl
        ret

; ----------------------------------------------------------------
; Set json start

set_json_start:
        ; Check for integer argument
        ld      a, (valtyp)
        cp      2
        jp      nz, type_mismatch
        ; Set json start
        ld      hl, (dac + 2)
        ld      (json_start), hl
        ; Check for valid json.
        call    check_json
        ; Return 0=error, -1=success
        ccf
        sbc     hl, hl
        ld      (dac + 2), hl
        ret

; ----------------------------------------------------------------
; Get json token type

get_json_type:
        ; Check for string argument
        ld      a, (valtyp)
        cp      3
        jp      nz, type_mismatch
        ; Check if json start was set
        ld      hl, (json_start)
        ld      a, h
        or      l
        ld      e, illegal_fcall
        jp      z, error_handler
        ; Save sentinel
        ld      a, (dac)
        ld      hl, (dac + 1)
        add     a, l
        ld      l, a
        ld      a, h
        adc     a, 0
        ld      h, a
        ld      a, (hl)
        ld      (sentinel), a
        ld      (hl), 0
        ; Start parsing
        ld      hl, (json_start)
        ld      (json_pos), hl
        ld      hl, (dac + 1)
        ld      (path_pos), hl
        call    parse_token
        ; Return an integer
        ld      a, 2
        ld      (valtyp), a
        ld      hl, 0
        ld      (dac + 2), hl
        ret

; ----------------------------------------------------------------

parse_token:
;        ld      hl, (path_pos)
;        call    getchar
        ret

; ----------------------------------------------------------------

skip_whitespace:
        ld      a, (hl)
        cp      32
        jr      z, 1f
        cp      10
        jr      z, 1f
        cp      13
        jr      z, 1f
        cp      9
        ret     nz
1:
        inc     hl
        jr      skip_whitespace
        
; ----------------------------------------------------------------

check_json:
        call    skip_whitespace
        ld      a, '{' 
        cp      (hl)
        jr      z, check_object
        ld      a, '['
        cp      (hl)
        jr      z, check_array
json_error:
        scf
        ret

check_object:
        ; HL must be pointing to '{'
        inc     hl
        call    skip_whitespace
        cp      '}'
        ret     z
        call    check_string
        call    skip_whitespace
        cp      ':'
        jr      nz, json_error
        ret

check_array:
        ; HL must be pointing to '['
        inc     hl
        call    skip_whitespace
        cp      ']'
        ret     z
        scf
        ret

check_string:
        call    skip_whitespace
        ld      a, '"'
        cp      (hl)
        jr      nz, json_error
        inc     hl
        call    check_key
        or      a
        ret

check_key:
        ld      a, (hl)
        cp      '"'
        jr      z, check_key_exit
        cp      '\\'
        jr      nz, 1f
        inc     hl
1:
        inc     hl
        jr      check_key
check_key_exit:
        inc     hl
        ret
        
; ----------------------------------------------------------------
; Variables

json_start:     dw      0
json_pos:       dw      0
path_pos:       dw      0
sentinel:       db      0

; ----------------------------------------------------------------

end_bin:

        end

