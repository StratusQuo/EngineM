// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Spin Lock                                                       ║  
// ╚═══════════════════════════════════════════════════════════════════╝

module enginem.sync.SpinLock;

import core.atomic;
import core.thread : Thread;

/// SpinLock provides a lightweight, busy-waiting synchronization primitive.
/// It's useful for protecting short critical sections where the overhead
/// of blocking might be higher than the cost of spinning.
struct SpinLock {
    private shared int locked = 0;

    @nogc @trusted void lock() const nothrow {
        debug import std.stdio : writefln;
        debug writefln("SpinLock: Attempting to acquire lock");
        int attempts = 0;
        while (!cas(cast(shared int*)&locked, 0, 1)) {
            Thread.yield();
            attempts++;
            if (attempts % 1000 == 0) {
                debug writefln("SpinLock: Still waiting to acquire lock after %d attempts", attempts);
            }
        }
        debug writefln("SpinLock: Lock acquired after %d attempts", attempts);
    }

    @nogc @trusted void unlock() const nothrow {
        debug import std.stdio : writefln;
        debug writefln("SpinLock: Releasing lock");
        atomicStore!(MemoryOrder.rel)(*cast(shared int*)&locked, 0);
        debug writefln("SpinLock: Lock released");
    }
}

// Usage example:
// auto spinLock = SpinLock();
// 
// spinLock.lock();
// scope(exit) spinLock.unlock();
// // Critical section here
// 
// // Or with tryLock:
// if (spinLock.tryLock()) {
//     scope(exit) spinLock.unlock();
//     // Critical section here
// }