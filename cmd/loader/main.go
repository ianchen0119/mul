package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/cilium/ebpf"
	"github.com/cilium/ebpf/link"
	"github.com/vishvananda/netlink"
)

type Stats struct {
	PacketsProcessed uint64
	PacketsCloned    uint64
	CloneErrors      uint64
}

func main() {
	var (
		ifaceName   string
		targetIfaces string
		showStats   bool
	)

	flag.StringVar(&ifaceName, "iface", "", "Network interface to attach TC egress hook")
	flag.StringVar(&targetIfaces, "targets", "", "Comma-separated list of target interfaces for packet duplication")
	flag.BoolVar(&showStats, "stats", false, "Show statistics and exit")
	flag.Parse()

	if ifaceName == "" && !showStats {
		log.Fatal("Please specify network interface with -iface flag")
	}

	// Load eBPF objects
	spec, err := ebpf.LoadCollectionSpec("src/packet_duplicator.o")
	if err != nil {
		log.Fatalf("Failed to load eBPF spec: %v", err)
	}

	coll, err := ebpf.NewCollection(spec)
	if err != nil {
		log.Fatalf("Failed to create eBPF collection: %v", err)
	}
	defer coll.Close()

	prog := coll.Programs["bpf_clone_redirect_example"]
	if prog == nil {
		log.Fatal("Program 'bpf_clone_redirect_example' not found in eBPF object")
	}

	targetMap := coll.Maps["target_interfaces"]
	statsMap := coll.Maps["statistics"]

	if showStats {
		printStats(statsMap)
		return
	}

	// Parse and populate target interfaces
	if targetIfaces != "" {
		if err := populateTargetInterfaces(targetMap, targetIfaces); err != nil {
			log.Fatalf("Failed to populate target interfaces: %v", err)
		}
	}

	// Get network interface
	iface, err := netlink.LinkByName(ifaceName)
	if err != nil {
		log.Fatalf("Failed to get interface %s: %v", ifaceName, err)
	}

	// Attach TC egress filter
	log.Printf("Attaching TC egress filter to interface %s", ifaceName)
	
	// Ensure qdisc exists
	attrs := netlink.QdiscAttrs{
		LinkIndex: iface.Attrs().Index,
		Handle:    netlink.MakeHandle(0xffff, 0),
		Parent:    netlink.HANDLE_CLSACT,
	}
	qdisc := &netlink.GenericQdisc{
		QdiscAttrs: attrs,
		QdiscType:  "clsact",
	}
	
	// Try to add qdisc (it's OK if it already exists)
	if err := netlink.QdiscAdd(qdisc); err != nil {
		log.Printf("Warning: failed to add clsact qdisc (may already exist): %v", err)
	}

	// Attach the eBPF program to TC egress
	l, err := link.AttachTCX(link.TCXOptions{
		Interface: iface.Attrs().Index,
		Program:   prog,
		Attach:    ebpf.AttachTCXEgress,
	})
	if err != nil {
		log.Fatalf("Failed to attach TC egress: %v", err)
	}
	defer l.Close()

	log.Printf("Successfully attached eBPF program to %s egress", ifaceName)
	log.Println("Press Ctrl+C to detach and exit")

	// Start statistics reporting goroutine
	go func() {
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()

		for range ticker.C {
			printStats(statsMap)
		}
	}()

	// Wait for interrupt signal
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	<-sig

	log.Println("Detaching eBPF program and cleaning up...")
}

func populateTargetInterfaces(targetMap *ebpf.Map, targetIfaces string) error {
	// Parse comma-separated interface names
	var ifaceNames []string
	current := ""
	for _, c := range targetIfaces {
		if c == ',' {
			if current != "" {
				ifaceNames = append(ifaceNames, current)
				current = ""
			}
		} else {
			current += string(c)
		}
	}
	if current != "" {
		ifaceNames = append(ifaceNames, current)
	}

	log.Printf("Configuring target interfaces: %v", ifaceNames)

	for i, name := range ifaceNames {
		if i >= 16 {
			log.Printf("Warning: Maximum 16 target interfaces supported, ignoring extra interfaces")
			break
		}

		iface, err := netlink.LinkByName(name)
		if err != nil {
			return fmt.Errorf("failed to get interface %s: %w", name, err)
		}

		key := uint32(i)
		value := uint32(iface.Attrs().Index)

		if err := targetMap.Put(&key, &value); err != nil {
			return fmt.Errorf("failed to update map for interface %s: %w", name, err)
		}

		log.Printf("Added target interface: %s (index: %d)", name, value)
	}

	return nil
}

func printStats(statsMap *ebpf.Map) error {
	var stats Stats
	key := uint32(0)

	if err := statsMap.Lookup(&key, &stats); err != nil {
		log.Printf("Failed to read statistics: %v", err)
		return err
	}

	fmt.Printf("\n=== eBPF Packet Duplication Statistics ===\n")
	fmt.Printf("Packets Processed: %d\n", stats.PacketsProcessed)
	fmt.Printf("Packets Cloned:    %d\n", stats.PacketsCloned)
	fmt.Printf("Clone Errors:      %d\n", stats.CloneErrors)
	fmt.Printf("==========================================\n\n")

	return nil
}
