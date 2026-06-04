import ApplicationServices
import CoreGraphics

enum PermissionManager {
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static var isInputMonitoringTrusted: Bool {
        CGPreflightListenEventAccess()
    }

    static func requestPermissions() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        CGRequestListenEventAccess()
    }
}
