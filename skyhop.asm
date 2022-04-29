model small
stack 100h
.386

.data
  ;_________bmp info_________
  handle dw ?
  header db 54 dup ('h')
  palette db 256*4 dup ('p')
  screenLine db 1280 dup(?)
  bmpH dw ?
  bmpW dw ?
  y dw 1023
  x dw 0

  ;_________bmp filenames_________
  player db 'player.bmp', 0
  bg db 'bg.bmp', 0
  start db 'start.bmp', 0
  inst db 'inst.bmp', 0

.code
____________________________________bmp_procs__________________________________:
  openFile proc
    ; Opens a file.
    ; I/O: filename / NONE

    mov ax, 3d00h
    nop ; dx gets inputted
    int 21h
    mov handle, ax
    ret
  openFile endp

  readHeader proc
    ; Reads the header of the file.
    ; I/O: NONE

    mov ah, 3fh
    mov bx, handle ; handle
    mov cx, 54 ; number of bytes to read
    lea dx, header ; header offset
    int 21h
    ret
  readHeader endp

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
  info endp

  readPal proc
    ; Reads the palette of the file.
    ; I/O: NONE

    mov ah, 3fh
    mov cx, 1024 ; colors*bytes 256*4
    lea dx, palette ; palette offset
    int 21h
    ret
  readPal endp

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
  sendPal endp

  loadBMP proc
    ; Copies the file's palette to the video memory.
    ; I/O: NONE

    mov cx, bmpH ; height
    mov dx, y ; bottom-left y coordinate

    row:
    push cx dx

    mov ah, 3fh
    mov cx, bmpW ; width
    lea dx, screenLine ; offset
    int 21h ; Copy one line into memory

    lea si, screenLine
    pop dx

    pixel:
    push cx
    mov al, [si] ; color
    add cx, x

      check:
      cmp al, 0fdh ; pink pixel
      je blank
      print:
      mov ah, 0ch
      int 10h
      blank:
      inc si
      pop cx
    loop pixel

    pop cx
    dec dx ; go up a line
    loop row

    ret
  loadBMP endp

  showBMP proc
    ; Copies the file's palette to the video memory.
    ; I/O: NONE
    call openFile
    call readHeader
    call info
    call readPal
    call sendPal
    call loadBMP
    ret
  showBMP endp

____________________________________other_procs________________________________:
  clear proc
    ; Clears screen.
    ; INPUT: None.
    ; OUTPUT: None.
    pusha

    xor cx, cx
    xor dx, dx
    mov al, 6

    sky_loop:
      mov ah, 0ch
      int 10h
      inc cx
      cmp cx, 1280
      jl sky_loop
      sub cx, 1280
      inc dx
      cmp dx, 1000
      jl sky_loop
      mov al, 5
      cmp dx, 1024
      jl sky_loop

    popa
    ret
  clear endp

  delay proc
    ; Creates delay.
    ; INPUT: None.
    ; OUTPUT: None.
    push cx

    mov cx, 10
    d1: push cx
    mov cx, 0FFFFh
    d2: loop d2
    pop cx
    loop d1

    pop cx
    ret
  delay endp

  screen proc
    ; Configures display.
    ; I/O: NONE
    pusha
    mov ax, @data
    mov ds, ax
    mov ax, 0A000h
    mov es, ax
    mov ax, 4F02h
    mov bx, 107h
    int 10h

    popa
    ret
  screen endp

  movement proc
    ; Checks if 'a' or 'd' keys have been pressed.
    ; INPUT:
    ; OUTPUT: None.
    pusha

    mov ah, 0
    int 16h
    jz move_end
    mov ah, 1
    int 16h

    a:
    cmp al, 'a'
    jne d
    cmp x, 50
    jl lb
    sub x, 50
    jmp move_end
    lb: mov x, 1280-100

    d:
    cmp al, 'd'
    jne q
    cmp x, 1280-100
    jge rb
    add x, 50
    jmp move_end
    rb: mov x, 0

    q:
    cmp al, 'q'
    jne move_end
    mov ah, 4ch
    int 21h

    move_end:
      popa
      ret
  movement endp

  ; touch_cloud proc
  ;   pusha
  ;
  ;   mov bx, [steve_y]
  ;   add bx, 200
  ;   cmp [cloud_y], bx
  ;   je same_level
  ;
  ;   same_level:
  ;       mov bx, [cloud_x]
  ;       add bx, 180
  ;       cmp [steve_x], bx
  ;       jg not_touching
  ;       mov [temp], 0
  ;       jmp touch_end
  ;
  ;   not_touching:
  ;       mov [temp], 1
  ;
  ;   touch_end:
  ;     popa
  ;     ret
  ; touch_cloud endp

____________________________________main_______________________________________:
  main:
    call screen
    startscreen:
      lea dx, start
      call showBMP
      keywait_1:
      mov ah, 0
      int 16h
      jz keywait_1
      mov ah, 1
      int 16h
      cmp al, 'i'
      je instructions
      cmp al, 13 ; enter key
      je game
      cmp al, 'q'
      je exit
      jmp keywait_1

    instructions:
      lea dx, inst
      call showBMP
      keywait_2:
      mov ah, 0
      int 16h
      jz keywait_2
      mov ah, 1
      int 16h
      cmp al, 'b'
      je startscreen
      cmp al, 'q'
      je exit
      jmp keywait_2

    game:
      lea dx, bg
      mov y, 1023
      mov x, 0
      call showBMP

      lea dx, player
      mov y, 400
      mov x, 590
      call showBMP


      m:
      call movement
      lea dx, player
      call showBMP
      jmp m

      mov ah, 1
      int 21h

  exit:
    mov ax, 2
    int 10h
    mov ah, 4ch
    int 21h
  end main
