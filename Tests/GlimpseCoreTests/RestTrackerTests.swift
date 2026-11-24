// When to check (fix for "sometimes nothing happens at all on hover", 2026-11-24).
import CoreGraphics
import Foundation
import Testing
@testable import GlimpseCore

private let t0 = Date(timeIntervalSince1970: 1000)

/// Feeds a cursor position every 50 ms from `from` to `to` seconds; returns the times (s) at which a check ran.
/// `found` decides what each check reports.
private func run(_ tracker: inout RestTracker, at p: (Double) -> CGPoint, from: Double = 0, to: Double,
                 found: (Int) -> Bool = { _ in false }) -> [Double] {
  var times: [Double] = []
  for tick in Int((from * 20).rounded())...Int((to * 20).rounded()) {  // one tick per 50 ms, counted, not summed
    let t = Double(tick) / 20
    let now = t0 + t
    if tracker.shouldCheck(at: p(t), now: now) {
      times.append(t)
      tracker.checked(found: found(times.count), now: now)
    }
  }
  return times
}

@Suite("When to check")
struct RestTrackerTests {
  @Test("a still cursor is checked once, after 0.35 s, when something is found")
  func stillFound() {
    var r = RestTracker()
    #expect(run(&r, at: { _ in CGPoint(x: 100, y: 100) }, to: 3, found: { _ in true }) == [0.35])
  }

  @Test("trackpad wobble of a point or two still counts as resting")
  func wobble() {
    var r = RestTracker()
    let wobbling: (Double) -> CGPoint = { t in CGPoint(x: 100 + (Int(t * 20) % 2 == 0 ? 0 : 1.5), y: 100 + (Int(t * 20) % 3 == 0 ? 0.5 : 0)) }
    #expect(run(&r, at: wobbling, to: 2, found: { _ in true }) == [0.35])
  }

  @Test("before the fix, the same wobble restarted the clock on every tick; a real move still does")
  func realMoveRestarts() {
    var r = RestTracker()
    // Moves 10 points every 0.2 s: never rests 0.35 s.
    #expect(run(&r, at: { t in CGPoint(x: 100 + 10 * Double(Int(t / 0.2)), y: 100) }, to: 2).isEmpty)
  }

  @Test("nothing found: retried every 0.6 s, 3 times, then it stops")
  func retries() {
    var r = RestTracker()
    #expect(run(&r, at: { _ in CGPoint(x: 100, y: 100) }, to: 5) == [0.35, 0.95, 1.55, 2.15])
  }

  @Test("Show Desktop: the first check is too early, the retry finds the icon")
  func showDesktop() {
    var r = RestTracker()
    #expect(run(&r, at: { _ in CGPoint(x: 100, y: 100) }, to: 5, found: { n in n >= 2 }) == [0.35, 0.95])
  }

  @Test("moving to a new spot starts over, retries included")
  func newSpot() {
    var r = RestTracker()
    let p: (Double) -> CGPoint = { t in t < 1 ? CGPoint(x: 100, y: 100) : CGPoint(x: 300, y: 100) }
    #expect(run(&r, at: p, to: 2, found: { _ in true }) == [0.35, 1.35])
  }
}
