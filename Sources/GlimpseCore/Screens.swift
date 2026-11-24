// Several screens (P4.1, lifts D1). macOS puts all screens in one coordinate space measured from the main screen (the
// one with the menu bar in System Settings → Displays → Arrange):
//
//   Cocoa  (cursor, our windows, NSScreen frames):  origin bottom-left of the main screen, y grows up
//   Quartz (window list, Accessibility):            origin top-left of the main screen,    y grows down
//
// So one formula converts for every screen: Quartz y = main screen's height − Cocoa y. A screen to the left of the main
// one has negative x; one above it has Cocoa y ≥ the main screen's height (negative Quartz y).
import CoreGraphics

public struct ScreenInfo: Sendable, Equatable {
  public let name: String
  /// Cocoa coordinates.
  public let frame: CGRect
  /// Cocoa coordinates: the frame minus this screen's menu bar and the Dock, if it's on this screen.
  public let visible: CGRect

  public init(name: String, frame: CGRect, visible: CGRect) {
    self.name = name; self.frame = frame; self.visible = visible
  }
}

public enum ScreenMath {
  public static func toQuartz(_ p: CGPoint, mainHeight: CGFloat) -> CGPoint {
    CGPoint(x: p.x, y: mainHeight - p.y)
  }

  public static func toQuartz(_ r: CGRect, mainHeight: CGFloat) -> CGRect {
    CGRect(x: r.minX, y: mainHeight - r.maxY, width: r.width, height: r.height)
  }

  /// The same formula both ways.
  public static func toCocoa(_ r: CGRect, mainHeight: CGFloat) -> CGRect { toQuartz(r, mainHeight: mainHeight) }

  /// The screen under a Cocoa point. Edges count as inside, because the cursor can sit on a screen's very top or right
  /// edge; where two screens touch, the first in the list wins.
  public static func screen(containing p: CGPoint, in screens: [ScreenInfo]) -> ScreenInfo? {
    screens.first { p.x >= $0.frame.minX && p.x <= $0.frame.maxX && p.y >= $0.frame.minY && p.y <= $0.frame.maxY }
  }

  /// True in the strip above the usable area: that screen's menu bar. Never true on a screen without a menu bar.
  public static func isInMenuBar(_ p: CGPoint, of screen: ScreenInfo) -> Bool {
    p.y > screen.visible.maxY
  }
}
