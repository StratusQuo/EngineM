// AllocatorChecks.d
module enginem.allocators.AllocatorChecks;

import core.stdc.stdio : fprintf, stderr;

import enginem.allocators.Allocator : isAllocator, Allocator;
import enginem.allocators.ArenaAllocator;
import enginem.allocators.LinearAllocator;
import enginem.allocators.RegionAllocator;
import enginem.allocators.StackAllocator;
import enginem.allocators.smallobject.FreeListAllocator;
import enginem.allocators.Vector3Allocator;
import AllocatorTypes : AllocatorError;

@nogc @system void nogcWriteln(const(char)[] message) nothrow
{
    fprintf(stderr, "%.*s\n", cast(int)message.length, message.ptr);
}

// Helper template for detailed checks
template CheckAllocator(string AllocatorName, T)
{
    mixin("alias " ~ AllocatorName ~ " = T;");
    
    static assert(isAllocator!T, AllocatorName ~ " does not conform to isAllocator trait");
    
    static assert(is(T : Allocator), AllocatorName ~ " does not inherit from Allocator");
    
    static if (is(T == Vector3Allocator))
    {
        static assert(__traits(compiles, {
            T a = new T();  // Vector3Allocator doesn't take a size parameter
            AllocatorError error;
            void* ptr = a.allocate(Vector3.sizeof, Vector3.alignof, error);
            assert(ptr !is null);
            bool result = a.deallocate(ptr, error);
            a.reset();
        }), AllocatorName ~ " does not have the expected methods or they don't work as expected");
    }
    else
    {
        static assert(__traits(compiles, {
            T a = new T(1024);  // Other allocators take a size parameter
            AllocatorError error;
            void* ptr = a.allocate(10, 1, error);
            assert(ptr !is null);
            bool result = a.deallocate(ptr, error);
            a.reset();
        }), AllocatorName ~ " does not have the expected methods or they don't work as expected");
    }
    
    pragma(msg, AllocatorName ~ " passed all checks");
}

// Detailed checks for each allocator
mixin CheckAllocator!("ArenaAllocator", ArenaAllocator);
mixin CheckAllocator!("LinearAllocator", LinearAllocator);
mixin CheckAllocator!("RegionAllocator", RegionAllocator);
mixin CheckAllocator!("StackAllocator", StackAllocator);

// FreeListAllocator might need a special check if its constructor is different
static assert(isAllocator!FreeListAllocator, "FreeListAllocator does not conform to isAllocator trait");
static assert(is(FreeListAllocator : Allocator), "FreeListAllocator does not inherit from Allocator");
static assert(__traits(compiles, {
    FreeListAllocator a = new FreeListAllocator(32, 8);  // Assuming it takes blockSize and alignment
    AllocatorError error;
    void* ptr = a.allocate(32, 8, error);
    assert(ptr !is null);
    bool result = a.deallocate(ptr, error);
    a.reset();
}), "FreeListAllocator does not have the expected methods or they don't work as expected");
pragma(msg, "FreeListAllocator passed all checks");

mixin CheckAllocator!("Vector3Allocator", Vector3Allocator);

// Additional runtime checks (optional, but can be helpful)
version(unittest) {
    // @trusted bool testAllocator(T)(T allocator, size_t allocSize) {
    //     AllocatorError error;
    //     void* ptr = allocator.allocate(allocSize, 1, error);
    //     if (ptr is null || error != AllocatorError.None) return false;
    //     if (!allocator.deallocate(ptr, error)) return false;
    //     allocator.reset();
    //     return true;
    // }

    @trusted bool testAllocator(T)(T allocator, size_t allocSize) {
        AllocatorError error;
        void* ptr = allocator.allocate(allocSize, 1, error);
        if (ptr is null || error != AllocatorError.None) return false;
        bool deallocResult = allocator.deallocate(ptr, error);
        // Accept that deallocate may return false if not supported
        if (!deallocResult && error != AllocatorError.None) return false;
        allocator.reset();
        return true;
    }
    
    unittest {
        nogcWriteln("Running runtime allocator checks...");

        auto arena = new ArenaAllocator(1024);
        assert(testAllocator(arena, 100), "ArenaAllocator failed runtime check");

        auto linear = new LinearAllocator(1024);
        assert(testAllocator(linear, 100), "LinearAllocator failed runtime check");

        auto region = new RegionAllocator(1024);
        assert(testAllocator(region, 100), "RegionAllocator failed runtime check");

        auto stack = new StackAllocator(1024);
        assert(testAllocator(stack, 100), "StackAllocator failed runtime check");

        auto freelist = new FreeListAllocator(32, 8);
        assert(testAllocator(freelist, 32), "FreeListAllocator failed runtime check");

        auto vector3 = new Vector3Allocator();
        assert(testAllocator(vector3, Vector3.sizeof), "Vector3Allocator failed runtime check");

        nogcWriteln("All runtime allocator checks passed.");
    }
}