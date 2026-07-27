import SwiftUI
import AppKit

// Renders AppIcon.iconset. Each size is rendered natively rather than
// downscaled from one big canvas, so the bolt stays crisp at 16pt where most
// of these will actually be seen (Finder lists, login items, Spotlight).
@MainActor
func iconView(_ size: CGFloat) -> some View {
    // macOS icons are a squircle at ~22.37% corner radius, inset from the
    // canvas so the shadow has room.
    let inset = size * 0.06
    let side = size - inset * 2
    return ZStack {
        Color.clear
        RoundedRectangle(cornerRadius: side * 0.2237, style: .continuous)
            .fill(LinearGradient(
                colors: [Color(red: 0.16, green: 0.17, blue: 0.19),
                         Color(red: 0.06, green: 0.06, blue: 0.07)],
                startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.2237, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: max(size * 0.005, 0.5))
            )
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.35), radius: size * 0.02, y: size * 0.012)

        Image(systemName: "bolt.fill")
            .font(.system(size: side * 0.52, weight: .black))
            .foregroundStyle(LinearGradient(
                colors: [Color(red: 0.42, green: 0.95, blue: 0.55),
                         Color(red: 0.13, green: 0.72, blue: 0.35)],
                startPoint: .top, endPoint: .bottom))
            // Keeps the mark readable when the icon is 16pt in a Finder list.
            .shadow(color: Color.green.opacity(0.45), radius: size * 0.03)
    }
    .frame(width: size, height: size)
}

MainActor.assumeIsolated {
    let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
    try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

    let variants: [(pt: CGFloat, scale: CGFloat, name: String)] = [
        (16, 1, "icon_16x16"), (16, 2, "icon_16x16@2x"),
        (32, 1, "icon_32x32"), (32, 2, "icon_32x32@2x"),
        (128, 1, "icon_128x128"), (128, 2, "icon_128x128@2x"),
        (256, 1, "icon_256x256"), (256, 2, "icon_256x256@2x"),
        (512, 1, "icon_512x512"), (512, 2, "icon_512x512@2x"),
    ]
    for v in variants {
        let renderer = ImageRenderer(content: iconView(v.pt))
        renderer.scale = v.scale
        guard let img = renderer.nsImage, let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("failed at \(v.name)"); exit(1)
        }
        try? png.write(to: URL(fileURLWithPath: "\(out)/\(v.name).png"))
    }
    print("wrote \(variants.count) sizes to \(out)")
}
