// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   CountdownEvent                                                  ║  
// ╚═══════════════════════════════════════════════════════════════════╝

module enginem.sync.CountdownEvent;

import core.atomic;
import core.thread : Thread;

/// CountdownEvent provides a synchronization primitive that unblocks waiting threads 
/// after it has been signaled a specific number of times.
struct CountdownEvent {
    private shared int count;

    /// Constructs a CountdownEvent with the specified initial count.
    /// 
    /// Params:
    ///     initialCount = The number of signals required before the event is set.
    @nogc this(int initialCount) nothrow {
        count = initialCount;
    }

    /// Signals the event, decrementing the count.
    /// 
    /// Returns: true if the count reaches zero, false otherwise.
    @nogc bool signal() nothrow {
        while (true) {
            int current = atomicLoad(count);
            if (current == 0) return true;
            if (cas(&count, current, current - 1)) {
                return current == 1;
            }
        }
    }

    /// Blocks until the event is set (the count reaches zero).
    @nogc void wait() nothrow {
        while (atomicLoad(count) > 0) {
            Thread.yield();
        }
    }

    /// Resets the event to the specified count.
    @nogc void reset(int newCount) nothrow {
        atomicStore(count, newCount);
    }
}

// Usage example:
// auto countdown = CountdownEvent(3);
// 
// // In multiple threads:
// // Do some work
// if (countdown.signal()) {
//     // This thread decremented the count to zero
// }
// 
// // In waiting thread:
// countdown.wait();
// // The count has reached zero