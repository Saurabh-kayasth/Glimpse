// P5.1: folders in Finder windows, icon view only. The icon-view, sidebar, background and title-bar chains are the
// ones the P0 probe recorded on 2026-11-24 (docs/rollout/P5.1-finder-windows-icon-view.md); the list-view and
// column-view chains are the shapes those views use (rows), to check that they're left out.
import CoreGraphics
import Foundation
import Testing
@testable import GlimpseCore

private let finder: pid_t = 460
private let folderURL = URL(fileURLWithPath: "/Users/someone/Documents/Projects/")

private func el(_ role: String, _ subrole: String? = nil, url: URL? = nil, frame: CGRect? = nil,
                children: [ElementInfo] = []) -> ElementInfo {
  ElementInfo(pid: finder, role: role, subrole: subrole, url: url, frame: frame, children: children)
}

private let image = el("AXImage", url: folderURL, frame: CGRect(x: 719, y: 348, width: 64, height: 64))
private let group = el("AXGroup", frame: CGRect(x: 719, y: 348, width: 64, height: 64))
private let section = el("AXList", "AXSectionList", frame: CGRect(x: 447, y: 214, width: 682, height: 112))
private let collection = el("AXList", "AXCollectionList", frame: CGRect(x: 431, y: 194, width: 764, height: 384))

@Suite("Is it the desktop, a Finder window, or something else?")
struct SurfaceTests {
  private let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)

  private func surface(_ windows: [WindowInfo], _ p: CGPoint) -> DesktopRules.Surface {
    DesktopRules.surface(windows, at: p, ownPID: 999, finderPID: finder)
  }

  @Test func desktop() {
    #expect(surface([WindowInfo(owner: "Finder", pid: finder, layer: -2147483603, bounds: screen)], CGPoint(x: 700, y: 400)) == .desktop)
  }

  @Test("a Finder window in front of the desktop, behind the Dock's full-screen window")
  func finderWindow() {
    let windows = [
      WindowInfo(owner: "Dock", pid: 456, layer: 20, bounds: screen),
      WindowInfo(owner: "Finder", pid: finder, layer: 0, bounds: CGRect(x: 275, y: 142, width: 920, height: 436)),
      WindowInfo(owner: "Finder", pid: finder, layer: -2147483603, bounds: screen),
    ]
    #expect(surface(windows, CGPoint(x: 700, y: 400)) == .finderWindow)
  }

  @Test("another app's window over a Finder window")
  func otherAppInFront() {
    let windows = [
      WindowInfo(owner: "Code", pid: 1379, layer: 0, bounds: CGRect(x: 0, y: 33, width: 1470, height: 872)),
      WindowInfo(owner: "Finder", pid: finder, layer: 0, bounds: CGRect(x: 275, y: 142, width: 920, height: 436)),
    ]
    #expect(surface(windows, CGPoint(x: 700, y: 400)) == .other("Code layer 0"))
  }
}

@Suite("Icon view items in Finder windows")
struct IconViewTests {
  private func item(_ chain: [ElementInfo]) -> ItemMatch { DesktopRules.iconViewItem(fromChain: chain, finderPID: finder) }

  @Test("an icon: AXImage with AXURL › AXGroup › AXSectionList › AXCollectionList (as recorded)")
  func icon() {
    #expect(item([image, group, section, collection]) == .item(folderURL, frame: image.frame, via: "AXURL, icon view"))
  }

  @Test("the label: its group's children hold the icon")
  func label() {
    let label = el("AXStaticText", frame: CGRect(x: 700, y: 414, width: 100, height: 30))
    let labelGroup = el("AXGroup", frame: CGRect(x: 700, y: 348, width: 100, height: 96), children: [image, label])
    #expect(item([label, labelGroup, section, collection]) == .item(folderURL, frame: image.frame, via: "AXURL, icon view"))
  }

  @Test("empty space in the window (as recorded): no item")
  func emptySpace() {
    let scroll = el("AXScrollArea", frame: collection.frame)
    #expect(item([collection, scroll, el("AXSplitGroup"), el("AXSplitGroup")]) == .background)
  }

  @Test("the sidebar (as recorded) is not icon view")
  func sidebar() {
    let chain = [el("AXStaticText"), el("AXCell"), el("AXRow", "AXOutlineRow"), el("AXOutline")]
    #expect(item(chain) == .unrecognised("not icon view: AXStaticText > AXCell > AXRow/AXOutlineRow > AXOutline"))
  }

  @Test("the title bar (as recorded) is not icon view")
  func titleBar() {
    guard case .unrecognised = item([el("AXStaticText"), el("AXWindow", "AXStandardWindow"), el("AXApplication")]) else {
      Issue.record("expected not icon view"); return
    }
  }

  @Test("list view: a row with an icon and a path is still left out")
  func listView() {
    let small = el("AXImage", url: folderURL, frame: CGRect(x: 300, y: 200, width: 16, height: 16))
    guard case .unrecognised = item([small, el("AXCell"), el("AXRow", "AXOutlineRow"), el("AXOutline")]) else {
      Issue.record("expected not icon view"); return
    }
  }

  @Test("column view: left out")
  func columnView() {
    let small = el("AXImage", url: folderURL, frame: CGRect(x: 300, y: 200, width: 16, height: 16))
    guard case .unrecognised = item([small, el("AXCell"), el("AXRow", "AXTableRow"), el("AXList", "AXContentList")]) else {
      Issue.record("expected not icon view"); return
    }
  }

  @Test("an answer from another app")
  func otherApp() {
    #expect(item([ElementInfo(pid: 1379, role: "AXScrollArea")]) == .notFinder(role: "AXScrollArea"))
  }

  @Test("the logged shape has roles only")
  func shapeHasNoNames() {
    let named = ElementInfo(pid: finder, role: "AXStaticText", title: "Secret plans", value: "Secret plans")
    #expect(DesktopRules.shape([named, el("AXCell")]) == "AXStaticText > AXCell")
  }
}

@Suite("The logged shape")
struct ShapeTests {
  @Test("marks which elements have a path and lists children, still without names or paths")
  func markers() {
    let image = ElementInfo(pid: finder, role: "AXImage", url: URL(fileURLWithPath: "/Users/someone/Secret/"), title: "Secret.png")
    let cell = ElementInfo(pid: finder, role: "AXCell", children: [image, ElementInfo(pid: finder, role: "AXTextField", value: "Secret")])
    let shape = DesktopRules.shape([cell, ElementInfo(pid: finder, role: "AXRow", subrole: "AXOutlineRow")])
    #expect(shape == "AXCell{AXImage[url], AXTextField} > AXRow/AXOutlineRow")
    #expect(!shape.contains("Secret") && !shape.contains("/Users"))
  }
}
