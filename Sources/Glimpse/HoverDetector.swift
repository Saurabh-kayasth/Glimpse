// 02 steps 1–2: watch the cursor 20 times a second; when it has rested on one point for 0.35 s (D7), ask once what's
// there (DesktopHitTest). Writes `hover: <path>` to the log and calls `onHover`, which HoverController (P2.1) uses
// to show the panel.
import AppKit
import GlimpseCore

@MainActor
final class HoverDetector {
  static let tick: TimeInterval = 0.05
  static let rest: TimeInterval = 0.35
  private static let maxUnrecognisedLines = 50
  private static let maxVerboseLines = 500

  /// Folder URL, Finder's box for the icon (Quartz), and when the cursor stopped moving.
  var onHover: ((URL, CGRect?, Date) -> Void)?
  /// Return false to skip a check at this point (Cocoa coordinates), for example over our own panel.
  var shouldCheck: ((CGPoint) -> Bool)?
  /// Every check written to the log, for troubleshooting. Off by default; turn on with
  /// `defaults write local.glimpse.app verboseHoverLog -bool true` and relaunch.
  var verbose = UserDefaults.standard.bool(forKey: "verboseHoverLog")

  private var timer: Timer?
  private var lastPoint = CGPoint(x: -1, y: -1)
  private var restingSince = Date()
  private var checkedThisRest = false
  private var lastFolder: URL?
  private var unrecognisedLogged = 0
  private var verboseLogged = 0

  var isRunning: Bool { timer != nil }

  func start() {
    guard timer == nil else { return }
    Log.write("hover detection on")
    timer = Timer.scheduledTimer(withTimeInterval: Self.tick, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tickNow() }
    }
  }

  func stop() {
    guard let t = timer else { return }
    t.invalidate()
    timer = nil
    lastFolder = nil
    Log.write("hover detection off")
  }

  private func tickNow() {
    let p = NSEvent.mouseLocation  // Cocoa: origin bottom-left
    if p != lastPoint {
      lastPoint = p
      restingSince = Date()
      checkedThisRest = false
      return
    }
    guard !checkedThisRest, Date().timeIntervalSince(restingSince) >= Self.rest else { return }
    checkedThisRest = true

    // Any screen (P4.1; D1 lifted): the one under the cursor.
    guard let screen = ScreenList.screen(at: p) else { return }
    // Skip that screen's menu bar: no icons there, and with Finder in front its menu items would be logged as
    // unrecognised.
    guard !ScreenMath.isInMenuBar(p, of: screen) else { return }
    guard shouldCheck?(p) ?? true else { return }
    let mainHeight = ScreenList.mainHeight
    let q = ScreenMath.toQuartz(p, mainHeight: mainHeight)  // as the window list and Accessibility use

    let started = Date()
    let outcome = DesktopHitTest.check(q, screen: ScreenMath.toQuartz(screen.frame, mainHeight: mainHeight))
    let ms = String(format: "%.1f", Date().timeIntervalSince(started) * 1000)
    report(outcome, at: q, on: screen.name, ms: ms)
  }

  private func report(_ outcome: HoverOutcome, at q: CGPoint, on screen: String, ms: String) {
    let at = "(\(Int(q.x)), \(Int(q.y))) on \(screen)"
    switch outcome {
    case .folder(let url, let frame, let via):
      if url != lastFolder {
        Log.write("hover: \(url.path) [\(via), \(ms) ms, at \(at), icon \(frame.map { "\($0)" } ?? "?")]")
      } else if verbose {
        verboseLine("same folder \(url.lastPathComponent) at \(at), \(ms) ms")
      }
      lastFolder = url
      onHover?(url, frame, restingSince)
    case .notAFolder(let url):
      lastFolder = nil
      if verbose { verboseLine("not a folder: \(url.lastPathComponent) at \(at), \(ms) ms") }
    case .nothing(let why):
      lastFolder = nil
      if verbose { verboseLine("nothing at \(at): \(why), \(ms) ms") }
    case .unrecognised(let what):
      lastFolder = nil
      if unrecognisedLogged < Self.maxUnrecognisedLines {
        unrecognisedLogged += 1
        Log.write("unrecognised Finder element at \(at): \(what)"
                  + (unrecognisedLogged == Self.maxUnrecognisedLines ? " (no more of these until relaunch)" : ""))
      }
    }
  }

  private func verboseLine(_ s: String) {
    guard verboseLogged < Self.maxVerboseLines else { return }
    verboseLogged += 1
    Log.write("check: " + s + (verboseLogged == Self.maxVerboseLines ? " (no more checks logged until relaunch)" : ""))
  }
}
