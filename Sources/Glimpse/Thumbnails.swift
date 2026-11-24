// P6.1: real previews in the panel's rows, from macOS's own Quick Look thumbnails (the same ones Finder shows), for
// pictures, PDFs and videos only (GlimpseCore's ThumbnailPolicy). Asked for in the background, only for rows on
// screen, and cached by file and modification date, so the panel opens as fast as before and re-opening it costs
// nothing. Everything else keeps its Finder icon. Read-only (D6): Quick Look reads the file to draw it, nothing more.
import AppKit
import QuickLookThumbnailing

@MainActor
final class Thumbnails {
  static let shared = Thumbnails()
  /// The size a row shows (points); the image is made at the screen's pixel density.
  nonisolated static let size = CGSize(width: 24, height: 24)

  private let cache = NSCache<NSString, NSImage>()

  private init() { cache.countLimit = 500 }

  /// A preview of the file, or nil when Quick Look has none for this kind of file.
  func image(for url: URL, modified: Date?) async -> NSImage? {
    let key = "\(url.path)|\(modified?.timeIntervalSince1970 ?? 0)" as NSString
    if let hit = cache.object(forKey: key) { return hit }
    let scale = NSScreen.screens.first?.backingScaleFactor ?? 2
    guard let cg = await Self.make(url, scale: scale) else { return nil }
    let image = NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / scale, height: CGFloat(cg.height) / scale))
    cache.setObject(image, forKey: key)
    return image
  }

  /// Quick Look runs the drawing in its own process; only the finished CGImage comes back here.
  private nonisolated static func make(_ url: URL, scale: CGFloat) async -> CGImage? {
    let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
    return await withCheckedContinuation { done in
      QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
        done.resume(returning: rep?.cgImage)
      }
    }
  }
}
