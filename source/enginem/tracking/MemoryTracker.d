// tracking/MemoryTracker.d
module enginem.tracking.MemoryTracker;

import enginem.allocators.Allocator;
import enginem.errors;
import enginem.sync.SpinLock;
import core.stdc.stdio : snprintf, fprintf, stderr;

debug import std.stdio : writefln;

/// Stores information about an allocated memory block
struct MemoryBlockInfo {
    void* address;  /// Pointer to the allocated memory
    size_t size;    /// Size of the allocated block in bytes
}

/// MemoryTracker tracks all memory allocations and deallocations, assisting in debugging and leak detection.
class MemoryTracker {
private:
    enum MAX_BLOCKS = 1000;  /// Maximum number of memory blocks that can be tracked
    MemoryBlockInfo[MAX_BLOCKS] allocatedBlocks;  /// Fixed-size array to store allocation info
    size_t blockCount;  /// Current number of tracked allocations
    SpinLock trackerLock;  /// Lock for thread-safety

public:
    @nogc:

    /// Constructs a MemoryTracker.
    this() nothrow {
        blockCount = 0;
        debug writefln("MemoryTracker: Initialized with capacity for %d blocks", MAX_BLOCKS);
    }

    /// Tracks a new memory allocation.
    /// 
    /// Params:
    ///     ptr = A pointer to the allocated memory block.
    ///     size = The size of the allocated memory block in bytes.
    void trackAllocation(void* ptr, size_t size) nothrow {
        debug writefln(" MemoryTracker: Tracking allocation of %d bytes at %x", size, cast(size_t)ptr);
        trackerLock.lock();
        scope(exit) trackerLock.unlock();

        if (blockCount < MAX_BLOCKS) {
            allocatedBlocks[blockCount++] = MemoryBlockInfo(ptr, size);
            debug writefln(" MemoryTracker: Total blocks tracked: %d", blockCount);
        } else {
            debug writefln("MemoryTracker: Maximum number of blocks reached, cannot track more");
        }
        // Note: If MAX_BLOCKS is reached, new allocations won't be tracked.
    }

    /// Tracks a memory deallocation.
    /// 
    /// Params:
    ///     ptr = A pointer to the memory block being deallocated.
    void trackDeallocation(void* ptr) nothrow {
        debug writefln("MemoryTracker: Tracking deallocation at %x", cast(size_t)ptr);
        trackerLock.lock();
        scope(exit) trackerLock.unlock();

        for (size_t i = 0; i < blockCount; i++) {
            if (allocatedBlocks[i].address == ptr) {
                // Move the last element to this position and decrement the count
                allocatedBlocks[i] = allocatedBlocks[--blockCount];
                debug writefln("MemoryTracker: Deallocation tracked. Total blocks remaining: %d", blockCount);
                return;
            }
        }
        debug writefln("MemoryTracker: Deallocation of untracked pointer %x", cast(size_t)ptr);
        // Note: If ptr is not found, it's silently ignored.
    }

    /// Retrieves all currently allocated memory blocks.
    /// 
    /// Returns: A slice of the internal array containing allocation information.
    const(MemoryBlockInfo)[] getAllocatedBlocks() const nothrow {
        trackerLock.lock();
        scope(exit) trackerLock.unlock();
        debug writefln("MemoryTracker: Returning %d allocated blocks", blockCount);
        return allocatedBlocks[0..blockCount];
    }

    /// Calculates the total memory usage from all tracked allocations.
    /// 
    /// Returns: The total allocated memory in bytes.
    size_t getTotalMemoryUsage() const nothrow {
        debug import std.stdio : writefln;
        debug writefln("MemoryTracker: Calculating total memory usage for %d blocks", blockCount);
        
        size_t total = 0;
        for (size_t i = 0; i < blockCount; ++i) {
            debug writefln("MemoryTracker: Processing block %d of %d", i + 1, blockCount);
            total += allocatedBlocks[i].size;
            debug writefln("MemoryTracker: Block at %x, size %d, running total %d", 
                        cast(size_t)allocatedBlocks[i].address, allocatedBlocks[i].size, total);
        }
        
        debug writefln("MemoryTracker: Total memory usage calculation complete: %d bytes", total);
        return total;
    }

    /// Generates a report of all current memory allocations.
    void generateReport() const nothrow {
        debug import std.stdio : writefln;
        debug writefln("MemoryTracker: Entering generateReport");
        
        trackerLock.lock();
        debug writefln("MemoryTracker: Lock acquired in generateReport");
        scope(exit) {
            trackerLock.unlock();
            debug writefln("MemoryTracker: Lock released in generateReport");
        }

        // Use a fixed-size buffer for @nogc-compatible output
        enum BUFFER_SIZE = 1024;
        char[BUFFER_SIZE] buffer;
        int len;

        len = snprintf(buffer.ptr, BUFFER_SIZE, "MemoryTracker Report:\n=====================\n");
        outputString(buffer[0..len]);

        size_t totalUsage = 0;
        foreach (ref block; allocatedBlocks[0..blockCount]) {
            len = snprintf(buffer.ptr, BUFFER_SIZE, "Address: %p, Size: %zu bytes\n", block.address, block.size);
            outputString(buffer[0..len]);
            totalUsage += block.size;
        }

        len = snprintf(buffer.ptr, BUFFER_SIZE, "Total Allocated Memory: %zu bytes\n", totalUsage);
        outputString(buffer[0..len]);
        
        debug writefln("MemoryTracker: Report generation completed");
    }

    /// Resets the MemoryTracker by clearing all tracked allocations.
    void resetTracker() nothrow {
        debug import std.stdio : writefln;
        debug writefln("MemoryTracker: Entering resetTracker");
        trackerLock.lock();
        debug writefln("MemoryTracker: Lock acquired in resetTracker");
        scope(exit) {
            trackerLock.unlock();
            debug writefln("MemoryTracker: Lock released in resetTracker");
        }
        debug writefln("MemoryTracker: Resetting tracker. Current block count: %d", blockCount);
        blockCount = 0;
        debug writefln("MemoryTracker: Reset completed. New block count: %d", blockCount);
        debug writefln("MemoryTracker: Exiting resetTracker");
    }

private:
    /// Outputs a string in an @nogc-compatible way.
    /// 
    /// This function writes directly to stderr for simplicity and @nogc compatibility.
    /// 
    /// Params:
    ///     str = The string to output.
    void outputString(const(char)[] str) const nothrow {
        fprintf(stderr, "%.*s", cast(int)str.length, str.ptr);
    }
}