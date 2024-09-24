// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ ARM Assembly Instructions                                     ║  
// ╚═══════════════════════════════════════════════════════════════════╝

#ifdef __arm__
// Count Leading Zeros for 32-bit input (ARM)
int arm_clz(unsigned int x) {
    unsigned int result;
    __asm__ volatile (
        "clz %0, %1"
        : "=r" (result)
        : "r" (x)
    );
    return result;
}
// Count Trailing Zeros for 32-bit input (ARM)
int arm_ctz(unsigned int x) {
    unsigned int result;
    __asm__ volatile (
        "rbit %0, %1\n\t"
        "clz %0, %0"
        : "=r" (result)
        : "r" (x)
    );
    return result;
}
// Reverse Bits for 32-bit input (ARM)
int arm_rbit(unsigned int x) {
    unsigned int result;
    __asm__ volatile (
        "rbit %0, %1"
        : "=r" (result)
        : "r" (x)
    );
    return result;
}
#else
// Fallback implementations for non-ARM architectures
int arm_clz(unsigned int x) {
    if (x == 0) return 32;
    int n = 0;
    if (x <= 0x0000FFFF) { n += 16; x <<= 16; }
    if (x <= 0x00FFFFFF) { n += 8;  x <<= 8;  }
    if (x <= 0x0FFFFFFF) { n += 4;  x <<= 4;  }
    if (x <= 0x3FFFFFFF) { n += 2;  x <<= 2;  }
    if (x <= 0x7FFFFFFF) { n += 1;  x <<= 1;  }
    return n;
}

int arm_ctz(unsigned int x) {
    if (x == 0) return 32;
    int n = 31;
    if (x & 0x0000FFFF) { n -= 16; x >>= 16; }
    if (x & 0x000000FF) { n -= 8;  x >>= 8;  }
    if (x & 0x0000000F) { n -= 4;  x >>= 4;  }
    if (x & 0x00000003) { n -= 2;  x >>= 2;  }
    if (x & 0x00000001) { n -= 1; }
    return n;
}

int arm_rbit(unsigned int x) {
    unsigned int result = 0;
    for (int i = 0; i < 32; i++) {
        result = (result << 1) | (x & 1);
        x >>= 1;
    }
    return result;
}

#endif
