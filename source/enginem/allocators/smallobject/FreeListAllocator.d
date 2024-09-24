// allocators/smallobject/FreeListAllocator.d
module enginem.allocators.smallobject.FreeListAllocator;

import std.traits;
import enginem.sync.SpinLock;
import enginem.errors;
import enginem.allocators.Allocator;
import AllocatorTypes : AllocatorError;
import enginem.utils;
import enginem : memoryTracker;

/// FreeListAllocator is optimized for allocating and deallocating fixed-size objects.
/// It maintains a freelist to reuse memory blocks efficiently.
class FreeListAllocator : Allocator {
public:
    /// Internal node structure for the freelist.
    struct FreeNode {
        FreeNode* next;
    }

    FreeNode* freeList;             // Head of the freelist
    size_t objectSize;              // Size of each object
    size_t alignment;               // Alignment requirement
    size_t capacity;                // Maximum capacity of the allocator
    size_t allocatedMemory = 0;     // Track currently allocated memory
    SpinLock freelistLock;          // SpinLock for thread safety

public:
    /// Constructs a FreeListAllocator with specified object size, alignment, and capacity.
    /// 
    /// @param objectSize The size of each object in bytes.
    /// @param alignment The alignment requirement in bytes (default is 8).
    /// @param capacity The maximum capacity of the allocator in bytes.
    this(size_t objectSize, size_t alignment = 8, size_t capacity = size_t.max) @nogc {
        assert(isPowerOfTwo(alignment), "Alignment must be a power of two");
        this.objectSize = objectSize;
        this.alignment = alignment; 
        this.capacity = capacity;
        freeList = null;
    }

    /// Allocates a memory block for an object.
    /// 
    /// @param size The size of the memory block (must match objectSize).
    /// @param alignment The alignment requirement (must match allocator's alignment).
    /// @param error An out parameter to report any allocation errors.
    /// @return A pointer to the allocated memory block, or null if allocation fails.
    override void* allocate(size_t size, size_t alignment = 1, out AllocatorError error) @nogc @system nothrow {
        debug { 
            import std.stdio : writeln;
            writeln("Entering allocate, size: ", size, ", alignment: ", alignment); 
        }

        // Handle zero capacity: 
        if (capacity == 0) { 
            error = AllocatorError.OutOfMemory;
            debug {
                import std.stdio : writeln;
                writeln("Exiting allocate, capacity is zero, error: ", error); 
            }
            return null;
        }

        // Check if the requested size is smaller than the object size
        if (size < objectSize) {
            error = AllocatorError.InvalidAssignment;
            debug {
                import std.stdio : writeln;
                writeln("Exiting allocate early (size too small), error: ", error);
            }
            return null;
        }

        // Check if the requested alignment is larger than the allocator's alignment
        if (alignment > this.alignment) {
            error = AllocatorError.InvalidAssignment;
            debug {
                import std.stdio : writeln;
                writeln("Exiting allocate early (alignment too large), error: ", error);
            }
            return null;
        }

        // Round up size to the next multiple of alignment
        size_t alignedSize = (size + alignment - 1) & ~(alignment - 1);

        // Check if the aligned size is within the object size
        if (alignedSize > objectSize) {
            error = AllocatorError.InvalidAssignment;
            debug {
                import std.stdio : writeln;
                writeln("Exiting allocate early (size too large), error: ", error); 
            }
            return null;
        }

        freelistLock.lock();
        scope(exit) freelistLock.unlock();

        if (freeList !is null) {
            // Reuse a block from the freelist
            FreeNode* node = freeList;
            freeList = freeList.next;

            memoryTracker.trackAllocation(node, objectSize);
            error = AllocatorError.None;
            debug {
                import std.stdio : writeln;
                writeln("Exiting allocate from free list, error: ", error); 
            }
            return node; 
        } else {
            // Free list is empty, allocate new memory if capacity allows:
            if (allocatedMemory + objectSize > capacity) {
                error = AllocatorError.OutOfMemory;
                debug {
                    import std.stdio : writeln;
                    writeln("Exiting allocate, capacity reached, error: ", error); 
                }
                return null;
            }

            void* ptr = alignedAllocate(objectSize, this.alignment);
            if (ptr is null) {
                error = AllocatorError.OutOfMemory;
                debug {
                    import std.stdio : writeln;
                    writeln("Exiting allocate, ptr is null, error: ", error); 
                }
                return null;
            }

            allocatedMemory += objectSize; // Update allocated memory
            memoryTracker.trackAllocation(ptr, objectSize);
            error = AllocatorError.None;
            debug {
                import std.stdio : writeln;
                writeln("Exiting allocate, ptr: ", ptr, " error: ", error); 
            }
            return ptr;
        }
    }

    /// Deallocates a previously allocated memory block, adding it back to the freelist.
    /// 
    /// @param ptr A pointer to the memory block to deallocate.
    /// @param error An out parameter to report any deallocation errors.
    /// @return `true` if deallocation was successful, `false` otherwise.
    override bool deallocate(void* ptr, out AllocatorError error) @nogc @system nothrow {
        debug {
            import std.stdio : writeln;
            writeln("Entering deallocate, ptr: ", ptr);
        }
        if (ptr is null) {
            error = AllocatorError.None;
            debug {
                import std.stdio : writeln;
                writeln("Exiting deallocate early because ptr is null"); 
            }
            return false;
        }

        freelistLock.lock();
        debug {
            import std.stdio : writeln;
            writeln("Acquired freelistLock in deallocate");
        }
        auto node = cast(FreeNode*) ptr;
        node.next = freeList;
        freeList = node;
        freelistLock.unlock();
        debug {
            import std.stdio : writeln;
            writeln("Released freelistLock deallocate");
        }

        allocatedMemory -= objectSize; // Update allocated memory after successful deallocation
        memoryTracker.trackDeallocation(ptr);
        error = AllocatorError.None;
        debug {
            import std.stdio : writeln;
            writeln("Exiting deallocate");
        }
        return true;
    }

    /// Resets the allocator by clearing the freelist.
    override void reset() @nogc @system nothrow {
        freelistLock.lock();
        // Optionally, iterate and deallocate all nodes if necessary
        freeList = null;
        allocatedMemory = 0; // Reset allocated memory on reset
        freelistLock.unlock();
        
        memoryTracker.resetTracker(); // Clears all tracked allocations
    }

    /// Destructor securely zeros out the memory and releases resources.
    ~this() @nogc {
        // Optionally, iterate through the freelist and securely zero memory
        FreeNode* current = freeList;
        while (current !is null) {
            secureZeroMemory(current, objectSize);
            current = current.next;
        }
        // No need to free individual blocks allocated via alignedAllocate
        // as they are managed elsewhere or will be freed upon program termination
    }
}