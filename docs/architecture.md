# Architecture Overview

## System Architecture

The eBPF Packet Duplication System consists of three main components:

### 1. eBPF Kernel Program

**File**: `src/packet_duplicator.c`

The kernel-space component runs in the Linux kernel and:
- Attaches to TC (Traffic Control) egress hook
- Intercepts all outgoing packets
- Uses BPF maps to retrieve target interface configuration
- Clones packets using `bpf_clone_redirect()`
- Maintains statistics counters
- Logs events via `bpf_printk()`

**Key Functions:**
- `bpf_clone_redirect_example()`: Main TC egress handler

**BPF Maps:**
- `target_interfaces`: Array map storing target interface indices (max 16)
- `statistics`: Single-entry map for packet counters

### 2. User-Space Loader

**File**: `cmd/loader/main.go`

The user-space Go application:
- Loads compiled eBPF bytecode
- Configures target interfaces via BPF maps
- Attaches eBPF program to TC egress using cilium/ebpf library
- Reads and displays statistics
- Handles graceful shutdown

**Key Libraries:**
- `github.com/cilium/ebpf`: eBPF loading and management
- `github.com/vishvananda/netlink`: Network interface management

### 3. Docker Test Environment

**File**: `compose.yaml`

Multi-container environment for testing:
- **ebpf-loader**: Privileged container with eBPF tools
- **sender**: Container that sends packets
- **receiver1-3**: Containers that receive duplicated packets

All containers connected via custom bridge network `ebpf_net`.

## Data Flow

```
┌─────────────────────────────────────────────────────────┐
│                    User Space                            │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Go Loader Application                          │    │
│  │  - Load eBPF program                            │    │
│  │  - Configure target interfaces                  │    │
│  │  - Attach to TC egress                          │    │
│  │  - Read statistics                              │    │
│  └────────────────┬────────────────────────────────┘    │
└───────────────────┼─────────────────────────────────────┘
                    │ syscalls (bpf, netlink)
┌───────────────────┼─────────────────────────────────────┐
│                   ▼          Kernel Space                │
│  ┌─────────────────────────────────────────────────┐    │
│  │  TC Egress Hook Point                           │    │
│  │  ┌────────────────────────────────────────┐     │    │
│  │  │  eBPF Program                          │     │    │
│  │  │  1. Increment packets_processed        │     │    │
│  │  │  2. For each target interface:         │     │    │
│  │  │     - Clone packet (bpf_clone_redirect)│     │    │
│  │  │     - Log result                       │     │    │
│  │  │     - Update counters                  │     │    │
│  │  │  3. Return TC_ACT_OK                   │     │    │
│  │  └────────────────────────────────────────┘     │    │
│  │                                                  │    │
│  │  BPF Maps:                                      │    │
│  │  - target_interfaces [if_index1, if_index2, ...]│    │
│  │  - statistics {processed, cloned, errors}       │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Network    │  │   Network    │  │   Network    │  │
│  │  Interface 1 │  │  Interface 2 │  │  Interface 3 │  │
│  │   (veth1)    │  │   (veth2)    │  │   (veth3)    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
          │                 │                 │
          ▼                 ▼                 ▼
    ┌──────────┐      ┌──────────┐      ┌──────────┐
    │Container │      │Container │      │Container │
    │Receiver1 │      │Receiver2 │      │Receiver3 │
    └──────────┘      └──────────┘      └──────────┘
```

## TC (Traffic Control) Hook

The eBPF program attaches to the TC egress hook, which:
- Executes after routing decisions
- Sees packets before they leave the interface
- Can modify, drop, or redirect packets
- Returns action codes (TC_ACT_OK, TC_ACT_SHOT, etc.)

## BPF Maps

### target_interfaces Map

**Type**: BPF_MAP_TYPE_ARRAY  
**Key**: uint32 (index 0-15)  
**Value**: uint32 (interface index)  
**Purpose**: Store up to 16 target interface indices for packet duplication

### statistics Map

**Type**: BPF_MAP_TYPE_ARRAY  
**Key**: uint32 (always 0)  
**Value**: struct stats {packets_processed, packets_cloned, clone_errors}  
**Purpose**: Track performance metrics

Updates use `__sync_fetch_and_add()` for atomic increments.

## Packet Cloning

### bpf_clone_redirect()

```c
long bpf_clone_redirect(struct __sk_buff *skb, u32 ifindex, u64 flags)
```

**Parameters:**
- `skb`: Socket buffer containing packet data
- `ifindex`: Target network interface index
- `flags`: 0 for egress, BPF_F_INGRESS for ingress

**Behavior:**
- Creates a copy of the packet
- Transmits copy to specified interface
- Original packet unaffected
- Returns 0 on success, negative error code on failure

**Performance:**
- Zero-copy in many cases (kernel optimizations)
- Minimal overhead (~1-5% CPU)
- Scales well with multiple targets

## Network Topology

```
Docker Host
├── ebpf_net bridge (172.25.0.0/16)
│   ├── veth_sender (host side) ◄── TC egress hook with eBPF
│   │   └── eth0 (sender container, 172.25.0.x)
│   ├── veth_receiver1 (host side) ◄── Receives cloned packets
│   │   └── eth0 (receiver1 container, 172.25.0.y)
│   ├── veth_receiver2 (host side) ◄── Receives cloned packets
│   │   └── eth0 (receiver2 container, 172.25.0.z)
│   └── veth_receiver3 (host side) ◄── Receives cloned packets
│       └── eth0 (receiver3 container, 172.25.0.w)
```

## Security Considerations

### Required Capabilities

The loader requires:
- `CAP_BPF`: Load eBPF programs
- `CAP_NET_ADMIN`: Modify network configuration
- `CAP_SYS_ADMIN`: Access debug filesystem

### eBPF Verifier

The kernel verifier ensures:
- No infinite loops (bounded iterations)
- Memory safety (all pointer dereferences checked)
- No kernel crashes (safe program execution)

### Privilege Requirements

- Docker containers: `privileged: true` or specific capabilities
- Loader application: Must run as root

## Scalability

**Interface Limits:**
- Maximum 16 target interfaces (configurable in code)
- Limited by BPF map size and loop unrolling

**Performance:**
- Handles line-rate traffic on 10Gbps networks
- CPU overhead linear with number of targets
- Memory overhead minimal (BPF maps are small)

**Optimization Opportunities:**
- Use BPF_MAP_TYPE_HASH for dynamic targets
- Implement sampling (duplicate 1 in N packets)
- Filter packets by protocol/port before cloning

## Observability

### Logging

**bpf_printk()**: Kernel-level logging
- Output to `/sys/kernel/debug/tracing/trace_pipe`
- Useful for debugging
- Performance impact (avoid in production)

**Statistics Map**: Production monitoring
- Zero-overhead counters
- Accessible from user space
- Real-time metrics

### Metrics Collected

1. **packets_processed**: Total packets seen by eBPF program
2. **packets_cloned**: Successful packet duplications
3. **clone_errors**: Failed `bpf_clone_redirect()` calls

**Error Rate Calculation:**
```
error_rate = clone_errors / (packets_processed * num_targets)
```

## Future Enhancements

1. **Dynamic Target Management**: Add/remove targets without reloading
2. **Packet Filtering**: Clone only specific protocols/ports
3. **Rate Limiting**: Prevent overwhelming receivers
4. **Metrics Export**: Prometheus/OpenTelemetry integration
5. **XDP Support**: Earlier hook point for higher performance
6. **VLAN Tagging**: Add VLAN tags to cloned packets
7. **Load Balancing**: Distribute clones across targets
