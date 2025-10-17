# Examples

This directory contains example configurations and use cases for the eBPF packet duplication system.

## Basic Examples

### 1. Simple Two-Container Setup

Minimal setup with one sender and one receiver:

```yaml
# compose-simple.yaml
version: '3.8'
services:
  sender:
    image: nicolaka/netshoot:latest
    container_name: sender
    networks:
      - test_net
    command: sleep infinity
    
  receiver:
    image: nicolaka/netshoot:latest
    container_name: receiver
    networks:
      - test_net
    command: sleep infinity

networks:
  test_net:
    driver: bridge
```

**Usage:**
```bash
docker-compose -f examples/compose-simple.yaml up -d
# Find interfaces
# Load eBPF: sudo ./loader -iface <sender_veth> -targets <receiver_veth>
```

### 2. Advanced Multi-Receiver Setup

Production-like setup with multiple receivers and monitoring:

See `compose-advanced.yaml` for configuration.

### 3. Custom Network Configuration

Using specific subnets and MTU settings:

See `compose-custom-network.yaml`.

## Use Cases

### Network Traffic Monitoring

Duplicate all traffic from a production container to a monitoring container:

```bash
# Attach to production container's veth
sudo ./loader -iface veth_prod -targets veth_monitor

# Monitor traffic
docker exec monitor tcpdump -i eth0 -w /tmp/capture.pcap
```

### Load Testing

Send the same traffic to multiple backend servers:

```bash
# Duplicate to 3 backend instances
sudo ./loader -iface veth_client -targets veth_be1,veth_be2,veth_be3
```

### Security Analysis

Clone traffic to IDS/IPS containers:

```bash
# Send to security scanners
sudo ./loader -iface veth_app -targets veth_ids,veth_ips,veth_siem
```

## Performance Testing

See `performance-test.sh` for automated performance benchmarks.

## Troubleshooting Examples

See individual example files for specific troubleshooting scenarios.
