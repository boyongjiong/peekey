import AppKit

/// Menu-bar glyph matching the app icon ("Code Cards"): a card outline with a 3+3 code.
/// Drawn as a vector template image so it's crisp at any scale and auto-tints for light/dark menu bars.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()
            let card = NSBezierPath(roundedRect: NSRect(x: 1.25, y: 3.75, width: 15.5, height: 10.5), xRadius: 3, yRadius: 3)
            card.lineWidth = 1.5
            card.stroke()
            for i in 0..<6 {
                let x = 3.6 + CGFloat(i) * 1.95 + (i >= 3 ? 1.05 : 0)
                NSBezierPath(roundedRect: NSRect(x: x, y: 6.4, width: 1.3, height: 3.4), xRadius: 0.5, yRadius: 0.5).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Peekey"
        return image
    }()
}
