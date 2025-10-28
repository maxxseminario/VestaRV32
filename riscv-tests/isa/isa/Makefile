#=======================================================================
# Makefile for riscv-tests/isa
#-----------------------------------------------------------------------

XLEN ?= 32

src_dir := .

ifeq ($(XLEN),64)
include $(src_dir)/rv64ui/Makefrag
include $(src_dir)/rv64uc/Makefrag
include $(src_dir)/rv64um/Makefrag
include $(src_dir)/rv64ua/Makefrag
include $(src_dir)/rv64uf/Makefrag
include $(src_dir)/rv64ud/Makefrag
include $(src_dir)/rv64uzfh/Makefrag
include $(src_dir)/rv64uzba/Makefrag
include $(src_dir)/rv64uzbb/Makefrag
include $(src_dir)/rv64uzbc/Makefrag
include $(src_dir)/rv64uzbs/Makefrag
include $(src_dir)/rv64si/Makefrag
include $(src_dir)/rv64ssvnapot/Makefrag
include $(src_dir)/rv64mi/Makefrag
include $(src_dir)/rv64mzicbo/Makefrag
include $(src_dir)/hypervisor/Makefrag
endif
include $(src_dir)/rv32ui/Makefrag
include $(src_dir)/rv32uc/Makefrag
include $(src_dir)/rv32um/Makefrag
include $(src_dir)/rv32ua/Makefrag
include $(src_dir)/rv32uf/Makefrag
include $(src_dir)/rv32ud/Makefrag
include $(src_dir)/rv32uzfh/Makefrag
include $(src_dir)/rv32uzba/Makefrag
include $(src_dir)/rv32uzbb/Makefrag
include $(src_dir)/rv32uzbc/Makefrag
include $(src_dir)/rv32uzbs/Makefrag
include $(src_dir)/rv32si/Makefrag
include $(src_dir)/rv32mi/Makefrag
include $(src_dir)/periph/Makefrag

default: all

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

# RISCV_PREFIX ?= riscv$(XLEN)-none-elf-
RISCV_PREFIX ?= riscv-none-elf-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
RISCV_GCC_OPTS ?= -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles
RISCV_OBJDUMP ?= $(RISCV_PREFIX)objdump --disassemble-all --disassemble-zeroes --section=.text --section=.text.startup --section=.text.init --section=.data
RISCV_SIM ?= spike

vpath %.S $(src_dir)


# Maxx Seminario 06/17/25
# Variables for generating rcf files
RISCV_OBJCOPY ?= $(RISCV_PREFIX)objcopy
MEM_SIZE ?= $(shell printf "%d" 0x8000)
BIN_OFFSET ?= $(shell printf "%d" 0x0000) # Remember to account for 0x4000 offset of ROM
WORD_COUNT ?= $(shell echo $$(( $(MEM_SIZE) / 4 )))  

#------------------------------------------------------------
# Build assembly tests

%.dump: %
	$(RISCV_OBJDUMP) $< > $@

%.out: %
	$(RISCV_SIM) --isa=rv64gch_zfh_zicboz_svnapot_zicntr_zba_zbb_zbc_zbs --misaligned $< 2> $@

%.out32: %
	$(RISCV_SIM) --isa=rv32gc_zfh_zicboz_svnapot_zicntr_zba_zbb_zbc_zbs --misaligned $< 2> $@


#=======================================================================
# RCF generation rules
# Maxx Seminario 06/17/2025
#-----------------------------------------------------------------------

# Rule to convert ELF to binary
%.bin: %
	$(RISCV_OBJCOPY) -O binary --gap-fill=0x00 $< $@

# # Rule to pad/truncate binary to exactly MEM_SIZE
# %_padded.bin: %.bin
# 	@# First create full-size zero file, then overlay binary (truncating if needed)
# 	dd if=/dev/zero of=$@ bs=$(MEM_SIZE) count=1 2>/dev/null
# 	dd if=$< of=$@ bs=1 conv=notrunc 2>/dev/null
# Rule to pad/truncate binary to exactly MEM_SIZE, overlaying at BIN_OFFSET

%_padded.bin: %.bin
	@# Create full-size zero file
	dd if=/dev/zero of=$@ bs=$(MEM_SIZE) count=1 2>/dev/null
	@# Overlay binary at offset BIN_OFFSET (e.g., 0x4000)
	dd if=$< of=$@ bs=1 seek=$(BIN_OFFSET) conv=notrunc 2>/dev/null


# Rule to convert padded binary to binary-formatted RCF (1s/0s)
%.rcf: %_padded.bin
	@echo "Generating $@ (binary format, $(WORD_COUNT) words)"
	@od -v -An -tx4 -w4 $< | awk '\
	{ \
	    hex = $$1; \
	    bin = ""; \
	    for (i = 1; i <= 8; i++) { \
	        c = substr(hex, i, 1); \
	        if (c == "0") bin = bin "0000"; \
	        else if (c == "1") bin = bin "0001"; \
	        else if (c == "2") bin = bin "0010"; \
	        else if (c == "3") bin = bin "0011"; \
	        else if (c == "4") bin = bin "0100"; \
	        else if (c == "5") bin = bin "0101"; \
	        else if (c == "6") bin = bin "0110"; \
	        else if (c == "7") bin = bin "0111"; \
	        else if (c == "8") bin = bin "1000"; \
	        else if (c == "9") bin = bin "1001"; \
	        else if (c == "a") bin = bin "1010"; \
	        else if (c == "b") bin = bin "1011"; \
	        else if (c == "c") bin = bin "1100"; \
	        else if (c == "d") bin = bin "1101"; \
	        else if (c == "e") bin = bin "1110"; \
	        else if (c == "f") bin = bin "1111"; \
	    } \
	    print bin; \
	}' > $@
	@# Verify we have exactly WORD_COUNT lines
	@lines=$$(wc -l < $@); \
	if [ $$lines -ne $(WORD_COUNT) ]; then \
	    echo "Error: $@ has $$lines lines (expected $(WORD_COUNT))"; \
	    exit 1; \
	fi


# Generate list of all RCF targets for built tests
tests_rcf = $(addsuffix .rcf, $(tests))

# Add to junk list for cleaning
junk += $(addsuffix .bin, $(tests)) $(addsuffix _padded.bin, $(tests)) $(tests_rcf)


# ---------------------------------------------------------------
# Compile Template - 
# Maxx Seminario 06/17/2025 - Added rcf generation
# ---------------------------------------------------------------


define compile_template

$$($(1)_p_tests): $(1)-p-%: $(1)/%.S
	$$(RISCV_GCC) $(2) $$(RISCV_GCC_OPTS) -I$(src_dir)/../env/p -I$(src_dir)/macros/scalar -T$(src_dir)/../env/p/link.ld $$< -o $$@
	$$(MAKE) $$@.rcf  
$(1)_tests += $$($(1)_p_tests)

# $$($(1)_v_tests): $(1)-v-%: $(1)/%.S
# 	$$(RISCV_GCC) $(2) $$(RISCV_GCC_OPTS) -DENTROPY=0x$$(shell echo \$$@ | md5sum | cut -c 1-7) -std=gnu99 -O2 -I$(src_dir)/../env/v -I$(src_dir)/macros/scalar -T$(src_dir)/../env/v/link.ld $(src_dir)/../env/v/entry.S $(src_dir)/../env/v/*.c $$< -o $$@
# $(1)_tests += $$($(1)_v_tests)

$(1)_tests_dump = $$(addsuffix .dump, $$($(1)_tests))

$(1): $$($(1)_tests_dump) pad_rcf_filenames

.PHONY: $(1)

COMPILER_SUPPORTS_$(1) := $$(shell $$(RISCV_GCC) $(2) -c -x c /dev/null -o /dev/null 2> /dev/null; echo $$$$?)

ifeq ($$(COMPILER_SUPPORTS_$(1)),0)
tests += $$($(1)_tests)
endif

endef

$(eval $(call compile_template,periph,-march=rv32g -mabi=ilp32))
$(eval $(call compile_template,rv32ui,-march=rv32g -mabi=ilp32))
$(eval $(call compile_template,rv32uc,-march=rv32g -mabi=ilp32))
$(eval $(call compile_template,rv32um,-march=rv32g -mabi=ilp32))
$(eval $(call compile_template,rv32ua,-march=rv32g -mabi=ilp32))
$(eval $(call compile_template,rv32uf,-march=rv32g -mabi=ilp32))
$(eval $(call compile_template,rv32ud,-march=rv32g -mabi=ilp32))
$(eval $(call compile_template,rv32uzfh,-march=rv32g_zfh -mabi=ilp32))
$(eval $(call compile_template,rv32uzba,-march=rv32g_zba -mabi=ilp32))
$(eval $(call compile_template,rv32uzbb,-march=rv32g_zbb -mabi=ilp32))
$(eval $(call compile_template,rv32uzbc,-march=rv32g_zbc -mabi=ilp32))
$(eval $(call compile_template,rv32uzbs,-march=rv32g_zbs -mabi=ilp32))
$(eval $(call compile_template,rv32si,-march=rv32g -mabi=ilp32))
$(eval $(call compile_template,rv32mi,-march=rv32g -mabi=ilp32))
ifeq ($(XLEN),64)
$(eval $(call compile_template,rv64ui,-march=rv64g -mabi=lp64))
$(eval $(call compile_template,rv64uc,-march=rv64g -mabi=lp64))
$(eval $(call compile_template,rv64um,-march=rv64g -mabi=lp64))
$(eval $(call compile_template,rv64ua,-march=rv64g -mabi=lp64))
$(eval $(call compile_template,rv64uf,-march=rv64g -mabi=lp64))
$(eval $(call compile_template,rv64ud,-march=rv64g -mabi=lp64))
$(eval $(call compile_template,rv64uzfh,-march=rv64g_zfh -mabi=lp64))
$(eval $(call compile_template,rv64uzba,-march=rv64g_zba -mabi=lp64))
$(eval $(call compile_template,rv64uzbb,-march=rv64g_zbb -mabi=lp64))
$(eval $(call compile_template,rv64uzbc,-march=rv64g_zbc -mabi=lp64))
$(eval $(call compile_template,rv64uzbs,-march=rv64g_zbs -mabi=lp64))
$(eval $(call compile_template,rv64mzicbo,-march=rv64g_zicboz -mabi=lp64))
$(eval $(call compile_template,rv64si,-march=rv64g -mabi=lp64))
$(eval $(call compile_template,rv64ssvnapot,-march=rv64g -mabi=lp64))
$(eval $(call compile_template,rv64mi,-march=rv64g -mabi=lp64))
$(eval $(call compile_template,hypervisor,-march=rv64gh -mabi=lp64))
endif

tests_dump = $(addsuffix .dump, $(tests))
tests_hex = $(addsuffix .hex, $(tests))
tests_out = $(addsuffix .out, $(filter rv64%,$(tests)))
tests32_out = $(addsuffix .out32, $(filter rv32%,$(tests)))

run: $(tests_out) $(tests32_out)

junk += $(tests) $(tests_dump) $(tests_hex) $(tests_out) $(tests32_out)


#=======================================================================
# 
#-----------------------------------------------------------------------
.PHONY: all-rcf

all-rcf: $(tests_rcf)


.PHONY: pad_rcf_filenames
pad_rcf_filenames:
	@maxlen=$$(find . -maxdepth 1 -name "*.rcf" -printf "%f\n" | awk '{ print length, $$0 }' | sort -nr | head -1 | cut -d' ' -f1); \
	for f in *.rcf; do \
	  len=$${#f}; \
	  if [ $$len -lt $$maxlen ]; then \
	    pad=$$(printf '%*s' $$((maxlen - len)) '' | tr ' ' x); \
	    mv "$$f" "$$pad$$f"; \
	  fi; \
	done

junk += $(wildcard x*.rcf)


#------------------------------------------------------------
# Default

all: $(tests_dump) all-rcf

#------------------------------------------------------------
# Clean up

clean:
	rm -rf $(junk)
