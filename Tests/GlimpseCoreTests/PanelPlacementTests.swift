// Where the panel goes and when it hides (02 steps 6–7), on this Mac's screen: 1470 × 956 points, usable area
// y 51…923 in Cocoa coordinates (Dock below, menu bar above).
import CoreGraphics
import Foundation
import Testing
@testable import GlimpseCore

private let screenHeight: CGFloat = 956
private let visible = CGRect(x: 0, y: 51, width: 1470, height: 872)
private let panel = CGSize(width: 300, height: 316)  // header + 12 rows

private func place(_ iconQuartz: CGRect) -> CGRect {
  PanelPlacement.frame(iconQuartz: iconQuartz, panelSize: panel, visible: visible, mainScreenHeight: screenHeight)
}

@Suite("Panel placement (step 6)")
struct PlacementTests {
  @Test("icon at the right edge, where desktop icons usually are: panel goes left")
  func rightEdgeGoesLeft() {
    let f = place(CGRect(x: 1380, y: 60, width: 64, height: 64))
    #expect(f == CGRect(x: 1056, y: 580, width: 300, height: 316))
  }

  @Test("icon on the left: panel goes right")
  func leftSideGoesRight() {
    let f = place(CGRect(x: 100, y: 400, width: 64, height: 64))
    #expect(f.minX == 188)  // 100 + 64 + 24
    #expect(f.maxY == 556)  // top aligned with the icon's top (956 − 400)
  }

  @Test("icon near the bottom: panel pushed up to stay above the Dock")
  func bottomIsPushedUp() {
    let f = place(CGRect(x: 1380, y: 820, width: 64, height: 64))
    #expect(f.minY == visible.minY)
  }

  @Test("icon under the menu bar: panel pushed down below it")
  func topIsPushedDown() {
    let f = place(CGRect(x: 1380, y: 10, width: 64, height: 64))
    #expect(f.maxY == visible.maxY)
  }

  @Test("the panel always fits inside the usable area and never covers the icon or its label",
        arguments: [CGRect(x: 1380, y: 60, width: 64, height: 64), CGRect(x: 0, y: 860, width: 64, height: 64),
                    CGRect(x: 700, y: 400, width: 64, height: 64), CGRect(x: 1406, y: 840, width: 64, height: 64)])
  func staysOnScreen(icon: CGRect) {
    let f = place(icon)
    #expect(visible.contains(f))
    #expect(!f.intersects(PanelPlacement.keepZone(iconQuartz: icon, mainScreenHeight: screenHeight)))
  }

  @Test("no gap between the icon's zone and the panel, so the cursor can cross into it")
  func zoneTouchesPanel() {
    let icon = CGRect(x: 1380, y: 60, width: 64, height: 64)
    let zone = PanelPlacement.keepZone(iconQuartz: icon, mainScreenHeight: screenHeight)
    let f = place(icon)
    #expect(zone.minX == f.maxX)
    let crossing = CGPoint(x: zone.minX, y: zone.midY)
    #expect(PanelPlacement.isInside(crossing, zone: zone, panel: f))
  }

  @Test("the label below the icon counts as the icon")
  func labelCounts() {
    let icon = CGRect(x: 1380, y: 60, width: 64, height: 64)  // Cocoa: y 832…896
    let zone = PanelPlacement.keepZone(iconQuartz: icon, mainScreenHeight: screenHeight)
    #expect(zone.contains(CGPoint(x: 1412, y: 810)))   // label, 22 points under the icon
    #expect(!zone.contains(CGPoint(x: 1412, y: 760)))  // well below: the next icon's area
  }
}

@Suite("Hide after 0.2 s outside (step 7)")
struct LeaveTimerTests {
  /// Feeds (inside, seconds since start) and returns what the timer said each time.
  private func run(_ steps: [(Bool, Double)]) -> [Bool] {
    var t = LeaveTimer(grace: 0.2)
    let t0 = Date(timeIntervalSince1970: 1000)
    return steps.map { t.update(inside: $0.0, now: t0 + $0.1) }
  }

  @Test func hidesOnlyAfterGrace() {
    #expect(run([(true, 0), (false, 0), (false, 0.15), (false, 0.2)]) == [false, false, false, true])
  }

  @Test("coming back inside restarts the clock")
  func backInsideResets() {
    #expect(run([(false, 0), (true, 0.15), (false, 0.3), (false, 0.45), (false, 0.5)]) == [false, false, false, false, true])
  }
}
