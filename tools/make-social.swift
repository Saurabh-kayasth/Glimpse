// Composes docs/images/social-preview.png (1280 × 640), the card GitHub shows when the repo link is shared:
// icon, name and tagline on the left; the panel-and-folders part of docs/images/hero.png on the right.
//   swift tools/make-social.swift        (after make-icon.swift and make-hero.swift)
// Upload it in the repo's Settings → General → Social preview.
import AppKit

let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let W = 1280, H = 640
func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Background: the hero's deep blue, darker so the text reads.
NSGradient(colors: [color(0x141E4A), color(0x27318F), color(0x1F5E8C)], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
  .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -25)

// Right: the hero's panel and folder column (its right half), in a rounded frame with a shadow.
let hero = NSImage(contentsOf: repo.appendingPathComponent("docs/images/hero.png"))!
let crop = NSRect(x: 880, y: 140, width: 920, height: 860)  // hero pixels (bottom-left origin): panel + folders
let frame = NSRect(x: 640, y: 40, width: 600, height: 560)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: color(0, 0.55).cgColor)
color(0x2A2F6A).setFill(); NSBezierPath(roundedRect: frame, xRadius: 28, yRadius: 28).fill()
ctx.restoreGState()
ctx.saveGState()
NSBezierPath(roundedRect: frame, xRadius: 28, yRadius: 28).addClip()
let scale = max(frame.width / crop.width, frame.height / crop.height)
let drawn = NSRect(x: frame.midX - crop.width * scale / 2, y: frame.midY - crop.height * scale / 2,
                   width: crop.width * scale, height: crop.height * scale)
hero.draw(in: drawn, from: crop, operation: .sourceOver, fraction: 1)
ctx.restoreGState()

// Left: icon, name, tagline, one line of facts.
let icon = NSImage(contentsOf: repo.appendingPathComponent("docs/images/icon.png"))!
/// Draws `s` with its bottom edge at `bottom`; returns the top edge, to stack the next line above.
@discardableResult
func text(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, _ c: NSColor, x: CGFloat, bottom: CGFloat) -> CGFloat {
  let para = NSMutableParagraphStyle(); para.lineSpacing = 4
  let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: c, .paragraphStyle: para]
  let box = (s as NSString).boundingRect(with: NSSize(width: 540, height: 400), options: [.usesLineFragmentOrigin], attributes: attrs)
  (s as NSString).draw(with: NSRect(x: x, y: bottom, width: 540, height: ceil(box.height)), options: [.usesLineFragmentOrigin], attributes: attrs)
  return bottom + ceil(box.height)
}
var y: CGFloat = 70
y = text("macOS menu-bar app · Swift · MIT", 22, .regular, color(0xAFC3F0), x: 82, bottom: y) + 22
y = text("Rest the cursor on a folder\nand see what's inside.", 34, .medium, color(0xDCE6FF), x: 82, bottom: y) + 18
y = text("Glimpse", 76, .bold, .white, x: 78, bottom: y) + 26
icon.draw(in: NSRect(x: 72, y: y, width: 150, height: 150))

NSGraphicsContext.restoreGraphicsState()
let out = repo.appendingPathComponent("docs/images/social-preview.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote docs/images/social-preview.png (\(W) × \(H))")
