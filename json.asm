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
        ld      ix, (dac + 2)
        ld      a, (ix)
        ld      l, (ix + 1)
        ld      h, (ix + 2)
        ld      (path_pos), hl
        add     a, l
        ld      l, a
        ld      a, h
        adc     a, 0
        ld      h, a
        ld      a, (hl)
        ld      (sentinel_pos), hl
        ld      (sentinel), a
        ld      (hl), 0
        ; Start parsing
        ld      hl, (json_start)
        ld      (json_pos), hl
        call    parse_token
        ex      af, af
        ; Restore sentinel
        ld      hl, (sentinel_pos)
        ld      a, (sentinel)
        ld      (hl), a
        ; Return an integer
        ld      a, 2
        ld      (valtyp), a
        ex      af, af
        ld      h, 0
        ld      l, a
        ld      (dac + 2), hl
        bit     7, a
        ld      e, illegal_fcall
        jp      nz, error_handler
        ret

; ----------------------------------------------------------------

parse_token:
        ld      hl, (path_pos)
        exx
        ld      hl, (json_pos)
        exx
parse_token_main:
        ld      a, (hl)
        or      a
        jr      z, parse_identify
        ld      a, 255
        ret

; ----------------------------------------------------------------

        macro   IDENTIFY token, value
        cp      token
        jr      nz, .skip
        ld      a, value
        ret
.skip:
        endm

parse_identify:
        exx
        call    skip_whitespace
        IDENTIFY '{', 1
        IDENTIFY '[', 2
        IDENTIFY '"', 3
        IDENTIFY 't', 5
        IDENTIFY 'f', 6
        IDENTIFY 'n', 7
        push    hl
        call    check_number
        pop     hl
        ld      a, 4
        ret     nc
        ld      a, 0
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
        cp      '{'
        jr      z, check_object
        cp      '['
        jp      z, check_array
json_error:
        scf
        ret

; ----------------------------------------------------------------

check_object:
        ; HL must be pointing to '{'
        inc     hl
        call    skip_whitespace
        cp      '}'
        jr      z, check_success
check_object_key
        call    check_string
        ret     c
        call    skip_whitespace
        cp      ':'
        jr      nz, json_error
        inc     hl
        call    check_anything
        ret     c
        call    skip_whitespace
        cp      '}'
        jr      z, check_success
        cp      ','
        jr      nz, json_error
        inc     hl
        call    skip_whitespace
        jr      check_object_key

; ----------------------------------------------------------------

check_success:
        inc     hl
        ret

; ----------------------------------------------------------------

check_anything:
        call    skip_whitespace
        cp      '{'
        jr      z, check_object
        cp      '['
        jr      z, check_array
        cp      '"'
        jp      z, check_string
        cp      't'
        jr      z, check_true
        cp      'f'
        jr      z, check_false
        cp      'n'
        jr      z, check_null
        ; fall through to check_number

; ----------------------------------------------------------------

check_number:
        cp      '-'
        jr      nz, 2f
        inc     hl
        ld      a, (hl)
2:
        cp      '0'
        jr      nz, 3f
        inc     hl
        ld      a, (hl)
        jr      check_fraction
3:
        call    check_digit_sequence
        ret     c
        ; fall through to check_fraction

; ----------------------------------------------------------------

check_fraction:
        cp      '.'
        jr      nz, check_scientific
        inc     hl
        ld      a, (hl)
        call    check_digit_sequence
        ret     c
        ; fall through to check_scientific

; ----------------------------------------------------------------

check_scientific:
        cp      'e'
        jr      z, 1f
        cp      'E'
        jr      z, 1f
        or      a
        ret
1:
        inc     hl
        ld      a, (hl)
        cp      '+'
        jr      nz, 2f
        inc     hl
        jr      check_digit_sequence
2:
        cp      '-'
        jr      nz, check_digit_sequence
        inc     hl
        ; fall through to check_digit_sequence

; ----------------------------------------------------------------

check_digit_sequence:
        ; Returns CF=not a digit sequence, NC=digit sequence
        call    check_digit
        jp      nc, json_error
1:
        inc     hl
        call    check_digit
        jr      c, 1b
        ret

; ----------------------------------------------------------------

check_true:
        ld      de, token_true
        jr      1f

check_false:
        ld      de, token_false
        jr      1f

check_null:
        ld      de, token_null
1:
        ld      a, (de)
        or      a
        ret     z
        cp      (hl)
        jp      nz, json_error
        inc     hl
        inc     de
        jr      1b

; ----------------------------------------------------------------

check_array:
        ; HL must be pointing to '['
        inc     hl
        call    skip_whitespace
        cp      ']'
        jp      z, check_success
check_array_next:
        call    check_anything
        ret     c
        call    skip_whitespace
        cp      ']'
        jp      z, check_success
        cp      ','
        jp      nz, json_error
        inc     hl
        call    skip_whitespace
        jr      check_array_next

; ----------------------------------------------------------------

check_string:
        cp      '"'
        jp      nz, json_error
        inc     hl
        ; fall through to check_key

; ----------------------------------------------------------------

check_key:
        ld      a, (hl)
        cp      '"'
        jp      z, check_success
        cp      '\\'
        jr      z, check_escape
check_key_next:
        inc     hl
        jr      check_key

; ----------------------------------------------------------------

check_escape:
        inc     hl
        ld      a, (hl)
        cp      '"'
        jr      z, check_key_next
        cp      '\\'
        jr      z, check_key_next
        cp      '/'
        jr      z, check_key_next
        cp      'b'
        jr      z, check_key_next
        cp      'f'
        jr      z, check_key_next
        cp      'n'
        jr      z, check_key_next
        cp      'r'
        jr      z, check_key_next
        cp      't'
        jr      z, check_key_next
        cp      'u'
        jp      nz, json_error
        ld      b, 4
1:
        inc     hl
        call    check_hex_digit
        jp      nc, json_error
        djnz    1b
        jr      check_key_next

; ----------------------------------------------------------------

        macro   CHECK_LIMITS lower, upper
        ; Returns CF=digit, NC=non-digit
        ld      a, (hl)
        cp      upper + 1
        ret     nc
        cp      lower
        ccf
        ret
        endm

; ----------------------------------------------------------------

check_hex_digit:
        call    check_digit
        ret     c
        call    check_hex_lower
        ret     c
        ; fall through to check_hex_upper

check_hex_upper:
        CHECK_LIMITS 'A', 'F'

check_hex_lower:
        CHECK_LIMITS 'a', 'f'

check_digit:
        CHECK_LIMITS '0', '9'

; ----------------------------------------------------------------
; Variables

token_true:     db      'true', 0
token_false:    db      'false', 0
token_null:     db      'null', 0
json_start:     dw      0
json_pos:       dw      0
path_pos:       dw      0
sentinel:       db      0
sentinel_pos:   dw      0

; ----------------------------------------------------------------

end_bin:

        end

