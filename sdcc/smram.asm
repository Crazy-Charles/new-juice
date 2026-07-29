;--------------------------------------------------------
; File Created by SDCC : free open source ISO C Compiler
; Version 4.6.0 #16555 (Mac OS X ppc)
;--------------------------------------------------------
	.module smram
	
	.optsdcc -mz80 sdcccall(1)
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl _main
	.globl _runROM_Reset_end
	.globl _runROM_Reset
	.globl _runROM_page2_end
	.globl _runROM_page2
	.globl _runROM_page1_end
	.globl _runROM_page1
	.globl _jump
	.globl _hexToNum
	.globl _dos2_getenv
	.globl _dos2_read
	.globl _dos2_close
	.globl _dos2_open
	.globl _chgcpu
	.globl _rdslt
	.globl _enaslt
	.globl _to_upper
	.globl _fputs
	.globl _bdos_c_rawio
	.globl _bdos_c_write
	.globl _bdos
	.globl _printf
	.globl _opll_vol
	.globl _psg_vol
	.globl _scc_vol
	.globl _help
	.globl _page2
	.globl _cpumode
	.globl _softReset
	.globl _presAB
	.globl _paramlen
	.globl _megaram_type
	.globl _filename
	.globl _found
	.globl _c
	.globl _romstart
	.globl _path
	.globl _slotid
	.globl _romsize
	.globl _page
	.globl _addr
	.globl _i
	.globl _bytes_read
	.globl _handle
	.globl _params
	.globl _t
	.globl _s
	.globl _b
	.globl _sslt
	.globl _cursslt
	.globl _curslt
	.globl _putchar
	.globl _getchar
;--------------------------------------------------------
; special function registers
;--------------------------------------------------------
_MEGA_PORT0	=	0x008e
_MEGA_PORT1	=	0x008f
_PPIA	=	0x00a8
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _DATA
_curslt::
	.ds 1
_cursslt::
	.ds 1
_sslt::
	.ds 1
_b::
	.ds 1
_s::
	.ds 2
_t::
	.ds 2
_params::
	.ds 2
_handle::
	.ds 1
_bytes_read::
	.ds 2
_i::
	.ds 2
_addr::
	.ds 2
_page::
	.ds 1
_romsize::
	.ds 4
_slotid::
	.ds 1
_path::
	.ds 256
_romstart::
	.ds 2
_c::
	.ds 1
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _INITIALIZED
_found::
	.ds 1
_filename::
	.ds 2
_megaram_type::
	.ds 2
_paramlen::
	.ds 1
_presAB::
	.ds 1
_softReset::
	.ds 1
_cpumode::
	.ds 1
_page2::
	.ds 1
_help::
	.ds 1
_scc_vol::
	.ds 1
_psg_vol::
	.ds 1
_opll_vol::
	.ds 1
;--------------------------------------------------------
; absolute ram data
;--------------------------------------------------------
	.area _DABS (ABS)
	.area _DABS (ABS)
;--------------------------------------------------------
; global & static initialisations
;--------------------------------------------------------
	.area _HOME
	.area _GSINIT
	.area _GSFINAL
	.area _GSINIT
;--------------------------------------------------------
; Home
;--------------------------------------------------------
	.area _HOME
	.area _HOME
;--------------------------------------------------------
; code
;--------------------------------------------------------
	.area _CODE
;smram.c:41: void bdos() __naked
;	---------------------------------
; Function bdos
; ---------------------------------
_bdos::
;smram.c:50: __endasm;
	push ix
	push iy
	call 5
	pop iy
	pop ix
	ret
;smram.c:51: }
;smram.c:53: void bdos_c_write(uchar c) __naked
;	---------------------------------
; Function bdos_c_write
; ---------------------------------
_bdos_c_write::
;smram.c:63: __endasm;
	ld e,a
	ld c,#2
	call _bdos
	ret
;smram.c:64: }
;smram.c:66: uchar bdos_c_rawio() __naked
;	---------------------------------
; Function bdos_c_rawio
; ---------------------------------
_bdos_c_rawio::
;smram.c:75: __endasm;
	ld e,#0xFF;
	ld c,#6
	call _bdos
	ret
;smram.c:76: }
;smram.c:78: int putchar(int c) 
;	---------------------------------
; Function putchar
; ---------------------------------
_putchar::
	ex	de, hl
;smram.c:80: if (c >= 0)
	bit	7, d
	ret	nz
;smram.c:81: bdos_c_write((char)c);
	ld	a, e
	push	de
	call	_bdos_c_write
	pop	de
;smram.c:82: return c;
;smram.c:83: }
	ret
;smram.c:85: int getchar()
;	---------------------------------
; Function getchar
; ---------------------------------
_getchar::
;smram.c:88: do {
00101$:
;smram.c:89: c = bdos_c_rawio();
	call	_bdos_c_rawio
	ld	e, a
;smram.c:90: } while(c == 0);
	or	a, a
	jr	z, 00101$
;smram.c:91: return (int)c;
	ld	d, #0x00
;smram.c:92: }
	ret
;smram.c:94: void fputs(const char *s)
;	---------------------------------
; Function fputs
; ---------------------------------
_fputs::
;smram.c:96: while(*s != NULL)
00101$:
	ld	a, (hl)
	or	a, a
	ret	z
;smram.c:97: putchar(*s++);
	inc	hl
	ld	c, #0x00
	push	hl
	ld	l, a
	ld	h, c
	call	_putchar
	pop	hl
;smram.c:98: }
	jr	00101$
;smram.c:100: char to_upper(char c)
;	---------------------------------
; Function to_upper
; ---------------------------------
_to_upper::
;smram.c:102: if (c >= 'a' && c <= 'z')
	cp	a, #0x61
	ret	c
	cp	a, #0x7b
	ret	nc
;smram.c:103: c = c - ('a'-'A');
	add	a, #0xe0
;smram.c:104: return c;
;smram.c:105: }
	ret
;smram.c:107: void enaslt(uchar slotid, uint addr) __naked
;	---------------------------------
; Function enaslt
; ---------------------------------
_enaslt::
;smram.c:129: __endasm;
	push af
	push bc
	push de
	push hl
	push ix
	push iy
	ex de,hl
	call #0x0024
	pop iy
	pop ix
	pop hl
	pop de
	pop bc
	pop af
	ret
;smram.c:130: }
;smram.c:132: uchar rdslt(uchar slotid, uint addr) __naked
;	---------------------------------
; Function rdslt
; ---------------------------------
_rdslt::
;smram.c:147: __endasm;
	push bc
	push de
	ex de,hl
	call #0x000C
	ex de,hl
	pop de
	pop bc
	ret
;smram.c:148: }
;smram.c:150: void chgcpu(uchar mode) __naked
;	---------------------------------
; Function chgcpu
; ---------------------------------
_chgcpu::
;smram.c:180: __endasm;
	push bc
	push de
	push af
	ld a,(0xFCC1)
	ld hl,#0x0180
	call #0x000C
	cp #0xC3
	jr nz,__no_turbo
	ld a,b
	pop af
	ld iy,(0xFCC1 -1)
	ld ix,#0x0180
	call #0x001C
	push af
__no_turbo:
	pop af
	pop de
	pop bc
	ret
;smram.c:181: }
;smram.c:198: FHANDLE dos2_open(uchar mode, const char* filepath) __naked
;	---------------------------------
; Function dos2_open
; ---------------------------------
_dos2_open::
;smram.c:216: __endasm;
	push bc
	push de
	push hl
	ld c,#0x43
	call 5
	or a
	jr z,__open_no_err
	ld b,#0
__open_no_err:
	ld a,b
	pop hl
	pop de
	pop bc
	ret
;smram.c:217: }
;smram.c:219: void dos2_close(FHANDLE hnd) __naked
;	---------------------------------
; Function dos2_close
; ---------------------------------
_dos2_close::
;smram.c:229: __endasm;
	push bc
	ld a,b
	ld c,#0x45
	call 5
	pop bc
	ret
;smram.c:230: }
;smram.c:232: uint dos2_read(FHANDLE hnd, void *dst, uint size) __naked
;	---------------------------------
; Function dos2_read
; ---------------------------------
_dos2_read::
;smram.c:252: __endasm;	
	push ix
	ld ix,#0
	add ix,sp
	push bc
	ld b,a
	ld l, 4 (ix)
	ld h, 5 (ix)
	ld c,#0x48
	call 5
	pop bc
	pop ix
	ex de,hl
	ret
;smram.c:253: }
;smram.c:255: uchar dos2_getenv(char *var, char *buf) __naked
;	---------------------------------
; Function dos2_getenv
; ---------------------------------
_dos2_getenv::
;smram.c:263: __endasm;	
	ld b,#255
	ld c,#0x6B
	call 5
	ret
;smram.c:264: }
;smram.c:266: char hexToNum(char h)
;	---------------------------------
; Function hexToNum
; ---------------------------------
_hexToNum::
;smram.c:270: if (h >= '0' && h <='9')
	cp	a, #0x30
	jr	c, 00102$
	cp	a, #0x3a
	jr	nc, 00102$
;smram.c:271: return h-'0';    
	add	a, #0xd0
	ret
00102$:
;smram.c:272: return 0;
	xor	a, a
;smram.c:273: }
	ret
;smram.c:275: void jump(uint addr) __naked
;	---------------------------------
; Function jump
; ---------------------------------
_jump::
;smram.c:283: __endasm;
	ld sp,(0x0006)
	jp (hl)
;smram.c:284: }
;smram.c:286: void runROM_page1() __naked
;	---------------------------------
; Function runROM_page1
; ---------------------------------
_runROM_page1::
;smram.c:302: __endasm;
	di
	ld sp,#0xCFFF
	ld hl,#0xFD9A
	ld a,#0xC9
	ld (hl),a
	ld hl,#0xFD9F
	ld (hl),a
	ld a,(0xFCC1)
	ld hl,#0
	call #0x0024
	ld hl,(0x4002)
	jp (hl)
;smram.c:303: }
;smram.c:304: void runROM_page1_end() __naked {}
;	---------------------------------
; Function runROM_page1_end
; ---------------------------------
_runROM_page1_end::
;smram.c:306: void runROM_page2() __naked
;	---------------------------------
; Function runROM_page2
; ---------------------------------
_runROM_page2::
;smram.c:322: __endasm;
	di
	ld sp,#0xCFFF
	ld hl,#0xFD9A
	ld a,#0xC9
	ld (hl),a
	ld hl,#0xFD9F
	ld (hl),a
	ld a,(0xFCC1)
	ld hl,#0
	call #0x0024
	ld hl,(0x8002)
	jp (hl)
;smram.c:323: }
;smram.c:324: void runROM_page2_end() __naked {}
;	---------------------------------
; Function runROM_page2_end
; ---------------------------------
_runROM_page2_end::
;smram.c:326: void runROM_Reset() __naked
;	---------------------------------
; Function runROM_Reset
; ---------------------------------
_runROM_Reset::
;smram.c:343: __endasm;
	di
	ld sp,#0xCFFF
	ld hl,#0xFD9A
	ld a,#0xC9
	ld (hl),a
	ld hl,#0xFD9F
	ld (hl),a
	ld a,(0xFCC1)
	ld hl,#0
	call #0x0024
	jp 0x0000
;smram.c:344: }
;smram.c:346: void runROM_Reset_end() __naked {}
;	---------------------------------
; Function runROM_Reset_end
; ---------------------------------
_runROM_Reset_end::
;smram.c:375: int main(void)
;	---------------------------------
; Function main
; ---------------------------------
_main::
;smram.c:377: curslt = (PPIA & 0x0C) >> 2;
	in	a, (_PPIA)
	and	a, #0x0c
	ld	l, #0x00
	sra	l
	rr	a
	sra	l
	rr	a
	ld	(_curslt), a
;smram.c:378: cursslt = (~(*((uchar*)0xFFFF)) & 0x0C) | *((uchar*)EXPTBL+curslt);
	ld	a, (#0xffff)
	cpl
	and	a, #0x0c
	ld	c, a
	ld	a, (_curslt)
	ld	l, a
	ld	h, #0x00
	ld	de, #0xfcc1
	add	hl, de
	ld	a, (hl)
	or	a, c
	ld	(#_cursslt), a
;smram.c:380: for(i = 1; i < 4; i++)
	ld	hl, #0x0001
	ld	(_i), hl
00234$:
;smram.c:382: slotid = *((uchar*)EXPTBL+i);
	ld	hl, (_i)
	ld	de, #0xfcc1
	add	hl, de
	ld	a, (hl)
	ld	(#_slotid), a
;smram.c:384: if (slotid & 0x80) {    // expanded ?
	ld	a, (_slotid)
	rlca
	jr	nc, 00235$
;smram.c:386: enaslt(i | 0x80, 0x4000); // looking for BIOS, sslot 0
	ld	a, (_i)
	set	7, a
	ld	de, #0x4000
	call	_enaslt
;smram.c:388: b = *(uchar*)(0x6000); // it might be RAM
	ld	a, (#0x6000)
	ld	(#_b), a
;smram.c:389: *((uchar*)0x6000) = 7;
	ld	hl, #0x6000
	ld	(hl), #0x07
;smram.c:390: s = "WonderTANG! uSD Driver";
	ld	hl, #___str_0
	ld	(_s), hl
;smram.c:391: t = (uchar*)0x4110;
	ld	hl, #0x4110
	ld	(_t), hl
;smram.c:392: for(int j=0; j<22; j++)
	ld	bc, #0x0000
00232$:
	ld	a, c
	sub	a, #0x16
	ld	a, b
	rla
	ccf
	rra
	sbc	a, #0x80
	jr	nc, 00105$
;smram.c:394: if (*s++ != *t++) break;
	ld	hl, (_s)
	ld	e, (hl)
	ld	hl, (_s)
	inc	hl
	ld	(_s), hl
	ld	hl, (_t)
	ld	d, (hl)
	ld	hl, (_t)
	inc	hl
	ld	(_t), hl
	ld	a, e
	sub	a, d
	jr	nz, 00105$
;smram.c:396: if (j == 21) 
	ld	a, c
	sub	a, #0x15
	or	a, b
	jr	nz, 00233$
;smram.c:398: found = TRUE;
	ld	hl, #_found
	ld	(hl), #0x01
;smram.c:399: break;
	jr	00105$
00233$:
;smram.c:392: for(int j=0; j<22; j++)
	inc	bc
	jr	00232$
00105$:
;smram.c:403: *((uchar*)0x6000) = b; // return whatever was there
	ld	hl, #0x6000
	ld	a, (_b)
	ld	(hl), a
;smram.c:405: enaslt(curslt | cursslt, 0x4000);
	ld	a, (_curslt)
	ld	hl, #_cursslt
	or	a, (hl)
	ld	de, #0x4000
	call	_enaslt
;smram.c:407: if (found) break;
	ld	a, (_found+0)
	or	a, a
	jr	nz, 00110$
00235$:
;smram.c:380: for(i = 1; i < 4; i++)
	ld	hl, (_i)
	inc	hl
	ld	(_i), hl
	ld	a, (_i+0)
	sub	a, #0x04
	ld	a, (_i+1)
	rla
	ccf
	rra
	sbc	a, #0x80
	jp	c, 00234$
00110$:
;smram.c:411: sslt = 0;
	xor	a, a
	ld	(#_sslt), a
;smram.c:413: if (found)
	ld	a, (_found+0)
	or	a, a
	jp	z, 00180$
;smram.c:415: printf("WonderTANG! Super MegaRAM SCC\n\r");
	ld	hl, #___str_1
	push	hl
	call	_printf
;smram.c:416: printf("v3.00 (new-juice)\n\r");
	ld	hl, #___str_2
	ex	(sp),hl
	call	_printf
	pop	af
;smram.c:418: sslt = 0x80 | (2 << 2) | i;
	ld	a, (_i)
	or	a, #0x88
	ld	(#_sslt), a
;smram.c:419: paramlen = *((char*)0x80);
	ld	a, (#0x0080)
	ld	(#_paramlen), a
;smram.c:420: for(params = (char*)0x81; *params != 0 || paramlen == 0; ++params, paramlen--)
	ld	hl, #0x0081
	ld	(_params), hl
00238$:
	ld	bc, (_params)
	ld	a, (bc)
	ld	e, a
	or	a, a
	jr	nz, 00237$
	ld	a, (_paramlen+0)
	or	a, a
	jp	nz, 00181$
00237$:
;smram.c:422: if (*params != ' ')
;smram.c:424: if (*params == '/')
	ld	a, e
	cp	a, #0x20
	jp	z, 00239$
	sub	a, #0x2f
	jp	nz, 00174$
;smram.c:426: params++;
	ld	hl, (_params)
	inc	hl
	ld	(_params), hl
;smram.c:420: for(params = (char*)0x81; *params != 0 || paramlen == 0; ++params, paramlen--)
	ld	hl, (_params)
	ld	c, (hl)
;smram.c:427: if (to_upper(*params) == 'R') 
	push	bc
	ld	a, c
	call	_to_upper
	pop	bc
;smram.c:426: params++;
	ld	hl, (_params)
	inc	hl
;smram.c:427: if (to_upper(*params) == 'R') 
	cp	a, #0x52
	jr	nz, 00167$
;smram.c:429: params++;
	ld	(_params), hl
;smram.c:420: for(params = (char*)0x81; *params != 0 || paramlen == 0; ++params, paramlen--)
	ld	hl, (_params)
	ld	a, (hl)
;smram.c:430: if (*params == '0')
	cp	a, #0x30
	jr	nz, 00124$
;smram.c:431: megaram_type = TYPE_MSCC;
	ld	hl, #0x0000
	ld	(_megaram_type), hl
	jp	00239$
00124$:
;smram.c:433: if (*params == '6')
	cp	a, #0x36
	jr	nz, 00121$
;smram.c:434: megaram_type = TYPE_K4;
	ld	hl, #0x0004
	ld	(_megaram_type), hl
	jp	00239$
00121$:
;smram.c:436: if (*params == '5')
	cp	a, #0x35
	jr	nz, 00118$
;smram.c:437: megaram_type = TYPE_K5;
	ld	hl, #0x0005
	ld	(_megaram_type), hl
	jp	00239$
00118$:
;smram.c:439: if (*params == '1')
	cp	a, #0x31
	jr	nz, 00115$
;smram.c:440: megaram_type = TYPE_A16;
	ld	hl, #0x0016
	ld	(_megaram_type), hl
	jp	00239$
00115$:
;smram.c:442: if (*params == '3')
	cp	a, #0x33
	jr	nz, 00112$
;smram.c:443: megaram_type = TYPE_A8;
	ld	hl, #0x0008
	ld	(_megaram_type), hl
	jp	00239$
00112$:
;smram.c:445: megaram_type = TYPE_UNK;                    
	ld	hl, #0x00ff
	ld	(_megaram_type), hl
	jp	00239$
00167$:
;smram.c:447: else if (to_upper(*params) == 'K')
	push	hl
	push	bc
	ld	a, c
	call	_to_upper
	pop	bc
	pop	hl
	cp	a, #0x4b
	jr	nz, 00164$
;smram.c:449: params++;
	ld	(_params), hl
;smram.c:420: for(params = (char*)0x81; *params != 0 || paramlen == 0; ++params, paramlen--)
	ld	hl, (_params)
	ld	a, (hl)
;smram.c:450: if (*params == '5')
	cp	a, #0x35
	jr	nz, 00130$
;smram.c:451: megaram_type = TYPE_K5;
	ld	hl, #0x0005
	ld	(_megaram_type), hl
	jp	00239$
00130$:
;smram.c:453: if (*params == '4')
	cp	a, #0x34
	jr	nz, 00127$
;smram.c:454: megaram_type = TYPE_K4;
	ld	hl, #0x0004
	ld	(_megaram_type), hl
	jp	00239$
00127$:
;smram.c:456: megaram_type = TYPE_UNK;
	ld	hl, #0x00ff
	ld	(_megaram_type), hl
	jp	00239$
00164$:
;smram.c:458: else if (to_upper(*params) == 'S')
	push	hl
	push	bc
	ld	a, c
	call	_to_upper
	pop	bc
	pop	hl
	cp	a, #0x53
	jr	nz, 00161$
;smram.c:460: softReset = TRUE;
	ld	hl, #_softReset
	ld	(hl), #0x01
;smram.c:461: presAB = TRUE;
	ld	hl, #_presAB
	ld	(hl), #0x01
	jp	00239$
00161$:
;smram.c:463: else if (to_upper(*params) == 'A')
	push	hl
	push	bc
	ld	a, c
	call	_to_upper
	pop	bc
	pop	hl
	cp	a, #0x41
	jr	nz, 00158$
;smram.c:465: params++;
	ld	(_params), hl
;smram.c:420: for(params = (char*)0x81; *params != 0 || paramlen == 0; ++params, paramlen--)
	ld	hl, (_params)
	ld	a, (hl)
;smram.c:466: if (*params == '8')
	cp	a, #0x38
	jr	nz, 00139$
;smram.c:467: megaram_type = TYPE_A8;
	ld	hl, #0x0008
	ld	(_megaram_type), hl
	jp	00239$
00139$:
;smram.c:469: if (*params == '1')
	cp	a, #0x31
	jr	nz, 00136$
;smram.c:471: params++;
	ld	hl, (_params)
	inc	hl
	ld	(_params), hl
;smram.c:472: if (*params == '6')
	ld	hl, (_params)
	ld	a, (hl)
	cp	a, #0x36
	jr	nz, 00133$
;smram.c:473: megaram_type = TYPE_A16;
	ld	hl, #0x0016
	ld	(_megaram_type), hl
	jp	00239$
00133$:
;smram.c:475: megaram_type = TYPE_UNK;
	ld	hl, #0x00ff
	ld	(_megaram_type), hl
	jp	00239$
00136$:
;smram.c:478: megaram_type = TYPE_UNK;
	ld	hl, #0x00ff
	ld	(_megaram_type), hl
	jr	00239$
00158$:
;smram.c:480: else if (to_upper(*params) == 'Y')
	push	hl
	push	bc
	ld	a, c
	call	_to_upper
	pop	bc
	pop	hl
	cp	a, #0x59
	jr	nz, 00155$
;smram.c:482: presAB = TRUE;
	ld	hl, #_presAB
	ld	(hl), #0x01
	jr	00239$
00155$:
;smram.c:512: else if (to_upper(*params) == 'Z')
	push	hl
	push	bc
	ld	a, c
	call	_to_upper
	pop	bc
	pop	hl
	cp	a, #0x5a
	jr	nz, 00152$
;smram.c:514: params++;
	ld	(_params), hl
;smram.c:420: for(params = (char*)0x81; *params != 0 || paramlen == 0; ++params, paramlen--)
	ld	hl, (_params)
	ld	a, (hl)
;smram.c:515: if (*params >= '0' && *params <= '3')
	cp	a, #0x30
	jr	c, 00239$
	cp	a, #0x34
	jr	nc, 00239$
;smram.c:516: cpumode = *params - '0';
	add	a, #0xd0
	ld	(#_cpumode), a
	jr	00239$
00152$:
;smram.c:518: else if (to_upper(*params) == '?')
	push	bc
	ld	a, c
	call	_to_upper
	pop	bc
	cp	a, #0x3f
	jr	nz, 00145$
;smram.c:520: help = TRUE;
	ld	hl, #_help
	ld	(hl), #0x01
	jr	00239$
;smram.c:525: while(*params++ != 0 && *params != ' ');
00145$:
	ld	hl, (_params)
	inc	hl
	ld	(_params), hl
	ld	a, c
	or	a, a
	jr	z, 00239$
;smram.c:420: for(params = (char*)0x81; *params != 0 || paramlen == 0; ++params, paramlen--)
	ld	hl, (_params)
	ld	c, (hl)
;smram.c:525: while(*params++ != 0 && *params != ' ');
	ld	a, c
	sub	a, #0x20
	jr	z, 00239$
	jr	00145$
00174$:
;smram.c:530: filename = params;
	ld	(_filename), bc
;smram.c:531: while(*params != 0 && *params != ' ') {
00170$:
;smram.c:420: for(params = (char*)0x81; *params != 0 || paramlen == 0; ++params, paramlen--)
	ld	hl, (_params)
	ld	a, (hl)
;smram.c:531: while(*params != 0 && *params != ' ') {
	or	a, a
	jr	z, 00181$
	cp	a, #0x20
	jr	z, 00181$
;smram.c:532: *params = to_upper(*params);
	push	hl
	call	_to_upper
	pop	hl
	ld	(hl), a
;smram.c:533: params++;
	ld	hl, (_params)
	inc	hl
	ld	(_params), hl
	jr	00170$
;smram.c:536: break;
00239$:
;smram.c:420: for(params = (char*)0x81; *params != 0 || paramlen == 0; ++params, paramlen--)
	ld	hl, (_params)
	inc	hl
	ld	(_params), hl
	ld	hl, #_paramlen
	dec	(hl)
	jp	00238$
00180$:
;smram.c:541: } else megaram_type = TYPE_UNK;
	ld	hl, #0x00ff
	ld	(_megaram_type), hl
00181$:
;smram.c:543: if (!found) 
	ld	a, (_found+0)
	or	a, a
	jr	nz, 00186$
;smram.c:545: printf("ERROR: WonderTANG! not found...\n\r");
	ld	hl, #___str_3
	push	hl
	call	_printf
	pop	af
;smram.c:546: return 0;
	ld	de, #0x0000
	ret
00186$:
;smram.c:549: if (help == TRUE || megaram_type == TYPE_UNK)
	ld	a, (_help)
	dec	a
	jr	z, 00182$
	ld	a, (_megaram_type)
	inc	a
	ld	hl, #_megaram_type + 1
	or	a, (hl)
	jr	nz, 00187$
00182$:
;smram.c:570: );
	ld	hl, #___str_4
	push	hl
	call	_printf
	pop	af
;smram.c:571: return 0;
	ld	de, #0x0000
	ret
00187$:
;smram.c:574: printf("\r\nMapper Type: ");
	ld	hl, #___str_5
	push	hl
	call	_printf
	pop	af
;smram.c:575: switch(megaram_type)
	ld	a, (_megaram_type+1)
	ld	iy, #_megaram_type
	or	a, 0 (iy)
	jr	z, 00188$
	ld	a, (_megaram_type+0)
	sub	a, #0x04
	or	a, 1 (iy)
	jr	z, 00189$
	ld	a, (_megaram_type+0)
	sub	a, #0x05
	or	a, 1 (iy)
	jr	z, 00190$
	ld	a, (_megaram_type+0)
	sub	a, #0x08
	or	a, 1 (iy)
	jr	z, 00192$
	ld	a, (_megaram_type+0)
	sub	a, #0x16
	or	a, 1 (iy)
	jr	z, 00191$
	jr	00193$
;smram.c:577: case TYPE_MSCC:
00188$:
;smram.c:578: printf("MegaRAM SCC (default)\n\r");
	ld	hl, #___str_6
	push	hl
	call	_printf
	pop	af
;smram.c:579: break;
	jr	00193$
;smram.c:580: case TYPE_K4:
00189$:
;smram.c:581: printf("Konami (/R6 or /K4)\n\r");
	ld	hl, #___str_7
	push	hl
	call	_printf
	pop	af
;smram.c:582: break;
	jr	00193$
;smram.c:583: case TYPE_K5:
00190$:
;smram.c:584: printf("Konami SCC (/R5 or /K5)\n\r");
	ld	hl, #___str_8
	push	hl
	call	_printf
	pop	af
;smram.c:585: break;
	jr	00193$
;smram.c:586: case TYPE_A16:
00191$:
;smram.c:587: printf("ASCII16 (/R1 or /A16)\n\r");
	ld	hl, #___str_9
	push	hl
	call	_printf
	pop	af
;smram.c:588: break;
	jr	00193$
;smram.c:589: case TYPE_A8:
00192$:
;smram.c:590: printf("ASCII8 (/R3 or /A8)\n\r");
	ld	bc, #___str_10+0
	push	bc
	call	_printf
	pop	af
;smram.c:592: }
00193$:
;smram.c:598: if (filename == 0) {        
	ld	a, (_filename+1)
	ld	hl, #_filename
	or	a, (hl)
	jr	nz, 00197$
;smram.c:599: if (megaram_type != TYPE_UNK)
	ld	a, (_megaram_type)
	inc	a
	ld	hl, #_megaram_type + 1
	or	a, (hl)
	jr	z, 00195$
;smram.c:600: MEGA_PORT1 = megaram_type;    
	ld	a, (_megaram_type+0)
	out	(_MEGA_PORT1), a
00195$:
;smram.c:601: return 0;
	ld	de, #0x0000
	ret
00197$:
;smram.c:604: for(t = filename; *t != ' ' && *t != 0; t++);
	ld	hl, (_filename)
	ld	(_t), hl
00242$:
;smram.c:394: if (*s++ != *t++) break;
	ld	hl, (_t)
;smram.c:604: for(t = filename; *t != ' ' && *t != 0; t++);
	ld	a, (hl)
	cp	a, #0x20
	jr	z, 00198$
	or	a, a
	jr	z, 00198$
	ld	hl, (_t)
	inc	hl
	ld	(_t), hl
	jr	00242$
00198$:
;smram.c:605: *t = 0;
	ld	(hl), #0x00
;smram.c:606: handle = dos2_open(0, filename);
	ld	de, (_filename)
	xor	a, a
	call	_dos2_open
	ld	(#_handle), a
;smram.c:608: MEGA_PORT1 = TYPE_K4;
	ld	a, #0x04
	out	(_MEGA_PORT1), a
;smram.c:610: if (handle)
	ld	a, (_handle+0)
	or	a, a
	jp	z, 00208$
;smram.c:612: printf("Loading ROM file: %s - ", filename);
	ld	hl, (_filename)
	push	hl
	ld	hl, #___str_11
	push	hl
	call	_printf
	pop	af
	pop	af
;smram.c:614: enaslt(sslt, 0x4000);
	ld	de, #0x4000
	ld	a, (_sslt)
	call	_enaslt
;smram.c:615: page = 0;
;smram.c:616: romsize = 0;
	xor	a, a
	ld	(#_page), a
	ld	(_romsize+0), a
	ld	(_romsize+1), a
	ld	(_romsize+2), a
	ld	(_romsize+3), a
;smram.c:617: printf("%04dKB", 0);
	ld	hl, #0x0000
	push	hl
	ld	hl, #___str_12
	push	hl
	call	_printf
	pop	af
	pop	af
;smram.c:619: do {
00204$:
;smram.c:621: MEGA_PORT0 = 0; // enable paging
	xor	a, a
	out	(_MEGA_PORT0), a
;smram.c:622: *((uchar *)0x4000) = page;
	ld	hl, #0x4000
	ld	a, (_page)
	ld	(hl), a
;smram.c:623: b = MEGA_PORT0; (b); // enable ram
	in	a, (_MEGA_PORT0)
	ld	(#_b), a
;smram.c:624: bytes_read = dos2_read(handle, (void*)0x8000, 0x2000);
	ld	hl, #0x2000
	push	hl
	ld	de, #0x8000
	ld	a, (_handle)
	call	_dos2_read
	ld	(_bytes_read), de
;smram.c:625: if (presAB == FALSE && romsize == 0) 
	ld	a, (_presAB+0)
	or	a, a
	jr	nz, 00200$
	ld	a, (_romsize+3)
	ld	iy, #_romsize
	or	a, 2 (iy)
	or	a, 1 (iy)
	or	a, 0 (iy)
	jr	nz, 00200$
;smram.c:626: *((uchar*)(0x8000)) = 0;
	ld	hl, #0x8000
	ld	(hl), #0x00
00200$:
;smram.c:627: romsize += bytes_read;
	ld	bc, (_bytes_read)
	ld	de, #0x0000
	ld	a, c
	ld	hl, #_romsize
	add	a, (hl)
	ld	(hl), a
	inc	hl
	ld	a, b
	adc	a, (hl)
	ld	(hl), a
	inc	hl
	ld	a, e
	adc	a, (hl)
	ld	(hl), a
	inc	hl
	ld	a, d
	adc	a, (hl)
	ld	(hl), a
;smram.c:628: memcpy((void*)0x4000, (void*)0x8000, bytes_read);
	ld	de, #0x4000
	ld	hl, #0x8000
	ld	bc, (_bytes_read)
	ld	a, b
	or	a, c
	jr	z, 00918$
	ldir
00918$:
;smram.c:629: if (page == 0)
	ld	a, (_page+0)
	or	a, a
	jr	nz, 00203$
;smram.c:630: romstart = *((uint*)0x8002);
	ld	hl, #0x8002
	ld	a, (hl)
	inc	hl
	ld	(_romstart+0), a
	ld	a, (hl)
	ld	(_romstart+1), a
00203$:
;smram.c:631: MEGA_PORT0 = 0; // enable paging
	xor	a, a
	out	(_MEGA_PORT0), a
;smram.c:632: printf("\b\b\b\b\b\b%04dKB", (uint)(romsize >> 10));
	ld	hl, (_romsize + 1)
	ld	a, (_romsize+3)
	ld	b, #0x02
00919$:
	srl	a
	rr	h
	rr	l
	djnz	00919$
	push	hl
	ld	hl, #___str_13
	push	hl
	call	_printf
	pop	af
	pop	af
;smram.c:633: page++;
	ld	hl, #_page
	inc	(hl)
;smram.c:635: } while (bytes_read > 0);
	ld	a, (_bytes_read+1)
	ld	hl, #_bytes_read
	or	a, (hl)
	jp	nz, 00204$
;smram.c:637: *((uchar *)0x4000) = 0;
	ld	hl, #0x4000
	ld	(hl), #0x00
;smram.c:639: dos2_close(handle);
	ld	a, (_handle)
	call	_dos2_close
	jr	00209$
00208$:
;smram.c:643: printf("ERROR: Failed loading %s\n\r", filename);
	ld	hl, (_filename)
	push	hl
	ld	hl, #___str_14
	push	hl
	call	_printf
	pop	af
	pop	af
;smram.c:644: return 0;
	ld	de, #0x0000
	ret
00209$:
;smram.c:646: *t = ' '; // restore space
	ld	hl, (_t)
	ld	(hl), #0x20
;smram.c:648: MEGA_PORT1 = megaram_type;
	ld	a, (_megaram_type+0)
	out	(_MEGA_PORT1), a
;smram.c:650: enaslt(sslt, 0x4000);
	ld	de, #0x4000
	ld	a, (_sslt)
	call	_enaslt
;smram.c:652: if (romstart > 0x7fff)
	ld	a, #0xff
	ld	iy, #_romstart
	cp	a, 0 (iy)
	ld	a, #0x7f
	sbc	a, 1 (iy)
	jr	nc, 00211$
;smram.c:654: enaslt(sslt, 0x8000);
	ld	de, #0x8000
	ld	a, (_sslt)
	call	_enaslt
;smram.c:655: page2 = TRUE;
	ld	hl, #_page2
	ld	(hl), #0x01
00211$:
;smram.c:657: printf("\n\r\n\rStart address: 0x%04x (page %d)\n\r", romstart, page2 == TRUE ? 2 : 1);
	ld	a, (_page2)
	dec	a
	jr	nz, 00246$
	ld	bc, #0x0002
	jr	00247$
00246$:
	ld	bc, #0x0001
00247$:
	push	bc
	ld	hl, (_romstart)
	push	hl
	ld	hl, #___str_15
	push	hl
	call	_printf
	pop	af
	pop	af
	pop	af
;smram.c:659: switch(megaram_type)
	ld	a, (_megaram_type)
	sub	a, #0x04
	ld	iy, #_megaram_type
	or	a, 1 (iy)
	jr	z, 00213$
	ld	a, (_megaram_type+0)
	sub	a, #0x05
	or	a, 1 (iy)
	jr	z, 00213$
	ld	a, (_megaram_type+0)
	sub	a, #0x08
	or	a, 1 (iy)
	jr	z, 00219$
	ld	a, (_megaram_type+0)
	sub	a, #0x16
	or	a, 1 (iy)
	jr	z, 00216$
	jr	00223$
;smram.c:662: case TYPE_K5:
00213$:
;smram.c:663: *((uchar *)0x4000) = 0;
	ld	hl, #0x4000
	ld	(hl), #0x00
;smram.c:664: *((uchar *)0x6000) = 1;
	ld	h, #0x60
	ld	(hl), #0x01
;smram.c:665: if (page2)
	ld	a, (_page2+0)
	or	a, a
	jr	z, 00223$
;smram.c:667: *((uchar *)0x8000) = 0;
	ld	h, #0x80
	ld	(hl), #0x00
;smram.c:668: *((uchar *)0xA000) = 1;
	ld	h, #0xa0
	ld	(hl), #0x01
;smram.c:670: break;
	jr	00223$
;smram.c:671: case TYPE_A16:
00216$:
;smram.c:672: *((uchar *)0x6000) = 0;
	ld	hl, #0x6000
	ld	(hl), #0x00
;smram.c:673: if (page2)
	ld	a, (_page2+0)
	or	a, a
	jr	z, 00223$
;smram.c:674: *((uchar *)0x8000) = 0;
	ld	h, #0x80
	ld	(hl), #0x00
;smram.c:675: break;
	jr	00223$
;smram.c:676: case TYPE_A8:
00219$:
;smram.c:677: *((uchar *)0x6000) = 0;
	ld	hl, #0x6000
	ld	(hl), #0x00
;smram.c:678: *((uchar *)0x6800) = 1;
	ld	h, #0x68
	ld	(hl), #0x01
;smram.c:679: if (page2)
	ld	a, (_page2+0)
	or	a, a
	jr	z, 00223$
;smram.c:681: *((uchar *)0x7000) = 0;
	ld	h, #0x70
	ld	(hl), #0x00
;smram.c:682: *((uchar *)0x7800) = 1;
	ld	h, #0x78
	ld	(hl), #0x01
;smram.c:687: }
00223$:
;smram.c:689: if (cpumode != 0)
	ld	a, (_cpumode+0)
	or	a, a
	jr	z, 00225$
;smram.c:690: chgcpu(cpumode == 1 ? Z80_ROM : cpumode == 2 ? R800_ROM : R800_DRAM);
	ld	a, (_cpumode)
	dec	a
	jr	z, 00249$
	ld	a, (_cpumode)
	sub	a, #0x02
	ld	a, #0x81
	jr	z, 00251$
	ld	a, #0x82
00251$:
00249$:
	call	_chgcpu
00225$:
;smram.c:692: if (softReset == FALSE)
	ld	a, (_softReset+0)
	or	a, a
	jr	nz, 00230$
;smram.c:694: if (page2 == TRUE)
	ld	a, (_page2)
	dec	a
	jr	nz, 00227$
;smram.c:695: memcpy((void*)0xC000, &runROM_page2, ((uint)&runROM_page2_end - (uint)&runROM_page2));
	ld	hl, #_runROM_page2
	ld	bc, #_runROM_page2_end
	ld	de, #_runROM_page2
	ld	a, c
	sub	a, e
	ld	c, a
	ld	a, b
	sbc	a, d
	ld	b, a
	ld	de, #0xc000
	ld	a, b
	or	a, c
	jr	z, 00228$
	ldir
	jr	00228$
00227$:
;smram.c:697: memcpy((void*)0xC000, &runROM_page1, ((uint)&runROM_page1_end - (uint)&runROM_page1));
	ld	hl, #_runROM_page1
	ld	bc, #_runROM_page1_end
	ld	de, #_runROM_page1
	ld	a, c
	sub	a, e
	ld	c, a
	ld	a, b
	sbc	a, d
	ld	b, a
	ld	de, #0xc000
	ld	a, b
	or	a, c
	jr	z, 00934$
	ldir
00934$:
00228$:
;smram.c:699: jump(0xC000);
	ld	hl, #0xc000
	call	_jump
00230$:
;smram.c:702: memcpy((void*)0xC000, &runROM_Reset, ((uint)&runROM_Reset_end - (uint)&runROM_Reset));
	ld	hl, #_runROM_Reset
	ld	bc, #_runROM_Reset_end
	ld	de, #_runROM_Reset
	ld	a, c
	sub	a, e
	ld	c, a
	ld	a, b
	sbc	a, d
	ld	b, a
	ld	de, #0xc000
	ld	a, b
	or	a, c
	jr	z, 00935$
	ldir
00935$:
;smram.c:703: jump(0xC000);
	ld	hl, #0xc000
	call	_jump
;smram.c:705: return 1; // make sdcc happy
	ld	de, #0x0001
;smram.c:706: }
	ret
___str_0:
	.ascii "WonderTANG! uSD Driver"
	.db 0x00
___str_1:
	.ascii "WonderTANG! Super MegaRAM SCC"
	.db 0x0a
	.db 0x0d
	.db 0x00
___str_2:
	.ascii "v3.00 (new-juice)"
	.db 0x0a
	.db 0x0d
	.db 0x00
___str_3:
	.ascii "ERROR: WonderTANG! not found..."
	.db 0x0a
	.db 0x0d
	.db 0x00
___str_4:
	.db 0x0a
	.db 0x0d
	.ascii "USAGE: SMRAM [/Rx /Zx /Y] [romfile]"
	.db 0x0a
	.db 0x0d
	.db 0x0a
	.db 0x0d
	.ascii " /Rx: Set MegaROM type"
	.db 0x0a
	.db 0x0d
	.ascii "   0: Megaram SCC (default)"
	.db 0x0a
	.db 0x0d
	.ascii "   1: ASCII16     (/A16)"
	.db 0x0a
	.db 0x0d
	.ascii "   3: ASCII8      (/A8)"
	.db 0x0a
	.db 0x0d
	.ascii "   5: Konami SCC  (/K5)"
	.db 0x0a
	.db 0x0d
	.ascii "   6: Konami      (/K4)"
	.db 0x0a
	.db 0x0d
	.db 0x0a
	.db 0x0d
	.ascii " /S: Soft reset"
	.db 0x0a
	.db 0x0d
	.ascii " /Zx: Set cpu mode"
	.db 0x0a
	.db 0x0d
	.ascii "   0: current"
	.db 0x0a
	.db 0x0d
	.ascii "   1: Z80"
	.db 0x0a
	.db 0x0d
	.ascii "   2: R800 ROM"
	.db 0x0a
	.db 0x0d
	.ascii "   3: R800 DRAM"
	.db 0x0a
	.db 0x0d
	.db 0x0a
	.db 0x0d
	.ascii " /Y:  Preserve AB header"
	.db 0x0a
	.db 0x0d
	.db 0x0a
	.db 0x0d
	.db 0x00
___str_5:
	.db 0x0d
	.db 0x0a
	.ascii "Mapper Type: "
	.db 0x00
___str_6:
	.ascii "MegaRAM SCC (default)"
	.db 0x0a
	.db 0x0d
	.db 0x00
___str_7:
	.ascii "Konami (/R6 or /K4)"
	.db 0x0a
	.db 0x0d
	.db 0x00
___str_8:
	.ascii "Konami SCC (/R5 or /K5)"
	.db 0x0a
	.db 0x0d
	.db 0x00
___str_9:
	.ascii "ASCII16 (/R1 or /A16)"
	.db 0x0a
	.db 0x0d
	.db 0x00
___str_10:
	.ascii "ASCII8 (/R3 or /A8)"
	.db 0x0a
	.db 0x0d
	.db 0x00
___str_11:
	.ascii "Loading ROM file: %s - "
	.db 0x00
___str_12:
	.ascii "%04dKB"
	.db 0x00
___str_13:
	.db 0x08
	.db 0x08
	.db 0x08
	.db 0x08
	.db 0x08
	.db 0x08
	.ascii "%04dKB"
	.db 0x00
___str_14:
	.ascii "ERROR: Failed loading %s"
	.db 0x0a
	.db 0x0d
	.db 0x00
___str_15:
	.db 0x0a
	.db 0x0d
	.db 0x0a
	.db 0x0d
	.ascii "Start address: 0x%04x (page %d)"
	.db 0x0a
	.db 0x0d
	.db 0x00
	.area _CODE
	.area _INITIALIZER
__xinit__found:
	.db #0x00	; 0
__xinit__filename:
	.dw #0x0000
__xinit__megaram_type:
	.dw #0x0000
__xinit__paramlen:
	.db #0x00	; 0
__xinit__presAB:
	.db #0x00	; 0
__xinit__softReset:
	.db #0x00	; 0
__xinit__cpumode:
	.db #0x01	; 1
__xinit__page2:
	.db #0x00	; 0
__xinit__help:
	.db #0x00	; 0
__xinit__scc_vol:
	.db #0x09	; 9
__xinit__psg_vol:
	.db #0x09	; 9
__xinit__opll_vol:
	.db #0x09	; 9
	.area _CABS (ABS)
