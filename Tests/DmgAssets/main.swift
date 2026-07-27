import SwiftUI
import AppKit

// Generates the DMG window background. The Finder icons are placed by
// scripts/make-dmg.sh at (150, 170) and (450, 170) in a 600x400 window,
// coordinates measured from the top-left of the window content. Everything
// here is absolutely positioned to line up with that.
MainActor.assumeIsolated {
    let W: CGFloat = 600, H: CGFloat = 400
    let iconY: CGFloat = 170

    let view = ZStack {
        Color(red: 0.11, green: 0.11, blue: 0.12)

        Text("Locked In")
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .position(x: W / 2, y: 52)

        Text("Drag the app into your Applications folder")
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.55))
            .position(x: W / 2, y: 84)

        // Sits between the two icon slots, level with their centres.
        HStack(spacing: 0) {
            Rectangle()
                .fill(LinearGradient(colors: [.green.opacity(0.08), .green.opacity(0.7)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 108, height: 3)
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.green.opacity(0.8))
                .offset(x: -2)
        }
        .position(x: W / 2, y: iconY)

        Text("Opening it straight from Downloads is blocked by macOS.")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.38))
            .position(x: W / 2, y: H - 42)
    }
    .frame(width: W, height: H)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2   // @2x so the window looks right on Retina
    if let img = renderer.nsImage, let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"
        try? png.write(to: URL(fileURLWithPath: out))
        print("wrote \(out)")
    } else {
        print("RENDER FAILED")
        exit(1)
    }
}
