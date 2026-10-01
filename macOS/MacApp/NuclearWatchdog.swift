import AppKit
import Darwin

/// A per-user, deadline-limited agent. It restores the app, not a second timer or rule owner.
@MainActor enum NuclearWatchdog {
    private static let label = "com.lockin.mac.nuclear"
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LockIn")
    }
    private static var plist: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist") }
    private static var service: String { "gui/\(getuid())/\(label)" }
    static func recordProcess() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? String(ProcessInfo.processInfo.processIdentifier).write(to: directory.appendingPathComponent("app.pid"), atomically: true, encoding: .utf8)
    }
    static func install(until deadline: Date) throws {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            throw NSError(domain: "LockIn", code: 1, userInfo: [NSLocalizedDescriptionKey: "Run the built LockIn.app from a stable location first"])
        }
        // Use a new service per consent; remove any expired loaded job first.
        remove()
        recordProcess()
        let script = directory.appendingPathComponent("nuclear-watchdog.sh")
        try scriptSource.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        try FileManager.default.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        let values: [String: Any] = [
            "Label": label, "RunAtLoad": true, "StartInterval": 15,
            "ProgramArguments": ["/bin/sh", script.path, String(Int(ceil(deadline.timeIntervalSince1970))), Bundle.main.bundleURL.path, plist.path, directory.appendingPathComponent("app.pid").path],
            "ProcessType": "Background", "LimitLoadToSessionType": "Aqua"
        ]
        try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0).write(to: plist, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: plist.path)
        let result = try launchctl(["bootstrap", "gui/\(getuid())", plist.path])
        guard result == 0, try launchctl(["print", service]) == 0 else {
            throw NSError(domain: "LockIn", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "macOS couldn't enable the background watchdog. Check System Settings → General → Login Items & Extensions"])
        }
    }
    static func remove() {
        // Remove the file first, so an interrupted cleanup cannot revive it at next login.
        try? FileManager.default.removeItem(at: plist)
        _ = try? launchctl(["bootout", service])
    }
    private static func launchctl(_ arguments: [String]) throws -> Int32 {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/launchctl"); process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit(); return process.terminationStatus
    }
    // All dynamic values are positional arguments, never interpolated into shell code.
    // No KeepAlive: the job terminates independently at its original wall-clock deadline.
    static let scriptSource = #"""
    #!/bin/sh
    deadline="$1"
    app="$2"
    plist="$3"
    pidfile="$4"
    case "$deadline" in ''|*[!0-9]*) exit 1 ;; esac
    while [ "$(/bin/date +%s)" -lt "$deadline" ]; do
        pid="$(/bin/cat "$pidfile" 2>/dev/null)"
        alive=false
        case "$pid" in
            ''|*[!0-9]*) ;;
            *)
                if /bin/kill -0 "$pid" 2>/dev/null; then
                    command="$(/bin/ps -p "$pid" -o comm= 2>/dev/null)"
                    case "$command" in "$app/Contents/MacOS/LockIn") alive=true ;; esac
                fi
                ;;
        esac
        if [ "$alive" = false ] && [ -d "$app" ]; then
            /usr/bin/open -g "$app" --args --nuclear-background
        fi
        /bin/sleep 2
    done
    /bin/rm -f "$plist"
    """#
}
