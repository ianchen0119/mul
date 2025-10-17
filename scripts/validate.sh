#!/bin/bash
# Validation script to check system requirements

echo "=== eBPF Packet Duplication System - Environment Check ==="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Track overall status
ALL_OK=true

# Check kernel version
echo -n "Checking kernel version... "
KERNEL_VERSION=$(uname -r | cut -d. -f1,2)
KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d. -f1)
KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d. -f2)

if [ "$KERNEL_MAJOR" -gt 5 ] || ([ "$KERNEL_MAJOR" -eq 5 ] && [ "$KERNEL_MINOR" -ge 10 ]); then
    echo -e "${GREEN}✓${NC} $(uname -r)"
else
    echo -e "${RED}✗${NC} $(uname -r) (need >= 5.10)"
    ALL_OK=false
fi

# Check for clang
echo -n "Checking for clang... "
if command -v clang &> /dev/null; then
    CLANG_VERSION=$(clang --version | head -1)
    echo -e "${GREEN}✓${NC} $CLANG_VERSION"
else
    echo -e "${RED}✗${NC} not found"
    ALL_OK=false
fi

# Check for Go
echo -n "Checking for Go... "
if command -v go &> /dev/null; then
    GO_VERSION=$(go version)
    echo -e "${GREEN}✓${NC} $GO_VERSION"
else
    echo -e "${RED}✗${NC} not found"
    ALL_OK=false
fi

# Check for Docker
echo -n "Checking for Docker... "
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✓${NC} $DOCKER_VERSION"
else
    echo -e "${RED}✗${NC} not found"
    ALL_OK=false
fi

# Check for Docker Compose (v2 is built into docker)
echo -n "Checking for Docker Compose... "
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    echo -e "${GREEN}✓${NC} $COMPOSE_VERSION"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    echo -e "${GREEN}✓${NC} $COMPOSE_VERSION"
else
    echo -e "${RED}✗${NC} not found"
    ALL_OK=false
fi

# Check for BPF support
echo -n "Checking BPF support... "
if [ -f /proc/config.gz ]; then
    if zgrep -q "CONFIG_BPF=y" /proc/config.gz 2>/dev/null; then
        echo -e "${GREEN}✓${NC} enabled"
    else
        echo -e "${RED}✗${NC} not enabled"
        ALL_OK=false
    fi
elif [ -f /boot/config-$(uname -r) ]; then
    if grep -q "CONFIG_BPF=y" /boot/config-$(uname -r) 2>/dev/null; then
        echo -e "${GREEN}✓${NC} enabled"
    else
        echo -e "${RED}✗${NC} not enabled"
        ALL_OK=false
    fi
else
    echo -e "${YELLOW}?${NC} cannot verify (config file not found)"
fi

# Check if running as root (for loading eBPF)
echo -n "Checking privileges... "
if [ "$EUID" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} running as root"
else
    echo -e "${YELLOW}!${NC} not running as root (sudo required for loading eBPF)"
fi

# Check if debugfs is mounted (for bpf_printk)
echo -n "Checking debugfs... "
if mount | grep -q debugfs; then
    echo -e "${GREEN}✓${NC} mounted"
else
    echo -e "${YELLOW}!${NC} not mounted (needed for bpf_printk logs)"
fi

echo ""
echo "=== Summary ==="
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}✓ All requirements met!${NC}"
    echo "You can proceed with building and running the system."
    exit 0
else
    echo -e "${RED}✗ Some requirements are missing.${NC}"
    echo "Please install missing components before proceeding."
    echo ""
    echo "Installation hints:"
    echo "  Ubuntu/Debian: sudo apt install clang golang docker.io"
    exit 1
fi
