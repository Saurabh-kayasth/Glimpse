// The menu-bar icon and its menu (P1.1), and the hover → panel feature (P1.3 + P2.1, through HoverController).
//
//   👁  Hover Previews            ✓      on/off, remembered; previews run while on and Accessibility is granted
//      ─────────────
//      Accessibility: granted            or  "Grant Accessibility Access…" (prompt + System Settings)
//      ─────────────
//      Finder Windows                ✓      P5.1: folders in Finder windows in icon view too
//      Launch at Login               ✓      P3.1; only for the installed copy (~/Applications)
//      About Glimpse
//      Show Log
//      Quit Glimpse                 ⌘Q
//
// Developer option (not in the menu): `--simulate-hover <folder> <x> <y> <w> <h>` shows that folder's panel as if the
// cursor rested on an icon with that box (Quartz coordinates) and keeps it up, to check placement without hovering.
// `--dump-finder-shapes <file>` writes what a hover would see on items in the open Finder windows (roles only; P5.2).
// Add `--simulate-click <row>` to then do what a click on that row does (0 = first row), or `--snapshot <png>` to save
// the panel as an image 2 s later (after thumbnails have arrived).
import AppKit
import GlimpseCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private var statusItem: NSStatusItem!
  private let menu = NSMenu()
  private var accessibilityGranted = Accessibility.isGranted
  private var watchTimer: Timer?
  private let hover = HoverController()

  static let previewsKey = "hoverPreviewsEnabled"
  private var previewsEnabled: Bool {
    get { UserDefaults.standard.object(forKey: Self.previewsKey) as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: Self.previewsKey) }
  }

  static let finderWindowsKey = "finderWindowsEnabled"
  private var finderWindowsEnabled: Bool {
    get { UserDefaults.standard.object(forKey: Self.finderWindowsKey) as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: Self.finderWindowsKey) }
  }

  // Lets timers reach the delegate without capturing a non-Sendable self.
  private static weak var shared: AppDelegate?

  func applicationDidFinishLaunching(_ notification: Notification) {
    AppDelegate.shared = self
    // One Glimpse at a time: two would each open a panel on every hover.
    let me = ProcessInfo.processInfo.processIdentifier
    if let other = NSRunningApplication.runningApplications(withBundleIdentifier: "local.glimpse.app")
      .first(where: { $0.processIdentifier != me }) {
      Log.write("launch: another Glimpse is running (pid \(other.processIdentifier), \(other.bundleURL?.path ?? "?")); quitting this one")
      NSApp.terminate(nil)
      return
    }
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    Log.write("launch: Glimpse \(version) (build \(build)), pid \(ProcessInfo.processInfo.processIdentifier), " +
              "accessibility \(accessibilityGranted ? "granted" : "not granted"), previews \(previewsEnabled ? "on" : "off"), " +
              "from \(Bundle.main.bundlePath), launch at login \(LoginItem.describe(LoginItem.status))")

    DesktopHitTest.includeFinderWindows = finderWindowsEnabled
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    menu.delegate = self
    statusItem.menu = menu
    refresh()

    if !accessibilityGranted { Accessibility.ask() }

    // The grant (or its removal) happens in System Settings, outside the app; check every 2 s so the icon, the menu
    // and hover detection follow. AXIsProcessTrusted() is a cheap local check.
    watchTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
      MainActor.assumeIsolated { AppDelegate.shared?.checkAccessibility() }
    }

    simulateHoverIfAsked()
    if let i = CommandLine.arguments.firstIndex(of: "--hit-test"), i + 2 < CommandLine.arguments.count,
       let x = Double(CommandLine.arguments[i + 1]), let y = Double(CommandLine.arguments[i + 2]), accessibilityGranted {
      Log.write(DesktopHitTest.debugHit(CGPoint(x: x, y: y)))
      let screen = ScreenList.screen(at: CGPoint(x: x, y: ScreenList.mainHeight - y))
      let frame = screen.map { ScreenMath.toQuartz($0.frame, mainHeight: ScreenList.mainHeight) } ?? .zero
      Log.write("full check at (\(Int(x)), \(Int(y))): \(DesktopHitTest.check(CGPoint(x: x, y: y), screen: frame))")
    }
    if let i = CommandLine.arguments.firstIndex(of: "--dump-finder-shapes"), i + 1 < CommandLine.arguments.count,
       accessibilityGranted {
      DesktopHitTest.dumpFinderShapes(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    Log.write("quit")
  }

  private func checkAccessibility() {
    let now = Accessibility.isGranted
    guard now != accessibilityGranted else { return }
    accessibilityGranted = now
    Log.write("accessibility \(now ? "granted" : "removed")")
    refresh()
  }

  // MARK: Icon and menu

  private func refresh() {
    let symbol: String, tip: String
    if !accessibilityGranted {
      symbol = "eye.trianglebadge.exclamationmark"; tip = "Glimpse: needs Accessibility access"
    } else if previewsEnabled {
      symbol = "eye"; tip = "Glimpse: previews on"
    } else {
      symbol = "eye.slash"; tip = "Glimpse: previews off"
    }
    if let button = statusItem.button {
      button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
      button.image?.isTemplate = true
      button.toolTip = tip
    }
    if previewsEnabled && accessibilityGranted { hover.start() } else { hover.stop() }
    rebuildMenu()
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    accessibilityGranted = Accessibility.isGranted
    rebuildMenu()
  }

  private func rebuildMenu() {
    menu.removeAllItems()

    let previews = NSMenuItem(title: "Hover Previews", action: #selector(togglePreviews), keyEquivalent: "")
    previews.state = previewsEnabled ? .on : .off
    previews.target = self
    menu.addItem(previews)
    menu.addItem(.separator())

    if accessibilityGranted {
      let item = NSMenuItem(title: "Accessibility: granted", action: nil, keyEquivalent: "")
      item.isEnabled = false
      menu.addItem(item)
    } else {
      let item = NSMenuItem(title: "Grant Accessibility Access…", action: #selector(grantAccessibility), keyEquivalent: "")
      item.target = self
      menu.addItem(item)
    }
    menu.addItem(.separator())

    let windows = NSMenuItem(title: "Finder Windows", action: #selector(toggleFinderWindows), keyEquivalent: "")
    windows.state = finderWindowsEnabled ? .on : .off
    windows.toolTip = "Also preview folders in Finder windows shown as icons"
    windows.target = self
    menu.addItem(windows)

    if LoginItem.isInstalled {
      let title = LoginItem.needsApproval ? "Launch at Login (approve in System Settings…)" : "Launch at Login"
      let login = NSMenuItem(title: title, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
      login.state = LoginItem.isOn ? .on : .off
      login.target = self
      menu.addItem(login)
    } else {
      let login = NSMenuItem(title: "Launch at Login (install with ./build.sh first)", action: nil, keyEquivalent: "")
      login.isEnabled = false
      menu.addItem(login)
    }

    menu.addItem(.separator())
    let about = NSMenuItem(title: "About Glimpse", action: #selector(showAbout), keyEquivalent: "")
    about.target = self
    menu.addItem(about)
    let log = NSMenuItem(title: "Show Log", action: #selector(showLog), keyEquivalent: "")
    log.target = self
    menu.addItem(log)
    let quit = NSMenuItem(title: "Quit Glimpse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    menu.addItem(quit)
  }

  // MARK: Actions

  @objc private func togglePreviews() {
    previewsEnabled.toggle()
    Log.write("previews \(previewsEnabled ? "on" : "off")")
    refresh()
  }

  @objc private func grantAccessibility() {
    Log.write("grant accessibility: prompt + settings")
    Accessibility.ask()
    Accessibility.openSettings()
  }

  @objc private func toggleFinderWindows() {
    finderWindowsEnabled.toggle()
    DesktopHitTest.includeFinderWindows = finderWindowsEnabled
    Log.write("finder windows \(finderWindowsEnabled ? "on" : "off")")
  }

  @objc private func toggleLaunchAtLogin() {
    if LoginItem.needsApproval {
      SMAppService.openSystemSettingsLoginItems()
    } else {
      LoginItem.set(!LoginItem.isOn)
    }
  }

  /// The standard About window: icon, name, version (build), and the one-line description from Info.plist.
  @objc private func showAbout() {
    NSApp.activate()
    NSApp.orderFrontStandardAboutPanel(nil)
  }

  @objc private func showLog() {
    Log.write("show log")
    NSWorkspace.shared.open(Log.url)
  }

  // MARK: Developer option

  private func simulateHoverIfAsked() {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: "--simulate-hover"), i + 5 < args.count,
          let x = Double(args[i + 2]), let y = Double(args[i + 3]), let w = Double(args[i + 4]), let h = Double(args[i + 5])
    else { return }
    let url = URL(fileURLWithPath: args[i + 1])
    Log.write("simulated hover: \(url.lastPathComponent), icon (\(x), \(y), \(w), \(h))")
    hover.pinned = true
    hover.hovered(url, iconQuartz: CGRect(x: x, y: y, width: w, height: h), restedAt: Date())
    if let j = args.firstIndex(of: "--simulate-click"), j + 1 < args.count, let row = Int(args[j + 1]) {
      hover.simulateClick(row: row)
    }
    if let j = args.firstIndex(of: "--snapshot"), j + 1 < args.count {
      let out = URL(fileURLWithPath: args[j + 1])
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        MainActor.assumeIsolated { AppDelegate.shared?.hover.snapshot(to: out) }
      }
    }
  }
}
