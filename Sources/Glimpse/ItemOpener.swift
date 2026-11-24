// 02 step 8 (P2.2): clicking a row opens the item, the same as double-clicking it in Finder.
//   file, app or other package → its default app (NSWorkspace.open)
//   folder                     → a Finder window, always Finder, even if another app is set as the default for
//                                 folders (D8, decided 2026-11-24)
// Opening is the only thing Glimpse does to an item; it never moves, renames, deletes or writes anything (D6).
import AppKit

@MainActor
enum ItemOpener {
  static func open(_ item: FolderItem) {
    if item.isFolder {
      openInFinder(item.url)
    } else {
      Log.write("open: \(item.url.lastPathComponent) (default app)")
      if !NSWorkspace.shared.open(item.url) {
        Log.write("open failed: \(item.url.lastPathComponent)")
      }
    }
  }

  private static func openInFinder(_ folder: URL) {
    Log.write("open: \(folder.lastPathComponent) (folder, in Finder)")
    guard let finder = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") else {
      NSWorkspace.shared.open(folder)
      return
    }
    let name = folder.lastPathComponent
    NSWorkspace.shared.open([folder], withApplicationAt: finder, configuration: NSWorkspace.OpenConfiguration()) { _, error in
      guard let error else { return }
      let reason = error.localizedDescription
      Task { @MainActor in Log.write("open failed: \(name): \(reason)") }
    }
  }
}
