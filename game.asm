; NES Pong Game
; Player 1 controls left paddle with Up/Down
; Simple AI controls right paddle

.segment "HEADER"
    .byte "NES", $1A    ; iNES header identifier
    .byte 2             ; 2x 16KB PRG ROM
    .byte 1             ; 1x 8KB CHR ROM
    .byte $01           ; mapper 0, vertical mirroring
    .byte $00           ; mapper 0
    .byte $00, $00, $00, $00, $00, $00, $00, $00 ; padding

.segment "VECTORS"
    .word nmi_handler, reset_handler, 0

.segment "STARTUP"

; Variables in zero page
.zeropage
ball_x: .res 1
ball_y: .res 1
ball_dx: .res 1         ; ball x velocity
ball_dy: .res 1         ; ball y velocity
paddle1_y: .res 1       ; left paddle (player)
paddle2_y: .res 1       ; right paddle (AI)
controller1: .res 1     ; controller input
controller1_old: .res 1 ; previous frame input
score1: .res 1          ; player score
score2: .res 1          ; AI score
frame_count: .res 1
temp: .res 1            ; temporary variable

; Constants
PADDLE_HEIGHT = 32
PADDLE_SPEED = 2
BALL_SPEED = 1
LEFT_WALL = 16
RIGHT_WALL = 240
TOP_WALL = 16
BOTTOM_WALL = 224

.segment "CODE"

reset_handler:
    sei             ; disable IRQs
    cld             ; disable decimal mode
    ldx #$40
    stx $4017       ; disable APU frame IRQ
    ldx #$ff
    txs             ; Set up stack
    inx             ; now X = 0
    stx $2000       ; disable NMI
    stx $2001       ; disable rendering
    stx $4010       ; disable DMC IRQs

    ; Wait for vblank
vblankwait1:
    bit $2002
    bpl vblankwait1

    ; Clear RAM
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
    sta $0200, x    ; move all sprites off screen
    inx
    bne clrmem

    ; Wait for vblank again
vblankwait2:
    bit $2002
    bpl vblankwait2

    ; Initialize game variables
    lda #120        ; center of screen
    sta ball_x
    sta ball_y
    lda #BALL_SPEED
    sta ball_dx
    sta ball_dy
    lda #100        ; center paddles
    sta paddle1_y
    sta paddle2_y
    lda #$00
    sta score1
    sta score2
    sta frame_count
    sta controller1
    sta controller1_old

    ; Load palette
    lda #$3f
    sta $2006    ; PPU high byte
    lda #$00
    sta $2006    ; PPU low byte
    
    ; Background palette
    lda #$0f     ; black
    sta $2007
    lda #$30     ; white
    sta $2007
    lda #$0f     ; black
    sta $2007
    lda #$30     ; white
    sta $2007
    
    ; Skip unused background palettes
    ldx #12
skip_bg_pal:
    lda #$0f
    sta $2007
    dex
    bne skip_bg_pal
    
    ; Sprite palette
    lda #$0f     ; black (transparent)
    sta $2007
    lda #$30     ; white
    sta $2007
    lda #$30     ; white
    sta $2007
    lda #$30     ; white
    sta $2007

    ; Skip remaining sprite palettes
    ldx #12
skip_spr_pal:
    lda #$0f
    sta $2007
    dex
    bne skip_spr_pal

    ; Clear background (all black)
    lda #$20
    sta $2006    ; PPU high byte
    lda #$00
    sta $2006    ; PPU low byte
    
    ; Clear first row
    ldx #$20
clear_first_row:
    lda #$00
    sta $2007
    dex
    bne clear_first_row
    
    ; Draw center line - every other row for 26 rows
    ldy #26     ; number of rows to draw
draw_center_rows:
    ; Draw 15 empty tiles, then center line tile, then 16 empty tiles
    ldx #15
draw_left_empty:
    lda #$00
    sta $2007
    dex
    bne draw_left_empty
    
    lda #$03    ; center line tile
    sta $2007
    
    ldx #16
draw_right_empty:
    lda #$00
    sta $2007
    dex
    bne draw_right_empty
    
    dey
    bne draw_center_rows
    
    ; Fill remaining background with empty tiles
    ldy #$02    ; remaining pages
fill_remaining:
    ldx #$00
clear_rest:
    lda #$00
    sta $2007
    inx
    bne clear_rest
    dey
    bne fill_remaining

    ; Initialize sprites
    jsr update_sprites
    jsr update_score_display

    ; Enable NMI and set PPU
    lda #%10000000   ; enable NMI
    sta $2000
    lda #%00011110   ; enable sprites and background
    sta $2001

game_loop:
    jmp game_loop

; Read controller input
read_controller:
    lda controller1
    sta controller1_old
    
    lda #$01
    sta $4016       ; start reading controller
    lda #$00
    sta $4016       ; finish reading controller
    
    ; Read A button (we'll ignore)
    lda $4016
    
    ; Read B button (we'll ignore) 
    lda $4016
    
    ; Read Select button (we'll ignore)
    lda $4016
    
    ; Read Start button (we'll ignore)
    lda $4016
    
    ; Read Up button
    lda $4016
    and #$01
    asl a
    asl a
    asl a           ; shift to bit 3
    sta controller1
    
    ; Read Down button
    lda $4016
    and #$01
    asl a
    asl a           ; shift to bit 2
    ora controller1
    sta controller1
    
    ; Skip Left and Right buttons
    lda $4016
    lda $4016
    
    rts

; Update paddle positions
update_paddles:
    ; Player paddle (left) - check Up button (bit 3)
    lda controller1
    and #%00001000  ; Up button
    beq check_down
    lda paddle1_y
    sec
    sbc #PADDLE_SPEED
    cmp #TOP_WALL
    bcc keep_paddle1_pos
    sta paddle1_y
    jmp ai_paddle

check_down:
    ; Check Down button (bit 2)
    lda controller1
    and #%00000100  ; Down button
    beq ai_paddle
    lda paddle1_y
    clc
    adc #PADDLE_SPEED
    cmp #BOTTOM_WALL-PADDLE_HEIGHT
    bcs keep_paddle1_pos
    sta paddle1_y

keep_paddle1_pos:

ai_paddle:
    ; Simple AI - follow ball
    lda ball_y
    sec
    sbc paddle2_y
    bmi ai_move_up
    cmp #16         ; dead zone
    bcc ai_done
    
    ; Move down
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

; Update ball position and handle collisions
update_ball:
    ; Move ball
    lda ball_x
    clc
    adc ball_dx
    sta ball_x
    
    lda ball_y
    clc
    adc ball_dy
    sta ball_y
    
    ; Check top/bottom walls
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
    ; Check left paddle collision
    lda ball_x
    cmp #LEFT_WALL+8
    bne check_right_paddle
    
    lda ball_y
    sec
    sbc paddle1_y
    bmi check_right_paddle
    cmp #PADDLE_HEIGHT
    bcs check_right_paddle
    
    ; Hit left paddle
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
    
    ; Hit right paddle
    lda #$ff
    sta ball_dx  ; negative speed
    jmp ball_done
    
check_goals:
    ; Check if ball went off screen
    lda ball_x
    cmp #LEFT_WALL
    bcc player2_scored
    cmp #RIGHT_WALL
    bcs player1_scored
    jmp ball_done
    
player1_scored:
    inc score1
    lda score1
    cmp #$0A    ; check if score reached 10
    bcc reset_ball_only
    ; Player 1 wins! Reset scores
    lda #$00
    sta score1
    sta score2
    jmp reset_ball_only
    
player2_scored:
    inc score2
    lda score2
    cmp #$0A    ; check if score reached 10
    bcc reset_ball_only  
    ; Player 2 wins! Reset scores
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

; Update score display using sprites
update_score_display:
    ; Player 1 score (top left corner)
    lda #$10        ; Y position (higher up)
    sta $0224       ; sprite 9 Y
    lda score1
    clc
    adc #$04        ; number tiles start at tile 4
    sta $0225       ; sprite 9 tile
    lda #$00
    sta $0226       ; sprite 9 attributes
    lda #$20        ; X position (left corner)
    sta $0227       ; sprite 9 X
    
    ; Player 2 score (top right corner)
    lda #$10        ; Y position (higher up)
    sta $0228       ; sprite 10 Y
    lda score2
    clc
    adc #$04        ; number tiles start at tile 4
    sta $0229       ; sprite 10 tile
    lda #$00
    sta $022A       ; sprite 10 attributes
    lda #$D0        ; X position (right corner)
    sta $022B       ; sprite 10 X
    
    rts

; Update all sprite positions
update_sprites:
    ; Ball sprite (sprite 0)
    lda ball_y
    sta $0200
    lda #$02     ; ball tile
    sta $0201
    lda #$00
    sta $0202
    lda ball_x
    sta $0203
    
    ; Left paddle - 4 sprites stacked vertically
    ; Sprite 1
    lda paddle1_y
    sta $0204
    lda #$01
    sta $0205
    lda #$00
    sta $0206
    lda #LEFT_WALL
    sta $0207
    
    ; Sprite 2
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
    
    ; Sprite 3
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
    
    ; Sprite 4
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
    
    ; Right paddle - 4 sprites stacked vertically
    ; Sprite 5
    lda paddle2_y
    sta $0214
    lda #$01
    sta $0215
    lda #$00
    sta $0216
    lda #RIGHT_WALL
    sta $0217
    
    ; Sprite 6
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
    
    ; Sprite 7
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
    
    ; Sprite 8
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
    ; Save registers
    pha
    txa
    pha
    tya
    pha
    
    inc frame_count
    
    ; Only update game logic every other frame
    lda frame_count
    and #$01
    bne skip_game_logic
    
    jsr read_controller
    jsr update_paddles
    jsr update_ball
    jsr update_score_display
    
skip_game_logic:
    jsr update_sprites
    
    ; DMA sprite data
    lda #$00
    sta $2003
    lda #$02
    sta $4014
    
    ; Reset scroll
    lda #$00
    sta $2005
    sta $2005
    
    ; Restore registers
    pla
    tay
    pla
    tax
    pla
    
    rti

.segment "CHARS"
    ; Tile 0 - empty
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    
    ; Tile 1 - paddle segment
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    
    ; Tile 2 - ball
    .byte $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c
    .byte $00,$42,$81,$81,$81,$81,$42,$00
    
    ; Tile 3 - center line segment
    .byte $18,$18,$18,$18,$18,$18,$18,$18
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    
    ; Tile 4 - number 0
    .byte $3c,$66,$6e,$76,$66,$66,$3c,$00
    .byte $00,$3c,$5a,$52,$4a,$5a,$3c,$00
    
    ; Tile 5 - number 1  
    .byte $18,$38,$18,$18,$18,$18,$7e,$00
    .byte $00,$18,$28,$18,$18,$18,$7e,$00
    
    ; Tile 6 - number 2
    .byte $3c,$66,$06,$0c,$18,$30,$7e,$00
    .byte $00,$3c,$5a,$06,$0c,$30,$7e,$00
    
    ; Tile 7 - number 3
    .byte $3c,$66,$06,$1c,$06,$66,$3c,$00
    .byte $00,$3c,$5a,$06,$1c,$5a,$3c,$00
    
    ; Tile 8 - number 4
    .byte $0c,$1c,$3c,$6c,$7e,$0c,$0c,$00
    .byte $00,$0c,$1c,$34,$6c,$7e,$0c,$00
    
    ; Tile 9 - number 5
    .byte $7e,$60,$7c,$06,$06,$66,$3c,$00
    .byte $00,$7e,$60,$7c,$06,$5a,$3c,$00
    
    ; Tile 10 - number 6
    .byte $3c,$66,$60,$7c,$66,$66,$3c,$00
    .byte $00,$3c,$5a,$60,$7c,$5a,$3c,$00
    
    ; Tile 11 - number 7
    .byte $7e,$06,$06,$0c,$18,$30,$30,$00
    .byte $00,$7e,$06,$06,$0c,$18,$30,$00
    
    ; Tile 12 - number 8
    .byte $3c,$66,$66,$3c,$66,$66,$3c,$00
    .byte $00,$3c,$5a,$5a,$3c,$5a,$3c,$00
    
    ; Tile 13 - number 9
    .byte $3c,$66,$66,$3e,$06,$66,$3c,$00
    .byte $00,$3c,$5a,$5a,$3e,$5a,$3c,$00

    ; Fill remaining CHR space
    .res $2000-224, $00