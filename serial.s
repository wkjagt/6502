.define ACIA_STATUS_IRQ         1 << 7
.define ACIA_STATUS_DSR         1 << 6
.define ACIA_STATUS_DCD         1 << 5
.define ACIA_STATUS_TX_EMPTY    1 << 4
.define ACIA_STATUS_RX_FULL     1 << 3
.define ACIA_STATUS_OVERRUN     1 << 2
.define ACIA_STATUS_FRAME_ERR   1 << 1
.define ACIA_STATUS_PARITY_ERR  1 << 0


.segment "SERIAL"
serial_data:    .res 1
serial_status:  .res 1
serial_command: .res 1
serial_control: .res 1

.segment "CODE"

.proc setup_acia
  lda #%11001011          ; No parity, no echo, no interrupt
  sta serial_command
  lda #%00011111          ; 1 stop bit, 8 data bits, 19200 baud
  sta serial_control
  rts
.endproc

.proc next_serial_byte
  lda serial_status
  and #ACIA_STATUS_RX_FULL
  beq next_serial_byte
  lda serial_data
  rts
.endproc

.proc write_acia
  jsr delay
  sta serial_data
  rts
.endproc

.proc delay
  ldy #$ff
delay_not_done:
  dey
  bne delay_not_done
  rts
.endproc