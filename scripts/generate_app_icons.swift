import Cocoa
import CoreGraphics

struct IconTheme {
    var name: String
    var isDark: Bool
    var hasBackground: Bool
}

func renderVectorIcon(size: CGFloat, theme: IconTheme) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }

    let fgColor = theme.isDark ? CGColor(gray: 1, alpha: 1) : CGColor(gray: 0, alpha: 1)
    let bgColor = theme.isDark ? CGColor(gray: 0, alpha: 1) : CGColor(gray: 1, alpha: 1)

    // 1. Background (if enabled)
    if theme.hasBackground {
        let margin = size * 0.08
        let rect = CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
        let radius = rect.width * 0.224
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.setFillColor(bgColor)
        ctx.addPath(path)
        ctx.fillPath()
    }

    let center = CGPoint(x: size / 2.0, y: size / 2.0)
    let scale = size / 1024.0
    let strokeW: CGFloat = 22.0 * scale

    ctx.setStrokeColor(fgColor)
    ctx.setLineWidth(strokeW)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.miter)

    // 2. Concentric Target Rings
    let rOuter: CGFloat = 320.0 * scale
    let rInner: CGFloat = 260.0 * scale

    ctx.addArc(center: center, radius: rOuter, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    ctx.addArc(center: center, radius: rInner, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    // 3. Diagonal "X" Crosshair Lines (45, 135, 225, 315 degrees)
    let armInner: CGFloat = 135.0 * scale
    let armOuter: CGFloat = 415.0 * scale
    let angles: [CGFloat] = [
        .pi / 4.0,
        3.0 * .pi / 4.0,
        5.0 * .pi / 4.0,
        7.0 * .pi / 4.0
    ]

    for a in angles {
        let p1 = CGPoint(x: center.x + cos(a) * armInner, y: center.y + sin(a) * armInner)
        let p2 = CGPoint(x: center.x + cos(a) * armOuter, y: center.y + sin(a) * armOuter)
        ctx.move(to: p1)
        ctx.addLine(to: p2)
    }
    ctx.strokePath()

    // 4. Centered Mouse Cursor Pointer (Outline only, NO fill)
    // Classic arrow polygon
    let cursorScale: CGFloat = 1.15 * scale
    let rawPoints: [CGPoint] = [
        CGPoint(x: 0, y: 0),          // Tip
        CGPoint(x: 0, y: -136),       // Left straight edge
        CGPoint(x: 40, y: -100),      // Inner notch left
        CGPoint(x: 72, y: -166),      // Stem bottom-left
        CGPoint(x: 104, y: -150),     // Stem bottom-right
        CGPoint(x: 72, y: -86),       // Stem notch right
        CGPoint(x: 108, y: -86),      // Right barb
    ]

    // Calculate centroid bounds to center the cursor precisely
    var minX: CGFloat = .greatestFiniteMagnitude
    var maxX: CGFloat = -.greatestFiniteMagnitude
    var minY: CGFloat = .greatestFiniteMagnitude
    var maxY: CGFloat = -.greatestFiniteMagnitude

    for p in rawPoints {
        let sx = p.x * cursorScale
        let sy = p.y * cursorScale
        minX = min(minX, sx)
        maxX = max(maxX, sx)
        minY = min(minY, sy)
        maxY = max(maxY, sy)
    }

    let midX = (minX + maxX) / 2.0
    let midY = (minY + maxY) / 2.0
    let origin = CGPoint(x: center.x - midX, y: center.y - midY)

    let cursorPath = CGMutablePath()
    for (i, p) in rawPoints.enumerated() {
        let pt = CGPoint(x: origin.x + p.x * cursorScale, y: origin.y + p.y * cursorScale)
        if i == 0 {
            cursorPath.move(to: pt)
        } else {
            cursorPath.addLine(to: pt)
        }
    }
    cursorPath.closeSubpath()

    // Draw outline only
    ctx.setLineWidth(strokeW)
    ctx.setLineJoin(.miter)
    ctx.addPath(cursorPath)
    ctx.strokePath()

    img.unlockFocus()
    return img
}

func savePNG(image: NSImage, path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let pngData = rep.representation(using: .png, properties: [:]) else {
        return
    }
    try? pngData.write(to: URL(fileURLWithPath: path))
}

let resourcesDir = "/Users/citizen/dev/autoclix/Resources"
try? FileManager.default.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)

// 1. AppIcon.png (Dark squircle master)
let darkSquircle = renderVectorIcon(size: 1024, theme: IconTheme(name: "Dark", isDark: true, hasBackground: true))
savePNG(image: darkSquircle, path: "\(resourcesDir)/AppIcon.png")
savePNG(image: darkSquircle, path: "\(resourcesDir)/AppIcon-Dark.png")

// 2. AppIcon-Light.png (Light squircle master)
let lightSquircle = renderVectorIcon(size: 1024, theme: IconTheme(name: "Light", isDark: false, hasBackground: true))
savePNG(image: lightSquircle, path: "\(resourcesDir)/AppIcon-Light.png")

// 3. Standalone Emblems (Transparent backgrounds)
let darkEmblem = renderVectorIcon(size: 1024, theme: IconTheme(name: "EmblemDark", isDark: false, hasBackground: false))
savePNG(image: darkEmblem, path: "\(resourcesDir)/AppIcon-Emblem-Black.png")

let lightEmblem = renderVectorIcon(size: 1024, theme: IconTheme(name: "EmblemLight", isDark: true, hasBackground: false))
savePNG(image: lightEmblem, path: "\(resourcesDir)/AppIcon-Emblem-White.png")

// 4. Generate Apple .icns using iconutil
let iconsetDir = "/tmp/Autoclix_AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (s, filename) in sizes {
    let resized = renderVectorIcon(size: s, theme: IconTheme(name: "Dark", isDark: true, hasBackground: true))
    savePNG(image: resized, path: "\(iconsetDir)/\(filename)")
}

let icnsPath = "\(resourcesDir)/AppIcon.icns"
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir, "-o", icnsPath]
try? proc.run()
proc.waitUntilExit()

print("✅ Successfully generated all production vector assets and AppIcon.icns!")
