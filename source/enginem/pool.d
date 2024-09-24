// pool.d
// pool.d
module enginem.pool;

import enginem.errors;
import enginem.allocators.Allocator;
import AllocatorTypes : AllocatorError;
import enginem.utils;
import enginem : memoryTracker;
import enginem.sync.SpinLock;

debug import std.stdio : writefln;

/// MemoryPool manages a pool of fixed-size memory blocks, optimizing allocation and deallocation performance.
class MemoryPool : Allocator {
private: 
    struct Block {
        Block* next;
        bool isAllocated;
    }

    Block* freeList;
    size_t blockSize;
    size_t poolSize;
    ubyte* poolMemory;
    SpinLock poolLock;

public:
    this(size_t poolSizeInBytes, size_t blockSizeInBytes) @nogc {
        debug writefln("MemoryPool: Initializing with poolSize=%d, blockSize=%d", poolSizeInBytes, blockSizeInBytes);
        assert(blockSizeInBytes > 0, "Block size must be greater than zero");
        assert(poolSizeInBytes >= blockSizeInBytes, "Pool size must be at least as large as block size");

        poolSize = poolSizeInBytes;
        blockSize = blockSizeInBytes;

        // Align poolMemory to blockSize
        poolMemory = cast(ubyte*) alignedAllocate(poolSize, blockSize);
        if (poolMemory is null) {
            debug writefln("MemoryPool: Failed to allocate poolMemory");
            return;
        }
        debug writefln("MemoryPool: poolMemory allocated at %x", cast(size_t)poolMemory);

        // Initialize the freelist
        freeList = null;
        size_t numBlocks = poolSize / blockSize;
        debug writefln("MemoryPool: Initializing %d blocks", numBlocks);
        for (size_t i = 0; i < numBlocks; ++i) {
            ubyte* blockData = poolMemory + i * blockSize;
            auto block = cast(Block*) blockData;
            block.next = freeList;
            freeList = block;
            debug writefln("MemoryPool: Block %d initialized at %x", i, cast(size_t)block);
        }

        memoryTracker.trackAllocation(poolMemory, poolSize);
        debug writefln("MemoryPool: Initialization complete");
    }

    override void* allocate(size_t size, size_t alignment = 1, out AllocatorError error) @nogc @system {
        debug writefln("MemoryPool: Allocate called with size=%d, alignment=%d", size, alignment);
        if (size > blockSize || alignment > blockSize || (blockSize % alignment) != 0) {
            error = AllocatorError.InvalidAssignment;
            debug writefln("MemoryPool: Invalid allocation parameters");
            return null;
        }

        debug writefln("MemoryPool: Attempting to lock for allocation");
        poolLock.lock();
        debug writefln("MemoryPool: Lock acquired for allocation");
        Block* block = freeList;
        if (block !is null) {
            auto nextBlock = block.next;
            freeList = nextBlock;
            // Mark block as allocated by setting next to null
            block.next = null;
            block.isAllocated = true; // Sets the Allocation flag
            debug writefln("MemoryPool: Block at %x marked as allocated", cast(size_t)block);
            poolLock.unlock();
            void* ptr = cast(void*) block;
            error = AllocatorError.None;
            memoryTracker.trackAllocation(ptr, size);
            debug writefln("MemoryPool: Allocated block at %x", cast(size_t)ptr);
            return ptr;
        }
        poolLock.unlock();
        error = AllocatorError.OutOfMemory;
        debug writefln("MemoryPool: Allocation failed, out of memory");
        return null;
    }

    override bool deallocate(void* ptr, out AllocatorError error) @nogc @system nothrow {
        debug writefln("MemoryPool: Deallocate called with ptr=%x", cast(size_t)ptr);
        assert(cast(size_t)ptr % blockSize == 0, "Pointer is not aligned to block size");
        if (ptr is null) {
            debug writefln("MemoryPool: Deallocate called with null ptr");
            error = AllocatorError.None;
            return false;
        }

        size_t ptrAddr = cast(size_t) ptr;
        size_t poolStart = cast(size_t) poolMemory;
        size_t poolEnd = poolStart + poolSize;

        if (ptrAddr < poolStart || ptrAddr >= poolEnd) {
            debug writefln("MemoryPool: Ptr %x outside of pool range [%x, %x)", ptrAddr, poolStart, poolEnd);
            error = AllocatorError.InvalidAssignment;
            return false;
        }

        debug writefln("MemoryPool: Attempting to lock for deallocation");
        poolLock.lock();
        debug writefln("MemoryPool: Lock acquired for deallocation");
        
        auto block = cast(Block*) ptr;
        if (!block.isAllocated) {
            // Block is Already Freed
            debug writefln("MemoryPool: Block at %x is already freed", cast(size_t)block);
            poolLock.unlock();
            error = AllocatorError.InvalidAssignment;
            return false;
        }
        // Add block to freelist
        debug writefln("MemoryPool: Adding block at %x to freelist", cast(size_t)block);
        block.next = freeList;
        block.isAllocated = false;  // Clear the allocation flag
        debug writefln("MemoryPool: Block at %x marked as deallocated", cast(size_t)block);
        freeList = block;
        poolLock.unlock();
        debug writefln("MemoryPool: Lock released after deallocation");

        memoryTracker.trackDeallocation(ptr);
        error = AllocatorError.None;
        return true; 
    }

    /// Resets the memory pool, marking all blocks as free.
    override void reset() @nogc @system {
        debug writefln("MemoryPool: Reset called");
        poolLock.lock();
        debug writefln("MemoryPool: Lock acquired for reset");
        size_t numBlocks = poolSize / blockSize;
        freeList = null;
        for (size_t i = 0; i < numBlocks; ++i) {
            ubyte* blockData = poolMemory + i * blockSize;
            auto block = cast(Block*) blockData;
            block.next = freeList;
            block.isAllocated = false;  // Clear the allocation flag
            debug writefln("MemoryPool: Block at %x reset to deallocated state", cast(size_t)block);
            freeList = block;
            debug writefln("MemoryPool: Reset block %d at %x", i, cast(size_t)block);
        }
        poolLock.unlock();
        debug writefln("MemoryPool: Lock released after reset");

        memoryTracker.resetTracker();
        secureZeroMemory(poolMemory, poolSize);
        debug writefln("MemoryPool: Reset complete");
    }

    ~this() @nogc {
        debug writefln("MemoryPool: Destructor called");
        secureZeroMemory(poolMemory, poolSize);
        alignedDeallocate(cast(void*) poolMemory);
        memoryTracker.trackDeallocation(poolMemory);
        debug writefln("MemoryPool: Destructor complete");
    }
}