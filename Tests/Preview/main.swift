import SwiftUI
import AppKit

MainActor.assumeIsolated {
    // Seed this harness's own defaults domain with a plausible month.
    let seed: [String: Int] = [
        "2026-07-01": 4500, "2026-07-02": 9000, "2026-07-03": 1200,
        "2026-07-06": 14400, "2026-07-07": 7200, "2026-07-08": 2400,
        "2026-07-09": 11000, "2026-07-10": 600, "2026-07-13": 18000,
        "2026-07-14": 5400, "2026-07-15": 8100, "2026-07-16": 3000,
        "2026-07-17": 12600, "2026-07-20": 900, "2026-07-21": 16200,
        "2026-07-22": 6300, "2026-07-23": 10800, "2026-07-24": 2100,
        "2026-07-26": 1500, "2026-07-27": 1312,
    ]
    UserDefaults.standard.set(seed, forKey: "dailyTotals")

    let view = HistoryView(showHistory: .constant(true))
        .padding(14)
        .frame(width: 320)
        .background(Color(red: 0.12, green: 0.12, blue: 0.13))
        .environment(\.colorScheme, .dark)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    if let img = renderer.nsImage,
       let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "history-preview.png"))
        print("wrote history-preview.png (\(Int(img.size.width))x\(Int(img.size.height)) pt)")
    } else {
        print("RENDER FAILED")
    }
    UserDefaults.standard.removeObject(forKey: "dailyTotals")
}
