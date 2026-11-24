// Draws Glimpse's app icon and writes Support/AppIcon.icns (plus docs/images/icon.png for the README).
//   swift tools/make-icon.swift            (from the repo folder; needs only macOS's own sips and iconutil)
// The design, kept simple like other Mac app icons: a blue rounded square, one white folder, and an eye on its front
// (the same idea as the menu-bar eye): "see inside folders".
import AppKit

let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let size: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
          blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func drawIcon() -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let ctx = NSGraphicsContext.current!.cgContext

  // 1. The rounded square (Apple's macOS grid: 824 × 824 body, 100-point margin, ~185 corner radius), with a soft
  //    drop shadow.
  let body = NSRect(x: 100, y: 100, width: 824, height: 824)
  let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35).cgColor)
  color(0x2F4FD6).setFill(); squircle.fill()
  ctx.restoreGState()
  ctx.saveGState()
  squircle.addClip()
  NSGradient(colors: [color(0x6FD0FF), color(0x4A7CF2), color(0x3A3FC4)], atLocations: [0, 0.5, 1],
             colorSpace: .sRGB)!.draw(in: body, angle: -60)
  // A gentle highlight across the top.
  NSGradient(colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)])!.draw(in: NSRect(x: 100, y: 560, width: 824, height: 364), angle: -90)
  ctx.restoreGState()

  // 2. One white folder, centred: the back with its tab, then the front.
  let back = NSBezierPath()
  back.move(to: NSPoint(x: 232, y: 300))
  back.line(to: NSPoint(x: 232, y: 690))
  back.appendArc(withCenter: NSPoint(x: 272, y: 690), radius: 40, startAngle: 180, endAngle: 90, clockwise: true)
  back.line(to: NSPoint(x: 420, y: 730))
  back.line(to: NSPoint(x: 470, y: 680))
  back.line(to: NSPoint(x: 752, y: 680))
  back.appendArc(withCenter: NSPoint(x: 752, y: 640), radius: 40, startAngle: 90, endAngle: 0, clockwise: true)
  back.line(to: NSPoint(x: 792, y: 300))
  back.close()
  color(0xD6E4FF).setFill(); back.fill()
  let frontRect = NSRect(x: 212, y: 260, width: 600, height: 380)
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x0A1A5C, 0.30).cgColor)
  color(0xFFFFFF).setFill(); NSBezierPath(roundedRect: frontRect, xRadius: 46, yRadius: 46).fill()
  ctx.restoreGState()

  // 3. An eye on the folder's front: the almond in the background blue, a white iris ring, a blue pupil.
  let c = NSPoint(x: frontRect.midX, y: frontRect.midY - 6)
  let eye = NSBezierPath()
  eye.move(to: NSPoint(x: c.x - 190, y: c.y))
  eye.curve(to: NSPoint(x: c.x + 190, y: c.y), controlPoint1: NSPoint(x: c.x - 90, y: c.y + 150), controlPoint2: NSPoint(x: c.x + 90, y: c.y + 150))
  eye.curve(to: NSPoint(x: c.x - 190, y: c.y), controlPoint1: NSPoint(x: c.x + 90, y: c.y - 150), controlPoint2: NSPoint(x: c.x - 90, y: c.y - 150))
  eye.close()
  ctx.saveGState(); eye.addClip()
  NSGradient(colors: [color(0x5B8CFF), color(0x3A3FC4)])!.draw(in: NSRect(x: c.x - 190, y: c.y - 120, width: 380, height: 240), angle: -90)
  ctx.restoreGState()
  color(0xFFFFFF).setFill(); NSBezierPath(ovalIn: NSRect(x: c.x - 70, y: c.y - 70, width: 140, height: 140)).fill()
  color(0x2F3FB8).setFill(); NSBezierPath(ovalIn: NSRect(x: c.x - 40, y: c.y - 40, width: 80, height: 80)).fill()
  color(0xFFFFFF, 0.9).setFill(); NSBezierPath(ovalIn: NSRect(x: c.x + 8, y: c.y + 12, width: 22, height: 22)).fill()

  NSGraphicsContext.restoreGraphicsState()
  return rep
}

func run(_ tool: String, _ args: [String]) {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: tool)
  p.arguments = args
  try! p.run(); p.waitUntilExit()
  precondition(p.terminationStatus == 0, "\(tool) failed")
}

let master = drawIcon().representation(using: .png, properties: [:])!
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("glimpse-icon-\(UUID().uuidString)")
let iconset = tmp.appendingPathComponent("AppIcon.iconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let masterURL = tmp.appendingPathComponent("icon-1024.png")
try! master.write(to: masterURL)
for points in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let px = points * scale
    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    run("/usr/bin/sips", ["-z", "\(px)", "\(px)", masterURL.path, "--out", iconset.appendingPathComponent(name).path, "-s", "format", "png"])
  }
}
run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", repo.appendingPathComponent("Support/AppIcon.icns").path])
let images = repo.appendingPathComponent("docs/images")
try! FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
run("/usr/bin/sips", ["-z", "256", "256", masterURL.path, "--out", images.appendingPathComponent("icon.png").path])
try? FileManager.default.removeItem(at: tmp)
print("wrote Support/AppIcon.icns and docs/images/icon.png")
