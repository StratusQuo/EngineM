// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Allocator                                                       ║  
// ╚═══════════════════════════════════════════════════════════════════╝

module enginem.allocators.Allocator;

import std.exception;
import std.experimental.allocator.common : stateSize;

import enginem.allocators.ArenaAllocator;
import enginem.allocators.LinearAllocator;
import enginem.allocators.RegionAllocator;
import enginem.allocators.StackAllocator;
import enginem.allocators.smallobject.FreeListAllocator;
import enginem.allocators.Vector3Allocator;

import AllocatorTypes : AllocatorError;

/// Abstract Allocator interface defining essential memory management operations.
abstract class Allocator {
    // Initialize the Error Interface
    AllocatorError lastError = AllocatorError.None;

    /// Allocates a block of memory with the specified size and alignment.
    /// 
    /// @param size The size of the memory block in bytes.
    /// @param alignment The alignment requirement in bytes (must be a power of two).
    /// @return A pointer to the allocated memory block.
    abstract void* allocate(size_t size, size_t alignment = 1, out AllocatorError error) @nogc @system nothrow;

    /// Deallocates a previously allocated block of memory.
    /// 
    /// @param ptr A pointer to the memory block to deallocate.
    /// @return `true` if deallocation was successful, `false` otherwise.
    abstract bool deallocate(void* ptr, out AllocatorError error) @nogc @system nothrow;

    /// Resets the allocator, deallocating all managed memory.
    abstract void reset() @nogc @system nothrow;
}

// isAllocator trait
template isAllocator(T)
{
    enum bool isAllocator = is(typeof((T t) {
        size_t a = 1;
        AllocatorError error;
        void* ptr = t.allocate(a, 1, error);
        assert(ptr !is null);
        bool result = t.deallocate(ptr, error);
        t.reset();
    }));
}

// Wrapper struct for compatibility with Automem
// Adjusted AllocatorWrapper
struct AllocatorWrapper(T) if (isAllocator!T)
{
    T* allocator;

    void[] allocate(size_t bytes) @nogc @system nothrow {
        AllocatorError error;
        void* ptr = allocator.allocate(bytes, T.alignment, error);
        return (error == AllocatorError.None && ptr !is null) ? ptr[0 .. bytes] : null;
    }

    bool deallocate(void[] b) @nogc @system nothrow {
        if (b.ptr is null) return false;
        AllocatorError error;
        return allocator.deallocate(b.ptr, error);
    }

    enum uint alignment = T.alignment;

    void reset() @nogc @system nothrow {
        allocator.reset();
    }
}



// Function to create an AllocatorWrapper
auto wrapAllocator(T)(T* allocator) if (isAllocator!T)
{
    return AllocatorWrapper!T(allocator);
}

// Static assertions to ensure allocators conform to the isAllocator trait
static assert(isAllocator!ArenaAllocator, "ArenaAllocator does not conform to isAllocator");
static assert(isAllocator!LinearAllocator, "LinearAllocator does not conform to isAllocator");
static assert(isAllocator!RegionAllocator, "RegionAllocator does not conform to isAllocator");
static assert(isAllocator!StackAllocator, "StackAllocator does not conform to isAllocator");
static assert(isAllocator!FreeListAllocator, "FreeListAllocator does not conform to isAllocator");
static assert(isAllocator!Vector3Allocator, "Vector3Allocator does not conform to isAllocator");