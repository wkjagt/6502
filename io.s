.segment "IO"
  ; 6522 I/O Port Controller
  io_b:     .res 1 ; Register "B"
  io_a:     .res 1 ; Register "A"
  io_ddrb:  .res 1 ; Data Direction Register "B"
  io_ddra:  .res 1 ; Data Direction Register "A"
  io_t1c_l: .res 1 ; Read:  T1 Low-Order Counter
                   ; Write: T1 Low-Order Latches
  io_t1c_h: .res 1 ; T1 High-Order Counter
  io_t1l_l: .res 1 ; T1 Low-Order Latches
  io_t1l_h: .res 1 ; T1 High-Order Latches
  io_t2c_l: .res 1 ; Read:  T2 Low-Order Counter
                   ; Write: T2 Low-Order Latches
  io_t2c_h: .res 1 ; T2 High-Order Counter
  io_sr:    .res 1 ; Shift Register
  io_acr:   .res 1 ; Auxilary Control Register
  io_pcr:   .res 1 ; Peripheral Control Register
  io_ifr:   .res 1 ; Interrupt Flag Register
  io_ier:   .res 1 ; Interrupt Enable Register
  io_a_noh: .res 1 ; Same as Register "A" (io_a) except no "Handshake"

.segment "CODE"

.proc setup_via
  lda #%11111111          ; Set all pins on port B to output
  sta io_ddrb
  lda #%11100001          ; Set top 3 pins on port A to output
  sta io_ddra
  rts
.endproc