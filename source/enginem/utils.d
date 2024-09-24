// utils.d
module enginem.utils;

import numem.core;

import std.conv;
import std.stdio;
import std.exception;
import std.experimental.allocator; 

import core.sync.mutex;
import core.bitop;
import core.stdc.stdlib : malloc, free;
import core.stdc.string;

import enginem.errors;
import enginem.sync.SpinLock;
import enginem.allocators.Allocator;
import enginem.allocators.RegionAllocator;
import enginem.allocators.smallobject.FreeListAllocator;

/// Re-exporting Essential Functions from std.experimental.allocator
public import std.experimental.allocator :
    make, dispose, makeArray, expandArray, shrinkArray,
    theAllocator, processAllocator;

/// Re-exporting Numem's core allocation functions
public import numem.core:
    nogc_new, nogc_delete, nogc_construct;

/// Declare C Functions fir CLZ, CTZ, and RBIT:

extern(C) @nogc int __builtin_clz(int);
extern(C) @nogc int __builtin_ctz(int);
extern(C) @nogc int __builtin_clzl(long);
extern(C) @nogc int __builtin_ctzl(long);

extern(C) int apple_clz(ulong x);    // Count Leading Zeros (Apple Silicon)
extern(C) int apple_ctz(ulong x);    // Count Trailing Zeros (Apple Silicon)
extern(C) int apple_rbit(ulong x);   // Reverse Bits (Apple Silicon)

extern(C) int arm_clz(uint x);    // Count Leading Zeros (ARM)
extern(C) int arm_ctz(uint x);    // Count Trailing Zeros (ARM)
extern(C) int arm_rbit(uint x);   // Reverse Bits (ARM)


//==================================================
// Machine Instructions
//==================================================

//  | ╭─────────────────────────────────────────────╮
//  | │ ⇩ CTLZ                                      │
//  | ╰─────────────────────────────────────────────╯
//  |  Cross-platform ctlz implementation

size_t ctlz(size_t x) @nogc nothrow @trusted {
    version(X86) {
        return ctlzX86(x);
    }
    version(X86_64) {
        return ctlzX86_64(x);
    }
    version(ARM) {
        return arm_clz(cast(uint)x);
    }
    version(AArch64) {
        return apple_clz(cast(ulong)x);
    }
    else {
        // Fallback to C library for unknown architectures
        return ctlzFallback(x);
    }
}

// X86 inline assembly
size_t ctlzX86(size_t x) @nogc nothrow @trusted {
    asm @nogc pure nothrow {
        bsr EAX, x;  // Bit scan reverse
        mov x, EAX;
        xor EAX, 31;
    }
    return x;
}

// X86_64 inline assembly
size_t ctlzX86_64(size_t x) @nogc nothrow @trusted {
    asm @nogc pure nothrow {
        bsr RAX, x;  // Bit scan reverse
        mov x, RAX;
        xor RAX, 63;
    }
    return x;
}

// Fallback to C Library for ctlz if no specific architecture is matched
// size_t ctlzFallback(size_t x) pure nothrow @trusted {
//     static if (size_t.sizeof == 4) {
//         return __builtin_clz(cast(int)x);  // 32-bit size_t
//     } else static if (size_t.sizeof == 8) {
//         return __builtin_clzl(cast(long)x);  // 64-bit size_t
//     }
//     return 0;
// }
size_t ctlzFallback(size_t x) @nogc @trusted {
    static if (size_t.sizeof == 4) {
        return __builtin_clz(cast(int)x);  // 32-bit size_t
    } else static if (size_t.sizeof == 8) {
        return __builtin_clzl(cast(long)x);  // 64-bit size_t
    }
    return 0;
}

//  | ╭─────────────────────────────────────────────╮
//  | │ ⇩ CTZ                                       │
//  | ╰─────────────────────────────────────────────╯
//  |  Cross-platform ctz implementation

size_t ctz(size_t x) @nogc nothrow @trusted {
    version(X86) {
        return ctzX86(x);
    }
    version(X86_64) {
        return ctzX86_64(x);
    }
    version(ARM) {
        return arm_ctz(cast(uint)x);
    }
    version(AArch64) {
        return apple_ctz(cast(ulong)x);
    }
    else {
        // Fallback to C library for unknown architectures
        return ctzFallback(x);
    }
}

// X86 inline assembly
size_t ctzX86(size_t x) @nogc nothrow @trusted {
    asm @nogc pure nothrow {
        bsf EAX, x;  // Bit scan forward
        mov x, EAX;
    }
    return x;
}

// X86_64 inline assembly
size_t ctzX86_64(size_t x) @nogc nothrow @trusted {
    asm @nogc pure nothrow {
        bsf RAX, x;  // Bit scan forward
        mov x, RAX;
    }
    return x;
}

// Fallback to C Library for ctz if no specific architecture is matched
// size_t ctzFallback(size_t x) pure nothrow @trusted {
//     static if (size_t.sizeof == 4) {
//         return __builtin_ctz(cast(int)x);  // 32-bit size_t
//     } else static if (size_t.sizeof == 8) {
//         return __builtin_ctzl(cast(long)x);  // 64-bit size_t
//     }
//     return 0;
// }
size_t ctzFallback(size_t x) @nogc @trusted {
    static if (size_t.sizeof == 4) {
        return __builtin_ctz(cast(int)x);  // 32-bit size_t
    } else static if (size_t.sizeof == 8) {
        return __builtin_ctzl(cast(long)x);  // 64-bit size_t
    }
    return 0;
}


//==================================================
// Zero Memory
//==================================================

void secureZeroMemory(void* ptr, size_t size) @nogc @system nothrow {
    import core.stdc.string : memset;
    memset(ptr, 0, size);
}

public @nogc:

//==================================================
// Allocation and Deallocation
//==================================================

void* alignedAllocate(size_t size, size_t alignment) @nogc @system nothrow {
    // Allocates a block of memory with the specified alignment.
    // 
    // Arguments:
    //    size:      The desired size of the memory block in bytes.
    //    alignment: The desired alignment in bytes (must be a power of two).
    // 
    // Returns:
    //    A pointer to the aligned memory block or null if allocation fails.

    // 1. Calculate total size needed (including alignment and bookkeeping)
    size_t totalSize = size + alignment + size_t.sizeof;

    // 2. Allocate using malloc (or nogc_new)
    void* rawPtr = malloc(totalSize);

    // void* rawPtr = nogc_new!(ubyte[])(totalSize);

    if (rawPtr is null) {
        assert(0, "alignedAllocate: Failed to allocate memory");
    }

    // 3. Calculate aligned address
    size_t alignedAddress = (cast(size_t) rawPtr + alignment + size_t.sizeof) & ~(alignment - 1); 

    // 4. Store original pointer for deallocation
    void** storedPtr = cast(void**)(alignedAddress - size_t.sizeof);
    *storedPtr = rawPtr;

    return cast(void*) alignedAddress; 
}

bool alignedDeallocate(void* ptr) @system {
    // Deallocates a memory block previously allocated with `alignedAllocate`.
    //
    // Arguments:
    //    ptr:  The pointer to the aligned memory block.
    //
    // Returns: 
    //    true if deallocation is successful (always in this example).

    if (ptr is null) return true;

    // 1. Retrieve the original pointer:
    void* originalPtr = *(cast(void**)(cast(size_t)ptr - size_t.sizeof)); 

    // 2. Free the original block
    free(originalPtr);
    // nogc_delete(cast(ubyte*) originalPtr);

    return true;
}

//==================================================
// Alignment and Power-of-Two Checks
//==================================================


bool isPowerOfTwo(size_t x) pure nothrow @safe {
    // Checks if a number is a power of two. 
    //
    // Arguments:
    //    x: The number to check.
    // 
    // Returns:
    //    true if 'x' is a power of two, false otherwise. 
    return (x != 0) && ((x & (x-1)) == 0);
}

// Efficient alignment check: 
bool isAligned(void* ptr, size_t alignment) pure nothrow @safe {
    // Checks if a pointer is aligned to a specified boundary.
    //
    // Arguments:
    //    ptr:       The pointer to check.
    //    alignment: The desired alignment (must be a power of two).
    // 
    // Returns: 
    //    true if 'ptr' is aligned to 'alignment' bytes, false otherwise.
    assert(isPowerOfTwo(alignment), "Alignment must be a power of two");
    return (cast(size_t) ptr & (alignment - 1)) == 0;
} 

size_t nextPowerOfTwo(size_t x) pure nothrow @safe {
    // Returns the next power of two greater than or equal to 'x'.
    // 
    // Arguments:
    //    x: The input number.
    // 
    // Returns:
    //    The next power of two.

    --x;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16; 
    static if (size_t.sizeof == 8) { // Handle 64-bit 
        x |= x >> 32; 
    }
    return ++x; 
}

//==================================================
// Memory Copy and Set
//==================================================

void memcpy(void* dest, const(void)* src, size_t numBytes) @system {
    // Copies 'numBytes' bytes from 'src' to 'dest'.
    // (This is a thin wrapper around the standard memcpy for convenience)
    // 
    // Arguments:
    //   dest:     The destination memory address.
    //   src:      The source memory address.
    //   numBytes: The number of bytes to copy.

    core.stdc.string.memcpy(dest, src, numBytes); 
}

void memset(void* dest, ubyte value, size_t numBytes) @system {
    // Sets 'numBytes' bytes at 'dest' to 'value'.
    // (Wrapper for the standard memset)
    // 
    // Arguments:
    //   dest:     The destination memory address.
    //   value:    The byte value to set.
    //   numBytes: The number of bytes to set.

    core.stdc.string.memset(dest, value, numBytes); 
}

//==================================================
// Bit Manipulation and Counting
//==================================================

size_t countLeadingZeros(size_t x) nothrow @safe {
    // Counts the number of leading zero bits in a size_t.
    //
    // Arguments:
    //     x: The number to examine.
    //
    // Returns:
    //     The number of leading zero bits.

    return ctlz(x); 
}

size_t countTrailingZeros(size_t x) nothrow @safe {
    // Counts the number of trailing zero bits in a size_t.
    //
    // Arguments:
    //     x: The number to examine.
    //
    // Returns:
    //     The number of trailing zero bits.

    return ctz(x); 
}

size_t countSetBits(size_t x) pure nothrow @safe {
    // Counts the number of set bits (bits equal to 1) in a size_t.
    //
    // Arguments:
    //    x: The number to examine.
    //
    // Returns: 
    //    The number of set bits.

    return core.bitop.popcnt(x);
}

size_t getFirstSetBit(size_t x) nothrow @safe {
    // Gets the index (from the least significant bit) of the first set bit (1).
    // If x is 0, returns size_t.max.
    //
    // Arguments: 
    //    x: The number. 
    //
    // Returns: 
    //    The index of the first set bit (0-based) or size_t.max if no bits are set. 

    if (x == 0) return size_t.max;
    return countTrailingZeros(x); 
}

size_t getLastSetBit(size_t x) pure nothrow @safe {
    // Gets the index (from the least significant bit) of the last set bit (1).
    // If x is 0, returns size_t.max.
    //
    // Arguments: 
    //    x: The number. 
    //
    // Returns: 
    //    The index of the last set bit (0-based) or size_t.max if no bits are set.

    if (x == 0) return size_t.max;

    // Efficiently find the highest set bit using bitop.bsr (bit scan reverse):
    return core.bitop.bsr(x); 
}

//==================================================
// Memory Comparison
//==================================================

int memcmp(const void* ptr1, const void* ptr2, size_t num) @system {
    // Compares two blocks of memory lexicographically.
    // (Wrapper around the standard memcmp function)
    // 
    // Arguments: 
    //    ptr1: The first memory block.
    //    ptr2: The second memory block. 
    //    num:  The number of bytes to compare.

    return core.stdc.string.memcmp(ptr1, ptr2, num); 
}

//==================================================
// Byte Swapping 
//==================================================

ushort swapBytes16(ushort value) pure nothrow @safe {
    // Swaps the bytes of a 16-bit unsigned integer (endianness conversion).
    // 
    // Arguments:
    //     value: The value to swap.
    //
    // Returns: 
    //     The byte-swapped value.

    //return bswap(value);
    return cast(ushort)(core.bitop.bswap(cast(uint)value) >>> 16);
}

uint swapBytes32(uint value) pure nothrow @safe {
    // Swaps the bytes of a 32-bit unsigned integer (endianness conversion). 
    // 
    // Arguments:
    //     value: The value to swap.
    //
    // Returns: 
    //     The byte-swapped value.

    //return bswap(value);
    return core.bitop.bswap(value);
}

ulong swapBytes64(ulong value) pure nothrow @safe {
    // Swaps the bytes of a 64-bit unsigned integer (endianness conversion). 
    //
    // Arguments:
    //    value: The value to swap.
    //
    // Returns:
    //    The byte-swapped value.

    //return bswap(value);
    return core.bitop.bswap(value);
}

//==================================================
// Memory Region Utilities
//================================================== 

RegionAllocator* createRegion(size_t size) @nogc nothrow {
    // Allocate raw memory for RegionAllocator
    void* rawPtr = malloc(RegionAllocator.sizeof);
    if (rawPtr is null) {
        assert(0, "createRegion: Failed to allocate memory");
    }
    // Use emplace to construct the RegionAllocator in the allocated memory
    import core.lifetime : emplace;
    return cast(RegionAllocator*)emplace!RegionAllocator(rawPtr[0 .. RegionAllocator.sizeof], size);
}

void destroyRegion(RegionAllocator* region) @nogc nothrow {
    // Deallocates a memory region.
    if (region !is null) {
        region.destroy();            // Explicitly call the destructor
        free(cast(void*)region);    // Free the allocated memory
    }
}

size_t getRegionSize(RegionAllocator* region) @nogc nothrow {
    // Returns the total size (capacity) of the memory region in bytes.
    return region.size; 
}

size_t getRegionFreeSpace(RegionAllocator* region) @nogc nothrow {
    // Returns the amount of free space (in bytes) remaining in the region.
    // Note: This implementation might vary based on your specific 
    // RegionAllocator implementation.
    return region.size - region.currentOffset; // Use bufferSize and offset
}

//==================================================
// Freelist Utilities
//==================================================

import enginem.allocators.smallobject.FreeListAllocator; // Import your FreeListAllocator
// ... (If you have a custom FreeList struct, import it here instead)

void freelistPush(FreeListAllocator.FreeNode* list, void* ptr) {
    // Adds a block to the head of the freelist.
    auto node = cast(FreeListAllocator.FreeNode*) ptr;
    node.next = list;
    list = node;
}

void* freelistPop(FreeListAllocator.FreeNode* list) {
    // Removes and returns the block at the head of the freelist.
    // Returns null if the freelist is empty. 

    if (list is null) return null; 

    auto node = list;
    list = list.next; 
    return node;
}

//==================================================
// Memory Block Header Utilities (Example)
//==================================================
struct MemoryBlockHeader {
    size_t size; 
    bool isFree; 
    // ... (Optional: additional fields like previous block pointer for 
    //      more complex allocators)
}

void setBlockSize(MemoryBlockHeader* header, size_t size) {
    // Sets the size of a memory block in the header.
    header.size = size;
}

bool isBlockFree(MemoryBlockHeader* header) {
    // Checks if a memory block is marked as free.
    return header.isFree;
}

//==================================================
// Bit Shifting
//==================================================

size_t rotateLeft(size_t x, uint n) pure nothrow @safe {
    // Rotates the bits in 'x' left by 'n' positions.
    return core.bitop.rol(x, n); 
}

size_t rotateRight(size_t x, uint n) pure nothrow @safe {
    // Rotates the bits in 'x' right by 'n' positions.
    return core.bitop.ror(x, n);
}

//==================================================
// Bit Field Manipulation
//==================================================

size_t getBitField(size_t x, uint startBit, uint numBits) pure nothrow @safe {
    // Extracts a bit field from a value. 
    //
    // Arguments:
    //   x:        The input value.
    //   startBit: The starting bit position (0-based, from the least significant bit).
    //   numBits:  The number of bits to extract.
    //
    // Returns:
    //   The extracted bit field.

    size_t mask = (1UL << numBits) - 1; // Create a mask with 'numBits' ones.
    return (x >> startBit) & mask;
}

size_t setBitField(size_t x, uint startBit, uint numBits, size_t value) pure nothrow @safe {
    // Sets a bit field within a value.
    //
    // Arguments:
    //   x:        The input value.
    //   startBit: The starting bit position (0-based).
    //   numBits:  The number of bits to set.
    //   value:    The new value for the bit field.
    //
    // Returns: 
    //   The modified value with the bit field set.

    size_t mask = (1UL << numBits) - 1; // Mask for the bit field
    value &= mask; // Ensure value fits in the bit field
    return (x & ~(mask << startBit)) | (value << startBit); 
}


//==================================================
//
// Thread Safe Tools
//  
//==================================================


//==================================================
// Freelist Utilities (Thread-Safe) 
//==================================================

// Mutex to protect the freelist from race conditions in multithreaded use:
private SpinLock freelistLock; 

void tsFreelistPush(FreeListAllocator.FreeNode* list, void* ptr) @nogc {
    // Thread-safe function to add a block to the freelist.
    // Acquires a lock before modifying the freelist.

    freelistLock.lock();
    auto node = cast(FreeListAllocator.FreeNode*) ptr;
    node.next = list;
    list = node;
    freelistLock.unlock();
}

void* tsFreelistPop(FreeListAllocator.FreeNode* list) {
    // Thread-safe function to remove and return a block from the freelist.
    // Returns null if the list is empty. 
    // Acquires a lock to prevent race conditions.

    freelistLock.lock(); 
    if (list is null) {
        freelistLock.unlock();
        return null;
    }

    auto node = list;
    list = list.next;
    freelistLock.unlock();  
    return node; 
}

//==================================================
// Memory Block Header Utilities (Thread-Safe)
//==================================================

struct tsMemoryBlockHeader {
    size_t size; 
    bool isFree; 
    // ... (Optional: Additional fields) 
}

// Mutex to protect block header operations:
private SpinLock blockHeaderLock; 

void setBlockSize(tsMemoryBlockHeader* header, size_t size) @nogc nothrow {
    // Thread-safe function to set the size of a block.

    blockHeaderLock.lock();
    header.size = size;
    blockHeaderLock.unlock();
}

bool isBlockFree(tsMemoryBlockHeader* header) @nogc nothrow {
    // Thread-safe check to see if a block is free. 

    blockHeaderLock.lock();
    bool result = header.isFree;
    blockHeaderLock.unlock(); 
    return result; 
}

//==================================================
// Bit Manipulation (Thread-Safe - Only If Necessary) 
//==================================================

// If you are manipulating bitfields in shared memory 
// (e.g., in a MemoryBlockHeader used by multiple threads),
// then these functions would need to be thread-safe.

private SpinLock bitfieldLock;

size_t tsGetBitField(size_t x, uint startBit, uint numBits) nothrow @safe {
    bitfieldLock.lock();
    size_t mask = (1UL << numBits) - 1;
    size_t result = (x >> startBit) & mask;
    bitfieldLock.unlock(); 
    return result;
}

size_t tsSetBitField(size_t x, uint startBit, uint numBits, size_t value) nothrow @safe {
    bitfieldLock.lock(); 
    size_t mask = (1UL << numBits) - 1;
    value &= mask; 
    size_t result = (x & ~(mask << startBit)) | (value << startBit);
    bitfieldLock.unlock(); 
    return result; 
}

//==================================================
// Additional Thread-Safe Utilities
//==================================================

// 1. Thread-Safe Reference Counting:
void atomicIncRef(T)(ref T obj) @nogc @system {
    // Atomically increments the reference count of an object.
    // 
    // Assumes 'obj' contains a member called 'refCount' of type 'size_t'.
    // This assumption is typical for reference counted objects. 
    //
    // Arguments:
    //   obj: The object whose reference count should be incremented. 

    static if (__traits(hasMember, T, "refCount")) {
        atomicFetchAdd!(size_t)(&obj.refCount, 1);
    } else {
        static assert(false, "Type " ~ T.stringof ~ " does not have a 'refCount' member.");
    }
}

bool atomicDecRef(T)(ref T obj) @nogc @system {
    // Atomically decrements the reference count of an object. 
    //
    // Returns true if the reference count reaches 0, indicating that the 
    // object should be deleted; otherwise, returns false.
    //
    // Arguments:
    //   obj: The object whose reference count should be decremented.

    static if (__traits(hasMember, T, "refCount")) {
        return (atomicFetchSub!(size_t)(&obj.refCount, 1) == 1);
    } else {
        static assert(false, "Type " ~ T.stringof ~ " does not have a 'refCount' member.");
    }
}

// 2. Atomic Memory Operations:
T atomicLoad(T)(const(T)* ptr) @nogc @system {
    // Atomically loads a value of type 'T' from the memory location pointed 
    // to by 'ptr'. 
    // 
    // Arguments: 
    //    ptr: The pointer to the memory location.
    //
    // Returns:
    //    The loaded value. 

    return atomicLoad!(T)(ptr);
}

void atomicStore(T)(T* ptr, T value) @nogc @system {
    // Atomically stores a value of type 'T' to the memory location pointed to by 'ptr'.
    //
    // Arguments:
    //    ptr:   The pointer to the memory location.
    //    value: The value to store. 

    atomicStore!(T)(ptr, value);
}

bool atomicCompareExchange(T)(T* ptr, T expected, T desired) @nogc @system {
    // Atomic compare-and-swap operation (CAS).
    //
    // Atomically compares the value at 'ptr' with 'expected'.  If they are equal, 
    // the value at 'ptr' is replaced with 'desired', and true is returned. 
    // If they are not equal, the value at 'ptr' is left unchanged, and false is returned. 
    //
    // Arguments:
    //    ptr:      The pointer to the memory location.
    //    expected: The expected value.
    //    desired:  The desired value to store if 'expected' matches.
    //
    // Returns:
    //    true if the swap was successful (values matched), false otherwise. 

    return atomicCompareExchange!(T)(ptr, expected, desired);
}


