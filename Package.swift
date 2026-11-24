// swift-tools-version:6.0
// Glimpse: folder previews on hover. Built by ./build.sh into build/Glimpse.app (see docs/rollout/P1.1-app-skeleton.md).
//   GlimpseCore   pure rules (which desktop item, where the panel goes, when it hides); no AppKit, fully tested
//   Glimpse       the app: menu bar, cursor watching, Accessibility, the panel
//   swift test    runs Tests/GlimpseCoreTests
import PackageDescription

let package = Package(
  name: "Glimpse",
  platforms: [.macOS(.v14)],
  targets: [
    .target(name: "GlimpseCore", path: "Sources/GlimpseCore"),
    .executableTarget(name: "Glimpse", dependencies: ["GlimpseCore"], path: "Sources/Glimpse"),
    .testTarget(name: "GlimpseCoreTests", dependencies: ["GlimpseCore"], path: "Tests/GlimpseCoreTests"),
  ]
)
