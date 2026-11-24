// The window rule (02 step 3) and turning Finder's answer into a desktop item (steps 4–5). Window stacks and element
// shapes are copied from what the P0 probe saw on 2026-11-24 (docs/rollout/P0.1-ax-probe.md).
import CoreGraphics
import Foundation
import Testing
@testable import GlimpseCore

private let finder: pid_t = 460
private let own: pid_t = 999
private let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
private let desktop = URL(fileURLWithPath: "/Users/someone/Desktop")
private let names = ["Notes", "Projects", "Archive[1]", "report.pdf"]

/// Front to back, as on this Mac: Dock's full-screen window, the widget, the 81-point Window Server strip, Finder's desktop.
private let stack = [
  WindowInfo(owner: "Dock", pid: 456, layer: 20, bounds: screen),
  WindowInfo(owner: "Notification Centre", pid: 514, layer: -2147483601, bounds: CGRect(x: 8, y: 41, width: 180, height: 180)),
  WindowInfo(owner: "Window Server", pid: 166, layer: -2147483602, bounds: CGRect(x: 0, y: 0, width: 1470, height: 81)),
  WindowInfo(owner: "Finder", pid: finder, layer: -2147483603, bounds: screen),
]

private func showing(_ p: CGPoint, _ windows: [WindowInfo] = stack) -> Bool {
  DesktopRules.desktopShowing(windows, at: p, ownPID: own, finderPID: finder).showing
}

private func item(_ chain: [ElementInfo]) -> ItemMatch {
  DesktopRules.item(fromChain: chain, finderPID: finder, desktop: desktop, desktopNames: { names }, screen: screen)
}

private let icon = ElementInfo(pid: finder, role: "AXImage", url: URL(fileURLWithPath: "/Users/someone/Desktop/Projects/"),
                               frame: CGRect(x: 1380, y: 60, width: 64, height: 64))

@Suite("Is the desktop showing here? (step 3)")
struct WindowRuleTests {
  @Test func iconMidScreen() { #expect(showing(CGPoint(x: 1400, y: 300))) }

  @Test("top-row icon under the 81-point Window Server strip")
  func topRow() { #expect(showing(CGPoint(x: 1400, y: 70))) }

  @Test func widgetInFront() { #expect(!showing(CGPoint(x: 50, y: 100))) }

  @Test func menuBarItemInFront() {
    let item = WindowInfo(owner: "Control Centre", pid: 457, layer: 25, bounds: CGRect(x: 1090, y: 0, width: 36, height: 33))
    #expect(!showing(CGPoint(x: 1100, y: 10), [item] + stack))
  }

  @Test func appWindowInFront() {
    let code = WindowInfo(owner: "Code", pid: 1379, layer: 0, bounds: CGRect(x: 0, y: 33, width: 1470, height: 872))
    #expect(!showing(CGPoint(x: 700, y: 400), [stack[0], code] + stack.dropFirst()))
  }

  @Test("a Finder window showing ~/Desktop is not the desktop (D5)")
  func finderWindowInFront() {
    let window = WindowInfo(owner: "Finder", pid: finder, layer: 0, bounds: CGRect(x: 482, y: 433, width: 920, height: 436))
    #expect(!showing(CGPoint(x: 700, y: 540), [stack[0], window] + stack.dropFirst()))
  }

  @Test("our own panel in front is skipped")
  func ownPanelSkipped() {
    let panel = WindowInfo(owner: "Glimpse", pid: own, layer: 3, bounds: CGRect(x: 1000, y: 200, width: 300, height: 316))
    #expect(showing(CGPoint(x: 1100, y: 300), [panel] + stack))
  }

  @Test("the rule as first planned (no Dock skip) would say no everywhere")
  func dockWindowIsWhyWeSkipIt() {
    let r = DesktopRules.desktopShowing(stack, at: CGPoint(x: 1400, y: 300), ownPID: own, finderPID: finder)
    #expect(r.decidedBy.hasPrefix("Finder"))
  }
}

@Suite("Which item is it? (steps 4–5)")
struct ItemTests {
  @Test func iconByURL() {
    #expect(item([icon]) == .item(icon.url!, frame: icon.frame, via: "AXURL"))
  }

  @Test func labelWithShownName() {
    let label = ElementInfo(pid: finder, role: "AXStaticText", value: "Projects", frame: CGRect(x: 1370, y: 126, width: 84, height: 16))
    #expect(item([label]) == .item(desktop.appendingPathComponent("Projects"), frame: label.frame, via: "AXValue"))
  }

  @Test("label without a name; its group holds the icon")
  func labelThroughGroupChildren() {
    let label = ElementInfo(pid: finder, role: "AXStaticText", frame: CGRect(x: 1370, y: 126, width: 84, height: 16))
    let group = ElementInfo(pid: finder, role: "AXGroup", frame: CGRect(x: 1370, y: 60, width: 84, height: 84), children: [icon])
    #expect(item([label, group]) == .item(icon.url!, frame: icon.frame, via: "AXURL"))
  }

  @Test func hiddenExtension() { #expect(DesktopRules.match(shown: "report", in: names) == "report.pdf") }

  @Test func ambiguousShownNameIsNotGuessed() {
    #expect(DesktopRules.match(shown: "notes", in: ["notes.txt", "notes.md"]) == nil)
  }

  @Test func emptyDesktop() { #expect(item([ElementInfo(pid: finder, role: "AXGroup", frame: screen)]) == .background) }

  @Test func dockTile() { #expect(item([ElementInfo(pid: 456, role: "AXDockItem")]) == .notFinder(role: "AXDockItem")) }

  @Test("same name outside ~/Desktop is not a desktop item")
  func outsideDesktop() {
    let other = ElementInfo(pid: finder, role: "AXImage", url: URL(fileURLWithPath: "/Users/someone/Documents/Projects/"), frame: icon.frame)
    guard case .unrecognised = item([other]) else { Issue.record("expected unrecognised"); return }
  }

  @Test func trailingSlashesDontMatter() {
    #expect(DesktopRules.isDirectlyIn(URL(fileURLWithPath: "/Users/someone/Desktop/Archive[1]/"), URL(fileURLWithPath: "/Users/someone/Desktop/")))
  }
}
