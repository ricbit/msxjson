; MSX BASIC JSON Parser
; by Ricardo Bittencourt 2017

        output  json.bin

        org     0D000h - 7

; ----------------------------------------------------------------
; MSX bios

usrtab          equ     0F39Ah  ; Callbacks for USR functions
valtyp          equ     0F663h  ; Type of argument in DAC
dac             equ     0F7F6h  ; Accumulator for MSX BASIC
dsctmp          equ     0F698h  ; Temporary string descriptor
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
        ld      hl, get_json_value
        ld      (usrtab + 4), hl
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
        jr      c, return_integer
        ld      (json_start), hl
return_integer:
        ld      (dac + 2), hl
        ret

; ----------------------------------------------------------------
; Get json token type

get_json_value:
        ; Alternate entry point, set token type as non-zero.
        db      03Eh
get_json_type:
        ; Set token type as zero.
        xor     a
get_json_action:
        ld      (get_action), a
        ; Check for string argument
        ld      a, (valtyp)
        cp      3
        jp      nz, type_mismatch
        ; Check if json start was set
        ld      hl, (json_start)
        ld      a, h
        or      l
        jr      z, ifc_error
        ; Save sentinel
        push    hl
        ld      ix, (dac + 2)
        ld      c, (ix)
        ld      l, (ix + 1)
        ld      h, (ix + 2)
        ld      d, h
        ld      e, l
        ld      b, 0
        add     hl, bc
        ld      a, (hl)
        ld      (sentinel_pos), hl
        ld      (sentinel), a
        ld      (hl), b
        ; Start parsing
        exx
        pop     hl
        exx
        ex      de, hl
        call    parse_token_main
        ld      b, a
        ; Restore sentinel
        ld      hl, (sentinel_pos)
        ld      a, (sentinel)
        ld      (hl), a
        ; Check for error
        bit     7, b
        jr      nz, ifc_error
        ; Check for string action
        ld      a, (get_action)
        or      a
        ld      a, 2
        jr      nz, get_string
        ; Return an integer
        ld      h, 0
        ld      l, b
return_valtyp:
        ld      (valtyp), a
        jr      return_integer

; ----------------------------------------------------------------
; Get json value as a string

get_string:
        ; Return a string
        cp      b
        jr      nc, ifc_error
        inc     a
        ld      hl, dsctmp
        jr      return_valtyp

; ----------------------------------------------------------------

parse_token_main_exx:
        exx
parse_token_main:
        call    skip_whitespace
        or      a
        inc     hl
        jr      z, parse_identify
        cp      '#'
        jr      z, parse_position
        cp      '$'
        jp      z, parse_value
        cp      '&'
        jp      z, parse_key
parse_return_error:
        ld      a, 255
        ret
ifc_error:
        ld      e, illegal_fcall
        jp      error_handler

; ----------------------------------------------------------------

parse_identify:
        exx
        ld      a, (get_action)
        or      a
        jp      nz, parse_string
        call    skip_whitespace
        ld      bc, 7 * 256 + 1
        ld      de, identifiers
        ex      de, hl
1:
        cp      (hl)
        jr      z, 2f
        inc     c
        inc     hl
        djnz    1b
        ex      de, hl
        push    hl
        call    check_number
        pop     hl
        ccf
        sbc     a, a
        and     4
        ret
2:
        ex      de, hl
        ld      a, c
        ret

; ----------------------------------------------------------------

parse_position:
        ld      de, 0
        call    skip_whitespace
        call    check_digit
        jr      nc, parse_return_error
1:
        call    check_digit
        jr      nc, parse_fetch
        sub     '0'
        ld      c, e
        ld      b, d
        ex      de, hl
        add     hl, hl
        add     hl, hl
        add     hl, bc
        add     hl, hl
        ld      c, a
        ld      b, 0
        add     hl, bc
        ex      de, hl
        inc     hl
        jr      1b

; ----------------------------------------------------------------

parse_end_collection:
        inc     hl
        exx
        ld      a, e
        or      d
        dec     de
        jp      nz, skip_whitespace_exx
        pop     bc
        jr      parse_token_main

; ----------------------------------------------------------------

parse_fetch:
        call    skip_whitespace_exx
        cp      '{'
        jr      z, parse_object
        cp      '['
        jr      nz, parse_return_error
1:
        call    parse_end_collection
        call    check_anything
        jr      c, parse_fail
        call    skip_whitespace
        cp      ']'
        jr      z, parse_fail
        cp      ','
        jr      z, 1b
parse_fail:
        xor     a
        ret

; ----------------------------------------------------------------

parse_object:
        call    parse_end_collection
        call    parse_next_item
        jr      parse_object

; ----------------------------------------------------------------

parse_next_item:
        call    check_key_value
        jr      c, parse_not_found
        call    skip_whitespace
        cp      '}'
        jr      z, parse_not_found
        cp      ','
        ret     z
parse_not_found:
        pop     hl
        xor     a
        ret

; ----------------------------------------------------------------

compare_fail    equ     parse_not_found

; ----------------------------------------------------------------

parse_value:
        call    skip_whitespace_exx
        call    check_key
        jr      c, parse_fail
        jp      parse_token_main_exx

; ----------------------------------------------------------------

parse_key:
        call    skip_whitespace_exx
        cp      '{'
        jp      nz, parse_token_main_exx
        call    skip_whitespace_next
        exx
1:
        call    compare_key
        jr      c, parse_value
        call    skip_whitespace_exx
        call    parse_next_item
        inc     hl
        exx
        jr      1b

; ----------------------------------------------------------------

compare_key:
        ; Returns CF=key found, NC=key not found
        push    hl
        call    skip_whitespace_exx
        push    hl
        exx
        pop     de
        ld      a, (de)
        cp      '"'
        jr      nz, compare_fail
        inc     de
1:
        ld      a, (hl)
        or      a
        jr      z, 2f
        cp      '#'
        jr      z, 2f
        cp      '&'
        jr      z, 2f
        cp      '$'
        jr      z, 2f
        ex      de, hl
        cp      (hl)
        ex      de, hl
        jr      nz, compare_fail
        inc     hl
        inc     de
        jr      1b
2:
        ld      a, (de)
        cp      '"'
        jr      nz, compare_fail
        pop     bc
compare_success:
        scf
        ret

; ----------------------------------------------------------------

json_error      equ     compare_success

; ----------------------------------------------------------------

parse_string:
        call    skip_whitespace
        cp      '{'
        jp      z, parse_fail
        cp      '['
        jp      z, parse_fail
        cp      '"'
        jr      z, parse_string_literal
        ld      (dsctmp + 1), hl
        push    hl
        call    check_anything
parse_string_common:
        or      a
        pop     de
        sbc     hl, de
        ld      a, h
        add     a, 255
        sbc     a, a
        or      l
        ld      (dsctmp), a
        ld      a, 3
        ret

; ----------------------------------------------------------------

parse_string_literal:
        inc     hl
        ld      (dsctmp + 1), hl
        push    hl
        call    check_contents_no_inc
        dec     hl
        jr      parse_string_common

; ----------------------------------------------------------------

skip_whitespace_exx:
        exx
skip_whitespace:
        ld      a, (hl)
        cp      32
        jr      z, skip_whitespace_next
        cp      10
        jr      z, skip_whitespace_next
        cp      13
        jr      z, skip_whitespace_next
        cp      9
        ret     nz
skip_whitespace_next:
        inc     hl
        jr      skip_whitespace

; ----------------------------------------------------------------

check_json:
        call    skip_whitespace
        cp      '['
        jp      z, check_array
        cp      '{'
        jr      nz, json_error
        ; Fall through to check_object

; ----------------------------------------------------------------

check_object:
        ; HL must be pointing to '{'
        call    skip_whitespace_next
        cp      '}'
        jr      z, check_success
check_object_key:
        call    check_key_value
        ret     c
        call    skip_whitespace
        cp      '}'
        jr      z, check_success
        cp      ','
        jr      nz, json_error
        call    skip_whitespace_next
        jr      check_object_key

; ----------------------------------------------------------------

check_key:
        call    check_string
        ret     c
        call    skip_whitespace
        cp      ':'
        jr      z, check_success
        scf
check_success:
        inc     hl
        ret

; ----------------------------------------------------------------

check_key_value:
        call    check_key
        ret     c
        ; Fall through to check_anything

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
        ld      de, token_true
        jr      z, check_string_literal
        cp      'f'
        ld      de, token_false
        jr      z, check_string_literal
        cp      'n'
        jr      z, check_null
        ; Fall through to check_number

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
        ; Fall through to check_fraction

; ----------------------------------------------------------------

check_fraction:
        cp      '.'
        jr      nz, check_scientific
        inc     hl
        call    check_digit_sequence
        ret     c
        ; Fall through to check_scientific

; ----------------------------------------------------------------

check_scientific:
        or      32
        cp      'e'
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
        ; Fall through to check_digit_sequence

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

check_null:
        ld      de, token_null
check_string_literal:
        ld      a, (de)
        or      a
        ret     z
        cp      (hl)
        jp      nz, json_error
        inc     hl
        inc     de
        jr      check_string_literal

; ----------------------------------------------------------------

check_array:
        ; HL must be pointing to '['
        call    skip_whitespace_next
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
        call    skip_whitespace_next
        jr      check_array_next

; ----------------------------------------------------------------

check_string:
        cp      '"'
        jp      nz, json_error
        ; Fall through to check_contents

; ----------------------------------------------------------------

check_contents:
        inc     hl
check_contents_no_inc:
        ld      a, (hl)
        cp      '"'
        jp      z, check_success
        cp      '\\'
        jr      z, check_escape
        jr      check_contents

; ----------------------------------------------------------------

check_escape:
        inc     hl
        ld      a, (hl)
        ex      de, hl
        ld      bc, 8
        ld      hl, string_escapes
        cpir
        ex      de, hl
        jr      z, check_contents
        cp      'u'
        jp      nz, json_error
        ld      b, 4
1:
        inc     hl
        call    check_hex_digit
        jp      nc, json_error
        djnz    1b
        jr      check_contents

; ----------------------------------------------------------------

        macro   CHECK_LIMITS lower, upper
        ; Returns CF=digit, NC=non-digit
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
        or      32
        ; Fall through to check_hex_lower

check_hex_lower:
        CHECK_LIMITS 'a', 'f'

check_digit:
        ld      a, (hl)
        CHECK_LIMITS '0', '9'

; ----------------------------------------------------------------
; Constants

identifiers:    db      '{["0tfn'
escapes_cont:   db      '"\/br'
token_true:     db      'true', 0
token_false:    db      'false', 0
token_null:     db      'null', 0
string_escapes  equ     escapes_cont - 3

; ----------------------------------------------------------------
; Variables

json_start:     dw      0
sentinel:       db      0
sentinel_pos:   dw      0
get_action:     db      0

; ----------------------------------------------------------------

end_bin:

        end

