// Composes docs/images/hero.png for the README: a desktop with a column of folders, the cursor resting on one, and
// Glimpse's real panel beside it, placed the way the app places it (left of the icon, top aligned).
//   swift tools/make-hero.swift <panel.png>
// <panel.png> is a snapshot of the panel (2× pixels), made with:
//   open -g ~/Applications/Glimpse.app --args --simulate-hover "<folder>" 1380 60 64 64 --snapshot <panel.png>
// The folder shown in the README is a made-up "Holiday photos" folder (drawn pictures, a PDF, a note), not real files.
import AppKit

let panelURL = URL(fileURLWithPath: CommandLine.arguments[1])
let out = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/images/hero.png")
let W = 1800, H = 1000  // pixels (2× of 900 × 500 points)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
/// Top-left based rectangles, like the app's Quartz coordinates.
func rect(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x, y: CGFloat(H) - top - h, width: w, height: h) }

// Wallpaper: a soft macOS-like gradient with two glows; rounded corners like a window screenshot.
let canvas = NSRect(x: 0, y: 0, width: W, height: H)
NSBezierPath(roundedRect: canvas, xRadius: 36, yRadius: 36).addClip()
NSGradient(colors: [color(0x1D2B64), color(0x3A3FC4), color(0x2E8BC0), color(0x7DD3C0)], atLocations: [0, 0.4, 0.75, 1],
           colorSpace: .sRGB)!.draw(in: canvas, angle: -35)
for (cx, cy, r, c) in [(300.0, 250.0, 620.0, color(0xFF7EB3, 0.35)), (1300.0, 900.0, 700.0, color(0x6FD0FF, 0.30))] {
  let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c.cgColor, c.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
  ctx.drawRadialGradient(g, startCenter: CGPoint(x: cx, y: cy), startRadius: 0, endCenter: CGPoint(x: cx, y: cy), endRadius: r, options: [])
}

// Menu bar strip.
color(0xFFFFFF, 0.18).setFill(); NSBezierPath(rect: rect(0, 0, CGFloat(W), 50)).fill()
let menuFont = NSFont.systemFont(ofSize: 24, weight: .semibold)
("Finder" as NSString).draw(at: NSPoint(x: 90, y: CGFloat(H) - 40), withAttributes: [.font: menuFont, .foregroundColor: NSColor.white])
if let eye = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 24, weight: .regular)) {
  let tinted = NSImage(size: eye.size, flipped: false) { r in eye.draw(in: r); NSColor.white.set(); r.fill(using: .sourceAtop); return true }
  tinted.draw(in: rect(CGFloat(W) - 260, 11, 40, 28))
}

// Desktop folders, right column (64-point icons = 128 px), labels under them.
let folderIcon = NSWorkspace.shared.icon(for: .folder)
let names = ["Holiday photos", "Projects", "Recipes", "Taxes 2026"]
let iconX: CGFloat = 1580, firstTop: CGFloat = 130, step: CGFloat = 210
let label: [NSAttributedString.Key: Any] = {
  let p = NSMutableParagraphStyle(); p.alignment = .center
  let s = NSShadow(); s.shadowColor = color(0x000000, 0.6); s.shadowBlurRadius = 4; s.shadowOffset = NSSize(width: 0, height: -1)
  return [.font: NSFont.systemFont(ofSize: 24, weight: .medium), .foregroundColor: NSColor.white, .paragraphStyle: p, .shadow: s]
}()
for (i, name) in names.enumerated() {
  let top = firstTop + CGFloat(i) * step
  folderIcon.draw(in: rect(iconX, top, 128, 128))
  (name as NSString).draw(in: rect(iconX - 50, top + 134, 228, 40), withAttributes: label)
}

// Glimpse's panel: left of the hovered icon's zone (icon − 24 pt = 48 px), top aligned with the icon.
let panel = NSImage(contentsOf: panelURL)!
let pr = panel.representations.first!
let pw = CGFloat(pr.pixelsWide), ph = CGFloat(pr.pixelsHigh)
let panelRect = rect(iconX - 48 - pw, firstTop, pw, ph)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 50, color: color(0x000000, 0.5).cgColor)
color(0x3A3A3C).setFill(); NSBezierPath(roundedRect: panelRect, xRadius: 20, yRadius: 20).fill()
ctx.restoreGState()
panel.draw(in: panelRect)

// The cursor, resting on "Holiday photos".
let tip = NSPoint(x: iconX + 70, y: CGFloat(H) - firstTop - 58)
let arrow = NSBezierPath()
let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, -48), (11, -37), (19, -55), (27, -52), (19, -34), (34, -34)]
for (i, (dx, dy)) in pts.enumerated() {
  let p = NSPoint(x: tip.x + dx * 1.15, y: tip.y + dy * 1.15)
  if i == 0 { arrow.move(to: p) } else { arrow.line(to: p) }
}
arrow.close(); arrow.lineJoinStyle = .round
ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 6, color: color(0, 0.5).cgColor)
NSColor.white.setStroke(); arrow.lineWidth = 7; arrow.stroke(); ctx.restoreGState()
NSColor.black.setFill(); arrow.fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote docs/images/hero.png (\(W) × \(H))")
