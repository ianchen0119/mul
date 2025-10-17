// SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause
/* eBPF program for packet duplication using bpf_clone_redirect */

#include <linux/bpf.h>
#include <linux/pkt_cls.h>

/* BPF helper function declarations */
static void *(*bpf_map_lookup_elem)(void *map, const void *key) = (void *) 1;
static long (*bpf_clone_redirect)(void *skb, __u32 ifindex, __u64 flags) = (void *) 36;
static long (*bpf_trace_printk)(const char *fmt, __u32 fmt_size, ...) = (void *) 6;

/* Helper macros */
#define SEC(NAME) __attribute__((section(NAME), used))
#define __uint(name, val) int (*name)[val]
#define __type(name, val) typeof(val) *name

/* bpf_printk helper */
#define bpf_printk(fmt, ...)                       \
({                                                  \
    char ____fmt[] = fmt;                          \
    bpf_trace_printk(____fmt, sizeof(____fmt),     \
                     ##__VA_ARGS__);               \
})

/* Atomic operations */
#define __sync_fetch_and_add(ptr, val) __sync_fetch_and_add(ptr, val)

/* Map to store target interface indices for packet duplication */
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 16);
    __type(key, __u32);
    __type(value, __u32);
} target_interfaces SEC(".maps");

/* Map to store statistics */
struct stats {
    __u64 packets_processed;
    __u64 packets_cloned;
    __u64 clone_errors;
};

struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct stats);
} statistics SEC(".maps");

SEC("tc/egress")
int bpf_clone_redirect_example(struct __sk_buff *skb)
{
    __u32 key = 0;
    struct stats *stat;
    
    /* Get statistics map */
    stat = bpf_map_lookup_elem(&statistics, &key);
    if (!stat)
        return TC_ACT_OK;
    
    /* Increment packets processed counter */
    __sync_fetch_and_add(&stat->packets_processed, 1);
    
    /* Iterate through target interfaces and clone packets */
    #pragma unroll
    for (__u32 i = 0; i < 16; i++) {
        __u32 *ifindex = bpf_map_lookup_elem(&target_interfaces, &i);
        
        if (!ifindex || *ifindex == 0)
            continue;
            
        /* Clone and redirect packet to target interface */
        int ret = bpf_clone_redirect(skb, *ifindex, 0);
        
        if (ret < 0) {
            bpf_printk("bpf_clone_redirect error: ifindex=%u, ret=%d\n", 
                      *ifindex, ret);
            __sync_fetch_and_add(&stat->clone_errors, 1);
        } else {
            __sync_fetch_and_add(&stat->packets_cloned, 1);
            bpf_printk("Packet cloned to interface %u\n", *ifindex);
        }
    }
    
    /* Return TC_ACT_OK to allow original packet to continue */
    return TC_ACT_OK;
}

char LICENSE[] SEC("license") = "Dual BSD/GPL";
