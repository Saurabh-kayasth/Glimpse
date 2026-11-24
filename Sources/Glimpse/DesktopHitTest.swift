// The live side of hover detection (desktop, and Finder windows in icon view since P5.1): reads the window list and asks Accessibility what's at a point, then applies
// DesktopRules. Every Accessibility question has a 0.25 s time-out, so a busy Finder can't freeze Glimpse for long.
import AppKit
import GlimpseCore
import ApplicationServices

enum HoverOutcome {
  case folder(URL, iconFrame: CGRect?, via: String)
  case notAFolder(URL)
  case nothing(String)          // not the desktop, empty desktop, another app's element
  case unrecognised(String)     // a Finder element on the desktop that DesktopRules can't name
}

@MainActor
enum DesktopHitTest {
  static let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
  private static let systemWide: AXUIElement = {
    let el = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(el, 0.25)
    return el
  }()

  static var finderPID: pid_t {
    NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.processIdentifier ?? -1
  }

  /// `p` in Quartz coordinates (origin top-left of the main screen); `screen` is the screen under it, in Quartz too.
  /// Folders in Finder windows (icon view) count too (P5.1); the menu's "Finder Windows" switch sets this.
  static var includeFinderWindows = true

  static func check(_ p: CGPoint, screen: CGRect) -> HoverOutcome {
    let finder = finderPID
    let surface = DesktopRules.surface(windows(), at: p, ownPID: ProcessInfo.processInfo.processIdentifier,
                                       finderPID: finder)
    switch surface {
    case .other(let what): return .nothing("desktop not showing (\(what))")
    case .finderWindow where !includeFinderWindows: return .nothing("Finder window (Finder Windows is off)")
    case .desktop, .finderWindow: break
    }

    finderBusy = false
    var hit: AXUIElement?
    let err = AXUIElementCopyElementAtPosition(systemWide, Float(p.x), Float(p.y), &hit)
    if err == .cannotComplete { return .nothing("Finder busy (time-out)") }
    guard err == .success, let el = hit else { return .nothing("accessibility error \(err.rawValue)") }

    var chain = [info(el, finder: finder)]
    var current = el
    for _ in 0..<3 {
      guard let parent = attr(current, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
      current = parent as! AXUIElement
      chain.append(info(current, finder: finder))
    }

    if finderBusy { return .nothing("Finder busy (time-out)") }
    let onDesktop = surface == .desktop
    let match = onDesktop
      ? DesktopRules.item(fromChain: chain, finderPID: finder, desktop: desktop, desktopNames: { desktopNames() }, screen: screen)
      : DesktopRules.iconViewItem(fromChain: chain, finderPID: finder)
    switch match {
    case .item(let url, let frame, let via):
      if let folder = realFolder(url) { return .folder(folder, iconFrame: frame, via: via) }
      return .notAFolder(url)
    case .background: return .nothing(onDesktop ? "empty desktop" : "Finder window: no item here")
    case .notFinder(let role): return .nothing("not Finder (\(role))")
    // On the desktop an unknown element is worth logging (capped); in a window it's usually the toolbar, sidebar or
    // another view, so it only shows with detailed logging, as roles only.
    case .unrecognised(let what): return onDesktop ? .unrecognised(what) : .nothing("Finder window: \(what)")
    }
  }

  // MARK: Window list

  private static func windows() -> [WindowInfo] {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
    return list.compactMap { w in
      guard let bd = w[kCGWindowBounds as String], let b = CGRect(dictionaryRepresentation: bd as! CFDictionary) else { return nil }
      return WindowInfo(owner: w[kCGWindowOwnerName as String] as? String ?? "?",
                        pid: pid_t(w[kCGWindowOwnerPID as String] as? Int ?? -1),
                        layer: w[kCGWindowLayer as String] as? Int ?? 0, bounds: b,
                        alpha: w[kCGWindowAlpha as String] as? Double ?? 1)
    }
  }

  // MARK: Accessibility

  /// Set when one question in this check timed out: Finder is busy, so the rest of the check is skipped instead of
  /// waiting 0.25 s per question (one check took 2.4 s that way on 2026-11-24, right after Show Desktop).
  private static var finderBusy = false

  private static func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    guard !finderBusy else { return nil }
    var v: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(el, name as CFString, &v)
    if err == .cannotComplete { finderBusy = true }
    return err == .success ? v : nil
  }

  /// Details only for Finder's elements (safety rule 2): for anything else, just the role.
  /// Developer option `--hit-test <x> <y>` (Quartz): what the system-wide question returns at that point, and the
  /// windows there. Roles and app names only. Used to check which overlays Accessibility sees through.
  static func debugHit(_ p: CGPoint) -> String {
    let wins = windows().filter { $0.bounds.contains(p) }.prefix(6).map { "\($0.owner)@\($0.layer)" }.joined(separator: ", ")
    var hit: AXUIElement?
    let err = AXUIElementCopyElementAtPosition(systemWide, Float(p.x), Float(p.y), &hit)
    guard err == .success, let el = hit else { return "hit-test (\(Int(p.x)), \(Int(p.y))): AX error \(err.rawValue); windows: \(wins)" }
    var pid: pid_t = -1
    AXUIElementGetPid(el, &pid)
    let app = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?"
    return "hit-test (\(Int(p.x)), \(Int(p.y))): \(app) \(attr(el, kAXRoleAttribute) as? String ?? "?"); windows front to back: \(wins)"
  }

  /// For the developer shape dump (FinderShapeDump.swift): the same element reading as a hover uses.
  static func elementInfo(_ el: AXUIElement, finder: pid_t) -> ElementInfo { info(el, finder: finder) }

  private static func info(_ el: AXUIElement, finder: pid_t, withChildren: Bool = true) -> ElementInfo {
    var pid: pid_t = -1
    AXUIElementGetPid(el, &pid)
    var i = ElementInfo(pid: pid, role: attr(el, kAXRoleAttribute) as? String ?? "")
    guard pid == finder else { return i }
    i.subrole = attr(el, kAXSubroleAttribute) as? String
    i.url = attr(el, kAXURLAttribute) as? URL
    i.filename = attr(el, "AXFilename") as? String
    i.title = attr(el, kAXTitleAttribute) as? String
    i.value = attr(el, kAXValueAttribute) as? String
    var pos = CGPoint.zero, size = CGSize.zero
    if let v = attr(el, kAXPositionAttribute), CFGetTypeID(v) == AXValueGetTypeID() { AXValueGetValue(v as! AXValue, .cgPoint, &pos) }
    if let v = attr(el, kAXSizeAttribute), CFGetTypeID(v) == AXValueGetTypeID() { AXValueGetValue(v as! AXValue, .cgSize, &size) }
    if size != .zero { i.frame = CGRect(origin: pos, size: size) }
    // A small element without a name of its own (a label's group), or a row or cell (list and column views, P5.2):
    // look at up to 4 children for the icon.
    let small = i.frame.map { $0.width <= 200 && $0.height <= 200 } ?? false
    if withChildren, i.url == nil, small || i.role == "AXRow" || i.role == "AXCell",
       let kids = attr(el, kAXChildrenAttribute) as? [AXUIElement] {
      i.children = kids.prefix(4).map { info($0, finder: finder, withChildren: false) }
    }
    return i
  }

  // MARK: Files

  private static func desktopNames() -> [String] {
    (try? FileManager.default.contentsOfDirectory(atPath: desktop.path))?.filter { !$0.hasPrefix(".") } ?? []
  }

  /// Follows symlinks and Finder aliases; keeps only real folders (not .app bundles or other packages).
  private static func realFolder(_ url: URL) -> URL? {
    var u = url.resolvingSymlinksInPath()
    if (try? u.resourceValues(forKeys: [.isAliasFileKey]))?.isAliasFile == true,
       let target = try? URL(resolvingAliasFileAt: u) {
      u = target
    }
    let v = try? u.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
    return v?.isDirectory == true && v?.isPackage != true ? u : nil
  }
}
