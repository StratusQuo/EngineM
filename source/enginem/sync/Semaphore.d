// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Semaphore                                                       ║  
// ╚═══════════════════════════════════════════════════════════════════╝

module enginem.sync.Semaphore;

import core.atomic;
import core.thread : Thread;

/// Semaphore provides a synchronization primitive that can control access to a 
/// resource with multiple units or permits.
struct Semaphore {
    private shared int count;
    private int maxCount;

    /// Constructs a Semaphore with the specified number of permits.
    /// 
    /// Params:
    ///     initialCount = The initial number of permits available.
    ///     maxCount = The maximum number of permits (optional).
    @nogc this(int initialCount, int maxCount = int.max) nothrow {
        this.count = initialCount;
        this.maxCount = maxCount;
    }

    /// Acquires a permit from this semaphore, blocking until one is available.
    @nogc void acquire() nothrow {
        while (true) {
            int current = atomicLoad(count);
            if (current > 0 && cas(&count, current, current - 1)) {
                return;
            }
            Thread.yield();
        }
    }

    /// Releases a permit, returning it to the semaphore.
    @nogc void release() nothrow {
        while (true) {
            int current = atomicLoad(count);
            if (current < maxCount && cas(&count, current, current + 1)) {
                return;
            }
            Thread.yield();
        }
    }

    /// Tries to acquire a permit from this semaphore, returning immediately if one is not available.
    /// 
    /// Returns: true if a permit was acquired, false otherwise.
    @nogc bool tryAcquire() nothrow {
        int current = atomicLoad(count);
        return current > 0 && cas(&count, current, current - 1);
    }
}

// Usage example:
// auto sem = Semaphore(3);  // Semaphore with 3 permits
// 
// sem.acquire();
// scope(exit) sem.release();
// // Access the protected resource here