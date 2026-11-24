// Developer option (P5.2 data collection): `--dump-finder-shapes <file>`. For each open Finder window, find items that
// carry a file path and ask Accessibility "what's at this point?" (of Finder alone, so windows in front don't matter)
// at the item, its name and further along its row: what a hover there would see. Writes one line per point: the
// window's view (as far as its roles tell), the chain's shape and whether the icon-view rule accepts it.
// Roles, [url] markers and sizes only: never names, titles or paths. Finder only. This walks Finder's windows beyond
// the cursor, which normal operation never does (safety rule 2), so it runs only when asked from the command line.
import AppKit
import ApplicationServices
import GlimpseCore

@MainActor
extension DesktopHitTest {
  static func dumpFinderShapes(to url: URL) {
    let finder = finderPID
    let app = AXUIElementCreateApplication(finder)
    AXUIElementSetMessagingTimeout(app, 0.5)
    var out = ["Finder shapes, \(ISO8601DateFormatter().string(from: Date())). Roles only; [url] = has a file path."]
    let windows = (attrValue(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    out.append("windows: \(windows.count)")

    for (w, window) in windows.enumerated() {
      // Walk the window breadth-first (bounded) to find elements with a file URL, and note the container roles seen.
      var queue: [(AXUIElement, Int)] = [(window, 0)], seen = 0, containers = Set<String>()
      var items: [(AXUIElement, [AXUIElement])] = []  // element with a URL, and its ancestors (nearest first)
      var parents: [AXUIElement: [AXUIElement]] = [:]
      while !queue.isEmpty, seen < 3000, items.count < 6 {
        let (el, depth) = queue.removeFirst()
        seen += 1
        let role = attrValue(el, kAXRoleAttribute) as? String ?? "?"
        let sub = attrValue(el, kAXSubroleAttribute) as? String
        if ["AXOutline", "AXBrowser", "AXList", "AXTable", "AXScrollArea", "AXSplitGroup"].contains(role) {
          containers.insert(sub.map { "\(role)/\($0)" } ?? role)
        }
        if depth > 0, role != "AXWindow", let u = attrValue(el, kAXURLAttribute) as? URL, u.isFileURL {
          items.append((el, parents[el] ?? []))
        }
        guard depth < 14, let kids = attrValue(el, kAXChildrenAttribute) as? [AXUIElement] else { continue }
        for k in kids.prefix(60) {
          parents[k] = [el] + (parents[el] ?? [])
          queue.append((k, depth + 1))
        }
      }
      out.append("window \(w): containers \(containers.sorted().joined(separator: ", ")); items with a path: \(items.count)")

      for (i, (item, ancestors)) in items.enumerated() {
        guard let frame = frameOf(item) else { continue }
        var points: [(String, CGPoint)] = [("item", CGPoint(x: frame.midX, y: frame.midY)),
                                           ("item+60", CGPoint(x: frame.maxX + 60, y: frame.midY))]
        if let row = ancestors.first(where: { (attrValue($0, kAXRoleAttribute) as? String) == "AXRow" }), let r = frameOf(row) {
          points.append(("row 60%", CGPoint(x: r.minX + r.width * 0.6, y: r.midY)))
          points.append(("row 85%", CGPoint(x: r.minX + r.width * 0.85, y: r.midY)))
        }
        for (label, p) in points {
          var hit: AXUIElement?
          guard AXUIElementCopyElementAtPosition(app, Float(p.x), Float(p.y), &hit) == .success, let h = hit else {
            out.append("  item \(i) \(label): no element"); continue
          }
          var chain: [AXUIElement] = [h]
          while chain.count < 4, let parent = attrValue(chain.last!, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() {
            chain.append(parent as! AXUIElement)
          }
          let infos = chain.map { elementInfo($0, finder: finder) }
          let verdict: String
          switch DesktopRules.iconViewItem(fromChain: infos, finderPID: finder) {
          case .item: verdict = "ICON-VIEW ITEM"
          case .background: verdict = "background"
          case .notFinder: verdict = "not Finder"
          case .unrecognised: verdict = "not icon view"
          }
          out.append("  item \(i) \(label) (\(Int(frame.width))x\(Int(frame.height))): \(DesktopRules.shape(infos))  → \(verdict)")
        }
      }
    }
    try? out.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
    Log.write("dumped Finder shapes: \(windows.count) windows")
  }

  private static func attrValue(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
  }

  private static func frameOf(_ el: AXUIElement) -> CGRect? {
    var pos = CGPoint.zero, size = CGSize.zero
    guard let p = attrValue(el, kAXPositionAttribute), let s = attrValue(el, kAXSizeAttribute),
          CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    AXValueGetValue(p as! AXValue, .cgPoint, &pos)
    AXValueGetValue(s as! AXValue, .cgSize, &size)
    return CGRect(origin: pos, size: size)
  }
}
