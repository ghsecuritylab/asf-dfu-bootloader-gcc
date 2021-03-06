
OLD_SHELL := $(SHELL)
SHELL = $(warning [$@ ($^) ($?)])$(OLD_SHELL)

MCU = atxmega384c3
AVRDUDE_OPTS = -c avrispmkii -P usb -p x384c3
CLOCK = 32000000
TARGET = dfu_bootloader
SRCDIR = common/services/usb/class/dfu_flip/device/bootloader
COMMONDIR = common
XMEGADIR = xmega
SRC = 
ASRC = 
OPT = s
BUILDDIR = _build
PLACE_IN_BOOTLOADER_MEM = yes
BOOTLOADER_MEM_START_ADDR = 60000  # Must match chosen MCU, in bytes (not words like the Atmel docs use)

#FUSE1: 0b11111111: 0xff  Watchdog initial settings: 0xf, 0xf
#FUSE2: 0b10111111: 0xff  BOD disabled, TOSC1/2 shared with XTAL, Bootloader enabled
#FUSE4: 0b11111111: 0xff  Reset pin enabled, no startup delay, no watchdog lock
#FUSE5: 0b11111111: 0xff  No BOD, Erase EEPROM during chip erase
#LOCK:  0b11111111: 0xff  No lock restrictions


ifeq ($(PLACE_IN_BOOTLOADER_MEM), yes)
#For running from bootloader mem
FUSES = -U fuse1:w:0xff:m -U fuse2:w:0xbf:m -U fuse4:w:0xff:m -U fuse5:w:0xff:m
else
#For running from application mem
FUSES = -U fuse1:w:0xff:m -U fuse2:w:0xff:m -U fuse4:w:0xff:m -U fuse5:w:0xff:m
endif

AS = avr-as
CC = avr-gcc
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump
SIZE = avr-size --mcu=$(MCU)
AVRDUDE = avrdude

# Name of this Makefile (used for "make depend").
MAKEFILE = Makefile

# Debugging format.
# Native formats for AVR-GCC's -g are stabs [default], or dwarf-2.
# AVR (extended) COFF requires stabs, plus an avr-objcopy run.
DEBUG = stabs

# Compiler flag to set the C Standard level.
# c89   - "ANSI" C
# gnu89 - c89 plus GCC extensions
# c99   - ISO C99 standard (not yet fully implemented)
# gnu99 - c99 plus GCC extensions
CSTANDARD = -std=gnu99

# Place -D or -U options here
CDEFS = \
	-DF_CPU=$(CLOCK) \
	-DBOARD=DUMMY_BOARD \
	-DNO_LOCKBITS_DEF \
#	-D_ASSERT_ENABLE_ \

ifeq ($(PLACE_IN_BOOTLOADER_MEM), yes)
CDEFS +=	-DPLACE_IN_BOOTLOADER_MEM
endif

CFLAGS = \
	-mmcu=$(MCU) \
	-save-temps=obj \
	-Os \
	-fdata-sections -ffunction-sections \

AFLAGS = \
	-x assembler-with-cpp

#---------------- Linker Options ----------------
#  -Wl,...:     tell GCC to pass this to linker.
#    -Map:      create map file
#    --cref:    add cross reference to  map file
LDFLAGS = -Wl,-Map=$(TARGET).map,--cref \
	      -Wl,--gc-sections \
#	      -Wl,-u,vfprintf -lprintf_min \
#		  -fwhole-program \

ifeq ($(PLACE_IN_BOOTLOADER_MEM), yes)
LDFLAGS += -Wl,--section-start=.text=$(BOOTLOADER_MEM_START_ADDR)
endif


# Place -I options here
CINCS = \
	-I$(SRCDIR)/xmega/atxmega384c3/iar \
	-I$(SRCDIR)/xmega/conf \
	-I$(XMEGADIR)/boards \
	-I$(XMEGADIR)/drivers/cpu \
	-I$(XMEGADIR)/drivers/nvm \
	-I$(XMEGADIR)/utils \
	-I$(XMEGADIR)/utils/preprocessor \
	-I$(COMMONDIR)/utils \
	-I$(COMMONDIR)/boards \
	-I$(COMMONDIR)/services/clock \
	-I$(COMMONDIR)/services/isp/flip \
	-I$(COMMONDIR)/services/usb \
	-I$(COMMONDIR)/services/usb/udc \
	-I$(COMMONDIR)/services/usb/class/dfu_flip \
	-I$(COMMONDIR)/services/usb/class/dfu_flip/device \
	-I$(XMEGADIR)/drivers/usart \
	-I$(COMMONDIR)/utils/stdio/stdio_serial \
	-I$(COMMONDIR)/services/serial \
	-I$(XMEGADIR)/drivers/pmic \
	-I$(COMMONDIR)/services/ioport \

SRC +=  \
	$(SRCDIR)/xmega/main.c \
	$(COMMONDIR)/services/usb/class/dfu_flip/device/udi_dfu_atmel.c \
	$(COMMONDIR)/services/usb/class/dfu_flip/device/udi_dfu_atmel_desc.c \
	$(COMMONDIR)/services/usb/udc/udc_dfu_small.c \
	$(COMMONDIR)/services/clock/xmega/sysclk.c \
	$(COMMONDIR)/services/isp/flip/xmega/isp.c \
	$(XMEGADIR)/drivers/nvm/nvm.c \
	$(XMEGADIR)/drivers/usb/usb_device.c \
	$(XMEGADIR)/drivers/usart/usart.c \
	
ASRC += \
	$(XMEGADIR)/drivers/nvm/nvm_asm.s \
	$(XMEGADIR)/drivers/cpu/ccp.s \
#	$(COMMONDIR)/services/isp/flip/xmega/cstartup.s90 \

#$(notdir $(ASRC:.s=.o)) $(notdir $(ASRC:.s90=.o))
OBJS += $(SRC:%.c=$(BUILDDIR)/%.o)
OBJS += $(ASRC:%.s=$(BUILDDIR)/%.o)


all: $(BUILDDIR)/$(TARGET).hex lss
#all: _build/main.o

clean:
	rm -rf $(BUILDDIR)

lss: $(TARGET).lss 

# Create extended listing file from ELF output file.
%.lss: $(BUILDDIR)/%.elf
	$(OBJDUMP) -h -S -z $< > $@

$(BUILDDIR)/%.o: %.c Makefile
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CDEFS) $(CINCS) -c $< -o $@

$(BUILDDIR)/%.o: %.s
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(AFLAGS) $(CDEFS) $(CINCS) -c $< -o $@

$(BUILDDIR)/$(TARGET).hex: $(BUILDDIR)/$(TARGET).elf
	$(OBJCOPY) -j .text -j .data -O ihex $< $@
	$(SIZE) $@

$(BUILDDIR)/$(TARGET).elf: $(OBJS)
	$(CC) $(CFLAGS) $(CDEFS) $(LDFLAGS) -o $@ $^ 

#If you see avrdude just doing nothing, the USB device might be
# in use by another program/VM. Make sure it's free.
erase:
	avrdude $(AVRDUDE_OPTS) -e

fuses:
	avrdude $(AVRDUDE_OPTS) $(FUSES)

#Don't use boot section here, avrdude bumps up the start address but the
# linker needs to do this work. Use linker option instead. 
# http://www.avrfreaks.net/forum/address-out-range-1
flashbootloader: $(BUILDDIR)/$(TARGET).hex erase fuses
	avrdude $(AVRDUDE_OPTS) -U flash:w:$(BUILDDIR)/$(TARGET).hex

