// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Barrier                                                         ║  
// ╚═══════════════════════════════════════════════════════════════════╝

module enginem.sync.Barrier;

import core.atomic;
import core.thread : Thread;

/// Barrier provides a synchronization point where multiple threads can wait for each other.
struct Barrier {
    private shared int count;
    private int totalThreads;
    private shared int generation;

    /// Constructs a Barrier for the specified number of threads.
    /// 
    /// Params:
    ///     n = The number of threads that must call await() before the barrier is lifted.
    @nogc this(int n) nothrow {
        totalThreads = n;
        count = n;
        generation = 0;
    }

    /// Waits until all threads have called await() on this barrier.
    @nogc void await() nothrow {
        int arrivalGeneration = atomicLoad(generation);
        if (atomicOp!"-="(count, 1) == 0) {
            // Last thread to arrive
            atomicStore(count, totalThreads);
            atomicOp!"+="(generation, 1);
        } else {
            // Wait for this generation to complete
            while (arrivalGeneration == atomicLoad(generation)) {
                Thread.yield();
            }
        }
    }
}

// Usage example:
// shared Barrier barrier = Barrier(3);
// 
// // In each thread:
// // Do some work
// barrier.await();
// // All threads have reached this point