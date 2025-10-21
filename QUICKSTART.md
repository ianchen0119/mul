# Quick Start Guide

Get started with the eBPF packet duplication system in 5 minutes.

## Prerequisites

- Linux kernel 5.10+
- Docker installed
- Root/sudo access

## 1. Build the System

```bash
make
```

This compiles both the eBPF program and Go loader.

## 2. Start Test Environment

```bash
./scripts/setup.sh
```

This starts Docker containers for testing.

## 3. Find Network Interfaces

```bash
# Quick helper to show all interfaces
docker exec sender ip link show eth0
# Note the peer interface index (the number after @if)

# Find the host interface name
ip link | grep "^<index>:"
```

## 4. Load eBPF Program

Replace `vethXXX` with your actual interface names:

```bash
sudo ./loader -iface veth_sender -targets veth_rcv1,veth_rcv2,veth_rcv3
```

## 5. Test Packet Duplication

In a new terminal:

```bash
# Send test packets
docker exec sender ping -c 5 172.25.0.3

# Check statistics
sudo ./loader -stats
```

## 6. Cleanup

```bash
# Stop the loader (Ctrl+C)
# Then cleanup containers
./scripts/cleanup.sh
```

## Troubleshooting

**"Permission denied"** → Run with `sudo`

**"Interface not found"** → Verify interface names with `ip link`

**"Failed to load eBPF"** → Check kernel version with `uname -r`

## Full Documentation

See [docs/guide.md](docs/guide.md) for detailed instructions.
