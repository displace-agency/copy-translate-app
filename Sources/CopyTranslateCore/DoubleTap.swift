import Foundation

/// Pure double-tap timing decision, extracted from the event tap so it can be
/// tested and so the detection window can be driven live from user preferences.
public enum DoubleTap {
    /// Given the current timestamp, the previous tap timestamp, and the window,
    /// decide whether this is the second tap of a double. On a double, the
    /// returned `newLast` resets to 0 so the next tap starts a fresh pair.
    public static func evaluate(now: Double, last: Double, window: Double) -> (isDouble: Bool, newLast: Double) {
        if last > 0, now - last <= window {
            return (true, 0)
        }
        return (false, now)
    }
}
