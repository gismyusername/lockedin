import SwiftUI
import Foundation

/// One green scale used everywhere time is shown as colour: calendar cells,
/// chart bars, leaderboard bars.
///
/// The scale is **absolute**, anchored to `reference` (a full working day).
/// Scaling to your best day instead was tempting and wrong: hitting a new
/// record silently dimmed every earlier day, so "bright" meant nothing except
/// "close to whatever my peak happens to be right now". With a fixed anchor a
/// colour means the same thing today, next month, and on a friend's board.
///
/// Above the reference the ramp keeps going — mint fades toward near-white —
/// so an exceptional day still stands out without compressing everything else.
enum GreenRamp {
    /// A full day of deep work. Reaching it means full mint.
    static let reference: Double = 8 * 3600

    /// Stops span 0...2, i.e. up to twice the reference day.
    private static let stops: [(at: Double, r: Double, g: Double, b: Double)] = [
        (0.00, 0.10, 0.26, 0.17),   // deep, barely-there green
        (0.45, 0.13, 0.62, 0.32),   // solid green
        (1.00, 0.44, 0.97, 0.60),   // mint: a full day
        (1.50, 0.72, 1.00, 0.82),   // pale: well beyond a full day
        (2.00, 0.92, 1.00, 0.95),   // near-white: twice a full day
    ]

    /// `t` is clamped to the range the stops cover.
    static func rgb(_ t: Double) -> (r: Double, g: Double, b: Double) {
        let last = stops[stops.count - 1]
        let f = min(max(t, 0), last.at)
        for i in 1..<stops.count {
            let lo = stops[i - 1], hi = stops[i]
            if f <= hi.at {
                let span = hi.at - lo.at
                let p = span > 0 ? (f - lo.at) / span : 0
                return (lo.r + (hi.r - lo.r) * p,
                        lo.g + (hi.g - lo.g) * p,
                        lo.b + (hi.b - lo.b) * p)
            }
        }
        return (last.r, last.g, last.b)
    }

    static func color(_ t: Double) -> Color {
        let c = rgb(t)
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    /// Where a day sits on the scale. 1.0 is a full reference day, 2.0 is
    /// double it, and anything tracked gets a floor so it stays visible.
    static func position(seconds: Int) -> Double {
        guard seconds > 0 else { return 0 }
        let n = Double(seconds) / reference
        // Slight curve below the reference so ordinary two- and three-hour days
        // are still told apart instead of all sitting in the dark end.
        let curved = n <= 1 ? pow(n, 0.75) : min(n, 2)
        return max(0.12, curved)
    }

    static func color(seconds: Int) -> Color {
        color(position(seconds: seconds))
    }

    /// Perceived brightness of a point on the ramp, so text drawn on top can
    /// flip to dark. A big day is near-white, and white-on-white is unreadable.
    static func luminance(_ t: Double) -> Double {
        let c = rgb(t)
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    /// Readable foreground for a cell filled at this position.
    static func textColor(seconds: Int) -> Color {
        luminance(position(seconds: seconds)) > 0.62
            ? Color(red: 0.05, green: 0.16, blue: 0.09)
            : .white
    }
}
