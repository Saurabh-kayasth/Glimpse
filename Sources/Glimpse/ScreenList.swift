// The connected screens, read fresh each time (screens come and go), as plain values for GlimpseCore's ScreenMath.
// NSScreen.screens[0] is always the main screen, whose height anchors both coordinate systems (see Screens.swift).
import AppKit
import GlimpseCore

@MainActor
enum ScreenList {
  static var all: [ScreenInfo] {
    NSScreen.screens.map { ScreenInfo(name: $0.localizedName, frame: $0.frame, visible: $0.visibleFrame) }
  }

  static var mainHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

  /// The screen under a Cocoa point.
  static func screen(at p: CGPoint) -> ScreenInfo? { ScreenMath.screen(containing: p, in: all) }
}
