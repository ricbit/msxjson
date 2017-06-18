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
        ld      hl, (dac)
        ld      (json_start), hl
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
        ; Return an integer
        ld      a, 2
        ld      (valtyp), a
        ld      hl, 0
        ld      (dac), hl
        ret

; ----------------------------------------------------------------
; Variables

json_start:     dw      0

; ----------------------------------------------------------------

end_bin:

        end

