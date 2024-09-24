// Main Entry File (source/enginem.d)
module enginem;

import enginem.allocators.AllocatorChecks;

public import enginem.allocators.Allocator;
public import enginem.allocators.ArenaAllocator;
public import enginem.allocators.LinearAllocator;
public import enginem.allocators.RegionAllocator;
public import enginem.allocators.StackAllocator;
public import enginem.allocators.Vector3Allocator;
public import enginem.allocators.smallobject.FreeListAllocator;
public import enginem.errors;
public import enginem.pointers.SharedPtr;
public import enginem.pointers.UniquePtr;
public import enginem.pool;
public import enginem.utils;
public import enginem.tracking.MemoryTracker : MemoryTracker;

public static MemoryTracker memoryTracker;

// Create a global MemoryTracker instance:
static this()
{
    memoryTracker = new MemoryTracker();
}


//! Immutable Instance (Not Working Yet):
//public static immutable MemoryTracker memoryTracker = new MemoryTracker();




