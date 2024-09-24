// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Read/Write Lock                                                 ║  
// ╚═══════════════════════════════════════════════════════════════════╝

module enginem.sync.ReadWriteLock;

import core.atomic;

/// ReadWriteLock provides a synchronization primitive that allows multiple readers
/// or a single writer to access a shared resource.
struct ReadWriteLock {
    private shared int readers = 0;  // Number of active readers
    private shared bool writer = false;  // Whether a writer is active

    /// Acquires a read lock. Multiple readers can hold the lock simultaneously.
    /// 
    /// This method will block if there's an active writer.
    @nogc @safe void readLock() nothrow {
        while (true) {
            while (atomicLoad(writer)) {} // Wait if there's a writer
            atomicOp!"+="(readers, 1);  // Increment reader count
            if (!atomicLoad(writer)) return; // Successfully acquired read lock
            atomicOp!"-="(readers, 1);  // Writer came in, back off and try again
        }
    }

    /// Releases a read lock.
    @nogc @safe void readUnlock() nothrow {
        atomicOp!"-="(readers, 1);  // Decrement reader count
    }

    /// Acquires a write lock. Only one writer can hold the lock at a time.
    /// 
    /// This method will block if there are active readers or another writer.
    @nogc @safe void writeLock() nothrow {
        while (!cas(&writer, false, true)) {} // Acquire writer lock
        while (atomicLoad(readers) > 0) {} // Wait for readers to finish
    }

    /// Releases a write lock.
    @nogc @safe void writeUnlock() nothrow {
        atomicStore(writer, false);  // Release writer lock
    }
}

// * | Usage example:
// auto rwLock = ReadWriteLock();
// 
// * | For read operations:
// rwLock.readLock();
// scope(exit) rwLock.readUnlock();
// * <Perform read_operation here>
// 
// * | For write operations:
// rwLock.writeLock();
// scope(exit) rwLock.writeUnlock();
// * <Perform write_operation here>