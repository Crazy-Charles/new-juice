CC = sdcc
CFLAGS = -mz80 --opt-code-size --std-sdcc11
ASM = sdasz80
ASMFLAGS =

.PHONY: all beta clean

%.asm : %.c
	$(CC) $(CFLAGS) -S $<

smram.com: crt0.rel smram.rel 
	$(CC) $(CFLAGS) --data-loc 0 --code-loc 0x200 --no-std-crt0 $^ -osmram.ihx
	hex2bin -e com smram.ihx
	cp smram.com disk/SMRAM.COM

SMRAMB.COM: crt0.rel smramb.rel
	$(CC) $(CFLAGS) --data-loc 0 --code-loc 0x200 --no-std-crt0 $^ -oSMRAMB.ihx
	hex2bin -e COM SMRAMB.ihx
	cp SMRAMB.COM disk/SMRAMB.COM

all: smram.com SMRAMB.COM

beta: SMRAMB.COM

smram.rel: smram.c types.h

smramb.rel: smram.c types.h
	$(CC) $(CFLAGS) -DBETA_ROM -o$@ -c $<

%.rel : %.c
	$(CC) $(CFLAGS) -o$@ -c $<

%.rel : %.s
	$(ASM) $(ASMFLAGS) -o $@ $<

clean:
	+rm -f *.rel *.asm *.lst *.sym *.map *.ihx smram.com SMRAMB.COM *.lk *.noi disk/SMRAM.COM disk/SMRAMB.COM
	
