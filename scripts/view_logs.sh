#!/bin/bash
# Script to view eBPF trace logs

echo "=== eBPF Trace Logs ==="
echo "Monitoring /sys/kernel/debug/tracing/trace_pipe"
echo "Press Ctrl+C to stop"
echo ""

if [ ! -r /sys/kernel/debug/tracing/trace_pipe ]; then
    echo "Error: Cannot read trace_pipe. Make sure you have root privileges."
    echo "Try: sudo $0"
    exit 1
fi

sudo cat /sys/kernel/debug/tracing/trace_pipe
