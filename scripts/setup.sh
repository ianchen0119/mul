#!/bin/bash
# Setup script for eBPF packet duplication environment

set -e

echo "=== eBPF Packet Duplication Setup ==="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Building eBPF program...${NC}"
cd src
make clean
make
cd ..

echo -e "${GREEN}✓ eBPF program built successfully${NC}"

echo -e "${YELLOW}Step 2: Building Go application...${NC}"
cd cmd/loader
go build -o ../../loader
cd ../..

echo -e "${GREEN}✓ Go application built successfully${NC}"

echo -e "${YELLOW}Step 3: Starting Docker containers...${NC}"
docker-compose up -d

echo -e "${GREEN}✓ Docker containers started${NC}"

echo -e "${YELLOW}Step 4: Waiting for containers to be ready...${NC}"
sleep 5

echo -e "${GREEN}✓ Environment setup complete!${NC}"

echo ""
echo "Container Status:"
docker-compose ps

echo ""
echo "Network Information:"
docker network inspect ebpf_net --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}'

echo ""
echo "=== Setup Complete ==="
echo "To run the packet duplication test, execute: ./scripts/test.sh"
echo "To view logs, execute: ./scripts/view_logs.sh"
echo "To cleanup, execute: ./scripts/cleanup.sh"
