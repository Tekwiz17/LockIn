import LocalAuthentication
import AppKit

@MainActor enum MacAuthentication {
    static func verify() async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? NSError(domain: "LockInAuthentication", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mac authentication isn't available. Set a login password in System Settings."])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Verify that you want to enable Nuclear Mode in LockIn.") { success, error in
                if success { continuation.resume() }
                else { continuation.resume(throwing: error ?? NSError(domain: "LockInAuthentication", code: 2, userInfo: [NSLocalizedDescriptionKey: "Authentication was cancelled."])) }
            }
        }
    }
    static func askFutureAuthentication() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Require Mac authentication for future Nuclear sessions?"
        alert.informativeText = "macOS verifies your identity using your login password or supported Touch ID. LockIn never sees your password. You can change this preference in Edit."
        alert.addButton(withTitle: "Require Every Time")
        alert.addButton(withTitle: "First Time Only")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
