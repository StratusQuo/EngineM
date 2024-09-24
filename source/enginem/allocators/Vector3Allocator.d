// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Vector3 Allocator                                               ║  
// ╚═══════════════════════════════════════════════════════════════════╝

// allocators/Vector3Allocator.d
module enginem.allocators.Vector3Allocator;

import std.traits;
import enginem.errors;
import enginem.allocators.Allocator;
import AllocatorTypes : AllocatorError;
import enginem.utils;
import enginem : memoryTracker;
import enginem.sync.SpinLock;

/// Vector3 structure representing a 3D vector.
struct Vector3 {
    double x;
    double y;
    double z;
}

/// Vector3Allocator is optimized for allocating and deallocating Vector3 objects.
/// It maintains a freelist to reuse memory blocks efficiently.
class Vector3Allocator : Allocator {
private:
    struct FreeNode {
        FreeNode* next;
    }

    FreeNode* freeList;       // Head of the freelist
    SpinLock freelistLock;    // SpinLock for thread safety

public:
    static enum uint alignment = Vector3.alignof; // Alignment
    
    /// Constructs a Vector3Allocator.
    this() @nogc {
        freeList = null;
    }

    /// Allocates a memory block for a Vector3 object.
    /// 
    /// @param size The size of the memory block (must match Vector3 size).
    /// @param alignment The alignment requirement (must match Vector3 alignment).
    /// @param error An out parameter to report any allocation errors.
    /// @return A pointer to the allocated Vector3 object, or null if allocation fails.
    override void* allocate(size_t size, size_t alignment = 1, out AllocatorError error) @nogc @system nothrow {
        if (size != Vector3.sizeof) {
            error = AllocatorError.InvalidAssignment;
            return null;
        }
        if (alignment > Vector3.alignof) {
            error = AllocatorError.InvalidAssignment;
            return null;
        }

        freelistLock.lock();
        scope(exit) freelistLock.unlock();

        if (freeList !is null) {
            // Reuse a block from the freelist
            FreeNode* node = freeList;
            freeList = freeList.next;
            memoryTracker.trackAllocation(node, size);
            error = AllocatorError.None;
            return node;
        }

        // Allocate a new Vector3 with proper alignment
        void* ptr = alignedAllocate(size, alignment);
        if (ptr is null) {
            error = AllocatorError.OutOfMemory;
            return null;
        }
        memoryTracker.trackAllocation(ptr, size);
        error = AllocatorError.None;
        return ptr;
    }

    /// Deallocates a previously allocated Vector3 object, adding it back to the freelist.
    /// 
    /// @param ptr A pointer to the Vector3 object to deallocate.
    /// @param error An out parameter to report any deallocation errors.
    /// @return `true` if deallocation was successful, `false` otherwise.
    override bool deallocate(void* ptr, out AllocatorError error) @nogc @system nothrow {
        if (ptr is null) {
            error = AllocatorError.None;
            return false;
        }

        freelistLock.lock();
        scope(exit) freelistLock.unlock();

        auto node = cast(FreeNode*) ptr;
        node.next = freeList;
        freeList = node;
        memoryTracker.trackDeallocation(ptr);
        error = AllocatorError.None;
        return true;
    }

    /// Resets the allocator by clearing the freelist.
    override void reset() @nogc @system nothrow {
        freelistLock.lock();
        scope(exit) freelistLock.unlock();

        // Optionally, iterate and deallocate all nodes if necessary
        freeList = null;
        memoryTracker.resetTracker(); // Clears all tracked allocations
    }

    /// Destructor securely zeros out the memory and releases resources.
    ~this() @nogc {
        // Optionally, iterate through the freelist and securely zero memory
        FreeNode* current = freeList;
        while (current !is null) {
            secureZeroMemory(current, Vector3.sizeof);
            current = current.next;
        }
        // No need to free individual blocks allocated via alignedAllocate
        // as they are managed elsewhere or will be freed upon program termination
    }
}
