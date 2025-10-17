# Development Setup

Guide for developers who want to contribute to the eBPF Packet Duplication System.

## Prerequisites

### Required Tools

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
    git \
    make \
    clang \
    llvm \
    libbpf-dev \
    linux-headers-$(uname -r) \
    build-essential \
    golang-1.21 \
    docker.io \
    docker-compose

# Verify installations
clang --version
go version
docker --version
```

### Optional Tools

```bash
# Code formatting and linting
go install honnef.co/go/tools/cmd/staticcheck@latest
go install golang.org/x/tools/cmd/goimports@latest

# Debugging tools
sudo apt-get install -y \
    bpftool \
    trace-cmd \
    perf-tools-unstable
```

## Development Workflow

### 1. Fork and Clone

```bash
# Fork the repository on GitHub first
git clone https://github.com/YOUR_USERNAME/mul.git
cd mul

# Add upstream remote
git remote add upstream https://github.com/ianchen0119/mul.git
```

### 2. Create Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 3. Make Changes

#### Editing eBPF Code

```bash
# Edit src/packet_duplicator.c
vim src/packet_duplicator.c

# Build and test
cd src
make
cd ..
```

#### Editing Go Code

```bash
# Edit cmd/loader/main.go
vim cmd/loader/main.go

# Format code
go fmt ./...

# Build
cd cmd/loader
go build -o ../../loader
cd ../..
```

### 4. Test Changes

```bash
# Build everything
make clean
make

# Run validation
./scripts/validate.sh

# Test with Docker
./scripts/setup.sh
# Manual testing here
./scripts/cleanup.sh
```

### 5. Lint and Format

```bash
# Go code
go fmt ./...
go vet ./...
staticcheck ./...

# Check for common issues
golangci-lint run
```

### 6. Commit Changes

```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "Add feature X

- Implement functionality Y
- Update documentation
- Add tests"
```

### 7. Push and Create PR

```bash
# Push to your fork
git push origin feature/your-feature-name

# Create Pull Request on GitHub
```

## Development Tips

### Debugging eBPF Programs

**View eBPF logs:**
```bash
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

**Check program is loaded:**
```bash
sudo bpftool prog list
```

**Inspect maps:**
```bash
sudo bpftool map list
sudo bpftool map dump id <map_id>
```

### Debugging Go Application

**Add debug logging:**
```go
log.Printf("Debug: variable = %v", variable)
```

**Run with verbose output:**
```bash
go run -v cmd/loader/main.go -iface eth0 -targets eth1
```

**Use delve debugger:**
```bash
dlv debug cmd/loader/main.go -- -iface eth0 -targets eth1
```

### Testing eBPF Without Docker

**Load program on host interface:**
```bash
# WARNING: This affects host networking!
sudo ./loader -iface lo -targets lo
ping 127.0.0.1
sudo pkill loader
```

### Common Development Tasks

**Rebuild only eBPF:**
```bash
make build-ebpf
```

**Rebuild only Go:**
```bash
make build-go
```

**Clean and rebuild:**
```bash
make clean
make
```

**Run tests:**
```bash
go test -v ./...
```

## Code Style Guide

### eBPF C Code

- Follow Linux kernel coding style
- Indent with tabs (8 spaces)
- Line length: 80 characters max
- Functions: lowercase with underscores
- Constants: UPPERCASE

**Example:**
```c
static long handle_packet(struct __sk_buff *skb)
{
    __u32 key = 0;
    struct stats *stat;
    
    stat = bpf_map_lookup_elem(&statistics, &key);
    if (!stat)
        return TC_ACT_OK;
    
    // ... implementation
}
```

### Go Code

- Follow standard Go conventions
- Use `gofmt` for formatting
- Run `go vet` before committing
- Add godoc comments for exported functions

**Example:**
```go
// LoadProgram loads the eBPF program and attaches it to the interface.
// Returns an error if loading or attachment fails.
func LoadProgram(ifaceName string) error {
    // ... implementation
}
```

### Shell Scripts

- Use `#!/bin/bash` shebang
- Set `set -e` for error handling
- Quote variables: `"$var"`
- Use meaningful variable names

**Example:**
```bash
#!/bin/bash
set -e

interface_name="$1"
if [ -z "$interface_name" ]; then
    echo "Error: interface name required"
    exit 1
fi
```

## Testing Guidelines

### Unit Tests

```go
func TestTargetInterfaceConfig(t *testing.T) {
    // Test implementation
}
```

### Integration Tests

```bash
# scripts/integration_test.sh
./scripts/setup.sh
# Run tests
./scripts/cleanup.sh
```

### Performance Tests

See `docs/performance.md` for benchmarking methodology.

## Documentation

Update documentation when:
- Adding new features
- Changing API
- Modifying behavior
- Adding configuration options

Documentation files:
- `README.md` - Overview and quick start
- `docs/architecture.md` - System design
- `docs/performance.md` - Performance data
- `docs/guide.md` - User guide
- Code comments - Complex logic

## Useful Commands

**Monitor eBPF events:**
```bash
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_bpf { printf("%s\n", comm); }'
```

**Check TC filters:**
```bash
tc filter show dev <interface> egress
```

**Monitor network traffic:**
```bash
sudo tcpdump -i <interface> -n
```

**Profile Go application:**
```bash
go build -o loader.prof cmd/loader/main.go
./loader.prof -cpuprofile=cpu.prof -memprofile=mem.prof
go tool pprof loader.prof cpu.prof
```

## Troubleshooting

**eBPF verifier errors:**
- Check map access bounds
- Ensure all paths return a value
- Verify loop bounds are constant

**Build errors:**
- Update dependencies: `go mod tidy`
- Check kernel headers: `ls /lib/modules/$(uname -r)/build`
- Verify clang version: `clang --version`

**Runtime errors:**
- Check permissions: `sudo`
- Verify interface exists: `ip link show`
- Check kernel version: `uname -r`

## Getting Help

- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: Questions and ideas
- Code Review: Submit PR for feedback

## Resources

- [eBPF Documentation](https://ebpf.io/)
- [Cilium eBPF Library](https://github.com/cilium/ebpf)
- [BPF and XDP Guide](https://docs.cilium.io/en/latest/bpf/)
- [Linux Kernel Development](https://www.kernel.org/doc/html/latest/)
