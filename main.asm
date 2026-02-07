; =========================================================
; TETRIS 
; Author: Xiayuan YE       999025695    ye25258@gtiit.edu.cn
;         Zitong YANG      999028004    yang25573@gtiit.edu.cn
;         Xiaoyuan WU      999020050    wu24321@gtiit.edu.cn
;Date:   2026-01-06
; =========================================================

INCLUDE "hardware.inc"

;Layout Constants
DEF BG_WIDTH        EQU 32
DEF BG_HEIGHT       EQU 32

;Constants
DEF GAME_LEFT_PAD          EQU 2
DEF GAME_WIDTH             EQU 10
DEF WALL_WIDTH             EQU 1
DEF SCORE_LEN              EQU 5
DEF LEVEL_LEN              EQU 5
DEF LINE_LEN               EQU 4
DEF NEXT_LEN               EQU 4
DEF UI_END_COL             EQU 20
DEF GAME_VISIBLE_ROWS      EQU 18
DEF NEXT_BOX_COL_OFFSET    EQU 1
DEF NEXT_BOX_SIZE          EQU 4
DEF NEXT_BOX_START_ROW     EQU 13
DEF NEXT_BOX_START_COL     EQU 16
DEF NEXT_BOX_SPACE_ADDRESS EQU TILEMAP0 + (NEXT_BOX_START_ROW-2) * 32 + NEXT_BOX_START_COL-1
DEF NEXT_BOX_BASE_ADDRESS  EQU TILEMAP0 + NEXT_BOX_START_ROW * 32 + NEXT_BOX_START_COL



DEF GAME_TOTAL_WIDTH  EQU GAME_LEFT_PAD + WALL_WIDTH + GAME_WIDTH + WALL_WIDTH
DEF UI_FOG_WIDTH      EQU UI_END_COL - GAME_TOTAL_WIDTH

DEF GAME_BG_START_COL EQU GAME_LEFT_PAD + WALL_WIDTH ; = 3
DEF GAME_BG_START_ROW EQU 0                         

;Title Layout
DEF TITLE_ROWS_TOP_EMPTY    EQU 7
DEF TITLE_TETRIS_COL        EQU 7
DEF TITLE_TETRIS_LEN        EQU 6
DEF TITLE_PRESS_ROW_GAP     EQU 1
DEF TITLE_PRESS_COL         EQU 4
DEF TITLE_PRESS_LEN         EQU 5
DEF TITLE_ATO_LEN           EQU 6
DEF TITLE_START_LEN         EQU 5
DEF TITLE_TOTAL_COLS        EQU 32
DEF TITLE_TOTAL_ROWS        EQU 32

;Tiles
DEF TILE_SPACE       EQU 0
DEF TILE_P           EQU 1
DEF TILE_R           EQU 2
DEF TILE_E           EQU 3
DEF TILE_S           EQU 4
DEF TILE_A           EQU 5
DEF TILE_T           EQU 6
DEF TILE_O           EQU 7
DEF TILE_I           EQU 8
DEF TILE_C           EQU 9
DEF TILE_L           EQU 10
DEF TILE_N           EQU 11
DEF TILE_X           EQU 12
DEF TILE_WALL        EQU 13
DEF TILE_DIGIT_0     EQU 14
DEF TILE_BOX         EQU 24
DEF TILE_FOG         EQU 25
DEF TILE_Ghost       EQU 26
DEF TILE_G           EQU 27
DEF TILE_M           EQU 28
DEF TILE_V           EQU 29
DEF TILE_BIG_V       EQU 30
DEF TILE_B           EQU 31
DEF TILE_Y           EQU 32
DEF AnimationStart   EQU 33



DEF KEY_A       EQU 0
DEF KEY_B       EQU 1
DEF KEY_SELECT  EQU 2
DEF KEY_START   EQU 3
DEF KEY_RIGHT   EQU 4
DEF KEY_LEFT    EQU 5
DEF KEY_UP      EQU 6
DEF KEY_DOWN    EQU 7


DEF MIN_X         EQU 4
DEF MAX_X         EQU 13  
DEF MAP_OFFSET_X  EQU 4  



SECTION "Header", ROM0[$100]
    jp EntryPoint
    ds $150 - @, 0

SECTION "WRAM", WRAM0

current: ds 1
previous:  ds 1

; Game State
Map:            ds 180  ; 10 * 18
ShadowOAM:      ds 160
NeedClearLines: ds 18
BaseX:          ds 1
BaseY:          ds 1
GhostY:         ds 1
next:           ds 1
BGChanged:      ds 1    
frameCounter:   ds 1
animationFrameCounter:   ds 1
dropTime:       ds 1
currentPiece:   ds 1
nextPiece:      ds 1
RotationState:  ds 1
Score:          ds 2
Lines:          ds 1
Level:          ds 1
GameOver:       ds 1
TempX:          ds 1
TempY:          ds 1
skipDropTime:   ds 1
softDropTime:   ds 1


SECTION "Main", ROM0

EntryPoint:

.wait_vblank
    ldh a, [rLY]
    cp 144
    jr c, .wait_vblank
    xor a
    ldh [rLCDC], a

    ; 1. Clean VRAM
    call NukeVRAM

    ; 2. Load Assets
    call CopyFontTiles
    
    ; 3. Load Title
    ld de, TitleTilemap
    ld hl, TILEMAP0
    ld bc, TitleTilemapEnd - TitleTilemap
    call Copy

    ; 4. Setup Palette
    ld a, %11111100
    ldh [rOBP0], a
    
    ld a, %01010011
    ldh [rOBP1], a
    
    ; Clear OAM
    ld hl, ShadowOAM
    ld bc, 160
    xor a
    call MemFill
    call CopyShadowOAMtoOAMTitle

    ; 5. Turn On
    ld a, LCDC_ON | LCDC_OBJ_ON | LCDC_BG_ON | LCDC_BLOCK01 
    ldh [rLCDC], a

; --- Title Loop ---
TitleLoop:
    call readKeys
    ld a, [current]
    bit KEY_START, a            ; Wait for key
    jr z, TitleLoop

    call StartGameInit
    ; Fall through to GameLoop

; --- Game Loop ---
MainLoop:
    call readKeys
    call HandleInput
    call AutoDrop
    call Pause
    call UpdateObjects

    ld a, [next]
    cp 1
    jr nz, .notNext1
    call LockCurrentPieceToMap
    call ClearLine
.notNext1

    call WaitVBlank ; Wait for VBlank here, before rendering
    ld a, [next]
    cp 1
    jr nz, .notNext2
    call RenderMapToBG
    call WaitVBlank
.notNext2
    call CopyShadowOAMtoOAM
    ld a, [GameOver]
    and a
    jp nz, GameOverSequence

    jp MainLoop

; --- Game Over Loop ---
GameOverSequence:
    ld e,255
.waitVBlankGameOver:
    call WaitVBlank
    dec e
    jr nz, .waitVBlankGameOver    ; game over slowly
    xor a
    ldh [rLCDC], a 

    ld hl, TILEMAP0
    ld bc, 1024 
    xor a
    call MemFill
    
    call ResetShadowOAM
    call CopyShadowOAMtoOAMTitle ; Push to hardware

    ld de, GameOverTilemap
    ld hl, TILEMAP0
    ld bc, GameOverTilemapEnd - GameOverTilemap
    call Copy


    ld a, LCDC_ON | LCDC_BG_ON | LCDC_BLOCK01 
    ldh [rLCDC], a

.waitRestart:
    call readKeys
    ld a, [current]
    bit KEY_START, a
    jr z, .waitRestart
    
    xor a
    ld [GameOver], a
    jp EntryPoint

StartGameInit:
.wait
    ldh a, [rLY]
    cp 144
    jr c, .wait
    xor a
    ldh [rLCDC], a

    ; Clear BG
    ld hl, TILEMAP0
    ld bc, 1024
    xor a
    call MemFill 

    ld hl, NeedClearLines
    ld bc, 18
    xor a
    call MemFill 
    
    ld de, GameTilemap
    ld hl, TILEMAP0
    ld bc, GameTilemapEnd - GameTilemap
    call Copy 

    ;Init
    xor a
    ld [currentPiece], a
    ld [nextPiece], a
    ld [frameCounter], a
    ld [RotationState], a
    ld [GameOver], a  
    ld [BGChanged], a  
    ld [Score], a
    ld [Score+1], a
    ld [Lines], a
    ld [Level], a
    ld [softDropTime], a
    
    ld a, 1
    ld [next], a

    ld a, 8         
    ld [BaseX], a
    ld a, 0         
    ld [BaseY], a
    
    ld a, 40
    ld [dropTime], a

    call RandomByte
    and %00000111
    cp 7
    jr nz, .getFirstNextPiece
    xor a
.getFirstNextPiece:
    ld [nextPiece], a

    ; update the first next display

    ; clear Map
    ld hl, Map
    ld bc, 180
    xor a
    call MemFill

    ld a, LCDC_ON | LCDC_OBJ_ON | LCDC_BG_ON | LCDC_BLOCK01
    ldh [rLCDC], a
    call GenerateNewPiece
    ret

Pause:
    ld a, [current]
    bit KEY_START,a
    ret z
  
  ;  pause
.pauseLoop:
    call readKeys
    ld a, [current]
    bit KEY_START,a
    jr z, .pauseLoop

    ret
  
AutoDrop:
    ld a,[next]
    cp 1
    jr nz, .notNew
    ld a,0
    ld [next],a
    call GenerateNewPiece
    ret
.notNew:
    ld a,[skipDropTime]
    cp 1
    jr z, .Skip
    ld a, [frameCounter]
    inc a
    ld [frameCounter], a
    ld b, a
    ld a, [dropTime]
    cp b
    ret nz

.Skip:
    xor a
    ld [skipDropTime], a
    and a
    ld [frameCounter], a
    call CheckCollisionDown

    jr nc, .storeDown
    ld a,1
    ld [next],a
    ret

.storeDown:
    call MoveDown
    ret

MoveDown:
    ld a, [BaseY]
    inc a
    ld [BaseY], a
    ret
    

UpdateScoreDisplay:
    ; Update the Score display on the screen
    ; get the score 
    ld hl, Score
    ld a, [hl+]
    ld e, a
    ld a, [hl]
    ld d, a

    ; Compute the address of the Score display
    ; Score is at row 3, col ( GAME_TOTAL_WIDTH + 1)
    ld hl, TILEMAP0 + 2 * BG_WIDTH + (GAME_TOTAL_WIDTH + 1)
    
    ; Compute each digit
    ; We compute how many times we can sub

    ; first digit
    ld bc, 10000
    call CountSubtractions
    add TILE_DIGIT_0
    ld [hl+], a

    ; second digit
    ld bc, 1000
    call CountSubtractions
    add TILE_DIGIT_0
    ld [hl+], a

    ; third digit
    ld bc, 100
    call CountSubtractions
    add TILE_DIGIT_0
    ld [hl+], a

    ; fourth digit
    ld bc, 10
    call CountSubtractions
    add TILE_DIGIT_0
    ld [hl+], a

    ; fifth digit
    ld a, e
    add TILE_DIGIT_0
    ld [hl+], a

    ret
    
UpdateLevelDisplay:
    ; Update the Lines display on the screen
    ld hl, Level
    ld a, [hl+]
    ld e, a
    ld a, [hl]
    ld d, a
    

    ; Compute the address of the Lines display
    ; Level is at row 9, col ( GAME_TOTAL_WIDTH + 1)
    ld hl, TILEMAP0 + 8 * BG_WIDTH + (GAME_TOTAL_WIDTH + 1)
    ; Compute each digit
    ; We compute how many times we can sub

    ; first digit
    ld bc, 10000
    call CountSubtractions
    add TILE_DIGIT_0
    ld [hl+], a

    ; second digit
    ld bc, 1000
    call CountSubtractions
    add TILE_DIGIT_0
    ld [hl+], a

    ; third digit
    ld bc, 100
    call CountSubtractions
    add TILE_DIGIT_0
    ld [hl+], a

    ; fourth digit
    ld bc, 10
    call CountSubtractions
    add TILE_DIGIT_0
    ld [hl+], a

    ; fifth digit
    ld a, e
    add TILE_DIGIT_0
    ld [hl+], a

    ret
UpdateLinesDisplay:
    ; Update the Lines display on the screen
    ld a, [Lines]
    ld e, a
    ld d, 0
    

    ; Compute the address of the Lines display
    ; Lines is at row 6, col ( GAME_TOTAL_WIDTH + 1)
    ld hl, TILEMAP0 + 5 * BG_WIDTH + (GAME_TOTAL_WIDTH + 1)
    ; Compute each digit
    ; We compute how many times we can sub

    ; first digit
    ld bc, 1000
    call CountSubtractions
    add TILE_DIGIT_0
    ld [hl+], a

    ; second digit
    ld bc, 100
    call CountSubtractions
    add TILE_DIGIT_0
    ld [hl+], a

    ; third digit
    ld bc, 10
    call CountSubtractions
    add TILE_DIGIT_0
    ld [hl+], a

    ; fourth digit
    ld a, e
    add TILE_DIGIT_0
    ld [hl+], a

    ret

DrawNextPieceDisplay:
    call WaitVBlank
    ld hl,NEXT_BOX_SPACE_ADDRESS
    ld b,4
.clearLoop:
    ld c,4
.clearInnerLoop:
    ld [hl],TILE_SPACE
    inc hl
    dec c
    jr nz, .clearInnerLoop
    ld c,28         ;32 per line - 4 element
    ld a,l
    add c
    ld l,a
    jr nc,.noCarry0
    inc h
.noCarry0:
    dec b
    jr nz, .clearLoop

    ld hl,PieceAddressTable
    ld a,[nextPiece]
    add a,a
    add a,l
    ld l,a
    jr nc,.notcarray
    inc h
.notcarray:
    ld a,[hl+]
    ld h,[hl]
    ld l,a

    call WaitVBlank
    ld b,4
.drawLoop:

    push bc
    ; --- Y ---
    ld a, [hl]
    inc hl
    ld c, a          ; c = Y
    ; --- X ---
    ld a, [hl]
    inc hl
    ld b, a          ; b = X    
    
    push hl
    push bc
    ld hl,TILEMAP0
    ld hl, NEXT_BOX_BASE_ADDRESS
    ld a, c
    bit 7, a
    jr z, .positive
    cpl
    inc a             ; a = |c| 
    
    ld e, a
    ld d, 0
      
    sla e
    rl d
    sla e
    rl d
    sla e
    rl d
    sla e
    rl d
    sla e
    rl d              ; ×32
      
    ld c, e
    ld b,d
    ld a, l
    sub c
    ld l, a
    ld a, h
    sbc b
    ld h, a           ;hl+= -c*32
    jr .ok 
      
  .positive:
  
    ld e, a
    ld d, 0
    
    sla e
    rl d
    sla e
    rl d
    sla e
    rl d
    sla e
    rl d
    sla e
    rl d              ; ×32

    add hl, de
.ok
    pop bc
    ld a,b
    bit 7, a
    jr z, .positive2
    cpl
    inc a             ; a = |b|
    ld b,a
    ld a, l
    sub b
    ld l, a
    jr nc, .noCarry1
    dec h
.noCarry1:
    jr .noCarry
.positive2:
    add a, l
    ld l, a
    jr nc, .noCarry
    inc h
.noCarry:
  ;hl=NEXT_BOX_BASE_ADDRESS + c*32 + d

    ld [hl],TILE_BOX
    pop hl
    pop bc

    dec b
    jr nz, .drawLoop

    ld a, 1
    ld [BGChanged], a
    ret

CountSubtractions:
    ; Input : DE = the number we need to sub
    ;         BC = the sub number
    ; Output: A  = the counter
    ;         DE = the remainder
    push hl
    ld hl, 0 ; counter
.countLoop:
    ; compare de, bc
    ld a, d
    cp b
    jr c, .done ; d < b, de < bc
    jr nz, .subtract ; d > b, de > bc
    ; d = b
    ld a, e
    cp c
    jr c, .done

.subtract:
    ; de >= bc, subtract
    ld a, e
    sub c
    ld e, a
    ld a, d
    sbc b
    ld d, a
    
    inc hl
    jr .countLoop

.done:
    ld a, l
    pop hl
    ret
  
GetDropTime:
    ; baseDropTime = 40
    ; DropTime = baseDropTime - level * 2
    ; level = 0, 1, 2, ....., 10
    push bc
    push hl
    
    ld a, [Level]
    cp 10
    jr c, .levelInRange
    ld a, 10
.levelInRange:
    ld [Level], a
    ld c, a
    ld a, 40
    sub c
    sub c
    
    cp 20 ; min dropTime
    jr nc, .noMin
    ld a, 20
    
.noMin:
    ld [dropTime], a
    pop hl
    pop bc
    ret

UpdateLevel:
    ; 5 lines 1 level
    push af
    push bc
    
    ; level = lines / 5
    ld a, [Lines]
    ld b, 0
.countLevel:
    cp 5
    jr c, .done
    sub 5
    inc b
    jr .countLevel
    
.done:
    ld a, b
    ld [Level], a
    
    call UpdateLevelDisplay
    call GetDropTime
    
    pop bc
    pop af
    ret
  

ClearLine:
    ; from the last line, check whether do we need to clear the line
  
    ld b, 17  ; from the last line
    ld c, 0   ; c is the cleared line counter
  
.checkCurrentLine:
    ; Check whether b = 0
    ld a, b
    and a
    jr z, .finishChecking

    ld hl, Map
    ld a, b
    call MultiplyBy10 ; de = b * 10
    add hl, de        ; hl = Map + b*10
    
    ; Check whether the line need to clear
    push bc
    ld d, 10
    ld e, 0
  
.checkRow:
    ld a, [hl+]
    and a
    jr z, .notFull
    inc e
    dec d
    jr nz, .checkRow
.notFull:
  
    ; if e = 10, full, need to clear
    ld a, e
    cp 10
    jr nz, .rowNotFull

    ;set this line map to 2, in order to play animation
    ld a,l
    sub 10
    ld l,a
    jr nc,.noCarry
    dec h
.noCarry:

    ld d,10
    .checkRow2:
    ld  [hl],AnimationStart
    inc hl
    dec d
    jr nz, .checkRow2
    ;full

    pop bc
    inc c 
    push hl
    ld hl,NeedClearLines
    ld a, l
    add b
    ld l,a
    jr nc,.noCarry2
    inc h
.noCarry2:
    ld [hl], 1
    pop hl
    push bc
.rowNotFull:
    pop bc
    dec b ; move to the above line
    ld a, b
    cp $FF ; when b underflowed, done
    jp nz, .checkCurrentLine

; finish checking all lines
.finishChecking:
    ld a, c
    and a
    jp z, .noLinesCleared
    
    call WaitVBlank
    call RenderMapToBG
    call RenderMapAmination         ;play animation

    ld b, 17
.clearCurrentLine:
    ; Check whether b = 0
    push bc
    ld hl,NeedClearLines
    ld a, l
    add b
    ld l,a
    jr nc,.noCarry3
    inc h
.noCarry3:
    ld a, b
    and a
    jr z, .finishedClearing
    ld a, b 
    ld [TempX], a       ; TempX = clearedRow
    ld [TempY], a       ; TempY = shift cursor
    ld a, [hl]
    and a
    jr z, .nextLineToClear
      ld a, b
      ld [TempX], a
      ld [TempY], a
.shiftLoop:
    ld a, [TempY]
    and a
    jr z, .clearTopLine  ; when TempY=0, done shifting, then clear top

    push bc
    
    ld a, [TempY]
    dec a
    
    ld hl,NeedClearLines
    add l
    ld l,a
    jr nc,.noCarry4
    inc h
.noCarry4:
    ld a,[hl]
    inc hl
    ld [hl],a

    ld a, [TempY]
    dec a
    call MultiplyBy10
    pop bc
    ld hl, Map
    add hl, de
    push hl
    
    push bc
    ld a, [TempY]
    call MultiplyBy10
    pop bc
    ld hl, Map
    add hl, de
    ld d, h
    ld e, l             ; de = dst
    pop hl              ; hl = src

    ; copy 10 times
    ld b, 10
.copy10:
    ld a, [hl+]
    ld [de], a
    inc de
    dec b
    jr nz, .copy10

    ld a, [TempY]
    dec a
    ld [TempY], a
    
    jr .shiftLoop
.clearTopLine:
    ld hl,NeedClearLines
    xor a
    ld [hl], a
    ld hl, Map
    ld b, 10
    xor a
.clearTopLoop:
    ld [hl+], a
    dec b
    jr nz, .clearTopLoop

    pop bc
    ; map changed, need request BGrender
    ld a, 1
    ld [BGChanged], a
    ; recheck the same line
    ld a, [TempX]
    ld b, a
    
    jr .clearCurrentLine

.nextLineToClear
    pop bc
    dec hl
    dec b ; move to the above line
    ld a, b
    cp $FF ; when b underflowed, done
    jp nz, .clearCurrentLine

.finishedClearing:
    pop bc



    ; make sure BG will refresh
    ld a, 1
    ld [BGChanged], a

    ; update Scores
    ; use two bytes to store Score
    ld hl, Score
    ld a, c
    cp 1
    jr z, .oneLine
    cp 2
    jr z, .twoLines
    cp 3
    jr z, .threeLines
    ; four lines
    ld de, 800
    jr .updateScore
.oneLine:
    ld de, 100
    jr .updateScore
.twoLines:
    ld de, 300
    jr .updateScore
.threeLines:
    ld de, 500
    
.updateScore:
    ld a, [hl]
    add e
    ld [hl+], a
    ld a, [hl]
    adc d
    ld [hl+], a
    ; update Lines
    ld a, [Lines]
    add c
    ld [Lines], a
    
    call UpdateLevel
    call WaitVBlank
    call UpdateScoreDisplay
    call UpdateLinesDisplay
    call UpdateLevelDisplay
.noLinesCleared:
    ret

HandleInput:
    ld a, [current]
    push af
    bit KEY_B, a ; B
    jr z, .checkRoutateLeft
    call Rotate
    jr .endInput

.checkRoutateLeft:
    bit KEY_A, a ; A
    jr z, .HardDrop
    call RotateLeft
    jr .endInput

.HardDrop:
    bit KEY_UP, a ; UP
    jr z, .checkLeft
    call HardDropFunction
    jr .endInput

.checkLeft:
    bit KEY_LEFT, a ; LEFT
    jr z, .checkRight
    call CheckCollisionLeft
    jr c, .checkRight
    ld a, [BaseX]
    dec a
    cp MIN_X
    jr nc, .saveX
    ld a, MIN_X
    jr .saveX
.checkRight:
    pop af
    bit KEY_RIGHT, a ; RIGHT
    push af
    jr z, .checkDown
    call CheckCollisionRight
    jr c, .checkDown
    ld a, [BaseX]
    inc a
    cp MAX_X
    jr c, .saveX
    ld a, MAX_X 
.saveX:
    ld [BaseX], a
.checkDown:
    ld a, [previous]
    bit KEY_DOWN, a
    jr z, .keyNotPressedDown
    
    ; Pressed
    call CheckCollisionDown
    jr c, .endInput
    
    ; Check whether the first time to be pressed
    ld a, [current]
    bit KEY_DOWN, a
    jr z, .notFirstPress
    
    call MoveDown
    xor a
    ld [softDropTime], a
    jr .resetAutoDrop
    
.notFirstPress:
    ; keep pressing
    ld a, [softDropTime]
    inc a
    ld [softDropTime], a
    
    ; set the softDrop time
    cp 5 ; set softDrop speed : 5 frames
    jr nz, .endInput
    
    call MoveDown
    
    ; reset the timeCounter
    xor a
    ld [softDropTime], a
    
.resetAutoDrop:
    xor a
    ld [frameCounter], a
    
    jr .endInput

.keyNotPressedDown:
    xor a
    ld [softDropTime], a
.endInput:
    pop af
    ret

Rotate:
    xor a
    ld d, a
    ld e,a
    call CheckCollisionRotateRight;d to left,e to right
    ; Check if rotation causes collision
    ld d, 0
    ld e,0
    jr nc, .applyMove

    ld e, 1           ; Try moving right by 1
    call CheckCollisionRotateRight
    ld d, 0
    ld e,1
    
    jr nc, .applyMove

    xor a
    ld e,a
    ld d, 1           ; move left by 1
    call CheckCollisionRotateRight
    ld e,0
    ld d, 1
    jr nc, .applyMove

    ld a, [currentPiece]
    cp 0
    jr nz, .noFurtherCheck ; If not piece I, stop further checks. Only I needs move 2 blocks.
    
    xor a
    ld d,a
    ld e, 2           ; Try moving right by 2
    call CheckCollisionRotateRight
    ld d,0
    ld e, 2           ; move right by 2
    jr nc, .applyMove

    xor a
    ld e,a
    ld d, 2          ; Try moving left by 2
    call CheckCollisionRotateRight
    ld e,0
    ld d, 2         ; move left by 2
    jr nc, .applyMove

    ret c

.applyMove:
    ld a, [BaseX]
    add e             ; Apply the movement
    sub d
    ld [BaseX], a
    ld a, [RotationState]
    add 8
    cp 32
    jr c, .ok
    xor a
.ok:
    ld [RotationState], a
    ret

.noFurtherCheck:
    ret

RotateLeft:
    xor a
    ld d, a
    ld e,a
    call CheckCollisionRotateLeft           ;d to left,e to right
    ; Check if rotation causes collision
    ld d, 0
    ld e,0
    jr nc, .applyMove


    ld e, 1           ; Try moving right by 1
    call CheckCollisionRotateLeft
    ld d, 0
    ld e,1
    
    jr nc, .applyMove


    xor a
    ld e,a
    ld d, 1           ; Try moving left by 1
    call CheckCollisionRotateLeft
    ld e,0
    ld d, 1
    jr nc, .applyMove

    ld a, [currentPiece]
    cp 0
    jr nz, .noFurtherCheck ; If not piece I, stop further checks. Only I needs move 2 blocks.
    
    xor a
    ld d,a
    ld e, 2           ; Try moving right by 2
    call CheckCollisionRotateLeft
    
    ld d,0
    ld e, 2           ; move right 2
    jr nc, .applyMove

    xor a
    ld e,a
    ld d, 2          ; Try moving left by 2
    call CheckCollisionRotateLeft
    ld e,0
    ld d, 2          ; move left 2
    jr nc, .applyMove

    ret c

.applyMove:
    ld a, [BaseX]
    add e             ; Apply the movement
    sub d
    ld [BaseX], a
    ret c
    ld a, [RotationState]
    sub 8
    jr nc, .ok
    ld a, 24
    .ok:
    ld [RotationState], a
    ret

.noFurtherCheck:
    ret

GenerateNewPiece:
    ld a, [nextPiece]
    ld [currentPiece], a

    call RandomByte
    and %00000111
    cp 7
    jr nz, .getNextPiece
    xor a
.getNextPiece:
    ld [nextPiece], a

    ; update the next display
    call DrawNextPieceDisplay

    ; reset position
    ld a, 8
    ld [BaseX], a
    ld d, a ; d : Xcoord
    ld a, 2
    ld [BaseY], a
    ld e, a ; e : Ycoord
    ld a, 0
    ld [RotationState], a
    
    call CheckCollisionAtPosition
    jr c, .gameOver
    ret
.gameOver:
    ld a, 1
    ld [GameOver], a

    ret
 

HardDropFunction:
; Drop the piece until it collides  
.dropLoop:
    call CheckCollisionDown
    jr c, .doneDrop
    call MoveDown
    jr .dropLoop
.doneDrop:
    ld a,1
    ld [skipDropTime], a
    ret

  
CheckCollisionRotateRight:
    ld a, [BaseX]
    sub d
    add e 
    ld d, a ; d : Xcoord
    ld a, [BaseY]
    dec a
    ld e, a ; e : Ycoord
    ld a, [RotationState]
    add a, 8
    cp 32
    jr c, .ok
    xor a
.ok:
    ld c,a
    call CheckCollisionAtPosition
    ret


CheckCollisionRotateLeft:
    ld a, [BaseX]
    sub d
    add e
    ld d, a ; d : Xcoord
    ld a, [BaseY]
    dec a
    ld e, a ; e : Ycoord
    ld a, [RotationState]
    sub 8
    jr nc, .okL
    ld a, 24
.okL:
    ld c, a
    call CheckCollisionAtPosition
    ret


CheckCollisionDown:
    ld a, [BaseX]
    ld d, a ; d : Xcoord
    ld a, [BaseY]
    ld e, a ; e : Ycoord
    ld a, [RotationState]
    ld c, a ; c : rotation state
    
    call CheckCollisionAtPosition
    ret

CheckCollisionLeft:
    ld a, [BaseX]
    dec a
    ld d, a ; d : Xcoord
    ld a, [BaseY]
    dec a
    ld e, a ; e : Ycoord
    ld a, [RotationState]
    ld c, a ; c : rotation state
    
    call CheckCollisionAtPosition
    ret

CheckCollisionRight:
    ld a, [BaseX]
    inc a
    ld d, a ; d : Xcoord
    ld a, [BaseY]
    dec a
    ld e, a ; e : Ycoord
    ld a, [RotationState]
    ld c, a ; c : rotation state
    
    call CheckCollisionAtPosition
    ret

CheckCollisionAtPosition:
    ; Get the address of the piece data
    ld b,0

    ld hl,PieceAddressTable
    ld a,[currentPiece]
    add a,a
    add a,l
    ld l,a
    jr nc,.notcarray
    inc h
.notcarray:
    ld a,[hl+]
    ld h,[hl]
    ld l,a

    add hl, bc       ; hl + current rotation data
  
    ld b, 4 ; Each Tetromino has 4 blocks
.checkLoop:
    push bc
    push hl
    push de
    ; OffsetY 
    ld a, [hl+]
    add e ; e : Ycoord
    ld c, a 
    ; OffsetX
    ld a, [hl]
    add d ; d : Xcoord
    ld b, a

    ; Check the boundary
    ld a, b
    cp 4
    jr c, .collision
    cp 14
    jr nc, .collision
    ld a, c
    
    cp 19
    jr c, .notcollisionOnY
    cp 255
    jr nz, .collision
    .notcollisionOnY
    ; Check map collision
    ; The Index of piece: Y * 10 + X

    dec c
    ld a, c
    add a, a            ; *2
    ld l, a
    ld h, 0
    ld de, MapRowTable
    add hl, de
    ld a, [hl+]
    ld h, [hl]
    ld l, a             ; HL = first address of the row
    
    ; HL += (X - 4)
    ld a, b
    sub 4
    add l
    jr nc,.notcarry
    inc h
.notcarry
    ld l,a
    ld a, [hl]
  
    cp TILE_BOX
    jr z, .collision
    pop de
    pop hl
    pop bc
    
    inc hl
    inc hl
    dec b
    jr nz, .checkLoop

    ; no collision
    and a ; clear the carry flag (no collision)
    jr .noCollision

.collision:
    pop de
    pop hl
    pop bc
    scf ; set the carry flag (collision)
    ret
.noCollision:
    ret
  
LockCurrentPieceToMap:
    ld a, [BaseX]
    ld d, a          ; d = BaseX
    ld a, [BaseY]
    ld e, a          ; e = BaseY

    ld a, [RotationState]     ; rotation (0 / 8 / 16 / 24)
    
    ld b, 0
    ld c, a

    ld hl,PieceAddressTable
    ld a,[currentPiece]
    add a,a
    add a,l
    ld l,a
    jr nc,.notcarray
    inc h
.notcarray:
    ld a,[hl+]
    ld h,[hl]
    ld l,a

    add hl, bc       ; hl + current rotation data
  
    ld b,4
.loop
    push bc
    ; --- Y ---
    ld a, [hl]
    inc hl
    add e 
    ld c, a          ; c = Y
    ; --- X ---
    ld a, [hl]
    inc hl
    add d
    ld b, a          ; b = X
    push hl
    push de
    call MarkPieceIntoMap
    pop de
    pop hl
    pop bc
    dec b
    jr nz, .loop
  
    ld a, 1
    ld [BGChanged], a
  
    ret

MarkPieceIntoMap:
    ; b = X (4–14)
    ; c = Y (1–18)

    ; HL = MapRowTable[(Y-1)] 
    dec c
    dec c
    ld a, c
    add a, a            ; *2
    ld l, a
    ld h, 0
    ld de, MapRowTable
    add hl, de
    ld a, [hl+]
    ld h, [hl]
    ld l, a             ; HL = first address of the row
    
    ; HL += (X - 4)
    ld a, b
    sub 4
    add l
    jr nc,.notcarry
    inc h
.notcarry
    ld l,a
    
    ld a, TILE_BOX
    ld [hl],a
    ret

;Compute the ghost piece position
UpdateGhostPiece:
    ld a, [BaseX]
    ld d, a ; d : X
    ld a, [BaseY]
    dec a
    ld e, a ; e : Y
    ld a, [RotationState]
    ld c, a ; c : rotation state
.loop
    ld a, e
    inc a
    ld e, a
    ld [GhostY], a
    call CheckCollisionAtPosition
    jr nc, .loop
    
    ret

RandomByte:
; Return a "random" byte into A
; by mixing a few values with XOR
    ld a,[rDIV]
    xor b
    xor l
    xor [hl]
    ret
ResetShadowOAM:
    ld hl, ShadowOAM
    call ResetOAM
    ret
; =========================================================
; Update Pieces (OAM)
; =========================================================

UpdateObjects:  
    call UpdateGhostPiece
    ld a,[RotationState]
    ld b,0
    ld c,a
    ld hl,PieceAddressTable
    ld a,[currentPiece]
    add a,a
    add a,l
    ld l,a
    jr nc,.notcarray
    inc h
.notcarray:
    ld a,[hl+]
    ld h,[hl]
    ld l,a

    add hl,bc
    ld d,h
    ld e,l
    ld hl,ShadowOAM
    push de
    ld c,4
.loop
    ld a,[BaseY]
    ld b,a
    ld a,[de]
    add b
    sla a
    sla a
    sla a
    
    ld [hl],a
    inc hl
    
    inc de
    ld a,[BaseX]
    ld b,a
    ld a,[de]
    add b
    sla a
    sla a
    sla a

    ld [hl],a
    inc hl
    ld a,TILE_BOX
    ld [hl],a
    inc hl
    inc hl
    
    inc de
    dec c
    jr nz,.loop

    ;ghost piece
    pop de
    ld c,4
.loop2
    ld a,[GhostY]
    ld b,a
    ld a,[de]
    add b
    sla a
    sla a
    sla a
    
    ld [hl],a
    inc hl
    
    inc de
    ld a,[BaseX]
    ld b,a
    ld a,[de]
    add b
    sla a
    sla a
    sla a
    
    ld [hl],a
    inc hl
    ld a,TILE_Ghost
    ld [hl],a
    inc hl
    ld a,%00010000
    ld [hl],a
    inc hl
    
    inc de
    dec c
    jr nz,.loop2
    
    ret


;Render 
RenderMapToBG:
    ld a, [BGChanged]
    cp 1
    ret nz              ; no change, do not render

    ld hl, Map
    ld de, TILEMAP0
    ld a, 3             ; x offset 3
    add a, e
    ld e, a

    ld b, 18                ; 18 rows
.rowLoop:
    ; ---- 10 columns, fully unrolled ----
    ld a, [hl+]             ; 1
    ld [de], a
    inc e

    ld a, [hl+]             ; 2
    ld [de], a
    inc e

    ld a, [hl+]             ; 3
    ld [de], a
    inc e

    ld a, [hl+]             ; 4
    ld [de], a
    inc e

    ld a, [hl+]             ; 5
    ld [de], a
    inc e

    ld a, [hl+]             ; 6
    ld [de], a
    inc e

    ld a, [hl+]             ; 7
    ld [de], a
    inc e

    ld a, [hl+]             ; 8
    ld [de], a
    inc e

    ld a, [hl+]             ; 9
    ld [de], a
    inc e

    ld a, [hl+]             ; 10
    ld [de], a
    inc e
    ; ---- end of row ----

    ; jump 22 to next row in tilemap
    ld a, e
    add a, 22
    ld e, a
    jr nc, .noCarryRow
    inc d
.noCarryRow:

    dec b
    jr nz, .rowLoop

    xor a
    ld [BGChanged], a
    ret


  
RenderMapAmination:
    call WaitVBlank
    ld hl, STARTOF(OAM)
    ld b, 32
    xor a
.loop:
    ld [hl], a
    inc hl
    dec b
    jr nz, .loop

    ld b, 7           ;totally 7 frames

    xor a
    ld [animationFrameCounter],a
.frame_loop:
    push bc
    ld hl, NeedClearLines
    ld de, TILEMAP0
    ld a, 3
    add a, e
    ld e, a
    jr nc, .noCarryX
    inc d
.noCarryX:

    ld b, 18

.rowLoop:
    push bc
    ld c, 10
    ld a, [hl+]         ; read Map
    cp 0
    jr z, .dontWrite
    ld a,[animationFrameCounter]
    ld b, a
    ld a,AnimationStart       ; animation tile
    
    add b

.colLoop:
    ld [de], a
    inc de
    dec c
    jr nz, .colLoop
    jr .noCarry2
.dontWrite:
    ld a, 10
    add a, e
    ld e, a
    jr nc, .noCarry2
    inc d
.noCarry2:

    ; jump 22 to next row
    ld a, b

    cp 14
    jr nz, .endRowSkip3
    call WaitVBlank
.endRowSkip3:
    ld a, e
    add a, 22
    ld e, a
    jr nc, .noCarryRow
    inc d
.noCarryRow:

        
    ;
    pop bc
    dec b
    jr nz, .rowLoop
    ld b,10
.waitLoop:
    call WaitVBlank
    dec b
    jr nz, .waitLoop
    pop bc
    ld a,[animationFrameCounter]

    inc a
    ld [animationFrameCounter],a
    
    dec b
    jr nz, .frame_loop
    ret

; =========================================================
; Helpers
; =========================================================

MultiplyBy10:
    ; Input: a 
    ; Output: de = a * 10
    add a, a ; * 2
    ld e, a ; e = a * 2
    add a, a ; * 4
    add a, a ; * 8
    add a, e ; * 10
    ld e, a
    ld d, 0
    ret
  
NukeVRAM:
    ld hl, STARTOF(VRAM)
    ld bc, $2000      ;8kb
    xor a
    call MemFill
    ret

MemFill: 
    push de
.loop:
    ld [hli], a
    dec bc
    ld d, a
    ld a, b
    or c
    ld a, d
    jr nz, .loop
    pop de
    ret

Copy:
    ld a, [de]
    inc de
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, Copy
    ret

CopyFontTiles:
    ld de, FontTiles
    ld hl, STARTOF(VRAM)
    ld bc, FontTilesEnd - FontTiles
.copy:
    ld a, [de]
    inc de
    ld [hli], a
    ld [hli], a 
    dec bc
    ld a, b
    or c
    jr nz, .copy
    ret

;---------------------------------------------------------------------
readKeys:
;---------------------------------------------------------------------
; Output:
; b : raw state:   pressing key triggers given action continuously
;                  as long as it is pressed
; c : rising edge: pressing key triggers given action only once,
;                  key must be released and pressed again
; Requires to define variables `previous` and `current`
  ld    a,$20
  ldh   [rP1],a   
  ldh   a,[rP1] :: ldh a,[rP1]
  cpl
  and   $0F         ; lower nibble has down, up, left, right
  swap	a           ; becomes high nibble
  ld	b,a
  ld    a,$10
  ldh   [rP1],a
  ldh   a,[rP1] :: ldh a,[rP1] :: ldh a,[rP1]
  ldh   a,[rP1] :: ldh a,[rP1] :: ldh a,[rP1]
  cpl
  and   $0F         ; lower nibble has start, select, B, A
  or    b
  ld    b,a

  ld    a,[previous]  ; load previous state
  xor   b	      ; result will be 0 if it's the same as current read
  and   b	      ; keep buttons that were pressed during this read only
  ld    [current],a   ; store result in "current" variable and c register
  ld    c,a
  ld    a,b           ; current state will be previous in next read
  ld    [previous],a

  ld    a,$30         ; reset rP1
  ldh   [rP1],a
  ret

WaitVBlank:
    ld a, [rLY]
    cp 144
    jr nz, WaitVBlank
    ret
ResetOAM:
    ld b, 160
    xor a
.loop:
    ld [hl], a
    inc hl
    dec b
    jr nz, .loop
    ret
CopyShadowOAMtoOAMTitle:
    ld hl, ShadowOAM
    ld de, STARTOF(OAM)
    ld c, 160
.loop
    ld a, [hli]
    ld [de], a
    inc e
    dec c
    jr nz, .loop
    ret

CopyShadowOAMtoOAM:
    ld hl, ShadowOAM
    ld de, STARTOF(OAM)
    ld b, 8
.loop:
    ld a,[hl+]
    ld [de],a
    inc e
    ld a,[hl+]
    ld [de],a
    inc e
    ld a,[hl+]
    ld [de],a
    inc e
    ld a,[hl+]
    ld [de],a
    inc e
    dec b
    jr nz, .loop
    ret

; =========================================================
; DATA TABLES
; =========================================================

SECTION "Data", ROM0
MapRowTable:
    dw Map
    dw Map+10
    dw Map+20
    dw Map+30
    dw Map+40
    dw Map+50
    dw Map+60
    dw Map+70
    dw Map+80
    dw Map+90
    dw Map+100
    dw Map+110
    dw Map+120
    dw Map+130
    dw Map+140
    dw Map+150
    dw Map+160
    dw Map+170
PieceAddressTable:
    dw Tetromino_I, Tetromino_J, Tetromino_L, Tetromino_O, Tetromino_S, Tetromino_Z, Tetromino_T

Tetromino_I: DB 1,0,0,0,-1,0,-2,0, 0,-1,0,0,0,1,0,2, 2,0,1,0,0,0,-1,0, 0,2,0,1,0,0,0,-1
Tetromino_J: DB -1,-1,-1,0,0,0,1,0, -1,1,0,1,0,0,0,-1, 1,1,1,0,0,0,-1,0, 1,-1,0,-1,0,0,0,1
Tetromino_L: DB 1,0,0,0,-1,0,-1,1, 0,-1,0,0,0,1,1,1, -1,0,0,0,1,0,1,-1, 0,1,0,0,0,-1,-1,-1
Tetromino_O: DB 0,0,1,0,0,1,1,1, 0,0,1,0,0,1,1,1, 0,0,1,0,0,1,1,1, 0,0,1,0,0,1,1,1
Tetromino_S: DB 0,-1,0,0,1,0,1,1, -1,0,0,0,0,-1,1,-1, 0,1,0,0,-1,0,-1,-1, 1,0,0,0,0,1,-1,1
Tetromino_Z: DB 1,-1,1,0,0,0,0,1, -1,-1,0,-1,0,0,1,0, -1,1,-1,0,0,0,0,-1, 1,1,0,1,0,0,-1,0
Tetromino_T: DB 0,-1,0,0,0,1,-1,0, -1,0,0,0,1,0,0,1, 0,1,0,0,0,-1,1,0, 1,0,0,0,-1,0,0,-1

SECTION "Font", ROM0
FontTiles:
  
    DB $00,$00,$00,$00,$00,$00,$00,$00 ; 0
    DB $00,$7C,$66,$66,$7C,$60,$60,$00 ; 1 P
    DB $00,$7C,$66,$66,$7C,$6C,$66,$00 ; 2 R
    DB $00,$7E,$60,$7C,$60,$60,$7E,$00 ; 3 E
    DB $00,$3C,$60,$3C,$0E,$4E,$3C,$00 ; 4 S
    DB $00,$3C,$66,$66,$7E,$66,$66,$00 ; 5 A
    DB $00,$7E,$18,$18,$18,$18,$18,$00 ; 6 T
    DB $00,$3C,$66,$66,$66,$66,$3C,$00 ; 7 O
    DB $00,$3C,$18,$18,$18,$18,$3C,$00 ; 8 I
    DB $00,$3C,$66,$60,$60,$66,$3C,$00 ; 9 C
    DB $00,$60,$60,$60,$60,$60,$7E,$00 ; 10 L
    DB $00,$66,$76,$7E,$5E,$4E,$46,$00 ; 11 N
    DB $00,$66,$3C,$18,$3C,$66,$66,$00 ; 12 X
    DB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; 13 WALL
    ; Digits
    DB $3C,$66,$6E,$76,$66,$66,$3C,$00 ;0
    DB $18,$38,$18,$18,$18,$18,$3C,$00 ;1
    DB $3C,$66,$06,$0C,$30,$60,$7E,$00 ;2
    DB $3C,$66,$06,$1C,$06,$66,$3C,$00 ;3
    DB $0C,$1C,$3C,$6C,$7E,$0C,$0C,$00 ;4
    DB $7E,$60,$7C,$06,$06,$66,$3C,$00 ;5
    DB $3C,$66,$60,$7C,$66,$66,$3C,$00 ;6
    DB $7E,$06,$0C,$18,$30,$30,$30,$00 ;7
    DB $3C,$66,$66,$3C,$66,$66,$3C,$00 ;8
    DB $3C,$66,$66,$3E,$06,$66,$3C,$00 ;9
    ; Box 
    DB %11111111
    DB %11000011
    DB %10000001
    DB %10000001
    DB %10000001
    DB %10000001
    DB %11000011
    DB %11111111

    ; Fog
    DB %10101010
    DB %01010101
    DB %10101010
    DB %01010101
    DB %10101010
    DB %01010101
    DB %10101010
    DB %01010101

    ; Ghost
    DB $7E,$C3,$A5,$99,$99,$A5,$C3,$7E

    DB $3C,$66,$60,$6E,$66,$66,$3C,$00 ; 26 G
    DB $C6,$EE,$FE,$D6,$C6,$C6,$C6,$00 ; 27 M
    DB $00,$66,$66,$66,$66,$3C,$18,$00 ; 28 V
    DB $66,$66,$66,$66,$66,$3C,$18,$00 ; 29 BIG V
    DB $00,$7C,$66,$7C,$66,$66,$7C,$00 ; 30 B
    DB $00,$66,$66,$3C,$18,$18,$18,$00 ; 31 Y

    AnimationFrames:
    ; frame 0
    DB %11111111, %11000011, %10000001, %10000001
    DB %10000001, %10000001, %11000011, %11111111
    
    ; frame 1: all white
    DB  %11111111,%11111111,%11111111,%11111111
    DB  %11111111,%11111111,%11111111,%11111111
    ; frame 2
    DB %11111111, %10000001, %10000001, %10000001
    DB %10000001, %10000001, %10000001, %11111111
    ; frame 3
    DB %00000000, %01111110, %01111110, %01111110
    DB %01111110, %01111110, %01111110, %00000000
    ; frame 4
    DB %00000000, %00000000, %00111100, %00111100
    DB %00111100, %00111100, %00000000, %00000000
    ; frame 5
    DB %00000000, %00000000, %00000000, %00011000
    DB %00011000, %00000000, %00000000, %00000000
    
    DB 0,0,0,0,0,0,0,0
FontTilesEnd:

SECTION "TitleMap", ROM0
TitleTilemap:
    ds TITLE_ROWS_TOP_EMPTY * TITLE_TOTAL_COLS, TILE_SPACE
    ds TITLE_TETRIS_COL, TILE_SPACE
    DB TILE_T,TILE_E,TILE_T,TILE_R,TILE_I,TILE_S
    ;tetris
    ds TITLE_TOTAL_COLS - (TITLE_TETRIS_COL + TITLE_TETRIS_LEN), TILE_SPACE
    ds TITLE_PRESS_ROW_GAP * TITLE_TOTAL_COLS, TILE_SPACE
    ds TITLE_PRESS_COL, TILE_SPACE
    DB TILE_P,TILE_R,TILE_E,TILE_S,TILE_S,TILE_SPACE,TILE_SPACE,TILE_S,TILE_T,TILE_A,TILE_R,TILE_T
    ;press B to start
    ds TITLE_TOTAL_COLS - (TITLE_PRESS_COL + TITLE_PRESS_LEN + 1 + TITLE_ATO_LEN + TITLE_START_LEN), TILE_SPACE
    ds (TITLE_TOTAL_ROWS * TITLE_TOTAL_COLS) - (@ - TitleTilemap), TILE_SPACE

TitleTilemapEnd:

GameOverTilemap:
    ds TITLE_ROWS_TOP_EMPTY * TITLE_TOTAL_COLS, TILE_SPACE  ; For top empty rows
    
    ; offset to center "GAME OVER"
    ; Center offset = (20 - 9) / 2 = 5
    db TILE_SPACE, TILE_SPACE, TILE_SPACE, TILE_SPACE, TILE_SPACE  ; Fill first 5 spaces
    DB TILE_G, TILE_A, TILE_M, TILE_E, TILE_SPACE, TILE_O, TILE_BIG_V, TILE_E, TILE_R  ; Display "GAME OVER"
    
    ; Fill remaining spaces
    ds TITLE_TOTAL_COLS - (5 + 10), TILE_SPACE  ; Calculate remaining spaces and fill

    ds TITLE_PRESS_ROW_GAP * TITLE_TOTAL_COLS, TILE_SPACE  ; Empty
    
    ; calculate space for "Press B"
    ;ds 1, TILE_SPACE
    DB TILE_SPACE,TILE_P, TILE_R, TILE_E, TILE_S, TILE_S, TILE_SPACE,TILE_S,TILE_T,TILE_A,TILE_R,TILE_T,TILE_SPACE,TILE_T,TILE_O,TILE_SPACE,TILE_R,TILE_E,TILE_T,TILE_R,TILE_Y
    ; press B to restart
    ds TITLE_TOTAL_COLS - (TITLE_PRESS_COL + 11), TILE_SPACE  ; Fill remaining spaces

    ds (TITLE_TOTAL_ROWS * TITLE_TOTAL_COLS) - (@ - GameOverTilemap), TILE_SPACE  ; Fill remaining area
GameOverTilemapEnd:

SECTION "GameMap", ROM0
GameTilemap:
MACRO FOG_ROW_UI
    ds GAME_LEFT_PAD, TILE_FOG
    DB TILE_WALL
    ds GAME_WIDTH, TILE_SPACE
    DB TILE_WALL
    ds UI_END_COL - GAME_TOTAL_WIDTH, TILE_FOG
    ds BG_WIDTH - UI_END_COL, TILE_SPACE
ENDM
REPT 1
    FOG_ROW_UI
ENDR
    ds GAME_LEFT_PAD, TILE_FOG
    DB TILE_WALL
    ds GAME_WIDTH, TILE_SPACE
    DB TILE_WALL
    DB TILE_FOG
    DB TILE_S,TILE_C,TILE_O,TILE_R,TILE_E        ;score
    ds UI_END_COL - (GAME_TOTAL_WIDTH + 1 + SCORE_LEN), TILE_FOG
    ds BG_WIDTH - UI_END_COL, TILE_SPACE
    ds GAME_LEFT_PAD, TILE_FOG
    DB TILE_WALL
    ds GAME_WIDTH, TILE_SPACE
    DB TILE_WALL
    DB TILE_FOG
    DB TILE_DIGIT_0,TILE_DIGIT_0,TILE_DIGIT_0,TILE_DIGIT_0,TILE_DIGIT_0
    ds UI_END_COL - (GAME_TOTAL_WIDTH + 1 + 5), TILE_FOG
    ds BG_WIDTH - UI_END_COL, TILE_SPACE
REPT 1
    FOG_ROW_UI
ENDR
    ds GAME_LEFT_PAD, TILE_FOG
    DB TILE_WALL
    ds GAME_WIDTH, TILE_SPACE
    DB TILE_WALL
    DB TILE_FOG
    DB TILE_L,TILE_I,TILE_N,TILE_E      ;line
    ds UI_END_COL - (GAME_TOTAL_WIDTH + 1 + LINE_LEN), TILE_FOG
    ds BG_WIDTH - UI_END_COL, TILE_SPACE
    ds GAME_LEFT_PAD, TILE_FOG
    DB TILE_WALL
    ds GAME_WIDTH, TILE_SPACE
    DB TILE_WALL
    DB TILE_FOG
    DB TILE_DIGIT_0,TILE_DIGIT_0,TILE_DIGIT_0,TILE_DIGIT_0
    ds UI_END_COL - (GAME_TOTAL_WIDTH + 1 + 4), TILE_FOG
    ds BG_WIDTH - UI_END_COL, TILE_SPACE
REPT 1
    FOG_ROW_UI
ENDR
    ds GAME_LEFT_PAD, TILE_FOG
    DB TILE_WALL
    ds GAME_WIDTH, TILE_SPACE
    DB TILE_WALL
    DB TILE_FOG
    DB TILE_L,TILE_E,TILE_V,TILE_E,TILE_L; level
    ds UI_END_COL - (GAME_TOTAL_WIDTH + 1 + LEVEL_LEN), TILE_FOG
    ds BG_WIDTH - UI_END_COL, TILE_SPACE
    ds GAME_LEFT_PAD, TILE_FOG
    DB TILE_WALL
    ds GAME_WIDTH, TILE_SPACE
    DB TILE_WALL
    DB TILE_FOG
    DB TILE_DIGIT_0,TILE_DIGIT_0,TILE_DIGIT_0,TILE_DIGIT_0,TILE_DIGIT_0
    ds UI_END_COL - (GAME_TOTAL_WIDTH + 1 + 5), TILE_FOG
    ds BG_WIDTH - UI_END_COL, TILE_SPACE
REPT 1
    FOG_ROW_UI
ENDR
    ds GAME_LEFT_PAD, TILE_FOG
    DB TILE_WALL
    ds GAME_WIDTH, TILE_SPACE
    DB TILE_WALL
    DB TILE_FOG
    DB TILE_N,TILE_E,TILE_X,TILE_T      ;next
    ds UI_END_COL - (GAME_TOTAL_WIDTH + 1 + NEXT_LEN), TILE_FOG
    ds BG_WIDTH - UI_END_COL, TILE_SPACE
REPT 4
    ds GAME_LEFT_PAD, TILE_FOG
    DB TILE_WALL
    ds GAME_WIDTH, TILE_SPACE
    DB TILE_WALL
    ds NEXT_BOX_COL_OFFSET, TILE_FOG
    ds NEXT_BOX_SIZE, TILE_SPACE
    ds UI_END_COL - (GAME_TOTAL_WIDTH + NEXT_BOX_COL_OFFSET + NEXT_BOX_SIZE), TILE_FOG
    ds BG_WIDTH - UI_END_COL, TILE_SPACE
ENDR
REPT 3
    FOG_ROW_UI
ENDR
REPT (32 - GAME_VISIBLE_ROWS)
    ds BG_WIDTH, TILE_SPACE
ENDR
GameTilemapEnd:
