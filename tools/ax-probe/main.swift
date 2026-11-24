// Glimpse probe (steps P0.1 + P0.2): a throwaway app that answers two questions.
//   P0.1  When the cursor rests on a desktop icon, does Finder say (through Accessibility) which item it is?
//   P0.2  Does the window list say "the desktop is showing here", even in the top 81-point Window Server strip?
// Once a second it writes one JSON line to ~/Library/Logs/Glimpse-probe.log. Read-only: it never clicks, types,
// moves or opens anything. For elements that belong to other apps it logs only the app name and role, never
// their titles or text.
//
// Build and start:  tools/ax-probe/build.sh --run     Options (after --args):  --seconds N   --no-ax
// Read the result:  python3 tools/ax-probe/check-log.py

import AppKit
import ApplicationServices
import CoreGraphics

// MARK: - Options

var seconds = 120
var useAX = true
do {
  let args = CommandLine.arguments
  if let i = args.firstIndex(of: "--seconds"), i + 1 < args.count, let n = Int(args[i + 1]), n > 0 { seconds = n }
  if args.contains("--no-ax") { useAX = false }  // window check only; for testing without the permission
}

// MARK: - Log

let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Glimpse-probe.log")
if !FileManager.default.fileExists(atPath: logURL.path) {
  FileManager.default.createFile(atPath: logURL.path, contents: nil)
}
let logHandle = try! FileHandle(forWritingTo: logURL)
logHandle.seekToEndOfFile()

func log(_ object: [String: Any]) {
  guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
  logHandle.write(data)
  logHandle.write("\n".data(using: .utf8)!)
}

func timestamp() -> String {
  let f = ISO8601DateFormatter()
  f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return f.string(from: Date())
}

// MARK: - Screens and the cursor

let ownPID = ProcessInfo.processInfo.processIdentifier
let mainScreen = NSScreen.screens[0]  // the one with the menu bar (D1)
let finderPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.processIdentifier ?? -1

/// Cursor in Quartz coordinates (origin top-left of the main screen, y grows down), the system that both the window
/// list and Accessibility use.
func cursorQuartz() -> (cocoa: CGPoint, quartz: CGPoint) {
  let c = NSEvent.mouseLocation
  return (c, CGPoint(x: c.x, y: mainScreen.frame.height - c.y))
}

func rect(_ r: CGRect) -> [Double] {
  [r.origin.x, r.origin.y, r.size.width, r.size.height].map { (v: CGFloat) -> Double in (Double(v) * 10).rounded() / 10 }
}

// MARK: - P0.2: windows at the point, front to back

func windowsAt(_ p: CGPoint) -> [[String: Any]] {
  guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
  var out: [[String: Any]] = []
  for w in list {  // already ordered front to back
    guard let bd = w[kCGWindowBounds as String], let b = CGRect(dictionaryRepresentation: bd as! CFDictionary),
          b.contains(p) else { continue }
    out.append([
      "owner": w[kCGWindowOwnerName as String] as? String ?? "?",
      "pid": w[kCGWindowOwnerPID as String] as? Int ?? -1,
      "layer": w[kCGWindowLayer as String] as? Int ?? 0,
      "alpha": w[kCGWindowAlpha as String] as? Double ?? 1,
      "bounds": rect(b),
    ])
  }
  return out
}

/// The rule from 02 step 3: skip our own windows and Window Server's; the first other window must be Finder's with
/// layer < 0. With `skipDock`, also skip the Dock's full-screen window at the Dock level (layer 20), which was found
/// in front of everything on 2026-11-24 while building this probe.
let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
func desktopRule(_ windows: [[String: Any]], skipDock: Bool) -> (showing: Bool, decidedBy: String?) {
  for w in windows {
    let pid = w["pid"] as! Int, owner = w["owner"] as! String, layer = w["layer"] as! Int
    if pid == Int(ownPID) || owner == "Window Server" { continue }
    if skipDock && owner == "Dock" && layer == dockLevel { continue }
    return (pid == Int(finderPID) && layer < 0, "\(owner) layer \(layer)")
  }
  return (false, nil)
}

// MARK: - P0.1: ask Finder what is at the point

// Two ways to ask: the whole system ("what's on top here?") and Finder alone ("which of your elements is here?").
// The second still works if another app's see-through window (the Dock's) is on top.
let systemWide = AXUIElementCreateSystemWide()
let finderApp = AXUIElementCreateApplication(finderPID)
AXUIElementSetMessagingTimeout(systemWide, 0.25)
AXUIElementSetMessagingTimeout(finderApp, 0.25)
var attributeNamesLogged = Set<String>()

func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
  var v: CFTypeRef?
  return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}

func string(_ el: AXUIElement, _ name: String) -> String? { attr(el, name) as? String }

func describe(_ el: AXUIElement) -> [String: Any] {
  var pid: pid_t = -1
  AXUIElementGetPid(el, &pid)
  var d: [String: Any] = [
    "pid": Int(pid),
    "app": NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?",
    "role": string(el, kAXRoleAttribute) ?? "",
  ]
  // Safety rule 2: details only for Finder's elements.
  guard pid == finderPID else { return d }
  d["subrole"] = string(el, kAXSubroleAttribute)
  d["title"] = string(el, kAXTitleAttribute)
  d["description"] = string(el, kAXDescriptionAttribute)
  d["identifier"] = string(el, kAXIdentifierAttribute)
  d["filename"] = string(el, "AXFilename")
  d["value"] = string(el, kAXValueAttribute)
  if let u = attr(el, kAXURLAttribute) {
    d["url"] = (u as? URL)?.absoluteString ?? String(describing: u)
  }
  var pos = CGPoint.zero, size = CGSize.zero
  if let v = attr(el, kAXPositionAttribute), CFGetTypeID(v) == AXValueGetTypeID() { AXValueGetValue(v as! AXValue, .cgPoint, &pos) }
  if let v = attr(el, kAXSizeAttribute), CFGetTypeID(v) == AXValueGetTypeID() { AXValueGetValue(v as! AXValue, .cgSize, &size) }
  if size != .zero { d["frame"] = rect(CGRect(origin: pos, size: size)) }
  // Once per kind of element: every attribute Finder offers, so we learn what else is there.
  let kind = "\(d["role"] ?? "")/\(d["subrole"] ?? "")"
  if !attributeNamesLogged.contains(kind) {
    attributeNamesLogged.insert(kind)
    var names: CFArray?
    if AXUIElementCopyAttributeNames(el, &names) == .success { d["attributeNames"] = names as? [String] }
  }
  return d.compactMapValues { $0 }
}

func askAccessibility(_ root: AXUIElement, _ p: CGPoint) -> [String: Any] {
  var hit: AXUIElement?
  let t0 = Date()
  let err = AXUIElementCopyElementAtPosition(root, Float(p.x), Float(p.y), &hit)
  let ms = (Date().timeIntervalSince(t0) * 10000).rounded() / 10
  guard err == .success, let el = hit else { return ["error": err.rawValue, "ms": ms] }
  var chain = [describe(el)]
  var current = el
  for _ in 0..<3 {  // the element and up to 3 parents (02 step 4)
    guard let parent = attr(current, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
    current = parent as! AXUIElement
    chain.append(describe(current))
  }
  return ["ms": ms, "chain": chain]
}

// MARK: - Run

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no Dock icon

func sample() {
  let (cocoa, q) = cursorQuartz()
  let windows = windowsAt(q)
  let planned = desktopRule(windows, skipDock: false)
  let skipDock = desktopRule(windows, skipDock: true)
  var line: [String: Any] = [
    "t": timestamp(),
    "cursorCocoa": [cocoa.x, cocoa.y],
    "cursor": [q.x, q.y],
    "windows": windows,
    "desktopRulePlanned": ["showing": planned.showing, "decidedBy": planned.decidedBy ?? "nothing"],
    "desktopRuleSkipDock": ["showing": skipDock.showing, "decidedBy": skipDock.decidedBy ?? "nothing"],
  ]
  if useAX {
    line["axSystemWide"] = askAccessibility(systemWide, q)
    line["axFinder"] = askAccessibility(finderApp, q)
  }
  log(line)
}

func startSampling() {
  NSSound(named: "Tink")?.play()
  log(["event": "sampling", "t": timestamp(), "seconds": seconds])
  var n = 0
  Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
    sample()
    n += 1
    if n >= seconds {
      timer.invalidate()
      log(["event": "done", "t": timestamp(), "samples": n])
      NSSound(named: "Glass")?.play()
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }
    }
  }
}

log([
  "event": "start", "t": timestamp(),
  "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
  "mainScreen": rect(mainScreen.frame), "screens": NSScreen.screens.count,
  "finderPID": Int(finderPID), "ownPID": Int(ownPID), "useAX": useAX,
])

if !useAX {
  startSampling()
} else {
  let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
  if AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary) {
    startSampling()
  } else {
    // Wait up to 5 minutes for the grant in System Settings, then start on its own.
    log(["event": "waiting for Accessibility", "t": timestamp()])
    var waited = 0
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
      waited += 1
      if AXIsProcessTrusted() {
        timer.invalidate()
        log(["event": "granted", "t": timestamp(), "afterSeconds": waited])
        startSampling()
      } else if waited >= 300 {
        log(["event": "gave up: Accessibility not granted within 5 minutes", "t": timestamp()])
        exit(1)
      }
    }
  }
}

app.run()
