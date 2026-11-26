// Renders the Peekey app icon (1024×1024 PNG). Usage: swift make-icon.swift <out.png>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: 824pt rounded square centered on a 1024 canvas.
let inset = (size - 824) / 2
let rect = CGRect(x: inset, y: inset, width: 824, height: 824)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)

ctx.saveGState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSColor.white.setFill()
path.fill()
ctx.restoreGState()

path.addClip()
let gradient = NSGradient(colors: [
    NSColor(red: 0.37, green: 0.66, blue: 0.94, alpha: 1),
    NSColor(red: 0.49, green: 0.36, blue: 0.88, alpha: 1),
])!
gradient.draw(in: path, angle: -60)

// Card-like highlight
let card = NSBezierPath(roundedRect: rect.insetBy(dx: 120, dy: 250).offsetBy(dx: 0, dy: -40), xRadius: 60, yRadius: 60)
NSColor.white.withAlphaComponent(0.18).setFill()
card.fill()

// Symbol
let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let s = symbol.size
    symbol.draw(in: CGRect(x: (size - s.width) / 2, y: (size - s.height) / 2 + 10, width: s.width, height: s.height))
}
image.unlockFocus()

let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
