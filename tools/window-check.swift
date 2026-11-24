// Read-only check: lists the screens, Finder's windows and every window not on the normal app layer (0): the desktop
// layers below 0 and system windows above it (menu bar, Dock).
// Needs no permissions. Run: swift tools/window-check.swift

import AppKit
import CoreGraphics
for (i, s) in NSScreen.screens.enumerated() {
  print("screen[\(i)] frame=\(s.frame) visible=\(s.visibleFrame) scale=\(s.backingScaleFactor) name=\(s.localizedName)")
}
print("desktopIconWindow level =", CGWindowLevelForKey(.desktopIconWindow), " desktopWindow level =", CGWindowLevelForKey(.desktopWindow), " floating =", CGWindowLevelForKey(.floatingWindow))
let finderPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.processIdentifier ?? -1
print("finder pid", finderPID)
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
print("on-screen windows:", list.count)
for w in list {
  let pid = w[kCGWindowOwnerPID as String] as! Int32
  let layer = w[kCGWindowLayer as String] as! Int
  if pid == finderPID || layer != 0 {
    let b = CGRect(dictionaryRepresentation: w[kCGWindowBounds as String] as! CFDictionary)!
    print(" owner=\(w[kCGWindowOwnerName as String] ?? "?") pid=\(pid) layer=\(layer) alpha=\(w[kCGWindowAlpha as String] ?? "?") bounds=\(b) name=\(w[kCGWindowName as String] ?? "<hidden>")")
  }
}
