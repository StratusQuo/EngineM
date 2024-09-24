// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ Apple Silicon Assembly Instructions                           ║  
// ╚═══════════════════════════════════════════════════════════════════╝

#ifdef __aarch64__

// Count Leading Zeros for 64-bit input (ARM64)
int apple_clz(unsigned long long x) {
    unsigned long long result;
    __asm__ volatile (
        "clz %0, %1"
        : "=r" (result)
        : "r" (x)
    );
    return result;
}

// Count Trailing Zeros for 64-bit input (ARM64)
int apple_ctz(unsigned long long x) {
    unsigned long long result;
    __asm__ volatile (
        "rbit %0, %1\n\t"
        "clz %0, %0"
        : "=r" (result)
        : "r" (x)
    );
    return result;
}

// Reverse Bits for 64-bit input (ARM64)
int apple_rbit(unsigned long long x) {
    unsigned long long result;
    __asm__ volatile (
        "rbit %0, %1"
        : "=r" (result)
        : "r" (x)
    );
    return result;
}

#else

// Fallback implementations for non-Apple Silicon architectures
int apple_clz(unsigned long long x) {
    if (x == 0) return 64;
    int n = 0;
    if (x <= 0x00000000FFFFFFFF) { n += 32; x <<= 32; }
    if (x <= 0x0000FFFFFFFFFFFF) { n += 16; x <<= 16; }
    if (x <= 0x00FFFFFFFFFFFFFF) { n += 8;  x <<= 8;  }
    if (x <= 0x0FFFFFFFFFFFFFFF) { n += 4;  x <<= 4;  }
    if (x <= 0x3FFFFFFFFFFFFFFF) { n += 2;  x <<= 2;  }
    if (x <= 0x7FFFFFFFFFFFFFFF) { n += 1;  x <<= 1;  }
    return n;
}

int apple_ctz(unsigned long long x) {
    if (x == 0) return 64;
    int n = 63;
    if (x & 0x00000000FFFFFFFF) { n -= 32; x >>= 32; }
    if (x & 0x000000000000FFFF) { n -= 16; x >>= 16; }
    if (x & 0x00000000000000FF) { n -= 8;  x >>= 8;  }
    if (x & 0x000000000000000F) { n -= 4;  x >>= 4;  }
    if (x & 0x0000000000000003) { n -= 2;  x >>= 2;  }
    if (x & 0x0000000000000001) { n -= 1; }
    return n;
}

int apple_rbit(unsigned long long x) {
    unsigned long long result = 0;
    for (int i = 0; i < 64; i++) {
        result = (result << 1) | (x & 1);
        x >>= 1;
    }
    return result;
}

#endif


