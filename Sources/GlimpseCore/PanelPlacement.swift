// Where the panel goes and when it hides (02 steps 6–7). Pure functions, covered by Tests/GlimpseCoreTests.
//
//   Quartz and Cocoa coordinates: see Screens.swift. `mainScreenHeight` is always the main screen's height, whichever
//   screen the icon is on; `visible` is the usable area of the icon's own screen, so the panel never spills over.
//
//        keep zone = icon + label + a margin            panel: beside the zone, top aligned with the icon
//      ┌──────────────┐┌──────────────────────┐        right of the icon if it fits on screen, else left;
//      │   ┌──────┐   ││ 📁 Work      47 items│        then pushed up/down to stay inside the usable area
//      │   │ icon │   ││ …                    │
//      │   └──────┘   ││                      │        hides when the cursor has been outside both the zone
//      │  Work        ││                      │        and the panel for 0.2 s (D7)
//      └──────────────┘│                      │
//                      └──────────────────────┘
import CoreGraphics
import Foundation

public enum PanelPlacement {
  /// Room around the icon that still counts as "on the icon": the label below it (up to two lines of 12-pt text) and
  /// some width, because labels are often wider than the 64-point icon.
  public static let sideMargin: CGFloat = 24
  public static let labelBelow: CGFloat = 44
  public static let marginAbove: CGFloat = 8

  public static func cocoa(_ quartz: CGRect, mainScreenHeight: CGFloat) -> CGRect {
    ScreenMath.toCocoa(quartz, mainHeight: mainScreenHeight)
  }

  /// The icon's box plus its label, in Cocoa coordinates.
  public static func keepZone(iconQuartz: CGRect, mainScreenHeight: CGFloat) -> CGRect {
    let icon = cocoa(iconQuartz, mainScreenHeight: mainScreenHeight)
    return CGRect(x: icon.minX - sideMargin, y: icon.minY - labelBelow,
                  width: icon.width + 2 * sideMargin, height: icon.height + labelBelow + marginAbove)
  }

  /// The panel's frame in Cocoa coordinates. Right of the keep zone if it fits inside `visible`, else left of it;
  /// top aligned with the icon's top, then moved to stay inside `visible` (the usable area of the icon's screen: no
  /// menu bar, no Dock).
  public static func frame(iconQuartz: CGRect, panelSize: CGSize, visible: CGRect, mainScreenHeight: CGFloat) -> CGRect {
    let zone = keepZone(iconQuartz: iconQuartz, mainScreenHeight: mainScreenHeight)
    let icon = cocoa(iconQuartz, mainScreenHeight: mainScreenHeight)

    var x = zone.maxX
    if x + panelSize.width > visible.maxX { x = zone.minX - panelSize.width }
    x = min(max(x, visible.minX), visible.maxX - panelSize.width)

    var top = icon.maxY
    top = min(top, visible.maxY)
    if top - panelSize.height < visible.minY { top = visible.minY + panelSize.height }
    return CGRect(x: x, y: top - panelSize.height, width: panelSize.width, height: panelSize.height)
  }

  /// True while the cursor (Cocoa) is on the icon's zone or on the panel.
  public static func isInside(_ p: CGPoint, zone: CGRect, panel: CGRect) -> Bool {
    zone.contains(p) || panel.insetBy(dx: -2, dy: -2).contains(p)
  }
}

/// Step 7: "outside for 0.2 s" as a small state machine, fed once per timer tick.
public struct LeaveTimer: Sendable {
  public let grace: TimeInterval
  private var outsideSince: Date?

  public init(grace: TimeInterval = 0.2) { self.grace = grace }

  /// Returns true when the panel should hide now.
  public mutating func update(inside: Bool, now: Date) -> Bool {
    if inside {
      outsideSince = nil
      return false
    }
    let since = outsideSince ?? now
    outsideSince = since
    return now.timeIntervalSince(since) >= grace
  }

  public mutating func reset() { outsideSince = nil }
}
