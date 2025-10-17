# Step-by-Step User Guide

## Introduction

This guide walks you through setting up, running, and validating the eBPF packet duplication system from scratch.

## Prerequisites

Before starting, ensure you have:

- **Operating System**: Linux (Ubuntu 20.04+ or similar)
- **Kernel Version**: Linux kernel 5.10 or later
  ```bash
  uname -r  # Check your kernel version
  ```
- **Packages**:
  - Docker and Docker Compose
  - Clang/LLVM (version 10+)
  - Go (version 1.19+)
  - Git
  
### Installing Prerequisites

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y \
    clang llvm \
    libbpf-dev \
    linux-headers-$(uname -r) \
    build-essential \
    golang \
    docker.io \
    docker-compose \
    iproute2 \
    tcpdump
```

**Verify Installation:**
```bash
clang --version     # Should show 10.0.0 or later
go version          # Should show 1.19 or later
docker --version    # Should show Docker installed
```

## Step 1: Clone the Repository

```bash
git clone https://github.com/ianchen0119/mul.git
cd mul
```

## Step 2: Build the eBPF Program

The eBPF program is written in C and must be compiled to BPF bytecode.

```bash
cd src
make
```

**Expected Output:**
```
clang -g -O2 -target bpf -D__TARGET_ARCH_x86 -I/usr/include/x86_64-linux-gnu -c packet_duplicator.c -o packet_duplicator.o
llvm-strip -g packet_duplicator.o
```

**Verify:**
```bash
ls -lh packet_duplicator.o
file packet_duplicator.o
```

You should see a file around 4-8KB in size, identified as ELF 64-bit LSB relocatable.

## Step 3: Build the Go Loader

```bash
cd ../cmd/loader
go build -o ../../loader
```

**Expected Output:**
```
go: downloading dependencies...
```

**Verify:**
```bash
cd ../..
./loader -h
```

If no help is shown, that's expected - the program requires arguments.

## Step 4: Set Up Docker Environment

### Start the Containers

```bash
./scripts/setup.sh
```

**Expected Output:**
```
=== eBPF Packet Duplication Setup ===
Step 1: Building eBPF program...
✓ eBPF program built successfully
Step 2: Building Go application...
✓ Go application built successfully
Step 3: Starting Docker containers...
✓ Docker containers started
Step 4: Waiting for containers to be ready...
✓ Environment setup complete!
```

### Verify Containers

```bash
docker ps
```

You should see 5 containers running:
- ebpf-loader
- sender
- receiver1
- receiver2
- receiver3

### Inspect Network

```bash
docker network inspect ebpf_net
```

This shows the network configuration and IP addresses assigned to each container.

## Step 5: Find Network Interfaces

When packets leave a container, they go through a veth (virtual ethernet) pair. We need to find these interfaces on the host.

### Get Container Interface Indices

```bash
# Sender's peer interface index
docker exec sender ip link show eth0
```

Look for output like: `4: eth0@if5: ...`
- `4` is the interface index inside the container
- `5` is the peer interface index on the host

### Find Host Interface Names

```bash
# List all interfaces and find the ones matching the indices
ip link show | grep "^5:"
```

Example output: `5: veth1a2b3c4@if4: ...`

The interface name is `veth1a2b3c4`.

### Quick Script to Get All Interfaces

```bash
# Create a helper script
cat > /tmp/get_interfaces.sh << 'EOF'
#!/bin/bash
echo "=== Network Interface Mapping ==="
for container in sender receiver1 receiver2 receiver3; do
    idx=$(docker exec $container ip link show eth0 | grep -oP '(?<=eth0@if)\d+')
    name=$(ip link | grep "^${idx}:" | awk '{print $2}' | sed 's/:$//' | sed 's/@.*//')
    ip=$(docker exec $container hostname -i)
    echo "$container: $name (index: $idx, IP: $ip)"
done
EOF

chmod +x /tmp/get_interfaces.sh
/tmp/get_interfaces.sh
```

**Example Output:**
```
=== Network Interface Mapping ===
sender: veth1a2b3c4 (index: 5, IP: 172.25.0.2)
receiver1: veth5d6e7f8 (index: 7, IP: 172.25.0.3)
receiver2: veth9g0h1i2 (index: 9, IP: 172.25.0.4)
receiver3: vethj3k4l5m (index: 11, IP: 172.25.0.5)
```

## Step 6: Load the eBPF Program

Now we'll attach the eBPF program to the sender's egress path.

**Important**: Replace the interface names with the actual ones from Step 5.

```bash
sudo ./loader \
    -iface veth1a2b3c4 \
    -targets veth5d6e7f8,veth9g0h1i2,vethj3k4l5m
```

**Expected Output:**
```
2024/10/17 12:00:00 Configuring target interfaces: [veth5d6e7f8 veth9g0h1i2 vethj3k4l5m]
2024/10/17 12:00:00 Added target interface: veth5d6e7f8 (index: 7)
2024/10/17 12:00:00 Added target interface: veth9g0h1i2 (index: 9)
2024/10/17 12:00:00 Added target interface: vethj3k4l5m (index: 11)
2024/10/17 12:00:00 Attaching TC egress filter to interface veth1a2b3c4
2024/10/17 12:00:00 Successfully attached eBPF program to veth1a2b3c4 egress
2024/10/17 12:00:00 Press Ctrl+C to detach and exit
```

**Keep this terminal open** - the program will continue running and print statistics every 5 seconds.

## Step 7: Test Packet Duplication

Open a new terminal.

### Start Packet Capture on Receivers

```bash
# Terminal 2 - Receiver 1
docker exec receiver1 tcpdump -i eth0 -n icmp

# Terminal 3 - Receiver 2 (open another terminal)
docker exec receiver2 tcpdump -i eth0 -n icmp

# Terminal 4 - Receiver 3 (open another terminal)
docker exec receiver3 tcpdump -i eth0 -n icmp
```

### Send Test Packets

```bash
# Terminal 5 - In the sender container
docker exec -it sender bash

# Inside the container:
# Ping receiver1 (the original destination)
ping -c 5 172.25.0.3
```

### Observe the Results

You should see:
- **Sender**: Sends 5 ICMP echo requests to 172.25.0.3
- **Receiver1**: Receives the original packets (should reply)
- **Receiver2**: Receives cloned packets (may not reply, that's OK)
- **Receiver3**: Receives cloned packets (may not reply, that's OK)

**Example tcpdump output on receiver2:**
```
12:05:00.123456 IP 172.25.0.2 > 172.25.0.3: ICMP echo request, id 1, seq 1
12:05:01.234567 IP 172.25.0.2 > 172.25.0.3: ICMP echo request, id 1, seq 2
```

Note: The packets show sender→receiver1 IP addresses even on receiver2/3 because they are exact clones.

## Step 8: Monitor eBPF Logs

In a new terminal:

```bash
sudo ./scripts/view_logs.sh
```

You should see output like:
```
=== eBPF Trace Logs ===
Monitoring /sys/kernel/debug/tracing/trace_pipe
Press Ctrl+C to stop

<...>-12345 [000] .... 123.456789: 0: Packet cloned to interface 7
<...>-12345 [000] .... 123.456790: 0: Packet cloned to interface 9
<...>-12345 [000] .... 123.456791: 0: Packet cloned to interface 11
```

## Step 9: View Statistics

While the loader is running, open another terminal:

```bash
sudo ./loader -stats
```

**Expected Output:**
```
=== eBPF Packet Duplication Statistics ===
Packets Processed: 25
Packets Cloned:    75
Clone Errors:      0
==========================================
```

Interpretation:
- **Packets Processed**: Total packets intercepted (5 ICMP + ARP + other traffic)
- **Packets Cloned**: Should be ~3x packets processed (one clone per target)
- **Clone Errors**: Should be 0 or very low

## Step 10: Performance Testing

### Latency Test

```bash
docker exec sender ping -c 100 172.25.0.3 | tail -2
```

### Throughput Test

**Start iperf3 server:**
```bash
docker exec receiver1 iperf3 -s
```

**Run client:**
```bash
docker exec sender iperf3 -c 172.25.0.3 -t 10
```

Compare results with and without the eBPF program loaded.

## Step 11: Cleanup

When finished testing:

### Stop the Loader

Press Ctrl+C in the terminal running the loader.

**Expected Output:**
```
^C2024/10/17 12:10:00 Detaching eBPF program and cleaning up...
```

### Clean Up Environment

```bash
./scripts/cleanup.sh
```

**Expected Output:**
```
=== Cleaning up eBPF Packet Duplication Environment ===
Stopping and removing containers...
Cleaning build artifacts...
Cleaning temporary files...
✓ Cleanup complete!
```

## Troubleshooting

### Problem: eBPF program fails to load

**Error**: "Failed to load eBPF spec"

**Solutions:**
1. Check if BPF is enabled:
   ```bash
   zgrep CONFIG_BPF /proc/config.gz
   ```
2. Verify kernel version:
   ```bash
   uname -r  # Must be >= 5.10
   ```
3. Check file exists:
   ```bash
   ls -l src/packet_duplicator.o
   ```

### Problem: Permission denied

**Error**: "Permission denied" when running loader

**Solution:**
```bash
sudo ./loader ...  # Must run as root
```

### Problem: Interface not found

**Error**: "Failed to get interface"

**Solution:**
1. Verify containers are running:
   ```bash
   docker ps
   ```
2. Check interface names:
   ```bash
   ip link show
   ```
3. Use the helper script from Step 5 to get correct names

### Problem: No packets cloned

**Possible causes:**
1. **eBPF program not attached**: Check loader output for "Successfully attached"
2. **Wrong interface**: Verify you're using the sender's veth interface
3. **No traffic**: Generate traffic with ping or iperf3

**Debug steps:**
1. Check if TC hook exists:
   ```bash
   tc filter show dev <sender_veth> egress
   ```
2. View eBPF logs:
   ```bash
   sudo ./scripts/view_logs.sh
   ```
3. Check statistics:
   ```bash
   sudo ./loader -stats
   ```

### Problem: Clone errors > 0

**Causes:**
- Resource limits (buffer overflow)
- Invalid target interface
- Network namespace issues

**Solutions:**
1. Check kernel logs:
   ```bash
   dmesg | tail -20
   ```
2. Reduce target count
3. Increase network buffers:
   ```bash
   sudo sysctl -w net.core.rmem_max=134217728
   ```

## Advanced Usage

### Custom Network Configuration

Edit `compose.yaml` to customize:
```yaml
networks:
  ebpf_net:
    driver_opts:
      com.docker.network.driver.mtu: 9000  # Jumbo frames
    ipam:
      config:
        - subnet: 10.100.0.0/16  # Custom subnet
```

### Filtering Packets

Modify `src/packet_duplicator.c` to add filters:
```c
// Example: Clone only ICMP packets
if (skb->protocol != htons(ETH_P_IP))
    return TC_ACT_OK;

// Parse IP header and check protocol
// ... (add IP protocol check for ICMP)
```

### Monitoring in Production

Set up periodic statistics collection:
```bash
while true; do
    sudo ./loader -stats >> /var/log/ebpf-stats.log
    sleep 60
done
```

## Next Steps

- Read [architecture.md](architecture.md) for system design details
- Review [performance.md](performance.md) for optimization strategies
- Explore the source code in `src/` and `cmd/`
- Contribute improvements via pull requests

## Support

For issues or questions:
1. Check existing GitHub issues
2. Review the troubleshooting section above
3. Open a new issue with:
   - Kernel version (`uname -r`)
   - Error messages
   - Steps to reproduce
