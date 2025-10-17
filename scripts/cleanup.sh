#!/bin/bash
# Cleanup script for eBPF packet duplication environment

echo "=== Cleaning up eBPF Packet Duplication Environment ==="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Stopping and removing containers...${NC}"
docker-compose down

echo -e "${YELLOW}Cleaning build artifacts...${NC}"
rm -f src/*.o
rm -f loader
rm -f cmd/loader/loader

echo -e "${YELLOW}Cleaning temporary files...${NC}"
rm -f /tmp/receiver*.log

echo -e "${GREEN}✓ Cleanup complete!${NC}"
