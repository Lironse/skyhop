model small
.386
locals @@
stack 100h

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
  step        dw       35
  rand        dw       ?
  prand       dw       ?
  score       dw       0
  scoremsg    db       'SCORE: $'
  safe        db       0
  sky         dw       1023

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
    r:  mov al, [si+2]
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

  loadBMP proc
    ; Copies the file's palette to the video memory.
    ; I/O: NONE

    mov cx, bmpH ; height
    mov dx, y ; bottom-left y coordinate
    lea di, buff


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
        jne check
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

  closeFile proc
    ; Closes a file.
    ; I/O: NONE
    mov bx, handle
    mov ah, 3eh
    int 21h
    ret
  endp

  showBMP proc
    ; Copies the file's palette to the video memory.
    ; I/O: NONE
    call openFile
    call readHeader
    call info
    call readPal
    call sendPal
    call loadBMP
    call closeFile
    ret
  endp

  hideBMP proc
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
    lea di, buff

    row2:
      push cx
      mov cx, bmpW ; width

      pixel2:
        push cx
        mov al, [di] ; color
        add cx, x
        print2:
        mov ah, 0ch
        int 10h
        inc di
        pop cx
      loop pixel2

      pop cx
      dec dx ; go up a line
    loop row2

    ret
  endp

____________________________________other_procs________________________________:

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

  movement proc
    ; Check if 'a', 'q', or 'd' keys have been pressed and update coordinates accordingly.
    ; I/O: NONE +4 x +6 y
    push bp
    mov bp, sp
    push ax
    mov ah, 0
    int 16h

    a:
    cmp al, 'a'
    jne d
    cmp x, 100
    jl leftBorder ; too left
    sub x, 100
    jmp moveEnd

    leftBorder:
    cmp x, 0 ; on border
    jne moveToLeft
    mov x, 1280-100-1 ; switch side
    jmp moveEnd

    moveToLeft:
    mov x, 0
    jmp moveEnd

    d:
    cmp al, 'd'
    jne q
    cmp x, 1280-100-2
    jg rightBorder ; too right
    add x, 100
    jmp moveEnd

    rightBorder:
    cmp x, 1280-100-1 ; on border
    jne moveToRight
    mov x, 0 ; switch side
    jmp moveEnd

    moveToRight:
    mov x, 1280-100-1
    jmp moveEnd

    q:
    cmp al, 'q'
    jne moveEnd
    pop ax
    call quitScreen

    moveEnd:
    pop ax
    pop bp
    ret
  endp

  random proc
    ; Generates a random number between 180-1100 using the xoroshift16+ algorithm.
    ; I/O: NONE/rand
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
    mov rand, dx
    pop dx cx bx ax
    ret
  endp

  quitScreen proc
    ; Displays a screen with an option to restart and an option to quit the game.
    ; I/O: NONE
    push ax dx
    mov x, 246
    mov y, 698
    lea dx, quit
    call showBMP

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

    mov x, 0
    mov y, 1023
    mov step, 35
    mov score, 0
    mov sky, 1023
    mov safe, 0
    pop dx ax
    jmp startscreen
    ret
  endp

  showScore proc
    pusha

    lea di, [scoremsg + 14]
    mov ax, score

    mov bx, 10
    more:
     mov dx, 0
     div bx         ; This divides DX:AX by BX
     dec di
     add dl, '0'    ; Turn remainder into a character
     mov [di], dl   ; Write in string
     test ax, ax
     jnz more

     lea dx, scoremsg
     mov ah, 9
     int 21h

    popa
    ret
  endp

  gameStart proc
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
      je game
      cmp al, 'q'
      call quitScreen
      jmp key

    instructions:
      lea dx, inst
      call showBMP
      .key:
      mov ah, 0
      int 16h
      cmp al, 'b'
      je startScreen
      cmp al, 'q'
      call quitScreen
      jmp .key

    gameBackground:
      mov y, 1023
      mov x, 0
      lea dx, background
      call showBMP
      popa
      ret
  endp

  newCloud proc
    pusha
    push x y
    call random
    mov dx, rand
    mov y, 400
    mov x, dx
    lea dx, cloud
    call showBMP
    pop y x
    popa
    ret
  endp

  ; clear proc
  ;   ; Clears screen.
  ;   ; I/O: None.
  ;   pusha
  ;
  ;   mov cx, 1279
  ;   mov dx, 1023
  ;   mov al, 0fch
  ;
  ;   sky_loop:
  ;     mov ah, 0ch
  ;     int 10h
  ;     loop sky_loop
  ;     dec dx
  ;     cmp dx, 420
  ;     jg sky_loop
  ;
  ;   popa
  ;   ret
  ; endp

____________________________________main_______________________________________:
  main:
    call gameStart

    game:
      mov y, 1023
      mov x, 0
      lea dx, background
      call showBMP

      mov y, 800 ; beginning player
      mov x, 590

      randomCloud:
        call newcloud

      jump:
        cmp step, 0
        je fall
        cmp step, -36
        jne pass

      fall:
        neg step
        cmp step, 36
        jne pass
        dec step

      pass:
        mov dx, step
        sub y, dx
        dec step
        lea dx, player
        call showBMP

        mov ah, 1
        int 16h
        jnz move
        lea dx, player
        call hideBMP
        jmp cloudCheck

      move:
        push x y
        call movement
        pop py px
        push x y
        mov ax, px
        mov x, ax
        mov ax, py
        mov y, ax
        lea dx, player
        call hideBMP
        pop y x

      cloudCheck:
        push x y

        cmp step, 0
        jg notTouching ; falling

        cmp y, 400-92
        jg notTouching
        cmp y, 365-92
        jl notTouching ; in range of cloud

        mov dx, x
        add dx, 99
        cmp dx, rand
        jl notTouching ; to the left
        mov dx, rand
        add dx, 191
        cmp dx, x
        jl notTouching ; to the right

        pop y x
        jmp isTouching

      notTouching:
        pop y x

        cmp y, 800 ; 891
        jl notFalling; in range of cloud

        mov dx, x
        add dx, 99
        cmp dx, prand
        jng falldeath ; to the left

        mov dx, prand
        add dx, 191
        cmp dx, x
        jl falldeath ; to the right

        jmp notFalling

      falldeath:
        call quitScreen

      notFalling:
        jmp jump

      isTouching:
        inc score
        push x y
        mov y, 400
        mov dx, rand
        mov x, dx
        lea dx, cloud
        call hideBMP

        inc safe
        cmp safe, 3
        jg hbg

        add sky, 200
        mov dx, sky
        mov y, dx
        mov x, 0
        lea dx, background
        call showbmp

      hbg:
        mov y, 891
        mov dx, prand
        mov x, dx
        lea dx, cloud
        call hideBMP

        mov dx, rand
        mov x, dx
        lea dx, cloud
        call showBMP

        mov dx, x
        mov prand, dx

        pop y x
        jmp randomCloud

  end main
