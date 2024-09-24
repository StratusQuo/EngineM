// errors.d 
module enginem.errors;

import std.exception;
import std.format;
import std.conv : to;
import core.stdc.stdio : snprintf;

//==================================================
// Base Class
//==================================================

/// Base class for all custom memory-related errors.

class MemoryError : Exception {
    private enum MAX_MSG_LEN = 256;
    private char[MAX_MSG_LEN] msgBuffer;

    /// Constructs a MemoryError with a message, file, and line number.
    /// @nogc ensures no garbage collection
    @nogc this(const(char)[] msg, string file = __FILE__, size_t line = __LINE__) {
        import core.stdc.stdio : snprintf;
        int len = snprintf(msgBuffer.ptr, MAX_MSG_LEN, 
                           "MemoryError: %.*s | File: %.*s | Line: %zu",
                           cast(int)msg.length, msg.ptr,
                           cast(int)file.length, file.ptr,
                           line);
        super(cast(string)msgBuffer[0 .. (len >= 0 ? len : 0)]);
    }
}


//==================================================
// Allocation Errors
//==================================================

/// Represents errors related to memory allocation failures.
class AllocationError : MemoryError {
    private enum MAX_MSG_LEN = 256;
    private char[MAX_MSG_LEN] msgBuffer;

    @nogc this(const(char)[] msg, string file = __FILE__, size_t line = __LINE__) {
        import core.stdc.stdio : snprintf;
        int len = snprintf(msgBuffer.ptr, MAX_MSG_LEN, 
                           "AllocationError: %.*s | File: %.*s | Line: %zu",
                           cast(int)msg.length, msg.ptr,
                           cast(int)file.length, file.ptr,
                           line);
        super(cast(string)msgBuffer[0 .. (len >= 0 ? len : 0)], file, line);
    }
}



/// Represents an out-of-memory error.
class OutOfMemoryError : AllocationError {
    /// Constructs an OutOfMemoryError.
    this(string file = __FILE__, size_t line = __LINE__) {
        super(format("OutOfMemoryError: Failed to allocate memory | File: %s | Line: %s", file, to!string(line)));
    }
}

/// Represents errors related to alignment failures.
class AlignmentError : AllocationError {
    /// Constructs an AlignmentError with details.
    this(size_t size, size_t alignment, string file = __FILE__, size_t line = __LINE__) {
        super(format("AlignmentError: Failed to allocate %s bytes with alignment %s bytes | File: %s | Line: %s",
                    to!string(size), to!string(alignment), file, to!string(line)));
    }
}

/// Represents errors when a memory pool is exhausted.
class PoolExhaustedError : MemoryError {
    /// Constructs a PoolExhaustedError.
    this(string file = __FILE__, size_t line = __LINE__) {
        super(format("PoolExhaustedError: Memory pool exhausted | File: %s | Line: %s", file, to!string(line)));
    }
}

/// Represents errors when a requested block size exceeds the pool's block size.
class InvalidBlockSizeError : PoolExhaustedError {
    /// Constructs an InvalidBlockSizeError with details.
    this(size_t requestedSize, size_t blockSize, string file = __FILE__, size_t line = __LINE__) 
    {
        super(format("InvalidBlockSizeError: Requested size (%s bytes) exceeds memory pool block size (%s bytes) | File: %s | Line: %s", 
                    to!string(requestedSize), to!string(blockSize), file, to!string(line)));
    }
}

/// Base class for freelist-related errors.
class FreeListError : MemoryError {
    /// Constructs a FreeListError with a message, file, and line number.
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(format("FreeListError: %s | File: %s | Line: %s", msg, file, to!string(line)));
    }
}

/// Represents errors when attempting to allocate from an empty freelist.
class EmptyFreeListError : FreeListError {
    /// Constructs an EmptyFreeListError.
    this(string file = __FILE__, size_t line = __LINE__) {
        super(format("EmptyFreeListError: Cannot allocate from an empty freelist | File: %s | Line: %s", file, to!string(line)));
    }
}

/// Represents errors when an invalid pointer is provided for freelist deallocation.
class InvalidFreeListPointerError : FreeListError {
    /// Constructs an InvalidFreeListPointerError with details.
    this(void* ptr, string file = __FILE__, size_t line = __LINE__) {
        string ptrStr = format("0x%x", cast(ulong) ptr);
        super(format("InvalidFreeListPointerError: Invalid pointer (%s) provided for freelist deallocation | File: %s | Line: %s", 
                    ptrStr, file, to!string(line)));
    }
}

/// Represents errors when a stack overflow occurs.
class StackOverflowError : MemoryError {
    /// Constructs a StackOverflowError.
    this(string file = __FILE__, size_t line = __LINE__) {
        super(format("StackOverflowError: Attempt to allocate beyond stack capacity | File: %s | Line: %s", file, to!string(line)));
    }
}

/// Represents errors when a stack underflow occurs.
class StackUnderflowError : MemoryError {
    /// Constructs a StackUnderflowError.
    this(string file = __FILE__, size_t line = __LINE__) {
        super(format("StackUnderflowError: Attempt to deallocate more than available | File: %s | Line: %s", file, to!string(line)));
    }
}

/// Base class for region-related errors.
class RegionError : MemoryError {
    /// Constructs a RegionError with a message, file, and line number.
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(format("RegionError: %s | File: %s | Line: %s", msg, file, to!string(line)));
    }
}

/// Represents errors when region allocation fails.
class RegionAllocationError : RegionError { 
    /// Constructs a RegionAllocationError.
    this(string file = __FILE__, size_t line = __LINE__) {
        super(format("RegionAllocationError: Failed to allocate memory for region | File: %s | Line: %s", file, to!string(line)));
    }
}

/// Represents errors when region destruction fails.
class RegionDestructionError: RegionError {
    /// Constructs a RegionDestructionError.
    this(string file = __FILE__, size_t line = __LINE__) {
        super(format("RegionDestructionError: Failed to destroy memory region | File: %s | Line: %s", file, to!string(line)));
    }
}

/// Base class for memory tracking-related errors.
class MemoryTrackingError : MemoryError {
    /// Constructs a MemoryTrackingError with a message, file, and line number.
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(format("MemoryTrackingError: %s | File: %s | Line: %s", msg, file, to!string(line)));
    }
}

/// Represents errors when attempting to track a duplicate allocation.
class DuplicateAllocationTrackingError : MemoryTrackingError {
    /// Constructs a DuplicateAllocationTrackingError with details.
    this(void* ptr, string file = __FILE__, size_t line = __LINE__) {
        string ptrStr = format("0x%x", cast(ulong) ptr);
        super(format("DuplicateAllocationTrackingError: Attempt to track a duplicate allocation at address %s | File: %s | Line: %s", 
                    ptrStr, file, to!string(line)));
    }
}

/// Represents errors when attempting to untrack a non-existent allocation.
class UntrackedDeallocationError : MemoryTrackingError {
    /// Constructs an UntrackedDeallocationError with details.
    this(void* ptr, string file = __FILE__, size_t line = __LINE__) {
        string ptrStr = format("0x%x", cast(ulong) ptr);
        super(format("UntrackedDeallocationError: Attempt to untrack a non-existent allocation at address %s | File: %s | Line: %s", 
                    ptrStr, file, to!string(line)));
    }
}

// TODO: Add More Error Types