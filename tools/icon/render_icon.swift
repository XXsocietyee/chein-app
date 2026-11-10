// Renders the Questify app icon (concept A, "seal on a fog map") and the launch mark.
// usage: swiftc -parse-as-library tools/icon/render_icon.swift -o $TMPDIR/ri && $TMPDIR/ri <outdir>
import SwiftUI
import AppKit

struct Seal: View {
    let showGround: Bool
    private let ink = Color(red: 0xF8/255, green: 0xF8/255, blue: 0xF8/255)
    private let amber = Color(red: 0xF2/255, green: 0xA3/255, blue: 0x3A/255)
    private let hole = Color(red: 0x0B/255, green: 0x0B/255, blue: 0x0C/255)
    var body: some View {
        ZStack {
            if showGround {
                RadialGradient(colors: [Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255), .black], center: .center, startRadius: 40, endRadius: 760)
            }
            // Stamp: perforated disc edge (28 notches), inner ring cut, one amber dot where you landed.
            ZStack {
                Circle().fill(ink).frame(width: 700, height: 700)
                ForEach(0..<28, id: \.self) { i in
                    Circle().fill(showGround ? hole : .clear).blendMode(showGround ? .normal : .destinationOut)
                        .frame(width: 34, height: 34)
                        .offset(y: -350).rotationEffect(.degrees(Double(i) * 360 / 28))
                }
                Circle().fill(showGround ? hole : .clear).blendMode(showGround ? .normal : .destinationOut).frame(width: 500, height: 500)
                Circle().stroke(ink, lineWidth: 26).frame(width: 430, height: 440)
                Circle().fill(amber).frame(width: 150, height: 150)
            }
            .compositingGroup()
            .frame(width: 800, height: 800)
        }
        .frame(width: 1024, height: 1024)
    }
}

@main struct Main {
    @MainActor static func main() {
        let out = CommandLine.arguments.dropFirst().first ?? "."
        func render(_ v: some View, _ name: String, _ px: CGFloat) {
            let r = ImageRenderer(content: v); r.scale = 1
            guard let cg = r.cgImage else { print("fail \(name)"); return }
            let rep = NSBitmapImageRep(cgImage: cg)
            try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
        }
        render(Seal(showGround: true), "AppIcon-1024.png", 1024)
        render(Seal(showGround: false), "LaunchMark.png", 1024)
    }
}
