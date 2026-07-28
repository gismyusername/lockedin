import SwiftUI

/// One green scale used everywhere time is shown as colour: calendar cells,
/// chart bars, leaderboard bars. A light day sits deep and muted, a heavy one
/// glows. Kept as plain numbers so the interpolation can be tested.
enum GreenRamp {
    /// Deep muted green -> solid green -> bright mint.
    private static let stops: [(at: Double, r: Double, g: Double, b: Double)] = [
        (0.00, 0.10, 0.26, 0.17),
        (0.45, 0.13, 0.62, 0.32),
        (1.00, 0.44, 0.97, 0.60),
    ]

    /// `fraction` is clamped to 0...1.
    static func rgb(_ fraction: Double) -> (r: Double, g: Double, b: Double) {
        let f = min(max(fraction, 0), 1)
        for i in 1..<stops.count {
            let lo = stops[i - 1], hi = stops[i]
            if f <= hi.at {
                let span = hi.at - lo.at
                let t = span > 0 ? (f - lo.at) / span : 0
                return (lo.r + (hi.r - lo.r) * t,
                        lo.g + (hi.g - lo.g) * t,
                        lo.b + (hi.b - lo.b) * t)
            }
        }
        let last = stops[stops.count - 1]
        return (last.r, last.g, last.b)
    }

    static func color(_ fraction: Double) -> Color {
        let c = rgb(fraction)
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    /// Fraction of the best value on record, with a floor so a tracked day is
    /// never invisible against the background.
    static func fraction(seconds: Int, peak: Int) -> Double {
        guard seconds > 0, peak > 0 else { return 0 }
        return 0.12 + 0.88 * min(1, Double(seconds) / Double(peak))
    }
}
