// Several screens (P4.1). The main screen is this Mac's built-in display (1470 × 956, usable y 51…923, Dock at the
// bottom). The second screen is a 1920 × 1080 display with its own 25-point menu bar and no Dock, placed to the right,
// to the left or above, as in System Settings → Displays → Arrange.
import CoreGraphics
import Foundation
import Testing
@testable import GlimpseCore

private let mainH: CGFloat = 956
private let main = ScreenInfo(name: "Built-in", frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                              visible: CGRect(x: 0, y: 51, width: 1470, height: 872))
private let right = ScreenInfo(name: "Right", frame: CGRect(x: 1470, y: 0, width: 1920, height: 1080),
                               visible: CGRect(x: 1470, y: 0, width: 1920, height: 1055))
private let left = ScreenInfo(name: "Left", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
                              visible: CGRect(x: -1920, y: 0, width: 1920, height: 1055))
private let above = ScreenInfo(name: "Above", frame: CGRect(x: 0, y: 956, width: 1920, height: 1080),
                               visible: CGRect(x: 0, y: 956, width: 1920, height: 1055))
private let panel = CGSize(width: 300, height: 316)

/// An icon given in Cocoa coordinates (easier to reason about), handed over in Quartz as Finder reports it.
private func iconQuartz(_ cocoa: CGRect) -> CGRect { ScreenMath.toQuartz(cocoa, mainHeight: mainH) }

private func place(_ iconCocoa: CGRect, on screen: ScreenInfo) -> CGRect {
  PanelPlacement.frame(iconQuartz: iconQuartz(iconCocoa), panelSize: panel, visible: screen.visible, mainScreenHeight: mainH)
}

@Suite("Coordinates across screens")
struct CoordinateTests {
  @Test("Quartz ↔ Cocoa uses the main screen's height for every screen, including negative coordinates",
        arguments: [CGRect(x: 3300, y: 970, width: 64, height: 64), CGRect(x: -100, y: 500, width: 64, height: 64),
                    CGRect(x: 1800, y: 1900, width: 64, height: 64)])
  func roundTrip(r: CGRect) {
    #expect(ScreenMath.toCocoa(ScreenMath.toQuartz(r, mainHeight: mainH), mainHeight: mainH) == r)
  }

  @Test("a screen above the main one has negative Quartz y")
  func aboveIsNegativeQuartz() {
    #expect(ScreenMath.toQuartz(above.frame, mainHeight: mainH).minY == -1080)
  }

  @Test func whichScreen() {
    let all = [main, right, left]
    #expect(ScreenMath.screen(containing: CGPoint(x: 700, y: 400), in: all) == main)
    #expect(ScreenMath.screen(containing: CGPoint(x: 2000, y: 500), in: all) == right)
    #expect(ScreenMath.screen(containing: CGPoint(x: -5, y: 10), in: all) == left)
    #expect(ScreenMath.screen(containing: CGPoint(x: 5000, y: 5000), in: all) == nil)
  }

  @Test("the very top and right edges count, so the cursor at an edge is still on a screen")
  func edges() {
    #expect(ScreenMath.screen(containing: CGPoint(x: 3390, y: 1080), in: [right]) == right)
  }

  @Test("each screen's own menu bar is skipped; a screen without one never is")
  func menuBars() {
    #expect(ScreenMath.isInMenuBar(CGPoint(x: 700, y: 940), of: main))
    #expect(!ScreenMath.isInMenuBar(CGPoint(x: 700, y: 900), of: main))
    #expect(ScreenMath.isInMenuBar(CGPoint(x: 2000, y: 1070), of: right))
    let noMenuBar = ScreenInfo(name: "No menu bar", frame: right.frame, visible: right.frame)
    #expect(!ScreenMath.isInMenuBar(CGPoint(x: 2000, y: 1080), of: noMenuBar))
  }
}

@Suite("Panel placement on other screens")
struct MultiScreenPlacementTests {
  @Test("screen to the right, icon at its right edge: panel goes left, stays on that screen")
  func rightScreen() {
    let f = place(CGRect(x: 3300, y: 970, width: 64, height: 64), on: right)
    #expect(f == CGRect(x: 2976, y: 718, width: 300, height: 316))
    #expect(right.visible.contains(f))
  }

  @Test("screen to the left, icon near the shared edge: panel goes left instead of spilling onto the main screen")
  func leftScreen() {
    let f = place(CGRect(x: -100, y: 500, width: 64, height: 64), on: left)
    #expect(f == CGRect(x: -424, y: 248, width: 300, height: 316))
    #expect(left.visible.contains(f))
  }

  @Test("screen above, icon near its bottom: panel pushed up so it doesn't dip onto the main screen")
  func aboveScreen() {
    let f = place(CGRect(x: 1800, y: 970, width: 64, height: 64), on: above)
    #expect(f == CGRect(x: 1476, y: 956, width: 300, height: 316))
    #expect(above.visible.contains(f))
  }
}

@Suite("Desktop rules on other screens")
struct MultiScreenRuleTests {
  private let finder: pid_t = 460

  @Test("Finder's desktop window on the second screen counts as the desktop")
  func desktopOnSecondScreen() {
    let rightQuartz = ScreenMath.toQuartz(right.frame, mainHeight: mainH)  // (1470, −124, 1920, 1080)
    let windows = [
      WindowInfo(owner: "Dock", pid: 456, layer: 20, bounds: rightQuartz),
      WindowInfo(owner: "Finder", pid: finder, layer: -2147483603, bounds: rightQuartz),
      WindowInfo(owner: "Finder", pid: finder, layer: -2147483603, bounds: CGRect(x: 0, y: 0, width: 1470, height: 956)),
    ]
    #expect(DesktopRules.desktopShowing(windows, at: CGPoint(x: 3000, y: 300), ownPID: 999, finderPID: finder).showing)
  }

  @Test("the second screen's empty desktop is recognised by that screen's size")
  func backgroundOnSecondScreen() {
    let rightQuartz = ScreenMath.toQuartz(right.frame, mainHeight: mainH)
    let group = ElementInfo(pid: finder, role: "AXGroup", frame: rightQuartz)
    let match = DesktopRules.item(fromChain: [group], finderPID: finder, desktop: URL(fileURLWithPath: "/Users/someone/Desktop"),
                                  desktopNames: { [] }, screen: rightQuartz)
    #expect(match == .background)
  }
}
