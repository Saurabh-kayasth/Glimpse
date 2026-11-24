// Reads one folder's list of items for the panel (02 step 6). Read-only (D6, safety rule 1): it only asks the file
// system for names and a few attributes. It never opens, moves, renames or writes anything.
import AppKit
import UniformTypeIdentifiers

struct FolderItem: Identifiable {
  let url: URL
  /// The name as Finder shows it (hidden extensions stay hidden).
  let name: String
  /// A real folder. Packages such as .app bundles count as files, the way Finder shows them.
  let isFolder: Bool
  /// Bytes, for files only.
  let size: Int64?
  /// Last change, so a cached thumbnail is redrawn when the file changes (P6.1).
  let modified: Date?
  /// The file's type, to decide whether it gets a preview (P6.1).
  let type: UTType?
  var id: URL { url }
}

enum FolderListing {
  enum Result {
    case items([FolderItem])
    case unreadable(reason: String)
  }

  private static let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .fileSizeKey, .localizedNameKey, .contentModificationDateKey, .contentTypeKey]

  /// Hidden files skipped; folders first, then by name in Finder's order (`localizedStandardCompare`, so "file 2" comes
  /// before "file 10").
  static func list(_ folder: URL) -> Result {
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(
        at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
    } catch {
      return .unreadable(reason: (error as NSError).localizedDescription)
    }
    let items = contents.map { url -> FolderItem in
      let v = try? url.resourceValues(forKeys: Set(keys))
      let isFolder = (v?.isDirectory ?? false) && !(v?.isPackage ?? false)
      return FolderItem(
        url: url,
        name: v?.localizedName ?? url.lastPathComponent,
        isFolder: isFolder,
        size: isFolder || (v?.isDirectory ?? false) ? nil : v?.fileSize.map(Int64.init),
        modified: v?.contentModificationDate,
        type: v?.contentType)
    }
    return .items(items.sorted {
      if $0.isFolder != $1.isFolder { return $0.isFolder }
      return $0.name.localizedStandardCompare($1.name) == .orderedAscending
    })
  }
}
