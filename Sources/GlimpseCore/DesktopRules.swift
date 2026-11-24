// The rules that turn "windows under the cursor" + "what Finder says is there" into a desktop item (02 steps 3–5).
// Pure functions on plain values, so they can be replayed against the P0 probe's log
// (docs/rollout/P1.3-hover-detection.md#tests-2026-11-24) and are covered by Tests/GlimpseCoreTests. This is the one place to fix if a macOS update changes how
// Finder describes its desktop icons.
import CoreGraphics
import Foundation

public struct WindowInfo: Sendable {
  public let owner: String
  public let pid: pid_t
  public let layer: Int
  public let bounds: CGRect  // Quartz: origin top-left
  /// 0 = fully transparent (invisible).
  public let alpha: Double

  public init(owner: String, pid: pid_t, layer: Int, bounds: CGRect, alpha: Double = 1) {
    self.owner = owner; self.pid = pid; self.layer = layer; self.bounds = bounds; self.alpha = alpha
  }
}

/// What Accessibility said about one element. Only Finder's elements carry details (safety rule 2); for other apps
/// only `pid` and `role` are filled in.
public struct ElementInfo: Sendable {
  public var pid: pid_t
  public var role: String
  public var subrole: String? = nil
  public var url: URL? = nil
  public var filename: String? = nil
  public var title: String? = nil
  public var value: String? = nil
  public var frame: CGRect? = nil
  /// Filled in only for small Finder elements (an icon's group), so a hit on a label can find the icon next to it.
  public var children: [ElementInfo] = []

  public init(pid: pid_t, role: String, subrole: String? = nil, url: URL? = nil, filename: String? = nil,
              title: String? = nil, value: String? = nil, frame: CGRect? = nil, children: [ElementInfo] = []) {
    self.pid = pid; self.role = role; self.subrole = subrole; self.url = url; self.filename = filename
    self.title = title; self.value = value; self.frame = frame; self.children = children
  }
}

public enum ItemMatch: Equatable, Sendable {
  /// A desktop item: its URL in ~/Desktop, the box Finder gave for it, and which attribute named it.
  case item(URL, frame: CGRect?, via: String)
  /// Finder's desktop background (empty desktop).
  case background
  /// The answer came from another app (Dock, a widget, an app window).
  case notFinder(role: String)
  /// A Finder element we can't turn into an item. Logged (capped) so a macOS change shows up in the log.
  case unrecognised(String)
}

public enum DesktopRules {
  public static let dockLevel = Int(CGWindowLevelForKey(.dockWindow))  // 20

  /// What the cursor is over, as far as windows go.
  public enum Surface: Equatable, Sendable {
    /// Finder's desktop (layer < 0).
    case desktop
    /// A normal Finder window (layer 0 and up): browser windows, but also Get Info and other Finder windows; the
    /// icon-view rule decides further (P5.1).
    case finderWindow
    /// Anything else in front: another app, a widget, nothing at all.
    case other(String)
  }

  /// 02 step 3: front to back, skip our own windows, Window Server's (menu bar, the top 81-point strip), every
  /// **system overlay at the Dock's layer (20) or above**, and fully transparent windows; the first other window
  /// decides. Windows are expected front to back, as `CGWindowListCopyWindowInfo` returns them.
  ///
  /// Overlays at layer ≥ 20 are see-through system UI: the Dock's full-screen window (found in P0), menu-bar items,
  /// and the Screenshot tool's full-screen window, which stays up while ⇧⌘5's toolbar is open or a recording runs
  /// (found 2026-11-24: it made every check fail, F1). Skipping them is safe because the system-wide Accessibility
  /// question decides next: it sees through them (checked with `--hit-test` while the Screenshot overlay was up), and
  /// when an overlay really is in the way (a Dock tile, Spotlight), it answers with that app instead of Finder.
  public static func surface(_ windows: [WindowInfo], at p: CGPoint, ownPID: pid_t, finderPID: pid_t) -> Surface {
    for w in windows where w.bounds.contains(p) {
      if w.pid == ownPID || w.owner == "Window Server" { continue }
      if w.layer >= dockLevel || w.alpha == 0 { continue }
      if w.pid == finderPID { return w.layer < 0 ? .desktop : .finderWindow }
      return .other("\(w.owner) layer \(w.layer)")
    }
    return .other("nothing")
  }

  /// The desktop-only form of `surface`, kept for the desktop tests.
  public static func desktopShowing(_ windows: [WindowInfo], at p: CGPoint, ownPID: pid_t, finderPID: pid_t)
    -> (showing: Bool, decidedBy: String)
  {
    switch surface(windows, at: p, ownPID: ownPID, finderPID: finderPID) {
    case .desktop: (true, "Finder desktop")
    case .finderWindow: (false, "Finder window")
    case .other(let what): (false, what)
    }
  }

  /// P5.1: an item in a Finder window **in icon view** (D5 as changed 2026-11-24). Seen in the P0 probe run: an
  /// `AXImage` carrying `AXURL` › `AXGroup` › `AXList/AXSectionList` › `AXList/AXCollectionList`. A hit on the label
  /// reaches the image through its group's children. List and column views (rows in an `AXOutline` or `AXBrowser`)
  /// and the sidebar (`AXOutline`) have no collection list in the chain, so they don't count. Only a real file URL
  /// names the item here: shown names can't be matched without knowing the window's folder.
  public static func iconViewItem(fromChain chain: [ElementInfo], finderPID: pid_t) -> ItemMatch {
    guard let hit = chain.first else { return .unrecognised("no element") }
    if hit.pid != finderPID { return .notFinder(role: hit.role) }
    let finderChain = Array(chain.prefix(4).prefix { $0.pid == finderPID })
    guard finderChain.contains(where: { $0.role == "AXList" && $0.subrole == "AXCollectionList" }) else {
      return .unrecognised("not icon view: " + shape(finderChain))
    }
    for el in finderChain {
      for candidate in [el] + el.children where candidate.role == "AXImage" {
        if let url = candidate.url, url.isFileURL { return .item(url, frame: candidate.frame ?? el.frame, via: "AXURL, icon view") }
      }
    }
    return .background  // the window's empty space, a section header, …
  }

  /// Roles only, never titles, values or paths: safe to log (safety rule 2). `[url]` says an element has a file URL
  /// (not which); `{…}` lists the children Glimpse read. Used to learn what other Finder views look like (P5.2).
  public static func shape(_ chain: [ElementInfo]) -> String {
    chain.map(describe).joined(separator: " > ")
  }

  private static func describe(_ el: ElementInfo) -> String {
    var s = el.subrole.map { "\(el.role)/\($0)" } ?? el.role
    if el.url?.isFileURL == true { s += "[url]" }
    if !el.children.isEmpty { s += "{" + el.children.map(describe).joined(separator: ", ") + "}" }
    return s
  }

  /// 02 steps 4–5: the hit element first, then up to 3 parents; on each, AXURL, then AXFilename, then the shown name.
  /// Small elements also look at their children (a label's group holds the icon). Only items directly in `desktop`
  /// count (D5). `screen` is the screen under the point (any size; only its size is used, to recognise the desktop's
  /// background).
  public static func item(fromChain chain: [ElementInfo], finderPID: pid_t, desktop: URL, desktopNames: () -> [String],
                   screen: CGRect) -> ItemMatch
  {
    guard let hit = chain.first else { return .unrecognised("no element") }
    if hit.pid != finderPID { return .notFinder(role: hit.role) }

    var names: [String]?
    for el in chain.prefix(4) where el.pid == finderPID {
      for candidate in [el] + el.children {
        if let match = named(candidate, desktop: desktop, names: { names = names ?? desktopNames(); return names! }) {
          return .item(match.url, frame: candidate.frame ?? el.frame, via: match.via)
        }
      }
    }
    // The desktop itself: a group or scroll area as big as the screen.
    if let f = hit.frame, f.width >= screen.width * 0.9, f.height >= screen.height * 0.9 { return .background }
    return .unrecognised("\(hit.role)/\(hit.subrole ?? "") frame \(hit.frame.map { "\($0)" } ?? "none")")
  }

  private static func named(_ el: ElementInfo, desktop: URL, names: () -> [String]) -> (url: URL, via: String)? {
    if let url = el.url, url.isFileURL, isDirectlyIn(url, desktop) {
      return (url, "AXURL")
    }
    if let f = el.filename, names().contains(f) {
      return (desktop.appendingPathComponent(f), "AXFilename")
    }
    for (shown, via) in [(el.title, "AXTitle"), (el.value, "AXValue")] {
      if let s = shown, let n = match(shown: s, in: names()) {
        return (desktop.appendingPathComponent(n), via)
      }
    }
    return nil
  }

  public static func isDirectlyIn(_ url: URL, _ folder: URL) -> Bool {
    let parent = url.standardizedFileURL.deletingLastPathComponent().path
    return trimmed(parent) == trimmed(folder.standardizedFileURL.path)
  }

  private static func trimmed(_ path: String) -> String {
    path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
  }

  /// A shown name → exactly one item, allowing a hidden extension ("report" for "report.pdf").
  public static func match(shown: String, in names: [String]) -> String? {
    if names.contains(shown) { return shown }
    let stems = names.filter { ($0 as NSString).deletingPathExtension == shown }
    return stems.count == 1 ? stems[0] : nil
  }
}
