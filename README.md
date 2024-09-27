# Engine M: Flexible Memory Management for D

EngineM is a D library designed to make writing `@nogc` code a _bit_ easier. 

> :warning: **Warning: Alpha Release**: I would urge caution before using this in *any* production build until further testing is done.

## Features

EngineM provides a quite a few allocators, as well as some memory management utilities to cater to various needs:

**Allocators:**

- **ArenaAllocator:** Efficiently allocate memory in a contiguous block, ideal for short-lived objects within a defined scope.
- **LinearAllocator:** Allocate memory sequentially, suitable for situations where deallocation is not required or handled in bulk.
- **StackAllocator:** Implements a stack-based allocation scheme with LIFO (Last-In, First-Out) deallocation.
- **FreeListAllocator:** Optimized for allocating and deallocating fixed-size objects, ideal for memory pools.
- **RegionAllocator:** Allocates from a fixed-size region of memory, without individual deallocations.
- **Vector3Allocator:** Special-purpose allocator tailored for the `Vector3` structure, optimizing allocations and deallocations.

**Memory Tools:**

- **UniquePtr:** Implements unique ownership semantics, ensuring that the managed object is automatically deallocated when the pointer goes out of scope.
- **SharedPtr:** Enables shared ownership of objects through reference counting.
- **MemoryPool:** Manages a pool of fixed-size blocks for efficient allocation and deallocation of small objects.
- **MemoryTracker:** Tracks all memory allocations and deallocations, helping you debug memory leaks and understand memory usage patterns.

**Synchronization Primitives:**

- **SpinLock:**  A lightweight lock suitable for short-lived critical sections.
- **TicketLock:** A fair lock that uses tickets to ensure first-come, first-served acquisition.
- **ReadWriteLock:** Allows multiple readers or a single writer to access a shared resource, suitable for optimizing performance when reads are more frequent than writes.
- **Semaphore:** Controls access to a limited number of resources.
- **Barrier:**  Synchronizes multiple threads, making them wait for each other at a specific point.
- **CountDownEvent:** A synchronization mechanism that unblocks waiting threads after it has been signaled a specified number of times.

**Utilities:**

- **Alignment and Power-of-Two Checks:** Functions to check for proper alignment and power-of-two values.
- **Memory Copy and Set:** Optimized memory operations for copying and setting memory blocks.
- **Bit Manipulation:**  Functions for counting leading and trailing zeros, counting set bits, and manipulating bit fields.
- **Thread-Safe Utilities:** Functions for atomic operations, reference counting, and managing memory blocks in a thread-safe manner.

## Installation

You can install EngineM using [Dub](https://code.dlang.org/getting_started#package-manager):

```bash
dub add enginem
```
└── _Note: You may need to clone the repo first, and add it to your project locally for the time being._

## Getting Started

Here is a simple example of using the ArenaAllocator:

```d
import enginem.allocators.ArenaAllocator;

void main() {
    // Create an arena with a capacity of 1024 bytes
    auto arena = new ArenaAllocator(1024);

    // Allocate memory for an integer
    int* intPtr = cast(int*) arena.allocate(int.sizeof, int.alignof);

    // Assign a value
    *intPtr = 42;

    // Use the allocated memory
    // ...

    // The memory will be deallocated automatically when the arena goes out of scope
}
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

EngineM is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
