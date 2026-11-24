// P2.1: hover → panel (02 steps 6–7). When the detector finds a desktop folder under the resting cursor, show its
// panel beside the icon. While it shows, watch the cursor every 50 ms and hide the panel once the cursor has been
// outside both the icon (with its label) and the panel for 0.2 s. Placement and the hide rule are in GlimpseCore.
// P2.2: a click on a row opens the item (ItemOpener) and hides the panel (step 8).
import AppKit
import GlimpseCore

@MainActor
final class HoverController {
  let detector = HoverDetector()
  private let panel = PreviewPanel()
  private var zone = NSRect.zero
  private var leave = LeaveTimer(grace: 0.2)
  private var watchTimer: Timer?
  /// For `--simulate-hover` only: keep the panel up wherever the cursor is.
  var pinned = false

  init() {
    panel.onOpen = { [weak self] item in
      ItemOpener.open(item)
      self?.hide(reason: "opened \(item.url.lastPathComponent)")
    }
    detector.onHover = { [weak self] url, icon, restedAt in self?.hovered(url, iconQuartz: icon, restedAt: restedAt) }
    // No checks while the cursor is on our own panel (moving into it to scroll shouldn't ask Finder anything).
    detector.shouldCheck = { [weak self] p in !(self?.panel.isVisible == true && self!.panel.frame.contains(p)) }
    // Screens added, removed or rearranged: the panel's place may no longer make sense.
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.hide(reason: "screens changed") }
    }
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.hide(reason: "space changed") }
    }
  }

  func start() { detector.start() }

  func stop() {
    detector.stop()
    hide(reason: "previews off")
  }

  /// `iconQuartz` is Finder's box for the icon (Quartz coordinates); `restedAt` is when the cursor stopped moving.
  func hovered(_ url: URL, iconQuartz: CGRect?, restedAt: Date) {
    guard let icon = iconQuartz else {
      Log.write("no icon box for \(url.lastPathComponent); panel not shown")
      return
    }
    // The icon's own screen (P4.1): the panel stays inside its usable area, never spilling onto a neighbour.
    let mainHeight = ScreenList.mainHeight
    let iconCocoa = ScreenMath.toCocoa(icon, mainHeight: mainHeight)
    guard let screen = ScreenList.screen(at: CGPoint(x: iconCocoa.midX, y: iconCocoa.midY)) else {
      Log.write("icon of \(url.lastPathComponent) isn't on any screen; panel not shown")
      return
    }
    zone = PanelPlacement.keepZone(iconQuartz: icon, mainScreenHeight: mainHeight)
    leave.reset()
    if panel.isVisible && panel.folder == url { return }

    panel.show(url) { size in
      PanelPlacement.frame(iconQuartz: icon, panelSize: size, visible: screen.visible, mainScreenHeight: mainHeight)
    }
    Log.write("panel shown \(Int(Date().timeIntervalSince(restedAt) * 1000)) ms after the cursor stopped")
    startWatching()
  }

  private func startWatching() {
    guard watchTimer == nil else { return }
    watchTimer = Timer.scheduledTimer(withTimeInterval: HoverDetector.tick, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.watch() }
    }
  }

  private func watch() {
    guard panel.isVisible, !pinned else { return }
    let inside = PanelPlacement.isInside(NSEvent.mouseLocation, zone: zone, panel: panel.frame)
    if leave.update(inside: inside, now: Date()) { hide(reason: "cursor left") }
  }

  /// Developer option: save the panel as a PNG.
  func snapshot(to url: URL) { panel.snapshot(to: url) }

  /// Developer option: what a click on row `index` does.
  func simulateClick(row index: Int) {
    guard let folder = panel.folder, case .items(let items) = FolderListing.list(folder), items.indices.contains(index)
    else { Log.write("simulated click: no row \(index)"); return }
    Log.write("simulated click: row \(index)")
    panel.onOpen?(items[index])
  }

  func hide(reason: String) {
    watchTimer?.invalidate()
    watchTimer = nil
    guard panel.isVisible else { return }
    panel.hide()
    Log.write("panel hidden (\(reason))")
  }
}
