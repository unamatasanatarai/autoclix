import Cocoa
import SwiftUI

public enum StatusBarIconHelper {
    // State updates arrive every 0.2s while running; build each variant once instead of re-reading PNGs each time.
    // Main thread only.
    private static var cache: [String: NSImage] = [:]

    public static func createIcon(for state: EngineState) -> NSImage {
        let imageName = imageName(for: state)
        if let cached = cache[imageName] {
            return cached
        }
        let icon = loadIcon(for: state)
        cache[imageName] = icon
        return icon
    }

    private static func imageName(for state: EngineState) -> String {
        switch state {
        case .running:
            return "StatusBarIcon-Active"
        case .waiting, .permissionRequired:
            return "StatusBarIcon-Waiting"
        default:
            return "StatusBarIcon"
        }
    }

    private static func loadIcon(for state: EngineState) -> NSImage {
        let imageName: String
        let isTemplate: Bool

        switch state {
        case .running:
            imageName = "StatusBarIcon-Active"
            isTemplate = false
        case .waiting, .permissionRequired:
            imageName = "StatusBarIcon-Waiting"
            isTemplate = false
        default:
            imageName = "StatusBarIcon"
            isTemplate = true
        }

        // 1. Load multi-resolution (1x & @2x Retina) pre-rendered representations from bundle / Resources
        let img = NSImage(size: NSSize(width: 18, height: 18))
        var hasRep = false

        let candidates1 = [
            Bundle.main.path(forResource: imageName, ofType: "png"),
            Bundle.main.path(forResource: imageName, ofType: "png", inDirectory: "Resources"),
            "Resources/\(imageName).png"
        ]
        let candidates2 = [
            Bundle.main.path(forResource: "\(imageName)@2x", ofType: "png"),
            Bundle.main.path(forResource: "\(imageName)@2x", ofType: "png", inDirectory: "Resources"),
            "Resources/\(imageName)@2x.png"
        ]

        for p in candidates1.compactMap({ $0 }) {
            if FileManager.default.fileExists(atPath: p), let rep = NSImageRep(contentsOfFile: p) {
                rep.size = NSSize(width: 18, height: 18)
                img.addRepresentation(rep)
                hasRep = true
                break
            }
        }

        for p in candidates2.compactMap({ $0 }) {
            if FileManager.default.fileExists(atPath: p), let rep = NSImageRep(contentsOfFile: p) {
                rep.size = NSSize(width: 18, height: 18)
                img.addRepresentation(rep)
                hasRep = true
                break
            }
        }

        if hasRep {
            img.isTemplate = isTemplate
            return img
        }

        // 2. Mathematically crisp vector drawing handler (fallback / direct vector resolution)
        let size = NSSize(width: 18, height: 18)
        let icon = NSImage(size: size, flipped: false) { rect in
            let targetH: CGFloat = 14.0
            let targetW: CGFloat = targetH * (132.0 / 135.0)

            let startX: CGFloat = (rect.width - targetW) / 2.0
            let startY: CGFloat = (rect.height - targetH) / 2.0

            func mapPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                let nx = x / 132.0
                let ny = y / 135.0
                let px = startX + nx * targetW
                let py = startY + (1.0 - ny) * targetH
                return CGPoint(x: px, y: py)
            }

            let strokeColor: NSColor
            switch state {
            case .running:
                strokeColor = NSColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1)
            case .waiting, .permissionRequired:
                strokeColor = NSColor(red: 249/255, green: 115/255, blue: 22/255, alpha: 1)
            default:
                strokeColor = NSColor.black
            }

            let rayPath = NSBezierPath()
            rayPath.lineWidth = 1.05
            rayPath.lineCapStyle = .round

            let rays: [(CGPoint, CGPoint)] = [
                (mapPoint(3, 15), mapPoint(37, 28)),
                (mapPoint(86, 23), mapPoint(115, 3)),
                (mapPoint(92, 44), mapPoint(126, 46)),
                (mapPoint(25, 94), mapPoint(44, 66))
            ]

            for (p1, p2) in rays {
                rayPath.move(to: p1)
                rayPath.line(to: p2)
            }
            strokeColor.setStroke()
            rayPath.stroke()

            let cursorPath = NSBezierPath()
            cursorPath.lineWidth = 1.05
            cursorPath.lineCapStyle = .round
            cursorPath.lineJoinStyle = .round

            cursorPath.move(to: mapPoint(62.9, 42.7))
            cursorPath.line(to: mapPoint(125.3, 100.9))
            cursorPath.line(to: mapPoint(89.0, 102.7))
            cursorPath.line(to: mapPoint(62.9, 127.9))
            cursorPath.close()

            strokeColor.setStroke()
            cursorPath.stroke()

            return true
        }

        if isTemplate {
            icon.isTemplate = true
        }
        return icon
    }
}
