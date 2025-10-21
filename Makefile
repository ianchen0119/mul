# Makefile for eBPF Packet Duplication System

.PHONY: all build build-ebpf build-go clean test help

all: build

# Build everything
build: build-ebpf build-go

# Build eBPF program
build-ebpf:
	@echo "Building eBPF program..."
	@cd src && $(MAKE)

# Build Go application
build-go:
	@echo "Building Go loader application..."
	@cd cmd/loader && go build -o ../../loader

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@cd src && $(MAKE) clean
	@rm -f loader
	@rm -f cmd/loader/loader

# Run tests
test:
	@echo "Running tests..."
	@go test -v ./...

# Show help
help:
	@echo "eBPF Packet Duplication System - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  all          - Build everything (default)"
	@echo "  build        - Build eBPF program and Go application"
	@echo "  build-ebpf   - Build eBPF program only"
	@echo "  build-go     - Build Go application only"
	@echo "  clean        - Remove build artifacts"
	@echo "  test         - Run tests"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make              # Build everything"
	@echo "  make clean        # Clean build artifacts"
	@echo "  make build-ebpf   # Rebuild only eBPF program"
