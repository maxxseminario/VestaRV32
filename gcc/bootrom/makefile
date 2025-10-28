# Name of target (without file extension, must be in SRC_DIR)
TARGET      = flashboot

# Project Sources (file names to use in SRC_DIR) and Global Library Sources (file names to use from LIB_DIR/src)
# WARNING: start.S must be first in the SRC_SOURCES list. This is to ensure it is placed in the appropriate memory location
SRC_SOURCES	= start.S main.c rv4th.c uart.c spi.c flash_memory.c
LIB_SOURCES	= 
EXTENSIONS	= i

# Chip Global Libraries and Linker Script
LIB_DIR		= ../lib
LD_DIR		= $(LIB_DIR)/linker
LD_SCRIPT	= $(LD_DIR)/MCU-bootrom.ld

# MCU Libraries
LIB_SRC_DIR = $(LIB_DIR)/src
LIB_INC_DIR = $(LIB_DIR)/include

# Project Files Source
SRC_DIR		= ./src
INC_DIR		= ./include
OBJ_DIR		= ./obj
BIN_DIR		= ./bin

# RAM and ROM Sizes
RAM_START	= `cat $(LD_DIR)/RAM_START.txt`
RAM_SIZE	= `cat $(LD_DIR)/RAM_SIZE.txt`
ROM_START	= `cat $(LD_DIR)/ROM_START.txt`
ROM_SIZE	= `cat $(LD_DIR)/ROM_SIZE.txt`

# Compiler flags
# Unused: Generate assembly listings for each C file: -Wa,-ahls=$*.lst
# Note: the -flto flag initiates link time optimization. It seems to force the compiler/linker to include only the functions explicitly used by the main function in the final output file. It also seems to require interrupts to have the __attribute__ prefix. This means that only the functions that are called by the main function and the interrupts will be added to the final binary file.
OPTIMIZATION_FLAGS = -Os -flto
#OPTIMIZATION_FLAGS = -flto
ARCH	= rv32$(EXTENSIONS)
CFLAGS	= -Werror -Wall -Wunused -march=$(ARCH) $(OPTIMIZATION_FLAGS) -D__nostdlib__ -I $(GCC_INC_DIR) -I $(INC_DIR) -I $(LIB_INC_DIR) -g
LFLAGS	= -lgcc -march=$(ARCH) $(OPTIMIZATION_FLAGS) -nostartfiles -Wl,-Bstatic,-T,$(LD_SCRIPT),-Map,$(BIN_DIR)/$(TARGET).map,--cref -L $(LD_DIR) -g

##################################################
### TOOLCHAIN DIRECTORIES
##################################################
ifdef RISCV
	RISCV_DIR = ${RISCV}
else
	RISCV_DIR = /opt/riscv
endif
RISCV_TOOLCHAIN_DIR	= $(RISCV_DIR)/rv32im
PYTHON_DIR	= ../../python
GCC_INC_DIR	= $(RISCV_TOOLCHAIN_DIR)/riscv32-unknown-elf/include
CC			= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-gcc
LD			= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-ld
AR			= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-ar
AS			= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-gcc
GASP		= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-gasp
NM			= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-nm
OBJCOPY		= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-objcopy
OBJDUMP		= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-objdump
RANLIB		= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-ranlib
STRIP		= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-strip
SIZE		= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-size
READELF		= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-readelf
GDB			= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-unknown-elf-gdb
MAKETXT		= srec_cat
CP			= cp -p
RM			= rm -f
MV			= mv
MKDIR		= mkdir
RCF			= $(PYTHON_DIR)/ihex2rcf.py

# Dependencies
SRC_OBJECTS	= $(patsubst %,%.src.o,$(SRC_SOURCES))
LIB_OBJECTS	= $(patsubst %,%.lib.o,$(LIB_SOURCES))

SOURCES		= $(patsubst %,$(SRC_DIR)/%,$(SRC_SOURCES)) $(patsubst %,$(LIB_DIR)/%,$(LIB_SOURCES))
OBJECTS     = $(patsubst %,$(OBJ_DIR)/%,$(SRC_OBJECTS)) $(patsubst %,$(OBJ_DIR)/%,$(LIB_OBJECTS))

HEADERS     =  $(wildcard $(GCC_INC_DIR)/*.h) $(wildcard $(LIB_INC_DIR)/*.h) $(wildcard $(INC_DIR)/*.h)

##################################################
### COMPILATION RULES
##################################################

# Make the entire project
.PHONY: all
all: $(BIN_DIR)/$(TARGET).hex $(BIN_DIR)/$(TARGET).lst $(BIN_DIR)/rom.rcf

# Compile project source files from the project source directory into object files
$(OBJ_DIR)/%.src.o: $(SRC_DIR)/% $(HEADERS)
	@echo ""
	@echo "> Compiling project source file $<"
	@echo ""
	$(CC) -c $(CFLAGS) $< -o $@
	
# Compile library source files from the library source directory into object files
$(OBJ_DIR)/%.lib.o: $(LIB_SRC_DIR)/% $(HEADERS)
	@echo ""
	@echo "> Compiling library source file $<"
	@echo ""
	$(CC) -c $(CFLAGS) $< -o $@

# Link object files together to create binary elf output file, show memory usage
$(BIN_DIR)/$(TARGET).elf: $(OBJECTS)
	@echo ""
	@echo "> Linking $@"
	@echo ""
	$(CC) $(LFLAGS) $(OBJECTS) -o $@

# Convert elf file into Intel hex file
$(BIN_DIR)/%.hex: $(BIN_DIR)/%.elf
	@echo ""
	@echo "> Creating output hex file $@"
	@echo ""
	$(OBJCOPY) -O ihex $< $@

# Create assembly lst file
$(BIN_DIR)/%.lst: $(BIN_DIR)/%.elf
	@echo ""
	@echo "> Creating C-to-assembly lst file $@"
	@echo ""
	$(OBJDUMP) --prefix-addresses --show-raw-insn -SrlD $< > $@
	@make memory -s

# Create ROM RCF file
$(BIN_DIR)/rom.rcf: $(BIN_DIR)/$(TARGET).hex
	@echo ""
	@echo "> Creating boot ROM RCF file $@"
	@echo ""
	$(RCF) $< $@ $(ROM_START) $(ROM_SIZE) 32 --default 0x00000000

	
##################################################
### HELPER RULES
##################################################

# Remove junk
.PHONY: tidy
tidy:
	@echo ""
	@echo "> Tidying up"
	@echo ""
	find $(OBJ_DIR) -type f -regextype posix-extended -iregex '.*\.(o)' -delete
	find $(BIN_DIR) -type f -regextype posix-extended -iregex '.*\.(map|xout|out|d|lst|map)' -delete

# Remove all non-source compilation artifacts
.PHONY: clean
clean: tidy
	@echo ""
	@echo "> Cleaning"
	@echo ""
	find $(BIN_DIR) -type f -regextype posix-extended -iregex '.*\.(hex|elf|rcf|hdlmem)' -delete

# Print the memory usage of the target
.PHONY: memory
memory:
	@echo ""
	@echo "> Memory usage for $(TARGET)"
	@echo "    text is length of program in bytes (decimal)"
	@echo "    data is length of global vars in bytes (decimal)"
	@echo "    bss is length of uninitialized vars in bytes (decimal)"
	@echo "    dec is combined memory usage in bytes (decimal)"
	@echo ""
	$(SIZE) $(BIN_DIR)/$(TARGET).elf --format=berkeley --radix=10

# Set up the folder hierarchy
.PHONY: setup
setup:
	@if [ ! -d $(SRC_DIR) ] ; then $(MKDIR) $(SRC_DIR) ; fi
	@if [ ! -d $(INC_DIR) ] ; then $(MKDIR) $(INC_DIR) ; fi
	@if [ ! -d $(OBJ_DIR) ] ; then $(MKDIR) $(OBJ_DIR) ; fi
	@if [ ! -d $(BIN_DIR) ] ; then $(MKDIR) $(BIN_DIR) ; fi
	@echo "!.gitignore" > $(SRC_DIR)/.gitignore
	@echo "!.gitignore" > $(INC_DIR)/.gitignore
	@echo "*" > $(OBJ_DIR)/.gitignore && echo "!.gitignore" >> $(OBJ_DIR)/.gitignore
	@echo "!.gitignore" > $(BIN_DIR)/.gitignore
