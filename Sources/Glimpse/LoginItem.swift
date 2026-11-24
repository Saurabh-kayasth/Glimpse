// P3.1: start Glimpse when you log in, through macOS's own login-item service (SMAppService). The item appears in
// System Settings → General → Login Items & Extensions, where it can also be switched off.
// It records the app where it runs, so it's offered only for the installed copy in an Applications folder
// (build.sh installs to ~/Applications/Glimpse.app), not for a copy in build/, which a rebuild deletes.
import AppKit
import ServiceManagement

@MainActor
enum LoginItem {
  static var status: SMAppService.Status { SMAppService.mainApp.status }
  static var isOn: Bool { status == .enabled }
  static var needsApproval: Bool { status == .requiresApproval }

  /// True when running from /Applications or ~/Applications.
  static var isInstalled: Bool {
    let path = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL.path
    let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").standardizedFileURL.path
    return path == "/Applications" || path == home
  }

  static func set(_ on: Bool) {
    do {
      if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
      Log.write("launch at login \(on ? "on" : "off"): \(describe(status))")
    } catch {
      Log.write("launch at login \(on ? "on" : "off") failed: \(error.localizedDescription) (\(describe(status)))")
    }
    if needsApproval { SMAppService.openSystemSettingsLoginItems() }
  }

  static func describe(_ s: SMAppService.Status) -> String {
    switch s {
    case .enabled: "enabled"
    case .notRegistered: "not registered"
    case .requiresApproval: "waiting for approval in System Settings"
    case .notFound: "not found"
    @unknown default: "unknown (\(s.rawValue))"
    }
  }
}
