import CoreGraphics

/// Reads global input idle time. No TCC permissions required —
/// this is the same API chat apps use for "away" status.
enum IdleTracker {
    /// kCGAnyInputEventType is (CGEventType)(~0); the C enum accepts any raw value.
    private static let anyInput = CGEventType(rawValue: UInt32.max)!

    /// Seconds since the last keyboard/mouse/trackpad event, system-wide.
    static func idleSeconds() -> Double {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput)
    }
}
