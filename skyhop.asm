.model small
.386
.stack 100h


;       ▄████████    ▄█   ▄█▄ ▄██   ▄      ▄█    █▄     ▄██████▄     ▄███████▄ 
;      ███    ███   ███ ▄███▀ ███   ██▄   ███    ███   ███    ███   ███    ███ 
;      ███    █▀    ███▐██▀   ███▄▄▄███   ███    ███   ███    ███   ███    ███ 
;      ███         ▄█████▀    ▀▀▀▀▀▀███  ▄███▄▄▄▄███▄▄ ███    ███   ███    ███ 
;    ▀███████████ ▀▀█████▄    ▄██   ███ ▀▀███▀▀▀▀███▀  ███    ███ ▀█████████▀  
;             ███   ███▐██▄   ███   ███   ███    ███   ███    ███   ███        
;       ▄█    ███   ███ ▀███▄ ███   ███   ███    ███   ███    ███   ███        
;     ▄████████▀    ███   ▀█▀  ▀█████▀    ███    █▀     ▀██████▀   ▄████▀      
;                   ▀                                                          

;                            by: Liron



.data
	x dw 640
	y dw 512
	color db 0bh

.code
clear proc
	push ax
	push bx
	push cx
	push dx

	mov bh, 0h
	mov cx, 0
	mov dx, 0
	mov al, 0bh

	loop1:
	mov ah, 0ch
	int 10h
	inc cx
	cmp cx, 1280
	jl loop1
	sub cx, 1280
	inc dx
	cmp dx, 1024
	jl loop1

	pop dx
	pop cx
	pop bx
	pop ax
	ret
clear endp

player proc
	push ax
	push bx
	push cx
	push dx
	push si

	mov bh, 0
	mov cx, [x]
	mov dx, [y]
	mov al, 4
	mov ah,0ch
	int 10h
	sub cx, 11
	sub dx, 10

	create_player:
		mov bx, 0
		inc cx
		int 10h
		mov si, [x]
		add si, 10
		cmp cx, si
		jle create_player
		inc dx
		sub cx, 21 ;5x
		mov si, [y]
		add si, 10
		cmp dx, si ;512+5x-2
		jle create_player

	 pop si
	 pop dx
	 pop cx
	 pop bx
	 pop ax
	 ret
player endp

delay proc
	push cx
	mov cx, 1
	d1:
	push cx
	mov cx, 0FFFFh
	d2:
	loop d2
	pop cx
	loop d1
	pop cx
	ret
delay endp

main:
	mov ax, @data
	mov ds, ax
	mov ax,0A000h
	mov es, ax

	;GRAPHIC MODE (1280x1024x256)
	mov ax, 4F02h
	mov bx, 107h
	int 10h

	;ADVANCED DISPLAY
	mov bx, 0
	mov ax, 1003h
	int 10h

mov bx, 0
fall:
	call delay
	call clear
	call player
	add [y], 20
	cmp [y], 994 ; 1024-addition(20)-10(half of player height)
	jl fall

jump:
	call delay
	call clear
	call player
	sub [y], 20
	cmp [y], 492 ; 512-substraction(10)
	jg jump
	jmp fall

; Wait for key press
mov ah,00h
int 16h

.exit
end main
