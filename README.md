# eBPF Packet Duplication System

A high-performance packet duplication system using eBPF TC (Traffic Control) hooks with `bpf_clone_redirect()` to duplicate network packets across multiple containers in a Docker network.

## 🚀 Quick Start

**New to the project?** See [QUICKSTART.md](QUICKSTART.md) for a 5-minute setup guide.

**Ready to contribute?** See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Overview

This project demonstrates a complete eBPF-based packet duplication solution that:
- Attaches an eBPF program to TC egress hooks
- Uses `bpf_clone_redirect()` to duplicate packets to multiple target interfaces
- Provides real-time statistics and monitoring
- Includes a complete Docker-based testing environment

## Features

- **eBPF TC Egress Hook**: Intercepts outgoing packets at the kernel level
- **Packet Duplication**: Clones packets to up to 16 target network interfaces
- **Real-time Statistics**: Tracks packets processed, cloned, and errors
- **User-space Controller**: Go application using cilium/ebpf library
- **Docker Test Environment**: Multi-container setup for validation
- **Performance Monitoring**: Built-in metrics collection and reporting

## Architecture

```
┌─────────────────┐
│   Container A   │
│    (Sender)     │
└────────┬────────┘
         │
         ▼
   ┌──────────┐
   │ TC Egress│◄──── eBPF Program (bpf_clone_redirect)
   │  Hook    │
   └─────┬────┘
         │
    ┌────┴────┬─────────┬─────────┐
    ▼         ▼         ▼         ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│  Orig  │ │  Copy  │ │  Copy  │ │  Copy  │
│  Dest  │ │   #1   │ │   #2   │ │   #3   │
└────────┘ └────────┘ └────────┘ └────────┘
```

## Project Structure

```
.
├── src/                    # eBPF C source code
│   ├── packet_duplicator.c # Main eBPF program
│   └── Makefile            # Build configuration
├── cmd/
│   └── loader/             # Go user-space application
│       └── main.go         # eBPF loader and controller
├── scripts/                # Automation scripts
│   ├── setup.sh            # Environment setup
│   ├── test.sh             # Test execution
│   ├── cleanup.sh          # Cleanup
│   └── view_logs.sh        # View eBPF logs
├── docs/                   # Documentation
│   ├── architecture.md     # Architecture details
│   ├── performance.md      # Performance analysis
│   └── guide.md            # Step-by-step guide
├── compose.yaml            # Docker Compose configuration
├── Dockerfile.loader       # Dockerfile for loader container
└── README.md               # This file
```

## Requirements

- Linux kernel >= 5.10 (with BPF support)
- Clang/LLVM (for compiling eBPF programs)
- Go >= 1.19
- Docker and Docker Compose
- Root/sudo privileges (for loading eBPF programs)

**Check your system:**
```bash
./scripts/validate.sh
```

## Quick Start

### 1. Validate Environment

```bash
./scripts/validate.sh
```

### 2. Build the System

```bash
make
```

### 3. Setup Test Environment

```bash
./scripts/setup.sh
```

This will:
- Build the eBPF program
- Build the Go loader application
- Start Docker containers
- Create the test network

### 4. Load eBPF Program

Find the network interface indices:

```bash
# Get interface information
docker network inspect ebpf_net
```

Load the eBPF program (as root):

```bash
sudo ./loader -iface <sender_veth> -targets <receiver1_veth>,<receiver2_veth>,<receiver3_veth>
```

Example:
```bash
sudo ./loader -iface veth1234abc -targets veth5678def,veth90abghi,vethjklm123
```

### 5. Test Packet Duplication

In another terminal, run the test script:

```bash
./scripts/test.sh
```

### 6. View Statistics

```bash
sudo ./loader -stats
```

### 7. Monitor eBPF Logs

```bash
sudo ./scripts/view_logs.sh
```

### 8. Cleanup

```bash
./scripts/cleanup.sh
```

## Building from Source

### Build eBPF Program

```bash
cd src
make
```

This generates `packet_duplicator.o` - the compiled eBPF bytecode.

### Build Go Application

```bash
cd cmd/loader
go build -o ../../loader
```

## Usage

### Loader Command-Line Options

```bash
./loader [OPTIONS]

Options:
  -iface string
        Network interface to attach TC egress hook
  -targets string
        Comma-separated list of target interfaces for packet duplication
  -stats
        Show statistics and exit
```

### Examples

**Attach eBPF program:**
```bash
sudo ./loader -iface eth0 -targets eth1,eth2,eth3
```

**View statistics:**
```bash
sudo ./loader -stats
```

## How It Works

1. **eBPF Program**: The C program (`packet_duplicator.c`) hooks into the TC egress point
2. **Packet Interception**: Every outgoing packet is intercepted
3. **Duplication**: For each configured target interface, `bpf_clone_redirect()` creates a copy
4. **Statistics**: Counters track processed packets, successful clones, and errors
5. **Original Packet**: Returns `TC_ACT_OK` to allow the original packet to continue

## Performance Considerations

- **Zero-copy**: `bpf_clone_redirect()` uses efficient kernel mechanisms
- **Overhead**: Minimal CPU overhead (~1-5% for typical workloads)
- **Scalability**: Can handle up to 16 target interfaces
- **Statistics**: Atomic counters prevent race conditions

## Testing

The project includes a complete Docker-based test environment with:
- 1 sender container
- 3 receiver containers
- Custom bridge network
- Automated test scripts

Run tests with:
```bash
./scripts/setup.sh
./scripts/test.sh
```

## Troubleshooting

**eBPF program won't load:**
- Check kernel version: `uname -r` (needs >= 5.10)
- Verify BPF is enabled: `zgrep CONFIG_BPF /proc/config.gz`
- Ensure running as root

**Packets not duplicated:**
- Verify target interfaces exist: `ip link show`
- Check eBPF logs: `sudo ./scripts/view_logs.sh`
- View statistics: `sudo ./loader -stats`

**Permission denied:**
- Run with sudo: `sudo ./loader ...`
- Check capabilities: CAP_BPF, CAP_NET_ADMIN, CAP_SYS_ADMIN

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

Dual BSD/GPL - See LICENSE file for details.

## References

- [eBPF Documentation](https://ebpf.io/)
- [Cilium eBPF Library](https://github.com/cilium/ebpf)
- [BPF and XDP Reference Guide](https://docs.cilium.io/en/latest/bpf/)
- [tc-bpf(8) man page](https://man7.org/linux/man-pages/man8/tc-bpf.8.html)