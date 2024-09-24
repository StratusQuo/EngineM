// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Read/Write Lock                                                 ║  
// ╚═══════════════════════════════════════════════════════════════════╝

module enginem.timing.ExponentialBackoff;

import core.thread : Thread;
import core.time : Duration, msecs;
import std.random : uniform;

/// ExponentialBackoff implements an exponential backoff algorithm.
/// It's useful for reducing contention in retry loops or when dealing with
/// external resources that might be temporarily unavailable.
struct ExponentialBackoff {
    private Duration baseDelay;    // The initial delay
    private Duration maxDelay;     // The maximum delay
    private Duration currentDelay; // The current delay

    /// Constructs an ExponentialBackoff instance.
    /// 
    /// Params:
    ///     base = The initial delay
    ///     max = The maximum delay
    @nogc this(Duration base, Duration max) nothrow {
        baseDelay = base;
        maxDelay = max;
        currentDelay = base;
    }

    /// Sleeps for the current delay and then increases it.
    @nogc void sleep() nothrow {
        Thread.sleep(currentDelay);
        currentDelay *= 2;  // Double the delay
        if (currentDelay > maxDelay) currentDelay = maxDelay;  // Cap at max delay
    }

    /// Resets the current delay to the initial base delay.
    @nogc void reset() nothrow {
        currentDelay = baseDelay;
    }
}

/// Retries an operation with exponential backoff.
/// 
/// Params:
///     operation = The operation to retry
@nogc void retryOperation(scope void delegate() @nogc nothrow operation) {
    auto backoff = ExponentialBackoff(1.msecs, 1000.msecs);
    while (true) {
        try {
            operation();
            return;
        } catch (Exception e) {
            backoff.sleep();
        }
    }
}

// Usage example:
// void someOperation() @nogc nothrow {
//     // Some operation that might fail temporarily
// }
// 
// retryOperation(&someOperation);