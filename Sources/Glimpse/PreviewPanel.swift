// The floating preview panel (02 "The panel"). It never takes focus: the app you're using stays active, and the panel
// shows on every Space and never appears in ⌘-Tab.
//
//   ┌──────────────────────────────────────┐
//   │ 📁 Work                   47 items    │  header
//   ├──────────────────────────────────────┤
//   │ 📁 apps                               │  folders first,
//   │ 📁 clips-lambda                       │  then files, in Finder's name order
//   │ 📄 notes.txt                   12 KB  │  sizes for files
//   │ …                (scrolls after 12)   │
//   └──────────────────────────────────────┘
import AppKit
import GlimpseCore
import SwiftUI

enum PanelLayout {
  static let width: CGFloat = 300
  static let rowHeight: CGFloat = 28  // 22 until P6.1; taller so a 24-point thumbnail is worth looking at
  static let iconSize: CGFloat = 24
  static let visibleRows = 12
  static let headerHeight: CGFloat = 40
  static let messageHeight: CGFloat = 56
  static let padding: CGFloat = 6

  static func height(for content: PanelContent) -> CGFloat {
    switch content.state {
    case .items(let items) where !items.isEmpty:
      headerHeight + CGFloat(min(items.count, visibleRows)) * rowHeight + 2 * padding
    default:
      headerHeight + messageHeight
    }
  }
}

struct PanelContent {
  let folder: URL
  let state: FolderListing.Result

  var title: String {
    (try? folder.resourceValues(forKeys: [.localizedNameKey]))?.localizedName ?? folder.lastPathComponent
  }
}

@MainActor
final class PreviewPanel {
  private let panel: NSPanel

  init() {
    panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: PanelLayout.width, height: 200),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: true)
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    panel.hidesOnDeactivate = false
    panel.becomesKeyOnlyIfNeeded = true
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.isReleasedWhenClosed = false
  }

  var isVisible: Bool { panel.isVisible }
  /// The folder on show, while visible.
  private(set) var folder: URL?
  /// The panel's frame in Cocoa coordinates.
  var frame: NSRect { panel.frame }
  /// Called when a row is clicked (P2.2).
  var onOpen: ((FolderItem) -> Void)?

  /// Shows `folder`. `place` gets the panel's size and returns its frame (Cocoa coordinates); without it, the panel is
  /// centred on the main screen.
  func show(_ folder: URL, place: ((NSSize) -> NSRect)? = nil) {
    let started = Date()
    let content = PanelContent(folder: folder, state: FolderListing.list(folder))
    let size = NSSize(width: PanelLayout.width, height: PanelLayout.height(for: content))

    // Size the background before adding the list: autoresizing adds the background's growth to the list, so a list
    // added to a 0 × 0 background would end up 300 points too wide.
    let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
    background.material = .popover
    background.blendingMode = .behindWindow
    background.state = .active
    background.wantsLayer = true
    background.layer?.cornerRadius = 10
    background.layer?.masksToBounds = true
    let hosting = FirstClickHostingView(rootView: PanelView(content: content, onOpen: { [weak self] in self?.onOpen?($0) }))
    hosting.frame = NSRect(origin: .zero, size: size)
    hosting.autoresizingMask = [.width, .height]
    background.addSubview(hosting)
    panel.contentView = background

    let screen = NSScreen.screens[0].visibleFrame  // fallback only (no placement given): the main screen
    let frame = place?(size)
      ?? NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
    panel.setFrame(frame, display: true)
    panel.orderFrontRegardless()  // shows it without activating Glimpse
    self.folder = folder

    let ms = Int(Date().timeIntervalSince(started) * 1000)
    switch content.state {
    case .items(let items): Log.write("panel: \(folder.lastPathComponent), \(items.count) items, \(ms) ms, at \(Int(frame.minX)),\(Int(frame.minY))")
    case .unreadable(let reason): Log.write("panel: can't read folder (\(reason)), \(ms) ms")
    }
  }

  func hide() {
    panel.orderOut(nil)
    folder = nil
  }

  /// Developer option: the panel's content as a PNG (no frosted background: a view snapshot can't see behind the
  /// window).
  func snapshot(to url: URL) {
    guard let view = panel.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    view.cacheDisplay(in: view.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
  }
}

/// The panel never becomes the active window, so every click on it is a "first click". By default AppKit uses a first
/// click only to bring a window forward; this view takes it as a real click, so one click opens a row.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - Content

private struct PanelView: View {
  let content: PanelContent
  let onOpen: (FolderItem) -> Void

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      switch content.state {
      case .unreadable:
        message("Can't read this folder")
      case .items(let items) where items.isEmpty:
        message("Empty folder")
      case .items(let items):
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(items) { item in Row(item: item, onOpen: onOpen) }
          }
          .padding(.vertical, PanelLayout.padding)
        }
      }
    }
    .frame(width: PanelLayout.width)
  }

  private var header: some View {
    HStack(spacing: 8) {
      Image(nsImage: NSWorkspace.shared.icon(forFile: content.folder.path))
        .resizable().frame(width: 20, height: 20)
      Text(content.title).font(.system(size: 13, weight: .semibold)).lineLimit(1).truncationMode(.middle)
      Spacer(minLength: 8)
      if case .items(let items) = content.state {
        Text(items.count == 1 ? "1 item" : "\(items.count) items").font(.system(size: 11)).foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 12)
    .frame(height: PanelLayout.headerHeight)
  }

  private func message(_ text: String) -> some View {
    Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, minHeight: PanelLayout.messageHeight)
  }
}

private struct Row: View {
  let item: FolderItem
  let onOpen: (FolderItem) -> Void
  @State private var hovering = false
  /// The Quick Look preview, once it arrives (P6.1); until then, and for folders, the Finder icon.
  @State private var thumbnail: NSImage?
  private static let sizes: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.countStyle = .file  // Finder's style: 1 KB = 1000 bytes
    return f
  }()

  var body: some View {
    Button { onOpen(item) } label: {
      HStack(spacing: 6) {
        Group {
          if let thumbnail {
            Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fit)
              .clipShape(RoundedRectangle(cornerRadius: 3))
          } else {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)).resizable()
          }
        }
        .frame(width: PanelLayout.iconSize, height: PanelLayout.iconSize)
        Text(item.name).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
        Spacer(minLength: 8)
        if let size = item.size {
          Text(Self.sizes.string(fromByteCount: size)).font(.system(size: 11)).foregroundStyle(.secondary)
            .monospacedDigit()
        }
      }
      .padding(.horizontal, 8)
      .frame(height: PanelLayout.rowHeight)
      .background(RoundedRectangle(cornerRadius: 5).fill(hovering ? Color.accentColor.opacity(0.25) : .clear))
      .contentShape(Rectangle())  // the whole row is clickable, not just the text
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 4)
    .onHover { hovering = $0 }
    // Runs when the row appears on screen (rows are created lazily while scrolling) and is cancelled if it goes away.
    .task(id: item.url) {
      guard !item.isFolder, ThumbnailPolicy.wantsThumbnail(item.type) else { return }
      thumbnail = await Thumbnails.shared.image(for: item.url, modified: item.modified)
    }
  }
}
