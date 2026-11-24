// When to ask "what's under the cursor?" (02 steps 1–2; made robust 2026-11-24 after "sometimes nothing happens at
// all on hover"). Fed once per 50 ms tick.
//
//   • Resting = staying within `tolerance` points of where the cursor stopped. A finger lying on the trackpad nudges
//     the cursor by fractions of a point; before this, any nudge restarted the 0.35 s clock, so a check could never
//     happen.
//   • A check that finds nothing is retried every `retryEvery` seconds, up to `maxRetries` times, while the cursor
//     stays put. Before this there was exactly one check per resting spot: if it ran while Show Desktop's animation
//     was still sliding windows away, or while Finder was busy, nothing happened until the cursor moved.
//   • Once something is found (or there's nothing to do at this spot), no more checks until the cursor moves.
import CoreGraphics
import Foundation

public struct RestTracker: Sendable {
  public let rest: TimeInterval
  public let tolerance: CGFloat
  public let retryEvery: TimeInterval
  public let maxRetries: Int

  private var anchor: CGPoint?
  /// When the cursor came to rest at `anchor`.
  public private(set) var restingSince = Date.distantPast
  private var checks = 0
  private var lastCheck: Date?
  private var done = false
  /// Slack for timer jitter and floating-point rounding, so "0.6 s later" isn't missed by a microsecond.
  private static let slack: TimeInterval = 0.001

  public init(rest: TimeInterval = 0.35, tolerance: CGFloat = 3, retryEvery: TimeInterval = 0.6, maxRetries: Int = 3) {
    self.rest = rest; self.tolerance = tolerance; self.retryEvery = retryEvery; self.maxRetries = maxRetries
  }

  /// Call every tick with the cursor position. True when a check should run now.
  public mutating func shouldCheck(at p: CGPoint, now: Date) -> Bool {
    if let a = anchor, hypot(p.x - a.x, p.y - a.y) <= tolerance {
      guard !done, now.timeIntervalSince(restingSince) >= rest - Self.slack else { return false }
      if let last = lastCheck, now.timeIntervalSince(last) < retryEvery - Self.slack { return false }
      return true
    }
    anchor = p
    restingSince = now
    checks = 0
    lastCheck = nil
    done = false
    return false
  }

  /// Call after each check. `found` = a folder was found, or there's nothing worth retrying at this spot.
  public mutating func checked(found: Bool, now: Date) {
    checks += 1
    lastCheck = now
    if found || checks > maxRetries { done = true }
  }
}
