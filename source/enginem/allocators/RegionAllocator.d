// RegionAllocator.d
module enginem.allocators.RegionAllocator;

import enginem.errors;
import enginem.allocators.Allocator;
import enginem.utils;
import std.traits;
import AllocatorTypes : AllocatorError;
import core.stdc.stdlib : malloc, free;
import enginem : memoryTracker;

/// RegionAllocator allocates memory within a fixed-size region, allowing for fast allocations.
/// It does not support individual deallocations but can reset the entire region.
class RegionAllocator : Allocator {
private:
    ubyte* buffer;        // Start of the region
    size_t bufferSize;    // Total size of the region in bytes
    size_t offset;        // Current offset within the region

public:
    /// Constructs a RegionAllocator with a specified size.
    /// 
    /// @param size The total size of the region in bytes.
    this(size_t size) @nogc nothrow {
        buffer = cast(ubyte*) malloc(size);
        if (buffer is null) {
            // Handle allocation failure silently as we can't throw exceptions
            return;
        }
        bufferSize = size;
        offset = 0;
    }

    /// Gets the total size of the region in bytes.
    @property size_t size() const @nogc nothrow {
        return bufferSize;
    }

    /// Gets the current offset within the region.
    @property size_t currentOffset() const @nogc nothrow {
        return offset;
    }

    /// Allocates a memory block within the region.
    /// 
    /// @param size The size of the memory block in bytes.
    /// @param alignment The alignment requirement in bytes.
    /// @param error An out parameter to report any allocation errors.
    /// @return A pointer to the allocated memory block, or null if allocation fails.
    override void* allocate(size_t size, size_t alignment = 1, out AllocatorError error) @nogc @system {
        size_t padding = (alignment - (offset % alignment)) % alignment;
        if (offset + padding + size > bufferSize) {
            error = AllocatorError.OutOfMemory;
            return null;
        }

        offset += padding;
        void* ptr = buffer + offset;
        offset += size;

        memoryTracker.trackAllocation(ptr, size);
        error = AllocatorError.None;
        return ptr;
    }

    /// Deallocates a memory block. RegionAllocator does not support individual deallocations.
    /// 
    /// @param ptr A pointer to the memory block to deallocate.
    /// @param error An out parameter to report any deallocation errors.
    /// @return Always returns `false` as individual deallocation is not supported.
    override bool deallocate(void* ptr, out AllocatorError error) @nogc @system nothrow {
        // RegionAllocator does not support individual deallocation
        error = AllocatorError.None;
        return false; 
    }

    /// Resets the allocator, deallocating all allocations at once.
    override void reset() @nogc @system nothrow {
        offset = 0;
        memoryTracker.resetTracker(); // Clears all tracked allocations
        secureZeroMemory(buffer, bufferSize);
    }

    /// Destructor securely zeros out the region and releases resources.
    ~this() @nogc {
        secureZeroMemory(buffer, bufferSize);
        free(buffer);
    }
}
