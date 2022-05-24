model small
stack 100h
.386

.data
  ;___________bmp info___________
  handle      dw       ?
  header      db       54 dup ('h')
  palette     db       256*4 dup ('p')
  screenLine  db       1280 dup('t')
  bmpH        dw       ?
  bmpW        dw       ?

  ;___________other___________
  x           dw       0
  y           dw       1023
  px          dw       ?
  py          dw       ?
  buff        db       200*100 dup ('b')
  cbuff       db       180*92 dup ('c')
  step        dw       35
  rand        dw       ?
  prand       dw       ?
  safe        dw       0
  sky         dw       1023
  r           dw       0
  msg         db       'SCORE:   $'
  score       dw       0,'$'


  ;___________bmp filenames___________
  player      db       'player.bmp',0
  background  db       'bg.bmp',0
  start       db       'start.bmp',0
  inst        db       'inst.bmp',0
  cloud       db       'cloud.bmp',0
  quit        db       'quit.bmp',0

.code
____________________________________bmp_procs__________________________________:

  openFile proc
    ; Opens a file.
    ; I/O: filename offset (dx)/NONE
    mov ax, 3d00h
    int 21h
    mov handle, ax
    ret
  endp

  readHeader proc
    ; Reads the header of the file.
    ; I/O: NONE

    mov ah, 3fh
    mov bx, handle ; handle
    mov cx, 54 ; number of bytes to read
    lea dx, header ; header offset
    int 21h
    ret
  endp

  info proc
    ; pulls important BMP info from the header
    ; I/O: NONE
    mov al, header[12h] ; width
    mov ah, header[13h]
    mov bmpW, ax
    mov al, header[16h] ; height
    mov ah, header[17h]
    mov bmpH, ax
    ret
  endp

  readPal proc
    ; Reads the palette of the file.
    ; I/O: NONE

    mov ah, 3fh
    mov cx, 1024 ; colors*bytes 256*4
    lea dx, palette ; palette offset
    int 21h
    ret
  endp

  sendPal proc
    ; Copies the file's palette to the video memory.
    ; I/O: NONE

    lea si, palette                    ; palette offset
    mov cx, 256                        ; number of colors to send
    mov dx, 3c8h                       ; port
    mov al, 0                          ; 0
    out dx, al                         ; Copy starting color to port 3C8h
    inc dx                             ; Copy palette itself to port 3C9h
    sendLoop:                              ; Note: Colors in a BMP file are saved as BGR values rather than RGB.
    re:  mov al, [si+2]
        shr al, 2                          ; Max is 255, video only allows up to 63, therefore div by 4
        out dx, al
    g:  mov al, [si+1]
        shr al, 2
        out dx, al
    b:  mov al, [si]
        shr al, 2
        out dx, al
        add si, 4                          ; Point to next color. There is a null char after every color
        loop sendLoop
    ret
  endp

  closeFile proc
    ; Closes a file.
    ; I/O: NONE
    mov bx, handle
    mov ah, 3eh
    int 21h
    ret
  endp

  loadBMP proc
    ; Copies the file's palette to the video memory.
    ; I/O: NONE

    mov cx, bmpH; height
    mov dx, y ; bottom-left y coordinate

    sload:
    cmp bmpH, 329
    jne bload
    lea di, buff
    jmp row

    bload:
    cmp bmpH, 1024
    jne pload
    dec cx
    jmp row

    pload:
    cmp bmpH, 200
    jne cload
    lea di, buff
    jmp row

    cload:
    cmp bmpH, 92
    jne row
    lea di, cbuff

    row:
      push cx dx
      mov ah, 3fh
      mov cx, bmpW ; width
      lea dx, screenLine ; saving location
      int 21h ; Copy one line into memory
      pop dx
      lea si, screenLine

      pixel:
        push cx
        add cx, x
        mov al, [si] ; color

        cmp bmpW, 100
        je buffcpy
        cmp bmpW, 180
        jne check

        buffcpy:
        push ax
        mov ah, 0dh
        int 10h
        mov [di], al
        pop ax

        check:
        cmp al, 0fdh ; pink pixel
        je blank
        print:
        mov ah, 0ch
        int 10h
        blank:
        inc di
        inc si
        pop cx
      loop pixel

      pop cx
      dec dx ; go up a line
    loop row
    ret
  endp

  saveBuffer proc
    ; Copies the file's palette to the video memory.
    ; I/O: NONE
    pusha

    mov cx, 200 ; height
    mov dx, y ; bottom-left y coordinate
    lea di, buff

    bRow: ; for 200 times
      push cx
      mov cx, 100 ; width

      bPixel: ; for 100 times
        push cx
        add cx, x
        mov ah, 0dh
        int 10h
        mov [di], al ; save to buffer

        bSkip:
        inc di ; buffer ptr
        pop cx
        loop bPixel

      pop cx
      dec dx ; go up a line
      loop bRow

    popa
    ret
  endp

  showBMP proc
    ; Copies the file's palette to the video memory.
    ; I/O: NONE
    pusha
    call openFile
    call readHeader
    call info
    call readPal
    call sendPal
    call loadBMP
    call closeFile
    popa
    ret
  endp

  hideBMP proc
    pusha
    ; Erases the bmp
    ; I/O: NONE
    call openFile
    call readHeader
    call info
    call readPal
    call sendPal
    call closeFile

    mov cx, bmpH ; height
    mov dx, y ; bottom-left y coordinate
    cmp bmpH, 200
    jne .cload
    lea di, buff
    jmp .row

    .cload:
    cmp bmpH, 92
    jne row
    lea di, cbuff

    .row:
      push cx
      mov cx, bmpW ; width

      .pixel:
        push cx
        add cx, x
        mov al, [di] ; color
        mov ah, 0ch
        int 10h
        inc di
        pop cx
      loop .pixel

      pop cx
      dec dx ; go up a line
    loop .row

    popa
    ret
  endp
____________________________________other_procs________________________________:

  delay proc
    ; create delay with loops
      push cx
      mov cx, 50
      d1:
      push cx
      mov cx, 0FFFFh
      d2:
      loop d2
      pop cx
      loop d1
      pop cx
      ret
  endp

  screen proc
    ; Configures segments and makes the display 1280x1024.
    ; I/O: NONE
    push ax bx
    push @data
    pop ds
    push 0a000h
    pop es
    mov ax, 4f02h
    mov bx, 107h
    int 10h
    pop bx ax
    ret
  endp

  random proc
    ; Generates a random number between 180-1100 using the xoroshift16+ algorithm.
    ; I/O: NONE/rand
    push bp
    mov bp, sp
    push ax bx cx dx

    time:
      push 40h ; system time
      pop es
      mov ax, es:6Ch

    algo:
      xor ah, al ; xoroshift 16+ algorithm
      mov cl, al
      rol cl, 6
      xor cl, ah
      mov ch, cl
      shl ch, 1
      xor cl, ch
      mov al, cl
      mov ch, ah
      rol ch, 3
      mov ah, ch ; random number goes to ax

    range:
      mov dx, 0
      mov cx, 550
      div cx
      shl dx, 1
      mov ax, dx
      cmp dx, 180
      jg endrand
      mov dx, 180  ; random number is between 180-1100

    endrand:
      mov bx, [bp+4]
      mov [bx], dx
      pop dx cx bx ax bp
      ret 2
  endp

  quitScreen proc
    ; Displays a screen with an option to restart and an option to quit the game.
    ; I: sky, safe, score, step, r
    push bp
    mov bp, sp

    push ax dx si di
    mov di, [bp+16] ; off x
    mov [di], 246
    mov si, [bp+14] ; off y
    mov [si], 698
    lea dx, quit
    call showBMP

    pusha
    mov bx, [bp+8]
    mov ax, [bx]
    mov bl, 10
    div bl
    mov di, [bp+18]
    mov [di+7], al
    add [di+7], '0'
    mov [di+8], ah
    add [di+8], '0'

    mov dx, [bp+18]
    mov ah, 9
    int 21h
    popa


    quitkey:
      mov ah, 0
      int 16h

    finalquit:
      cmp al, 'q'
      jne restart
      pop dx ax
      mov ax, 2
      int 10h
      mov ah, 4ch
      int 21h

    restart:
      cmp al, 'r'
      jne quitkey
      push bx
      mov [di], 0
      mov [si], 1023
      mov bx, [bp+10]
      mov [bx], 35
      mov bx, [bp+8]
      mov [bx], 0
      mov bx, [bp+4]
      mov [bx], 1023
      mov bx, [bp+6]
      mov [bx], 0
      mov bx, [bp+12]
      mov [bx], 1

    pop bx di si dx ax bp
    ret 16
  endp

  gameStart proc
    push bp
    mov bp, sp
    pusha
    call screen
    startScreen:
      lea dx, start
      call showBMP
      key:
      mov ah, 0
      int 16h
      cmp al, 'i'
      je instructions
      cmp al, 13 ; enter key
      je gameBackground
      cmp al, 'q'
      jne key
      push [bp+18] ; msg
      push [bp+16] ; x off
      push [bp+14] ; y off
      push [bp+12] ; r
      push [bp+10] ; step
      push [bp+8] ; score
      push [bp+6] ; safe
      push [bp+4] ; sky
      call quitScreen
      mov bx, [bp+12]
      cmp [bx], 1
      jne key
      jmp ssend

    instructions:
      lea dx, inst
      call showBMP
      .key:
      mov ah, 0
      int 16h
      cmp al, 'b'
      je startScreen
      cmp al, 'q'
      jne .key
      push [bp+18] ; msg
      push [bp+16] ; x off
      push [bp+14] ; y off
      push [bp+12] ; r
      push [bp+10] ; step
      push [bp+8] ; score
      push [bp+6] ; safe
      push [bp+4] ; sky
      call quitScreen
      mov bx, [bp+12]
      cmp [bx], 1
      jne .key
      jmp ssend

    gameBackground:
      mov di, [bp+16] ; x off
      mov si, [bp+14] ; y off
      mov [di], 0
      mov [si], 1023
      lea dx, background
      call showBMP

      push [bp+18] ; rand
      push [bp+14]
      push [bp+16] ; y x
      call newCloud

    ssend:
      popa
      pop bp
      ret 18
  endp

  newCloud proc
    push bp
    mov bp, sp

    push dx bx

    mov di, [bp+4]
    mov si, [bp+6]
    mov bx, [bp+8] ; rand
    push [di]
    push [si]

    push bx
    call random
    mov bx, [bp+8]

    mov dx, [bx]

    mov [di], dx
    mov [si], 400
    lea dx, cloud
    call showBMP

    pop [si]
    pop [di]
    pop bx dx bp
    ret 6
  endp
____________________________________movement_procs_____________________________:

  movement proc
    ; Check if 'a', 'q', or 'd' keys have been pressed and update coordinates accordingly.
    ; I/O: ; x 4, y 6, px 8, py 10 r 12 step 14 score 16 safe 18 sky 20
    push bp
    mov bp, sp

    mov di, [bp+4]
    mov si, [bp+6]
    push [di] ; x
    push [si] ; y
    push ax
    mov ah, 0
    int 16h

    a:
      cmp al, 'a'
      jne d
      cmp [di], 100
      jl leftBorder ; too left
      sub [di], 100
      jmp moveEnd

      leftBorder:
      cmp [di], 0 ; on border
      jne moveToLeft
      mov [di], 1280-100-1 ; switch side
      jmp moveEnd

      moveToLeft:
      mov [di], 0
      jmp moveEnd

    d:
      cmp al, 'd'
      jne q
      cmp [di], 1280-100-2
      jg rightBorder ; too right
      add [di], 100
      jmp moveEnd

      rightBorder:
      cmp [di], 1280-100-1 ; on border
      jne moveToRight
      mov [di], 0 ; switch side
      jmp moveEnd

      moveToRight:
      mov [di], 1280-100-1
      jmp moveEnd

    q:
      cmp al, 'q'
      jne moveEnd
      pop ax

      push [bp+22] ; msg
      push [bp+4] ; x off
      push [bp+6] ; y off
      push [bp+12] ; r
      push [bp+15] ; step
      push [bp+16] ; score
      push [bp+18] ; safe
      push [bp+20] ; sky
      call quitScreen
      push bx
      mov bx, [bp+12]
      cmp [bx], 1
      je preSkip
      pop bx
      jmp moveEnd

      preSkip:
        pop bx
        jmp skipmoveEnd

    moveEnd:
      push bx
      mov bx, [bp+8]
      mov ax, [di]
      mov [bx], ax
      mov bx, [bp+10]
      mov ax, [si]
      mov [bx], ax

      pop bx ax ax bx
      push ax bx
      mov [si], ax
      mov [di], bx

    skipmoveEnd:
      pop bx ax bp
      ret 20
  endp

  fallCheck proc
    push bp
    mov bp, sp
    push ax dx bx di si

    mov di, [bp+16] ; x off
    mov si, [bp+14] ; y off

    mov bx, [bp+20]
    cmp [bx], 1
    jl fcEnd
    cmp y, 765
    jl fcEnd
    mov bx, [bp+18]
    mov ax, [bx]
    add ax, 180
    cmp [di], ax
    jg fell
    mov ax, [di]
    add ax, 100
    cmp ax, [bx]
    jge fcEnd

    fell:
      fellLoop:
      add [si], 40
      lea dx, player
      call showBMP
      call hideBMP
      cmp [si], 1600
      jl fellLoop
      push [bp+22] ; msg
      push [bp+16] ; x off
      push [bp+14] ; y off
      push [bp+12] ; r
      push [bp+10] ; step
      push [bp+8] ; score
      push [bp+6] ; safe
      push [bp+4] ; sky
      call quitScreen

    fcEnd:
    pop si di bx dx ax bp
    ret 20
  endp

  cloudTouch proc
    push bp
    mov bp, sp
    push dx ax di si

    mov di, [bp+4] ; x
    mov si, [bp+6] ; y

    push [di]
    push [si]

    cmp [si], 380
    jl noTouch
    cmp [si], 400
    jg noTouch

    mov bx, [bp+12]
    mov ax, [di]
    add ax, 100
    cmp ax, [bx]
    jl noTouch
    mov ax, [bx]
    add ax, 180
    cmp [di], ax
    jg noTouch

    mov bx, [bp+8]
    cmp [bx], 1
    jg notfr

    firstRound:
      mov bx, [bp+8]
      cmp [bx], 1
      je secondRound
      mov [si], 1400
      jmp srskip

    secondRound:
      mov [si], 1650

    srskip:
      mov [di], 0
      lea dx, background
      call showBMP
      jmp cloudNext

    notfr:
      mov [si], 892
      mov bx, [bp+10]
      push [bx]
      pop [di]
      lea dx, cloud
      call hideBMP

    cloudNext:
      mov [si], 400
      mov bx, [bp+12]
      push [bx]
      pop [di]
      lea dx, cloud
      call hideBMP
      add [si], 40

    cloudDown:
      lea dx, cloud
      call showBMP
      call hideBMP
      add [si], 40
      cmp [si], 892
      jge cloudEnd
      jmp cloudDown

    cloudEnd:
      mov [si], 892
      call showBMP
      mov bx, [bp+12]
      push [bx]
      mov bx, [bp+10]
      pop [bx]

      push [bp+12] ; rand
      push [bp+6]
      push [bp+4] ; y x
      call newCloud
      mov bx, [bp+8]
      inc [bx]

    noTouch:
      pop [si]
      pop [di]
      pop si di ax dx bp
      ret 10
  endp
____________________________________main_______________________________________:
  main:
    mov r, 0

    push offset msg ; msg
    push offset rand
    push offset x ; x off
    push offset y ; y off
    push offset r ; r
    push offset step ; step
    push offset score ; score
    push offset safe ; safe
    push offset sky ; sky
    call gameStart

    cmp r, 1
    je main

    mov x, 550
    mov y, 800
    upLoop:
      lea dx, player
      call showBMP
      mov ah, 1
      int 16h
      jz noMove

      move:
        push offset msg
        push offset sky
        push offset safe
        push offset score
        push offset step
        push offset r
        push offset py
        push offset px
        push offset y
        push offset x
        call movement
        cmp r, 1
        je .restart
        call hideBMP
        push py px
        pop x y
        cmp r, 1
        je .restart
        jmp newStep

      noMove:
        call hideBMP

      newStep:
        mov ax, step
        sub y, ax
        dec step
        cmp step, 0
        jne upLoop

    downLoop:
      push offset msg
      push offset score
      push offset prand
      push offset x ; x off
      push offset y ; y off
      push offset r ; r
      push offset step ; step
      push offset score ; score
      push offset safe ; safe
      push offset sky ; sky
      call fallCheck
      cmp r, 1
      je .restart
      lea dx, player
      call showBMP
      mov ah, 1
      int 16h
      jz .noMove

      .move:
        push offset msg
        push offset sky
        push offset safe
        push offset score
        push offset step
        push offset r
        push offset py
        push offset px
        push offset y
        push offset x
        call movement
        cmp r, 1
        je .restart
        call hideBMP
        push py px
        pop x y
        jmp .newStep

      .noMove:
        call hideBMP

      .newStep:
        push offset rand
        push offset prand
        push offset score
        push offset y
        push offset x
        call cloudTouch
        mov ax, step
        add y, ax
        inc step
        cmp y, 800
        jl downLoop
        mov y, 800
        mov step, 35
        jmp upLoop

      .restart:
    jmp main

    .exit
  end main
