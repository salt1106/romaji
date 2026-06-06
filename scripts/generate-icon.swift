import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("App/AppIcon.iconset", isDirectory: true)
let output = root.appendingPathComponent("App/AppIcon.icns")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

struct IconVariant {
    let fileName: String
    let pixels: Int
}

let variants = [
    IconVariant(fileName: "icon_16x16.png", pixels: 16),
    IconVariant(fileName: "icon_16x16@2x.png", pixels: 32),
    IconVariant(fileName: "icon_32x32.png", pixels: 32),
    IconVariant(fileName: "icon_32x32@2x.png", pixels: 64),
    IconVariant(fileName: "icon_128x128.png", pixels: 128),
    IconVariant(fileName: "icon_128x128@2x.png", pixels: 256),
    IconVariant(fileName: "icon_256x256.png", pixels: 256),
    IconVariant(fileName: "icon_256x256@2x.png", pixels: 512),
    IconVariant(fileName: "icon_512x512.png", pixels: 512),
    IconVariant(fileName: "icon_512x512@2x.png", pixels: 1024)
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawIcon(pixels: Int, to url: URL) throws {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: size)
    NSColor.clear.setFill()
    rect.fill()

    let inset = CGFloat(pixels) * 0.045
    let card = rect.insetBy(dx: inset, dy: inset)
    let radius = CGFloat(pixels) * 0.22
    let path = NSBezierPath(roundedRect: card, xRadius: radius, yRadius: radius)

    NSGraphicsContext.current?.saveGraphicsState()
    NSShadow().then {
        $0.shadowColor = NSColor.black.withAlphaComponent(0.22)
        $0.shadowOffset = NSSize(width: 0, height: -CGFloat(pixels) * 0.025)
        $0.shadowBlurRadius = CGFloat(pixels) * 0.045
        $0.set()
    }
    NSGradient(colors: [
        color(76, 182, 255),
        color(111, 105, 255),
        color(235, 104, 255)
    ])!.draw(in: path, angle: 135)
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.42),
        NSColor.white.withAlphaComponent(0.04)
    ])!.draw(in: path, angle: 90)

    let shine = NSBezierPath(roundedRect: card.insetBy(dx: CGFloat(pixels) * 0.07, dy: CGFloat(pixels) * 0.08), xRadius: radius * 0.72, yRadius: radius * 0.72)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    shine.lineWidth = max(1, CGFloat(pixels) * 0.018)
    shine.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowOffset = NSSize(width: 0, height: -CGFloat(pixels) * 0.012)
    shadow.shadowBlurRadius = CGFloat(pixels) * 0.025

    let font = NSFont.systemFont(ofSize: CGFloat(pixels) * 0.48, weight: .heavy)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
        .shadow: shadow
    ]

    let text = "あ"
    let textHeight = CGFloat(pixels) * 0.56
    let textRect = NSRect(
        x: 0,
        y: CGFloat(pixels) * 0.245,
        width: CGFloat(pixels),
        height: textHeight
    )
    (text as NSString).draw(in: textRect, withAttributes: attributes)

    let rFont = NSFont.systemFont(ofSize: CGFloat(pixels) * 0.20, weight: .bold)
    let rAttributes: [NSAttributedString.Key: Any] = [
        .font: rFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.82),
        .paragraphStyle: paragraph
    ]
    ("R" as NSString).draw(
        in: NSRect(
            x: CGFloat(pixels) * 0.56,
            y: CGFloat(pixels) * 0.19,
            width: CGFloat(pixels) * 0.2,
            height: CGFloat(pixels) * 0.18
        ),
        withAttributes: rAttributes
    )

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "RomajiIcon", code: 1)
    }
    try png.write(to: url)
}

extension NSObjectProtocol {
    @discardableResult
    func then(_ configure: (Self) -> Void) -> Self {
        configure(self)
        return self
    }
}

for variant in variants {
    try drawIcon(pixels: variant.pixels, to: iconset.appendingPathComponent(variant.fileName))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "RomajiIcon", code: Int(process.terminationStatus))
}
