import AppKit
import CoreGraphics

@MainActor
protocol PermissionChecking: AnyObject {
    var granted: Bool { get }
    func refresh()
    func request()
    func openSettings()
}

@MainActor
final class PermissionManager: PermissionChecking {
    private(set) var granted = false
    func refresh() {
        granted = CGPreflightListenEventAccess()
    }

    func request() {
        granted = CGRequestListenEventAccess()
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }
}
