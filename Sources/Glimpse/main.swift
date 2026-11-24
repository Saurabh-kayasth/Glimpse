// Entry point. A menu-bar-only app: no Dock icon (LSUIElement in Support/Info.plist, and .accessory here).
import AppKit

MainActor.assumeIsolated {
  let app = NSApplication.shared
  let delegate = AppDelegate()
  app.delegate = delegate
  app.setActivationPolicy(.accessory)
  withExtendedLifetime(delegate) { app.run() }
}
