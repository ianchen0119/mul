#!/bin/bash
# Test script for eBPF packet duplication

set -e

echo "=== eBPF Packet Duplication Test ==="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get container network interfaces
echo -e "${YELLOW}Getting network interface information...${NC}"

SENDER_IFACE=$(docker exec sender ip link show eth0 | grep -oP '(?<=eth0@if)\d+')
RECEIVER1_IFACE=$(docker exec receiver1 ip link show eth0 | grep -oP '(?<=eth0@if)\d+')
RECEIVER2_IFACE=$(docker exec receiver2 ip link show eth0 | grep -oP '(?<=eth0@if)\d+')
RECEIVER3_IFACE=$(docker exec receiver3 ip link show eth0 | grep -oP '(?<=eth0@if)\d+')

echo "Sender interface index: $SENDER_IFACE"
echo "Receiver1 interface index: $RECEIVER1_IFACE"
echo "Receiver2 interface index: $RECEIVER2_IFACE"
echo "Receiver3 interface index: $RECEIVER3_IFACE"

# Get interface names on host for these indices
SENDER_VETH=$(ip link | grep "^${SENDER_IFACE}:" | awk '{print $2}' | sed 's/:.*$//' | sed 's/@.*$//')
RECEIVER1_VETH=$(ip link | grep "^${RECEIVER1_IFACE}:" | awk '{print $2}' | sed 's/:.*$//' | sed 's/@.*$//')
RECEIVER2_VETH=$(ip link | grep "^${RECEIVER2_IFACE}:" | awk '{print $2}' | sed 's/:.*$//' | sed 's/@.*$//')
RECEIVER3_VETH=$(ip link | grep "^${RECEIVER3_IFACE}:" | awk '{print $2}' | sed 's/:.*$//' | sed 's/@.*$//')

echo -e "${YELLOW}Host veth interfaces:${NC}"
echo "Sender: $SENDER_VETH"
echo "Receiver1: $RECEIVER1_VETH"
echo "Receiver2: $RECEIVER2_VETH"
echo "Receiver3: $RECEIVER3_VETH"

# Start packet capture on receivers
echo -e "${YELLOW}Starting packet capture on receivers...${NC}"
docker exec -d receiver1 tcpdump -i eth0 -n -l icmp > /tmp/receiver1.log 2>&1 &
docker exec -d receiver2 tcpdump -i eth0 -n -l icmp > /tmp/receiver2.log 2>&1 &
docker exec -d receiver3 tcpdump -i eth0 -n -l icmp > /tmp/receiver3.log 2>&1 &

sleep 2

# Send test packets from sender
echo -e "${YELLOW}Sending test packets...${NC}"
RECEIVER1_IP=$(docker exec receiver1 hostname -i)
echo "Pinging $RECEIVER1_IP from sender..."
docker exec sender ping -c 5 $RECEIVER1_IP

echo ""
echo -e "${GREEN}=== Test Complete ===${NC}"
echo "Check logs to verify packet duplication"
echo "Note: For actual eBPF packet duplication to work, the loader must be running"
echo "Run './loader -iface $SENDER_VETH -targets $RECEIVER1_VETH,$RECEIVER2_VETH,$RECEIVER3_VETH' to attach the eBPF program"
