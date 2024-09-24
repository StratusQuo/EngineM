// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Stack Allocator                                                 ║  
// ╚═══════════════════════════════════════════════════════════════════╝

// allocators/StackAllocator.d
module enginem.allocators.StackAllocator;

import enginem.errors;
import enginem.allocators.Allocator;
import AllocatorTypes : AllocatorError;
import enginem.utils;
import core.stdc.stdlib : malloc, free;
import enginem : memoryTracker;

/// AllocationRecord keeps track of each allocation's offset and size for proper deallocation.
struct AllocationRecord {
    size_t offset;
    size_t size;
}

/// StackAllocator allocates memory in a stack-like fashion, supporting LIFO deallocations.
class StackAllocator : Allocator {
private:
    enum MAX_ALLOCATIONS = 1000; // Adjust as needed
    ubyte* start;             // Start of the stack buffer
    size_t totalSize;         // Total size of the stack in bytes
    size_t top;               // Current top of the stack
    AllocationRecord[MAX_ALLOCATIONS] allocationRecords; // Fixed-size array of allocation records
    size_t recordCount;       // Number of records currently in use
    static enum uint alignment = 8;

public:
    /// Constructs a StackAllocator with a specified size.
    /// 
    /// @param sizeInBytes The total size of the stack in bytes.
    this(size_t sizeInBytes) @nogc {
        start = cast(ubyte*) malloc(sizeInBytes);
        if (start is null) {
            // Handle allocation failure silently as we can't throw exceptions
        }
        totalSize = sizeInBytes;
        top = 0;
        recordCount = 0;
    }

    /// Allocates a memory block within the stack.
    /// 
    /// @param size The size of the memory block in bytes.
    /// @param alignment The alignment requirement in bytes.
    /// @param error An out parameter to report any allocation errors.
    /// @return A pointer to the allocated memory block, or null if allocation fails.
    override void* allocate(size_t size, size_t alignment = 1, out AllocatorError error) @nogc @system nothrow {
        size_t padding = (alignment - (top % alignment)) % alignment;
        if (top + padding + size > totalSize || recordCount >= MAX_ALLOCATIONS) {
            error = AllocatorError.StackOverflow;
            return null;
        }

        top += padding;
        void* ptr = start + top;
        top += size;

        allocationRecords[recordCount++] = AllocationRecord(top, size);
        memoryTracker.trackAllocation(ptr, size);
        error = AllocatorError.None;
        return ptr;
    }

    /// Deallocates the most recently allocated memory block.
    /// 
    /// @param ptr A pointer to the memory block to deallocate.
    /// @param error An out parameter to report any deallocation errors.
    /// @return `true` if deallocation was successful, `false` otherwise.
    override bool deallocate(void* ptr, out AllocatorError error) @nogc @system nothrow {
        if (ptr is null) {
            error = AllocatorError.None;
            return false;
        }

        if (recordCount == 0) {
            error = AllocatorError.StackUnderflow;
            return false;
        }

        AllocationRecord lastRecord = allocationRecords[recordCount - 1];
        size_t expectedOffset = lastRecord.offset - lastRecord.size;
        ubyte* expectedPtr = start + expectedOffset;

        if (cast(ubyte*)ptr != expectedPtr) {
            error = AllocatorError.StackUnderflow;
            return false;
        }

        // Pop the allocation record
        recordCount--;
        top = expectedOffset;

        memoryTracker.trackDeallocation(ptr);
        error = AllocatorError.None;
        return true; 
    }

    /// Resets the allocator, deallocating all allocations at once.
    override void reset() @nogc @system nothrow {
        top = 0;
        recordCount = 0;
        memoryTracker.resetTracker(); // Clears all tracked allocations
        secureZeroMemory(start, totalSize);
    }

    /// Destructor securely zeros out the stack and releases resources.
    ~this() @nogc {
        secureZeroMemory(start, totalSize);
        free(start);
    }
}
