// ╔═══════════════════════════════════════════════════════════════════╗ 
// ║   Time Limiter                                                    ║  
// ╚═══════════════════════════════════════════════════════════════════╝

module enginem.timing.TimeLimiter;

import core.time : MonoTime, Duration;

/// TimeLimiter provides a mechanism to limit the execution time of operations.
struct TimeLimiter {
    private Duration timeout;  // The maximum allowed duration
    private MonoTime startTime;  // The time when the limiter was created or reset

    /// Constructs a TimeLimiter instance.
    /// 
    /// Params:
    ///     timeout = The maximum allowed duration
    @nogc this(Duration timeout) nothrow {
        this.timeout = timeout;
        this.startTime = MonoTime.currTime;
    }

    /// Checks if the time limit has been reached.
    /// 
    /// Returns: true if the time limit has been exceeded, false otherwise.
    @nogc bool isTimeUp() nothrow {
        return MonoTime.currTime - startTime > timeout;
    }

    /// Calculates the remaining time before the limit is reached.
    /// 
    /// Returns: The remaining time, or Duration.zero if the limit has been exceeded.
    @nogc Duration remainingTime() nothrow {
        Duration elapsed = MonoTime.currTime - startTime;
        return elapsed > timeout ? Duration.zero : timeout - elapsed;
    }
}

/// Executes an operation with a time limit.
/// 
/// Params:
///     operation = The operation to execute
///     limit = The time limit for the operation
@nogc void limitedTimeOperation(scope void delegate() @nogc nothrow operation, Duration limit) {
    auto timeLimiter = TimeLimiter(limit);
    while (!timeLimiter.isTimeUp()) {
        operation();
        // TODO: Optionally add a small delay here to prevent tight looping
    }
}

// Usage example:
// void someOperation() @nogc nothrow {
//     // Some operation that should be time-limited
// }
// 
// limitedTimeOperation(&someOperation, 5.seconds);