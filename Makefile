DEBUG = 0
FRONTEND_SUPPORTS_RGB565 = 1

CORE_DIR := .

# system platform
ifeq ($(platform),)
   platform = unix
   ifeq ($(shell uname -a),)
      EXE_EXT = .exe
      platform = win
   else ifneq ($(findstring MINGW,$(shell uname -a)),)
      platform = win
   else ifneq ($(findstring win,$(shell uname -a)),)
      platform = win
   else ifneq ($(findstring Darwin,$(shell uname -a)),)
      platform = osx
   endif
else ifneq (,$(findstring armv,$(platform)))
   override platform += unix
else ifneq (,$(findstring rpi,$(platform)))
   override platform += unix
endif

ifeq ($(shell uname -p),powerpc)
   arch = ppc
else
   arch = intel
endif

# If you have a system with 1GB RAM or more - cache the whole 
# CD for CD-based systems in order to prevent file access delays/hiccups
CACHE_CD = 0

NEED_BPP = 16
NEED_BLIP = 1
WANT_NEW_API = 1
NEED_STEREO_SOUND = 1
CORE_DEFINE := -DWANT_VB_EMU

TARGET_NAME := mednafen_vb

# GIT HASH
GIT_VERSION := " $(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
   CXXFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
endif

# Unix
ifneq (,$(findstring unix,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   fpic := -fPIC
   SHARED := -shared -Wl,--no-undefined -Wl,--version-script=link.T
   ifneq ($(shell uname -p | grep -E '((i.|x)86|amd64)'),)
      IS_X86 = 1
   else
      IS_X86 = 0
   endif

   # Raspberry Pi
   ifneq (,$(findstring rpi,$(platform)))
      FLAGS += -fomit-frame-pointer -ffast-math -marm
      ifneq (,$(findstring rpi1,$(platform)))
         FLAGS += -march=armv6j -mfpu=vfp -mfloat-abi=hard
      else ifneq (,$(findstring rpi2,$(platform)))
         FLAGS += -mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard
      else ifneq (,$(findstring rpi3,$(platform)))
         FLAGS += -mcpu=cortex-a53 -mfpu=neon-fp-armv8 -mfloat-abi=hard
      endif
   endif

# OS X
else ifeq ($(platform), osx)
   TARGET := $(TARGET_NAME)_libretro.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
   ifeq ($(arch),ppc)
      ENDIANNESS_DEFINES := -DMSB_FIRST
      OLD_GCC := 1
   endif
   OSXVER = `sw_vers -productVersion | cut -d. -f 2`
   OSX_LT_MAVERICKS = `(( $(OSXVER) <= 9)) && echo "YES"`
   fpic += -mmacosx-version-min=10.1

# iOS
else ifneq (,$(findstring ios,$(platform)))
   TARGET := $(TARGET_NAME)_libretro_ios.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
   ifeq ($(IOSSDK),)
      IOSSDK := $(shell xcodebuild -version -sdk iphoneos Path)
   endif
   CC = cc -arch armv7 -isysroot $(IOSSDK)
   CXX = c++ -arch armv7 -isysroot $(IOSSDK)
   IPHONEMINVER :=
   ifeq ($(platform),ios9)
      IPHONEMINVER = -miphoneos-version-min=8.0
   else
      IPHONEMINVER = -miphoneos-version-min=5.0
   endif
   LDFLAGS += $(IPHONEMINVER)
   FLAGS += $(IPHONEMINVER)
   CC += $(IPHONEMINVER)
   CXX += $(IPHONEMINVER)

# QNX
else ifeq ($(platform), qnx)
   TARGET := $(TARGET_NAME)_libretro_$(platform).so
   fpic := -fPIC
   SHARED := -lcpp -lm -shared -Wl,--no-undefined -Wl,--version-script=link.T
   CC = qcc -Vgcc_ntoarmv7le
   CXX = QCC -Vgcc_ntoarmv7le_cpp
   AR = QCC -Vgcc_ntoarmv7le
   FLAGS += -D__BLACKBERRY_QNX__ -marm -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=softfp

# PS3
else ifneq (,$(filter $(platform), ps3 sncps3 psl1ght))
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   ENDIANNESS_DEFINES := -DMSB_FIRST
   STATIC_LINKING = 1

   # sncps3
   ifneq (,$(findstring sncps3,$(platform)))
      TARGET := $(TARGET_NAME)_libretro_ps3.a
      CC = $(CELL_SDK)/host-win32/sn/bin/ps3ppusnc.exe
      CXX = $(CC)
      AR = $(CELL_SDK)/host-win32/sn/bin/ps3snarl.exe
      OLD_GCC := 1
      NO_GCC := 1
      CXXFLAGS += -Xc+=exceptions
      FLAGS += -DARCH_POWERPC_ALTIVEC

   # PS3
   else ifneq (,$(findstring ps3,$(platform)))
      CC = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-gcc.exe
      CXX = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-g++.exe
      AR = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-ar.exe
      OLD_GCC := 1
      FLAGS += -DARCH_POWERPC_ALTIVEC

   # Lightweight PS3 Homebrew SDK
   else ifneq (,$(findstring psl1ght,$(platform)))
      CC = $(PS3DEV)/ppu/bin/ppu-gcc$(EXE_EXT)
      CXX = $(PS3DEV)/ppu/bin/ppu-g++$(EXE_EXT)
      AR = $(PS3DEV)/ppu/bin/ppu-ar$(EXE_EXT)
   endif

# PSP
else ifeq ($(platform), psp1)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = psp-gcc$(EXE_EXT)
   CXX = psp-g++$(EXE_EXT)
   AR = psp-ar$(EXE_EXT)
   FLAGS += -DPSP -G0
   STATIC_LINKING = 1

# Vita
else ifeq ($(platform), vita)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = arm-vita-eabi-gcc$(EXE_EXT)
   CXX = arm-vita-eabi-g++$(EXE_EXT)
   AR = arm-vita-eabi-ar$(EXE_EXT)
   FLAGS += -DVITA
   NEED_BPP := 16
   STATIC_LINKING = 1

# CTR (3DS)
else ifeq ($(platform), ctr)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(DEVKITARM)/bin/arm-none-eabi-gcc$(EXE_EXT)
   CXX = $(DEVKITARM)/bin/arm-none-eabi-g++$(EXE_EXT)
   AR = $(DEVKITARM)/bin/arm-none-eabi-ar$(EXE_EXT)
   FLAGS += -DARM11 -D_3DS
   FLAGS += -march=armv6k -mtune=mpcore -mfloat-abi=hard
   FLAGS += -mword-relocations
   FLAGS += -fomit-frame-pointer -fstrict-aliasing -ffast-math
   FLAGS += -fno-rtti
   FLAGS += -fno-exceptions -DDISABLE_EXCEPTIONS
   STATIC_LINKING = 1
   IS_X86 := 0
   NEED_BPP := 16

# Xbox 360
else ifeq ($(platform), xenon)
   TARGET := $(TARGET_NAME)_libretro_xenon360.a
   CC = xenon-gcc$(EXE_EXT)
   CXX = xenon-g++$(EXE_EXT)
   AR = xenon-ar$(EXE_EXT)
   ENDIANNESS_DEFINES += -D__LIBXENON__ -m32 -D__ppc__ -DMSB_FIRST
   STATIC_LINKING = 1

# Nintendo Game Cube / Wii / WiiU
else ifneq (,$(filter $(platform), ngc wii wiiu))
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(DEVKITPPC)/bin/powerpc-eabi-gcc$(EXE_EXT)
   CXX = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)
   ENDIANNESS_DEFINES += -DGEKKO -mcpu=750 -meabi -mhard-float -DMSB_FIRST
   FLAGS += -U__INT32_TYPE__ -U __UINT32_TYPE__ -D__INT32_TYPE__=int
   EXTRA_INCLUDES := -I$(DEVKITPRO)/libogc/include
   STATIC_LINKING = 1

   # Nintendo WiiU
   ifneq (,$(findstring wiiu,$(platform)))
      ENDIANNESS_DEFINES += -DWIIU -DHW_RVL -mwup

   # Nintendo Wii
   else ifneq (,$(findstring wii,$(platform)))
      ENDIANNESS_DEFINES += -DHW_RVL -mrvl

   # Nintendo Game Cube
   else ifneq (,$(findstring ngc,$(platform)))
      ENDIANNESS_DEFINES += -DHW_DOL -mrvl
   endif

# Emscripten
else ifeq ($(platform), emscripten)
   TARGET := $(TARGET_NAME)_libretro_$(platform).bc
   STATIC_LINKING = 1

# GCW0
else ifeq ($(platform), gcw0)
   TARGET := $(TARGET_NAME)_libretro.so
   CC = /opt/gcw0-toolchain/usr/bin/mipsel-linux-gcc
   CXX = /opt/gcw0-toolchain/usr/bin/mipsel-linux-g++
   AR = /opt/gcw0-toolchain/usr/bin/mipsel-linux-ar
   fpic := -fPIC
   SHARED := -shared -Wl,--no-undefined -Wl,--version-script=link.T
   FLAGS += -ffast-math -march=mips32 -mtune=mips32r2 -mhard-float

# Windows
else
   TARGET := $(TARGET_NAME)_libretro.dll
   CC = gcc
   CXX = g++
   IS_X86 = 1
   SHARED := -shared -Wl,--no-undefined -Wl,--version-script=link.T
   LDFLAGS += -static-libgcc -static-libstdc++ -lwinmm
   FLAGS += -DHAVE__MKDIR
endif

include Makefile.common

WARNINGS := -Wall \
	-Wno-sign-compare \
	-Wno-unused-variable \
	-Wno-unused-function \
	-Wno-uninitialized \
	$(NEW_GCC_WARNING_FLAGS) \
	-Wno-strict-aliasing

EXTRA_GCC_FLAGS := -funroll-loops

ifeq ($(NO_GCC),1)
   EXTRA_GCC_FLAGS :=
   WARNINGS :=
else
   EXTRA_GCC_FLAGS := -g
endif

OBJECTS := $(SOURCES_CXX:.cpp=.o) $(SOURCES_C:.c=.o)

all: $(TARGET)

ifeq ($(DEBUG),0)
   FLAGS += -O2 $(EXTRA_GCC_FLAGS)
else
   FLAGS += -O0
endif

LDFLAGS += $(fpic) $(SHARED)
FLAGS   += $(fpic) $(NEW_GCC_FLAGS)
FLAGS   += $(INCFLAGS)

FLAGS += $(ENDIANNESS_DEFINES) -DSIZEOF_DOUBLE=8 $(WARNINGS) -DMEDNAFEN_VERSION=\"0.9.31\" -DPACKAGE=\"mednafen\" -DMEDNAFEN_VERSION_NUMERIC=931 -DPSS_STYLE=1 -DMPC_FIXED_POINT $(CORE_DEFINE) -DSTDC_HEADERS -D__STDC_LIMIT_MACROS -D__LIBRETRO__ -D_LOW_ACCURACY_ $(EXTRA_INCLUDES) $(SOUND_DEFINE)

CXXFLAGS += $(FLAGS)
CFLAGS += $(FLAGS)

$(TARGET): $(OBJECTS)
ifeq ($(STATIC_LINKING), 1)
	$(AR) rcs $@ $(OBJECTS)
else
	$(CXX) -o $@ $^ $(LDFLAGS)
endif

%.o: %.cpp
	$(CXX) -c -o $@ $< $(CPPFLAGS) $(CXXFLAGS)

%.o: %.c
	$(CC) -c -o $@ $< $(CPPFLAGS) $(CFLAGS)

clean:
	rm -f $(TARGET) $(OBJECTS)

.PHONY: clean
