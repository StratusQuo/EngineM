// pointers/SharedPtr.d
module enginem.pointers.SharedPtr;

import automem.ref_counted;
import enginem.allocators.Allocator;
import enginem.utils;

/// SharedPtr allows multiple owners of the same object, managing its lifetime through reference counting.
/// 
/// @tparam T The type of the managed object.
/// @tparam A The allocator type used for object allocation (default is ArenaAllocator).
alias SharedPtr(T, AllocatorType = AllocatorWrapper!(ArenaAllocator)) = automem.ref_counted.RefCounted!(T, AllocatorType);

// Potential Enhancements:
// - Integrate weak pointers to prevent reference cycles.
// - Support custom deleters for specialized cleanup procedures.
// - Provide specialized aliases for different allocators as needed.
