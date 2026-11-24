// The Accessibility permission: is it granted, ask for it, open the right System Settings pane.
// Glimpse needs it to ask Finder what is under the cursor (docs/02-design.md, step 4).
import AppKit
import ApplicationServices

enum Accessibility {
  /// True when this exact build is allowed. An ad-hoc signed rebuild is a new app to macOS (D4), so this turns false
  /// after every rebuild until granted again.
  static var isGranted: Bool { AXIsProcessTrusted() }

  /// Shows macOS's own prompt (only if not granted yet). The key is the value of `kAXTrustedCheckOptionPrompt`,
  /// written out because Swift 6 rejects the C global as not concurrency-safe.
  static func ask() {
    _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
  }

  /// System Settings → Privacy & Security → Accessibility.
  static func openSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
  }
}
