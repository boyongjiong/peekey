// Renders the Peekey app icon ("Code Cards") as a complete .iconset.
// Usage: swift make-icon.swift <out.iconset>
//
// Sizes ≥ 64px get the full artwork (two stacked cards, code bars, countdown ring).
// 16/32px get a simplified single-card variant so the icon stays legible in Finder lists & Spotlight.
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

/// Shadow offset/blur are specified in device pixels and ignore the CTM, so scale them per render size.
var shadowScale: CGFloat = 1
func shadow(_ ctx: CGContext, dy: CGFloat, blur: CGFloat, color: CGColor) {
    ctx.setShadow(offset: CGSize(width: 0, height: dy * shadowScale), blur: blur * shadowScale, color: color)
}

func rgb(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
}

func fillGradient(_ ctx: CGContext, _ path: CGPath, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient(colors), start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

// Palette shared with the app's cards (Sources/Peekey/UI/Palette.swift).
let blue = [rgb(0x3D8AF0), rgb(0x2459D0)]
let purple = [rgb(0x8E6BF0), rgb(0x6440D4)]

/// macOS grid: 824×824 squircle centered in a 1024 canvas.
let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let tile = CGPath(roundedRect: tileRect, cornerWidth: 185, cornerHeight: 185, transform: nil)

func drawTile(_ ctx: CGContext) {
    // drop shadow
    ctx.saveGState()
    shadow(ctx, dy: -12, blur: 28, color: rgb(0x000000, 0.28))
    ctx.addPath(tile)
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()
    // slightly cool off-white so it doesn't vanish on a light Dock
    fillGradient(ctx, tile, [rgb(0xFFFFFF), rgb(0xDCE2EC)], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
    // hairline edge
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: tileRect.insetBy(dx: 2, dy: 2), cornerWidth: 183, cornerHeight: 183, transform: nil))
    ctx.setStrokeColor(rgb(0x1E2A5A, 0.10))
    ctx.setLineWidth(4)
    ctx.strokePath()
    ctx.restoreGState()
}

/// Draws a rotated rounded card with a soft colored shadow; `content` runs in card-local coordinates
/// (origin at the card's center, unrotated).
func card(_ ctx: CGContext, center: CGPoint, size: CGSize, angle: CGFloat, colors: [CGColor],
          radius: CGFloat, shadowAlpha: CGFloat, content: ((CGContext, CGRect) -> Void)? = nil) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: angle * .pi / 180)
    let r = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    let path = CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    shadow(ctx, dy: -14, blur: 34, color: rgb(0x1E2A5A, shadowAlpha))
    ctx.addPath(path)
    ctx.setFillColor(colors[1])
    ctx.fillPath()
    ctx.restoreGState()
    fillGradient(ctx, path, colors, from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
    content?(ctx, r)
    ctx.restoreGState()
}

/// Six code "digits" grouped 3 + 3, like `482 913` on the real cards.
func codeBars(_ ctx: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, step: CGFloat, gap: CGFloat, radius: CGFloat) {
    ctx.setFillColor(rgb(0xFFFFFF))
    for i in 0..<6 {
        let bx = x + CGFloat(i) * step + (i >= 3 ? gap : 0)
        ctx.addPath(CGPath(roundedRect: CGRect(x: bx, y: y, width: w, height: h), cornerWidth: radius, cornerHeight: radius, transform: nil))
    }
    ctx.fillPath()
}

func countdownRing(_ ctx: CGContext, center: CGPoint, radius: CGFloat, width: CGFloat) {
    ctx.setLineCap(.round)
    ctx.setLineWidth(width)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.35))
    ctx.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
    ctx.strokePath()
    ctx.setStrokeColor(rgb(0xFFFFFF))
    ctx.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: .pi / 2 - 1.4 * .pi, clockwise: true)
    ctx.strokePath()
}

func drawFull(_ ctx: CGContext) {
    drawTile(ctx)
    card(ctx, center: CGPoint(x: 510, y: 670), size: CGSize(width: 560, height: 300), angle: 8,
         colors: purple, radius: 64, shadowAlpha: 0.2)
    card(ctx, center: CGPoint(x: 512, y: 430), size: CGSize(width: 624, height: 340), angle: -4,
         colors: blue, radius: 64, shadowAlpha: 0.35) { ctx, _ in
        codeBars(ctx, x: -250, y: -90, w: 54, h: 92, step: 72, gap: 30, radius: 16)
        ctx.setFillColor(rgb(0xFFFFFF, 0.75))
        ctx.addPath(CGPath(roundedRect: CGRect(x: -250, y: 50, width: 210, height: 34), cornerWidth: 17, cornerHeight: 17, transform: nil))
        ctx.fillPath()
        countdownRing(ctx, center: CGPoint(x: 231, y: 67), radius: 31, width: 16)
    }
}

/// Single, larger, unrotated card with chunky bars — readable at 16–32px.
func drawSmall(_ ctx: CGContext) {
    drawTile(ctx)
    card(ctx, center: CGPoint(x: 512, y: 512), size: CGSize(width: 700, height: 440), angle: 0,
         colors: blue, radius: 90, shadowAlpha: 0.3) { ctx, _ in
        codeBars(ctx, x: -265, y: -110, w: 70, h: 150, step: 84, gap: 26, radius: 22)
        countdownRing(ctx, center: CGPoint(x: 250, y: 125), radius: 42, width: 26)
    }
}

func render(px: Int, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    shadowScale = CGFloat(px) / 1024
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    draw(ctx)
    return ctx.makeImage()!
}

func save(_ img: CGImage, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let img = render(px: px, px <= 32 ? drawSmall : drawFull)
        save(img, scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png")
    }
}
print("wrote \(outDir)")
