# Makefile for building eBPF programs

CLANG ?= clang
LLVM_STRIP ?= llvm-strip
ARCH := $(shell uname -m | sed 's/x86_64/x86/' | sed 's/aarch64/arm64/')

BPF_CFLAGS := -g -O2 -target bpf -D__TARGET_ARCH_$(ARCH)
BPF_INCLUDES := -I/usr/include/$(shell uname -m)-linux-gnu

TARGETS := packet_duplicator.o

.PHONY: all clean

all: $(TARGETS)

%.o: %.c
	$(CLANG) $(BPF_CFLAGS) $(BPF_INCLUDES) -c $< -o $@
	@if command -v $(LLVM_STRIP) > /dev/null 2>&1; then \
		$(LLVM_STRIP) -g $@; \
	fi

clean:
	rm -f *.o
