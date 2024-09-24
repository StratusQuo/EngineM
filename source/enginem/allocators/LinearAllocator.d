// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Linear Allocator                                                ║  
// ╚═══════════════════════════════════════════════════════════════════╝

module enginem.allocators.LinearAllocator;

import enginem.errors;
import enginem.allocators.Allocator;
import AllocatorTypes : AllocatorError;
import enginem.utils;
import core.stdc.stdlib : malloc, free;
import enginem : memoryTracker;

/// LinearAllocator allocates memory sequentially without supporting individual deallocations.
/// It allows resetting all allocations at once.
class LinearAllocator : Allocator {
private:
    ubyte* buffer;        // Start of the linear buffer
    size_t bufferSize;    // Total size of the buffer in bytes
    size_t offset;        // Current offset in the buffer

public:
    /// Constructs a LinearAllocator with a specified size.
    /// 
    /// @param size The total size of the linear buffer in bytes.
    static enum uint alignment = 8;
    this(size_t size) @nogc {
        buffer = cast(ubyte*) malloc(size);
        if (buffer is null) {
            // Handle allocation failure silently as we can't throw exceptions
        }
        bufferSize = size;
        offset = 0;
    }

    /// Allocates a memory block within the linear buffer.
    /// 
    /// @param size The size of the memory block in bytes.
    /// @param alignment The alignment requirement in bytes.
    /// @param error An out parameter to report any allocation errors.
    /// @return A pointer to the allocated memory block, or null if allocation fails.
    override void* allocate(size_t size, size_t alignment = 1, out AllocatorError error) @nogc @system nothrow {
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

    /// Deallocates a memory block. LinearAllocator does not support individual deallocations.
    /// 
    /// @param ptr A pointer to the memory block to deallocate.
    /// @param error An out parameter to report any deallocation errors.
    /// @return Always returns `false` as individual deallocation is not supported.
    override bool deallocate(void* ptr, out AllocatorError error) @nogc @system nothrow {
        // LinearAllocator does not support individual deallocation
        error = AllocatorError.None;
        return false;
    }

    /// Resets the allocator, deallocating all allocations at once.
    override void reset() @nogc @system nothrow {
        offset = 0;
        memoryTracker.resetTracker(); // Clears all tracked allocations
        secureZeroMemory(buffer, bufferSize);
    }

    /// Destructor securely zeros out the buffer and releases resources.
    ~this() @nogc {
        secureZeroMemory(buffer, bufferSize);
        free(buffer);
    }
}
