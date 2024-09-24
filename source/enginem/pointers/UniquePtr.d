// pointers/UniquePtr.d
module enginem.pointers.UniquePtr;

import automem.unique;
import enginem.allocators.Allocator;
import enginem.utils;

/// UniquePtr provides exclusive ownership of an object, ensuring proper deallocation.
/// 
/// @tparam T The type of the managed object.
/// @tparam A The allocator type used for object allocation (default is ArenaAllocator).
alias UniquePtr(T, AllocatorType = AllocatorWrapper!(ArenaAllocator)) = automem.unique.Unique!(T, AllocatorType);

// Potential Enhancements:
// - Integrate secureZeroMemory during deallocation for sensitive data.
// - Add specialized aliases for different allocators like LinearAllocator, PoolAllocator, etc.
// - Implement custom deleters if Automem supports them.
