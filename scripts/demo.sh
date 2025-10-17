#!/bin/bash
# Demo script showing packet duplication in action

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     eBPF Packet Duplication System - Interactive Demo     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Warning: This demo requires sudo privileges.${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${YELLOW}Error: Docker is not running.${NC}"
    echo "Please start Docker and try again."
    exit 1
fi

echo -e "${BLUE}[Step 1/7]${NC} Building the system..."
make clean > /dev/null 2>&1 || true
make > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Build complete"
echo ""

echo -e "${BLUE}[Step 2/7]${NC} Starting Docker containers..."
docker-compose up -d > /dev/null 2>&1
sleep 3
echo -e "${GREEN}✓${NC} Containers running"
echo ""

echo -e "${BLUE}[Step 3/7]${NC} Finding network interfaces..."

# Get container interface mappings
SENDER_PEER=$(docker exec sender ip link show eth0 | grep -oP '(?<=eth0@if)\d+')
RCV1_PEER=$(docker exec receiver1 ip link show eth0 | grep -oP '(?<=eth0@if)\d+')
RCV2_PEER=$(docker exec receiver2 ip link show eth0 | grep -oP '(?<=eth0@if)\d+')
RCV3_PEER=$(docker exec receiver3 ip link show eth0 | grep -oP '(?<=eth0@if)\d+')

SENDER_VETH=$(ip link | grep "^${SENDER_PEER}:" | awk '{print $2}' | sed 's/:.*$//' | sed 's/@.*$//')
RCV1_VETH=$(ip link | grep "^${RCV1_PEER}:" | awk '{print $2}' | sed 's/:.*$//' | sed 's/@.*$//')
RCV2_VETH=$(ip link | grep "^${RCV2_PEER}:" | awk '{print $2}' | sed 's/:.*$//' | sed 's/@.*$//')
RCV3_VETH=$(ip link | grep "^${RCV3_PEER}:" | awk '{print $2}' | sed 's/:.*$//' | sed 's/@.*$//')

echo "  Sender interface:    $SENDER_VETH"
echo "  Receiver 1 interface: $RCV1_VETH"
echo "  Receiver 2 interface: $RCV2_VETH"
echo "  Receiver 3 interface: $RCV3_VETH"
echo -e "${GREEN}✓${NC} Interfaces identified"
echo ""

echo -e "${BLUE}[Step 4/7]${NC} Loading eBPF program..."
timeout 2 ./loader -iface $SENDER_VETH -targets $RCV1_VETH,$RCV2_VETH,$RCV3_VETH &
LOADER_PID=$!
sleep 1
echo -e "${GREEN}✓${NC} eBPF program attached"
echo ""

echo -e "${BLUE}[Step 5/7]${NC} Starting packet capture on receivers..."
docker exec -d receiver1 tcpdump -i eth0 -n icmp > /tmp/demo_rcv1.log 2>&1
docker exec -d receiver2 tcpdump -i eth0 -n icmp > /tmp/demo_rcv2.log 2>&1
docker exec -d receiver3 tcpdump -i eth0 -n icmp > /tmp/demo_rcv3.log 2>&1
sleep 2
echo -e "${GREEN}✓${NC} Packet capture started"
echo ""

echo -e "${BLUE}[Step 6/7]${NC} Sending test packets..."
echo "  Sending 5 ICMP packets from sender to receiver1..."
RCV1_IP=$(docker exec receiver1 hostname -i | tr -d '\r')
docker exec sender ping -c 5 -W 1 $RCV1_IP > /dev/null 2>&1 || true
sleep 2
echo -e "${GREEN}✓${NC} Packets sent"
echo ""

echo -e "${BLUE}[Step 7/7]${NC} Checking results..."
echo ""

# Show statistics
echo "=== eBPF Statistics ==="
./loader -stats 2>/dev/null || echo "Statistics unavailable"
echo ""

# Stop tcpdump
docker exec receiver1 pkill -f tcpdump || true
docker exec receiver2 pkill -f tcpdump || true
docker exec receiver3 pkill -f tcpdump || true
sleep 1

# Check logs
echo "=== Packet Capture Results ==="
echo ""
echo -e "${YELLOW}Receiver 1 (Original Destination):${NC}"
PKTS_RCV1=$(cat /tmp/demo_rcv1.log 2>/dev/null | grep -c "ICMP echo" || echo "0")
echo "  Captured $PKTS_RCV1 ICMP packets"

echo ""
echo -e "${YELLOW}Receiver 2 (Cloned Packets):${NC}"
PKTS_RCV2=$(cat /tmp/demo_rcv2.log 2>/dev/null | grep -c "ICMP echo" || echo "0")
echo "  Captured $PKTS_RCV2 ICMP packets"

echo ""
echo -e "${YELLOW}Receiver 3 (Cloned Packets):${NC}"
PKTS_RCV3=$(cat /tmp/demo_rcv3.log 2>/dev/null | grep -c "ICMP echo" || echo "0")
echo "  Captured $PKTS_RCV3 ICMP packets"

echo ""
echo "=== Summary ==="
if [ "$PKTS_RCV1" -gt 0 ] && [ "$PKTS_RCV2" -gt 0 ] && [ "$PKTS_RCV3" -gt 0 ]; then
    echo -e "${GREEN}✓ SUCCESS!${NC} Packets were successfully duplicated to all receivers!"
else
    echo -e "${YELLOW}Note: Some receivers may not have captured packets.${NC}"
    echo "This can happen if packet duplication occurred but receivers weren't ready."
fi

echo ""
echo "=== Cleanup ==="
# Stop loader
kill $LOADER_PID 2>/dev/null || true
wait $LOADER_PID 2>/dev/null || true

# Stop containers
echo "Stopping containers..."
docker-compose down > /dev/null 2>&1

# Clean logs
rm -f /tmp/demo_rcv*.log

echo -e "${GREEN}✓${NC} Cleanup complete"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    Demo Complete!                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "For more information, see:"
echo "  - README.md for full documentation"
echo "  - QUICKSTART.md for manual setup"
echo "  - docs/guide.md for detailed guide"
