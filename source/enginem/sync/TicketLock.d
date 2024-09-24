// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Ticket Lock                                                     ║  
// ╚═══════════════════════════════════════════════════════════════════╝

module enginem.sync.TicketLock;

import core.atomic;

/// TicketLock provides a first-come, first-served synchronization primitive.
/// It ensures fairness by giving each thread a ticket and serving them in order.
struct TicketLock {
    private shared uint next_ticket = 0;  // The next ticket to be issued
    private shared uint now_serving = 0;  // The current ticket being served

    /// Acquires the lock. Each call receives a unique ticket and waits until that ticket is served.
    @nogc @safe void lock() nothrow {
        uint my_ticket = atomicOp!"+="(next_ticket, 1) - 1;  // Get a ticket
        while (atomicLoad(now_serving) != my_ticket) {
            // Busy-wait until our ticket is served
            // TODO: Optionally add a small delay or yield here to reduce contention
        }
    }

    /// Releases the lock, allowing the next ticket holder to acquire it.
    @nogc @safe void unlock() nothrow {
        atomicOp!"+="(now_serving, 1);  // Serve the next ticket
    }
}

// Usage example:
// auto ticketLock = TicketLock();
// 
// ticketLock.lock();
// scope(exit) ticketLock.unlock();
// // Critical section here