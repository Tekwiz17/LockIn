import Foundation
import Darwin

// Headless: no app UI, timer, notifications or sync service.
do {
    if try DockStore.restoreIfNeeded() {
        let label = "com.lockin.mac.dock-recovery"
        let agent = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist")
        try? FileManager.default.removeItem(at: agent)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
    }
} catch { fputs("LockIn Dock recovery: \(error.localizedDescription)\n", stderr); exit(1) }
