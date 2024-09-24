module test.test_runner;

import enginem;
import std.stdio;
import std.string;
import std.algorithm.comparison;
import std.exception;
import std.parallelism;
import std.random;
import resusage.memory;
import core.thread;
import core.stdc.string : memcpy, memcmp;
import AllocatorTypes : AllocatorError;
import enginem.allocators.Allocator : AllocatorWrapper;
import automem.unique : Unique;
import automem.ref_counted : RefCounted;
import std.algorithm : move;

// Helper function to test alignment
bool testAlignment(void* ptr, size_t alignment) {
    return (cast(size_t) ptr % alignment) == 0;
}

// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ Arena Allocator Test                                          ║  
// ╚═══════════════════════════════════════════════════════════════════╝

unittest {
    writeln("---- Arena Allocator Tests ----");

    auto arena = new ArenaAllocator(1024);
    AllocatorError error;

    // Test 1: Basic allocation
    int* intPtr = cast(int*) arena.allocate(int.sizeof, int.alignof, error);
    assert(error == AllocatorError.None, "ArenaAllocator: Basic allocation failed");
    *intPtr = 42;
    assert(*intPtr == 42, "ArenaAllocator: Basic allocation value incorrect");

    // Test 2: Alignment
    double* dblPtr = cast(double*) arena.allocate(double.sizeof, double.alignof, error);
    assert(error == AllocatorError.None, "ArenaAllocator: Alignment allocation failed");
    *dblPtr = 3.14159;
    assert(*dblPtr == 3.14159, "ArenaAllocator: Alignment allocation value incorrect");
    assert(testAlignment(dblPtr, double.alignof), "ArenaAllocator: Alignment check failed");

    // Test 3: Exhaustion
    void* exhaustPtr = arena.allocate(2048, 1, error);
    assert(error == AllocatorError.OutOfMemory, "ArenaAllocator: Expected OutOfMemory error not set");
    assert(exhaustPtr is null, "ArenaAllocator: Expected null pointer on exhaustion");

    // Test 4: Reset functionality
    arena.reset();
    // After reset, we should be able to allocate again
    void* resetPtr = arena.allocate(100, 1, error);
    assert(error == AllocatorError.None, "ArenaAllocator: Allocation after reset failed");
    assert(resetPtr !is null, "ArenaAllocator: Expected non-null pointer after reset");

    writeln("Arena Allocator tests passed.");
}

// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ Linear Allocator Test                                         ║  
// ╚═══════════════════════════════════════════════════════════════════╝

unittest {
    writeln("---- Linear Allocator Tests ----");

    auto linear = new LinearAllocator(512);
    AllocatorError error;

    // Test 1: Basic allocation
    char* charPtr = cast(char*) linear.allocate(100, 1, error);
    assert(error == AllocatorError.None, "LinearAllocator: Basic allocation failed");
    charPtr[0] = 'A';
    assert(charPtr[0] == 'A', "LinearAllocator: Basic allocation value incorrect");

    // Test 2: Alignment
    long* longPtr = cast(long*)(linear.allocate(long.sizeof, long.alignof, error));
    assert(error == AllocatorError.None, "LinearAllocator: Alignment allocation failed");
    *longPtr = 123456789L;
    assert(*longPtr == 123456789L, "LinearAllocator: Alignment allocation value incorrect");
    assert(testAlignment(longPtr, long.alignof), "LinearAllocator: Alignment check failed");

    // Test 3: Exhaustion
    void* exhaustPtr = linear.allocate(600, 1, error);
    assert(error == AllocatorError.OutOfMemory, "LinearAllocator: Expected OutOfMemory error not set");
    assert(exhaustPtr is null, "LinearAllocator: Expected null pointer on exhaustion");

    // Test 4: Reset functionality
    linear.reset();
    // After reset, we should be able to allocate again
    void* resetPtr = linear.allocate(100, 1, error);
    assert(error == AllocatorError.None, "LinearAllocator: Allocation after reset failed");
    assert(resetPtr !is null, "LinearAllocator: Expected non-null pointer after reset");

    writeln("Linear Allocator tests passed.");
}

// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ Stack Allocator Test                                          ║  
// ╚═══════════════════════════════════════════════════════════════════╝

unittest {
    writeln("---- Stack Allocator Tests ----");
    auto stack = new StackAllocator(256);
    AllocatorError error;

    // Test 1: Basic allocation
    float* floatPtr = cast(float*) stack.allocate(float.sizeof, float.alignof, error);
    assert(error == AllocatorError.None, "StackAllocator: Basic allocation failed");
    *floatPtr = 1.23f;
    assert(*floatPtr == 1.23f, "StackAllocator: Basic allocation value incorrect");

    // Test 2: Alignment
    double* dblPtr = cast(double*) stack.allocate(double.sizeof, double.alignof, error);
    assert(error == AllocatorError.None, "StackAllocator: Alignment allocation failed");
    *dblPtr = 4.56;
    assert(*dblPtr == 4.56, "StackAllocator: Alignment allocation value incorrect");
    assert(testAlignment(dblPtr, double.alignof), "StackAllocator: Alignment check failed");

    // Test 3: Stack Underflow
    bool deallocDbl = stack.deallocate(cast(void*)dblPtr, error);
    assert(deallocDbl, "StackAllocator: Deallocation of dblPtr failed");
    bool deallocFloat = stack.deallocate(cast(void*)floatPtr, error);
    assert(deallocFloat, "StackAllocator: Deallocation of floatPtr failed");
    bool doubleFree = stack.deallocate(cast(void*)floatPtr, error);
    assert(!doubleFree, "StackAllocator: Expected false on double free");
    assert(error == AllocatorError.StackUnderflow, "StackAllocator: Expected StackUnderflow error not set");

    // Test 4: Stack Overflow
    for (int i = 0; i < 100; i++) {
        void* ptr = stack.allocate(5, 1, error);
        if (error == AllocatorError.StackOverflow) {
            break;
        }
        assert(ptr !is null, "StackAllocator: Allocation failed before overflow");
    }
    assert(error == AllocatorError.StackOverflow, "StackAllocator: Expected StackOverflow error not set");

    // Test 5: Reset functionality
    stack.reset();
    void* resetPtr = stack.allocate(100, 1, error);
    assert(error == AllocatorError.None, "StackAllocator: Allocation after reset failed");
    assert(resetPtr !is null, "StackAllocator: Expected non-null pointer after reset");

    writeln("Stack Allocator tests passed.");
}

// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ FreeList Allocator Test                                       ║  
// ╚═══════════════════════════════════════════════════════════════════╝

unittest {
    writeln("---- FreeList Allocator Tests ----");

    // Get available system RAM using resusage with retries:
    size_t availableRAM = 0;
    int retries = 3;
    while (availableRAM == 0 && retries > 0) {
        auto sysMemInfo = systemMemInfo();
        availableRAM = sysMemInfo.freeRAM();
        if (availableRAM == 0) {
            Thread.sleep(100.msecs); 
            retries--;
        }
    }

    if (availableRAM == 0) {
        writeln("WARNING: resusage reported 0 available RAM after retries. Using default capacity.");
        availableRAM = 1024 * 1024; // 1 MB default <<<--- HARDCODED DEFAULT
    }

    // Calculate a reasonable capacity for the FreeListAllocator:
    size_t freeListCapacity = availableRAM / 100; 

    writeln("Available RAM: ", availableRAM);
    writeln("FreeList Capacity: ", freeListCapacity);

    auto freelist = new FreeListAllocator(32, 8, freeListCapacity); 
    AllocatorError error;

    // Test 1: Basic allocation
    void* ptr1 = freelist.allocate(32, 8, error);
    assert(error == AllocatorError.None, "FreeListAllocator: Basic allocation failed");
    assert(ptr1 !is null, "FreeListAllocator: Basic allocation returned null");
    assert(testAlignment(ptr1, 8), "FreeListAllocator: Alignment check failed");

    // Test 2: Reuse freed block
    assert(freelist.deallocate(ptr1, error), "FreeListAllocator: Deallocation failed");
    void* ptr2 = freelist.allocate(32, 8, error);
    assert(error == AllocatorError.None, "FreeListAllocator: Reallocation failed");
    assert(ptr1 == ptr2, "FreeListAllocator: Freed block was not reused");

    // Test 3: Allocation with incorrect size
    void* invalidPtr = freelist.allocate(16, 8, error);
    assert(error == AllocatorError.InvalidAssignment, "FreeListAllocator: Expected InvalidAssignment error not set");
    assert(invalidPtr is null, "FreeListAllocator: Expected null pointer for invalid allocation");

    // Test 4: Alignment error
    invalidPtr = freelist.allocate(32, 16, error);
    assert(error == AllocatorError.InvalidAssignment, "FreeListAllocator: Expected InvalidAssignment error not set for incorrect alignment");
    assert(invalidPtr is null, "FreeListAllocator: Expected null pointer for invalid alignment");

    // Test 5: Exhaustion
    int allocCount = 0;
    int maxAllocations = 100000; // <<<--- ALLOCATION LIMIT (adjust as needed)

    while (allocCount < maxAllocations) { // <<<--- CHECK AGAINST THE LIMIT
        void* ptr = freelist.allocate(32, 8, error);
        if (error == AllocatorError.OutOfMemory) {
            break;
        }
        assert(ptr !is null, "FreeListAllocator: Allocation failed before exhaustion");
        allocCount++;
    }
    assert(error == AllocatorError.OutOfMemory, "FreeListAllocator: Expected OutOfMemory error not set");

    // Test 6: Reset functionality
    freelist.reset();
    void* resetPtr = freelist.allocate(32, 8, error);
    assert(error == AllocatorError.None, "FreeListAllocator: Allocation after reset failed");
    assert(resetPtr !is null, "FreeListAllocator: Expected non-null pointer after reset");

    writeln("FreeList Allocator tests passed.");
}

// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ Region Allocator Test                                         ║  
// ╚═══════════════════════════════════════════════════════════════════╝

unittest {
    writeln("---- Region Allocator Tests ----");
    auto region = new RegionAllocator(1024);
    AllocatorError error;

    // Test 1: Basic allocation
    char* ptr1 = cast(char*) region.allocate(100, 1, error);
    assert(error == AllocatorError.None, "RegionAllocator: Basic allocation failed");
    string testString = "Region Allocator Test";
    memcpy(ptr1, testString.ptr, testString.length);
    assert(memcmp(ptr1, testString.ptr, testString.length) == 0, "RegionAllocator: Basic allocation content incorrect");

    // Test 2: Alignment
    int* intPtr = cast(int*) region.allocate(int.sizeof, int.alignof, error);
    assert(error == AllocatorError.None, "RegionAllocator: Alignment allocation failed");
    *intPtr = 256;
    assert(*intPtr == 256, "RegionAllocator: Alignment allocation value incorrect");
    assert(testAlignment(intPtr, int.alignof), "RegionAllocator: Alignment check failed");

    // Test 3: Out of Memory
    void* exhaustPtr = region.allocate(2000, 1, error);
    assert(error == AllocatorError.OutOfMemory, "RegionAllocator: Expected OutOfMemory error not set");
    assert(exhaustPtr is null, "RegionAllocator: Expected null pointer on exhaustion");

    // Test 4: Reset functionality
    region.reset();
    void* resetPtr = region.allocate(100, 1, error);
    assert(error == AllocatorError.None, "RegionAllocator: Allocation after reset failed");
    assert(resetPtr !is null, "RegionAllocator: Expected non-null pointer after reset");

    writeln("Region Allocator tests passed.");
}

// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ Unique Pointer Allocator Test                                 ║  
// ╚═══════════════════════════════════════════════════════════════════╝

unittest {
    writeln("---- UniquePtr Tests ----");
    auto arena = new ArenaAllocator(512);
    // Properly initialize AllocatorWrapper using parentheses
    AllocatorWrapper!(ArenaAllocator) arenaWrapper = AllocatorWrapper!(ArenaAllocator)(&arena);

    // Test 1: Basic UniquePtr functionality
    auto uniqueInt = Unique!(int, AllocatorWrapper!(ArenaAllocator))(arenaWrapper, 123);
    assert(*uniqueInt == 123, "UniquePtr: Basic functionality failed");

    // Test 2: Move semantics
    auto uniqueInt2 = move(uniqueInt); // Use the move function from std.algorithm.move
    assert(uniqueInt2.get() !is null, "UniquePtr: Move failed");
    assert(*uniqueInt2 == 123, "UniquePtr: Moved pointer value incorrect");
    assert(uniqueInt.get() is null, "UniquePtr: Original pointer not empty after move"); // Check for null

    // Test 3: Allocation with different allocator
    auto linear = new LinearAllocator(256);
    AllocatorWrapper!(LinearAllocator) linearWrapper = AllocatorWrapper!(LinearAllocator)(&linear);
    auto uniqueStr = Unique!(string, AllocatorWrapper!(LinearAllocator))(linearWrapper, "Hello, Unique!");
    assert(*uniqueStr == "Hello, Unique!", "UniquePtr: Allocation with different allocator failed");

    // Test 4: Reset functionality
    uniqueStr = Unique!(string, AllocatorWrapper!(LinearAllocator))(); // Reset by assigning null
    assert(uniqueStr.get() is null, "UniquePtr: Reset failed"); // Check for null

    writeln("UniquePtr tests passed.");
}

// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ Shared Pointer Allocator Test                                 ║  
// ╚═══════════════════════════════════════════════════════════════════╝

unittest {
    writeln("---- SharedPtr Tests ----");
    auto arena = new ArenaAllocator(512);
    // Properly initialize AllocatorWrapper using parentheses
    AllocatorWrapper!(ArenaAllocator) arenaWrapper = AllocatorWrapper!(ArenaAllocator)(&arena);

    // Test 1: Basic SharedPtr functionality
    auto sharedInt1 = RefCounted!(int, AllocatorWrapper!(ArenaAllocator))(arenaWrapper, 456);
    assert(*sharedInt1 == 456, "SharedPtr: Basic functionality failed");
    // Since automem's Shared does not expose `refCount`, we skip this assertion

    // Test 2: Copy semantics
    auto sharedInt2 = sharedInt1; // Shared pointers are copyable
    // Since automem's Shared does not expose `refCount`, we verify by ensuring both point to the same value
    assert(*sharedInt2 == 456, "SharedPtr: Copied pointer value incorrect");

    // Test 3: Deallocation
    sharedInt1 = RefCounted!(int, AllocatorWrapper!(ArenaAllocator))(arenaWrapper, 456);
    sharedInt2 = sharedInt1; 
    // Both sharedInt1 and sharedInt2 exist here -- sharedInt1 and sharedInt2 go out of scope, ref count drops to zero,
    // and as a result, the int object should be deallocated here.

    // Test 4: Allocation with different allocator
    auto linear = new LinearAllocator(256);
    AllocatorWrapper!(LinearAllocator) linearWrapper = AllocatorWrapper!(LinearAllocator)(&linear);
    auto sharedStr1 = RefCounted!(string, AllocatorWrapper!(LinearAllocator))(linearWrapper, "Hello, Shared!");
    auto sharedStr2 = sharedStr1; // Copy shared pointer
    assert(*sharedStr2 == "Hello, Shared!", "SharedPtr: Copied pointer value incorrect");

    writeln("SharedPtr tests passed.");
}

// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ Memory Pool Test                                              ║  
// ╚═══════════════════════════════════════════════════════════════════╝

unittest {
    writeln("---- MemoryPool Tests ----");
    auto pool = new MemoryPool(1024, 64); // Pool size 1024 bytes with 64-byte blocks
    AllocatorError error;

    // Test 1: Basic allocation and deallocation
    void* ptr1 = pool.allocate(64, 8, error);
    assert(error == AllocatorError.None, "MemoryPool: Basic allocation failed");
    assert(ptr1 !is null, "MemoryPool: Basic allocation returned null");
    assert(testAlignment(ptr1, 8), "MemoryPool: Alignment check failed");
    
    bool dealloc1 = pool.deallocate(ptr1, error);
    assert(dealloc1, "MemoryPool: Deallocation failed");
    assert(error == AllocatorError.None, "MemoryPool: Deallocation error");

    // Test 2: Double free detection
    bool doubleFree = pool.deallocate(ptr1, error);
    assert(!doubleFree, "MemoryPool: Double free should fail");
    assert(error == AllocatorError.InvalidAssignment, "MemoryPool: Expected InvalidAssignment error for double free");

    // Test 3: Exhaustion
    int allocCount = 0;
    void* lastPtr;
    while (true) {
        void* ptr = pool.allocate(64, 8, error);
        if (error == AllocatorError.OutOfMemory) break;
        assert(ptr !is null, "MemoryPool: Allocation failed before exhaustion");
        lastPtr = ptr;
        allocCount++;
    }
    assert(error == AllocatorError.OutOfMemory, "MemoryPool: Expected OutOfMemory error not set");

    // Test 4: Deallocation after exhaustion
    bool deallocLast = pool.deallocate(lastPtr, error);
    assert(deallocLast, "MemoryPool: Deallocation of last allocated block failed");
    assert(error == AllocatorError.None, "MemoryPool: Deallocation error after exhaustion");

    // Test 5: Allocation after deallocation
    void* newPtr = pool.allocate(64, 8, error);
    assert(error == AllocatorError.None, "MemoryPool: Allocation after deallocation failed");
    assert(newPtr == lastPtr, "MemoryPool: New allocation should reuse last deallocated block");

    // Test 6: Reset functionality
    pool.reset();
    void* resetPtr = pool.allocate(64, 8, error);
    assert(error == AllocatorError.None, "MemoryPool: Allocation after reset failed");
    assert(resetPtr !is null, "MemoryPool: Expected non-null pointer after reset");

    writeln("MemoryPool tests passed.");
}

// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ Memory Tracker Test                                           ║  
// ╚═══════════════════════════════════════════════════════════════════╝

unittest {
    import std.stdio : writeln, writefln;
    import core.thread : Thread;
    import core.time : Duration, seconds;

    writeln("---- MemoryTracker Tests ----");
    
    writeln("Resetting tracker before test");
    memoryTracker.resetTracker();
    
    auto arena = new ArenaAllocator(512);
    AllocatorError error;

    writeln("Step 1: Allocations");
    void* ptr1 = arena.allocate(64, 8, error);
    writefln("Allocated ptr1: %x", cast(size_t)ptr1);
    void* ptr2 = arena.allocate(128, 16, error);
    writefln("Allocated ptr2: %x", cast(size_t)ptr2);
    
    auto trackedBlocks = memoryTracker.getAllocatedBlocks();
    writefln("Number of tracked blocks: %d", trackedBlocks.length);
    foreach (block; trackedBlocks) {
        writefln("Tracked block: address=%x, size=%d", cast(size_t)block.address, block.size);
    }
    
    assert(trackedBlocks.length == 2, "MemoryTracker: Allocation tracking failed");

    writeln("Step 2: Deallocation");
    bool deallocResult = arena.deallocate(ptr1, error);
    writefln("Deallocated ptr1: %x, result: %s", cast(size_t)ptr1, deallocResult);
    trackedBlocks = memoryTracker.getAllocatedBlocks();
    writefln("Number of tracked blocks after deallocation: %d", trackedBlocks.length);
    assert(trackedBlocks.length == 1, "MemoryTracker: Deallocation tracking failed");

    writeln("Step 3: Generate report");
    memoryTracker.generateReport();

    writeln("Step 4: Check total memory usage");
    size_t totalUsage;
    bool completed = false;
    auto timeoutThread = new Thread({
        Thread.sleep(5.seconds);  // Wait for 5 seconds
        if (!completed) {
            writeln("ERROR: getTotalMemoryUsage timed out after 5 seconds");
            assert(false, "Test timed out");
        }
    });
    timeoutThread.start();

    totalUsage = memoryTracker.getTotalMemoryUsage();
    completed = true;
    timeoutThread.join();

    writefln("Total memory usage: %d bytes", totalUsage);
    assert(totalUsage == 128, "MemoryTracker: Incorrect total memory usage");

    writeln("Step 5: Reset tracker");
    memoryTracker.resetTracker();
    trackedBlocks = memoryTracker.getAllocatedBlocks();
    writefln("Number of tracked blocks after reset: %d", trackedBlocks.length);
    assert(trackedBlocks.length == 0, "MemoryTracker: Reset tracking failed");

    writeln("MemoryTracker tests passed.");
}

// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   ⇩ Main                                                          ║  
// ╚═══════════════════════════════════════════════════════════════════╝

void main()
{
    writeln("Running all tests...");
    // The unittest blocks will be automatically executed
}