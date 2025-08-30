.segment "HEADER"
    .byte "NES", $1A
    .byte 2
    .byte 1
    .byte $01
    .byte $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00

.segment "VECTORS"
    .word nmi_handler, reset_handler, 0

.segment "STARTUP"

.zeropage
ball_x: .res 1
ball_y: .res 1
ball_dx: .res 1
ball_dy: .res 1
paddle1_y: .res 1
paddle2_y: .res 1
controller1: .res 1
controller1_old: .res 1
score1: .res 1
score2: .res 1
frame_count: .res 1
temp: .res 1

PADDLE_HEIGHT = 32
PADDLE_SPEED = 2
BALL_SPEED = 1
LEFT_WALL = 16
RIGHT_WALL = 240
TOP_WALL = 16
BOTTOM_WALL = 224

.segment "CODE"

reset_handler:
    sei
    cld
    ldx #$40
    stx $4017
    ldx #$ff
    txs
    inx
    stx $2000
    stx $2001
    stx $4010

vblankwait1:
    bit $2002
    bpl vblankwait1

clrmem:
    lda #$00
    sta $0000, x
    sta $0100, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    lda #$fe
    sta $0200, x
    inx
    bne clrmem

vblankwait2:
    bit $2002
    bpl vblankwait2

    lda #120
    sta ball_x
    sta ball_y
    lda #BALL_SPEED
    sta ball_dx
    sta ball_dy
    lda #100
    sta paddle1_y
    sta paddle2_y
    lda #$00
    sta score1
    sta score2
    sta frame_count
    sta controller1
    sta controller1_old

    lda #$3f
    sta $2006
    lda #$00
    sta $2006

    lda #$0f
    sta $2007
    lda #$30
    sta $2007
    lda #$0f
    sta $2007
    lda #$30
    sta $2007

    ldx #12
skip_bg_pal:
    lda #$0f
    sta $2007
    dex
    bne skip_bg_pal

    lda #$0f
    sta $2007
    lda #$30
    sta $2007
    lda #$30
    sta $2007
    lda #$30
    sta $2007

    ldx #12
skip_spr_pal:
    lda #$0f
    sta $2007
    dex
    bne skip_spr_pal

    lda #$20
    sta $2006
    lda #$00
    sta $2006

    ldx #$20
clear_first_row:
    lda #$00
    sta $2007
    dex
    bne clear_first_row

    ldy #26
draw_center_rows:
    ldx #15
draw_left_empty:
    lda #$00
    sta $2007
    dex
    bne draw_left_empty

    lda #$03
    sta $2007

    ldx #16
draw_right_empty:
    lda #$00
    sta $2007
    dex
    bne draw_right_empty

    dey
    bne draw_center_rows

    ldy #$02
fill_remaining:
    ldx #$00
clear_rest:
    lda #$00
    sta $2007
    inx
    bne clear_rest
    dey
    bne fill_remaining

    jsr update_sprites
    jsr update_score_display

    lda #%10000000
    sta $2000
    lda #%00011110
    sta $2001

game_loop:
    jmp game_loop

read_controller:
    lda controller1
    sta controller1_old

    lda #$01
    sta $4016
    lda #$00
    sta $4016

    lda $4016
    lda $4016
    lda $4016
    lda $4016

    lda $4016
    and #$01
    asl a
    asl a
    asl a
    sta controller1

    lda $4016
    and #$01
    asl a
    asl a
    ora controller1
    sta controller1

    lda $4016
    lda $4016

    rts

update_paddles:
    lda controller1
    and #%00001000
    beq check_down
    lda paddle1_y
    sec
    sbc #PADDLE_SPEED
    cmp #TOP_WALL
    bcc keep_paddle1_pos
    sta paddle1_y
    jmp ai_paddle

check_down:
    lda controller1
    and #%00000100
    beq ai_paddle
    lda paddle1_y
    clc
    adc #PADDLE_SPEED
    cmp #BOTTOM_WALL-PADDLE_HEIGHT
    bcs keep_paddle1_pos
    sta paddle1_y

keep_paddle1_pos:

ai_paddle:
    lda ball_y
    sec
    sbc paddle2_y
    bmi ai_move_up
    cmp #16
    bcc ai_done

    lda paddle2_y
    clc
    adc #PADDLE_SPEED
    cmp #BOTTOM_WALL-PADDLE_HEIGHT
    bcs ai_done
    sta paddle2_y
    jmp ai_done

ai_move_up:
    lda paddle2_y
    sec
    sbc #PADDLE_SPEED
    cmp #TOP_WALL
    bcc ai_done
    sta paddle2_y

ai_done:
    rts

update_ball:
    lda ball_x
    clc
    adc ball_dx
    sta ball_x

    lda ball_y
    clc
    adc ball_dy
    sta ball_y

    lda ball_y
    cmp #TOP_WALL
    bcc bounce_y
    cmp #BOTTOM_WALL-8
    bcs bounce_y
    jmp check_paddles

bounce_y:
    lda ball_dy
    eor #$ff
    clc
    adc #$01
    sta ball_dy

check_paddles:
    lda ball_x
    cmp #LEFT_WALL+8
    bne check_right_paddle

    lda ball_y
    sec
    sbc paddle1_y
    bmi check_right_paddle
    cmp #PADDLE_HEIGHT
    bcs check_right_paddle

    lda #BALL_SPEED
    sta ball_dx
    jmp ball_done

check_right_paddle:
    lda ball_x
    cmp #RIGHT_WALL-8
    bne check_goals

    lda ball_y
    sec
    sbc paddle2_y
    bmi check_goals
    cmp #PADDLE_HEIGHT
    bcs check_goals

    lda #$ff
    sta ball_dx
    jmp ball_done

check_goals:
    lda ball_x
    cmp #LEFT_WALL
    bcc player2_scored
    cmp #RIGHT_WALL
    bcs player1_scored
    jmp ball_done

player1_scored:
    inc score1
    lda score1
    cmp #$0A
    bcc reset_ball_only
    lda #$00
    sta score1
    sta score2
    jmp reset_ball_only

player2_scored:
    inc score2
    lda score2
    cmp #$0A
    bcc reset_ball_only
    lda #$00
    sta score1
    sta score2

reset_ball_only:
reset_ball:
    lda #120
    sta ball_x
    sta ball_y
    lda #BALL_SPEED
    sta ball_dx
    sta ball_dy

ball_done:
    rts

update_score_display:
    lda #$10
    sta $0224
    lda score1
    clc
    adc #$04
    sta $0225
    lda #$00
    sta $0226
    lda #$20
    sta $0227

    lda #$10
    sta $0228
    lda score2
    clc
    adc #$04
    sta $0229
    lda #$00
    sta $022A
    lda #$D0
    sta $022B

    rts

update_sprites:
    lda ball_y
    sta $0200
    lda #$02
    sta $0201
    lda #$00
    sta $0202
    lda ball_x
    sta $0203

    lda paddle1_y
    sta $0204
    lda #$01
    sta $0205
    lda #$00
    sta $0206
    lda #LEFT_WALL
    sta $0207

    lda paddle1_y
    clc
    adc #$08
    sta $0208
    lda #$01
    sta $0209
    lda #$00
    sta $020A
    lda #LEFT_WALL
    sta $020B

    lda paddle1_y
    clc
    adc #$10
    sta $020C
    lda #$01
    sta $020D
    lda #$00
    sta $020E
    lda #LEFT_WALL
    sta $020F

    lda paddle1_y
    clc
    adc #$18
    sta $0210
    lda #$01
    sta $0211
    lda #$00
    sta $0212
    lda #LEFT_WALL
    sta $0213

    lda paddle2_y
    sta $0214
    lda #$01
    sta $0215
    lda #$00
    sta $0216
    lda #RIGHT_WALL
    sta $0217

    lda paddle2_y
    clc
    adc #$08
    sta $0218
    lda #$01
    sta $0219
    lda #$00
    sta $021A
    lda #RIGHT_WALL
    sta $021B

    lda paddle2_y
    clc
    adc #$10
    sta $021C
    lda #$01
    sta $021D
    lda #$00
    sta $021E
    lda #RIGHT_WALL
    sta $021F

    lda paddle2_y
    clc
    adc #$18
    sta $0220
    lda #$01
    sta $0221
    lda #$00
    sta $0222
    lda #RIGHT_WALL
    sta $0223

    rts

nmi_handler:
    pha
    txa
    pha
    tya
    pha

    inc frame_count

    lda frame_count
    and #$01
    bne skip_game_logic

    jsr read_controller
    jsr update_paddles
    jsr update_ball
    jsr update_score_display

skip_game_logic:
    jsr update_sprites

    lda #$00
    sta $2003
    lda #$02
    sta $4014

    lda #$00
    sta $2005
    sta $2005

    pla
    tay
    pla
    tax
    pla

    rti

.segment "CHARS"
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00

    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $00,$00,$00,$00,$00,$00,$00,$00

    .byte $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c
    .byte $00,$42,$81,$81,$81,$81,$42,$00

    .byte $18,$18,$18,$18,$18,$18,$18,$18
    .byte $00,$00,$00,$00,$00,$00,$00,$00

    .byte $3c,$66,$6e,$76,$66,$66,$3c,$00
    .byte $00,$3c,$5a,$52,$4a,$5a,$3c,$00

    .byte $18,$38,$18,$18,$18,$18,$7e,$00
    .byte $00,$18,$28,$18,$18,$18,$7e,$00

    .byte $3c,$66,$06,$0c,$18,$30,$7e,$00
    .byte $00,$3c,$5a,$06,$0c,$30,$7e,$00

    .byte $3c,$66,$06,$1c,$06,$66,$3c,$00
    .byte $00,$3c,$5a,$06,$1c,$5a,$3c,$00

    .byte $0c,$1c,$3c,$6c,$7e,$0c,$0c,$00
    .byte $00,$0c,$1c,$34,$6c,$7e,$0c,$00

    .byte $7e,$60,$7c,$06,$06,$66,$3c,$00
    .byte $00,$7e,$60,$7c,$06,$5a,$3c,$00

    .byte $3c,$66,$60,$7c,$66,$66,$3c,$00
    .byte $00,$3c,$5a,$60,$7c,$5a,$3c,$00

    .byte $7e,$06,$06,$0c,$18,$30,$30,$00
    .byte $00,$7e,$06,$06,$0c,$18,$30,$00

    .byte $3c,$66,$66,$3c,$66,$66,$3c,$00
    .byte $00,$3c,$5a,$5a,$3c,$5a,$3c,$00

    .byte $3c,$66,$66,$3e,$06,$66,$3c,$00
    .byte $00,$3c,$5a,$5a,$3e,$5a,$3c,$00

    .res $2000-224, $00
