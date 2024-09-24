// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Arena Allocator                                                 ║  
// ╚═══════════════════════════════════════════════════════════════════╝


module enginem.allocators.ArenaAllocator;

import core.stdc.stdlib;
import std.traits;
import enginem.errors;
import enginem.allocators.Allocator;
import AllocatorTypes : AllocatorError;
import enginem.utils;
import enginem : memoryTracker;
import enginem.utils : secureZeroMemory;
import core.stdc.stdlib : malloc, free;
import core.stdc.string : memset;

/// ArenaAllocator allocates memory in a contiguous arena, allowing efficient allocations
/// and bulk deallocations by resetting the arena.

class ArenaAllocator : Allocator {
    private ubyte* buffer;
    private size_t bufferSize;
    private size_t offset;
    public static enum uint alignment = 8;

    @nogc:
    this(size_t size) {
        buffer = cast(ubyte*)malloc(size);
        if (buffer is null) {
            lastError = AllocatorError.OutOfMemory;
            return;
        }
        bufferSize = size;
        offset = 0;
    }

    override void* allocate(size_t size, size_t alignment = 1, out AllocatorError error) @nogc @system nothrow {
        if (buffer is null) {
            error = AllocatorError.OutOfMemory;
            return null;
        }

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

    override bool deallocate(void* ptr, out AllocatorError error) @nogc @system nothrow {
        // ArenaAllocator doesn't support individual deallocation
        error = AllocatorError.None;
        debug import std.stdio : writefln;
        debug writefln("ArenaAllocator: Attempted to deallocate %x", cast(size_t)ptr);
        memoryTracker.trackDeallocation(ptr);  // Add this line
        return false;
    }

    override void reset() @nogc @system nothrow {
        offset = 0;
        memoryTracker.resetTracker();
        memset(buffer, 0, bufferSize);
    }

    ~this() {
        if (buffer !is null) {
            secureZeroMemory(buffer, bufferSize);
            free(buffer);
        }
    }
}