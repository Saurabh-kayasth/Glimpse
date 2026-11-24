// A small local log at ~/Library/Logs/Glimpse.log (safety rule 4: nothing leaves the Mac).
// Opened from the menu with "Show Log" (Console.app). Kept under 1 MB: a bigger file is moved to Glimpse.old.log at
// launch.
import Foundation

@MainActor
enum Log {
  static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Glimpse.log")
  private static let maxBytes = 1_000_000
  private static var handle: FileHandle?
  private static let stamp: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  static func write(_ message: String) {
    let h = handle ?? open()
    h?.write(Data("\(stamp.string(from: Date())) \(message)\n".utf8))
  }

  private static func open() -> FileHandle? {
    let fm = FileManager.default
    if let size = (try? fm.attributesOfItem(atPath: url.path))?[.size] as? Int, size > maxBytes {
      let old = url.deletingLastPathComponent().appendingPathComponent("Glimpse.old.log")
      try? fm.removeItem(at: old)
      try? fm.moveItem(at: url, to: old)
    }
    if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil) }
    handle = try? FileHandle(forWritingTo: url)
    handle?.seekToEndOfFile()
    return handle
  }
}
