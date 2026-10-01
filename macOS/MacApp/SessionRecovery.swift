import Foundation
import Darwin

/// App monitors its user watchdog; watchdog monitors the app. Neither is privileged.
@MainActor final class SessionRecovery {
    private weak var controller: SessionController?
    private var timer: Timer?
    private var installed = false
    private var warned = false
    private let label = "com.lockin.mac.session-recovery"
    private var agent: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist") }
    private var deadline: URL { DockStore.directory.appendingPathComponent("session-recovery.deadline") }
    private var service: String { "gui/\(getuid())/\(label)" }
    init(controller: SessionController) {
        self.controller = controller
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
    func refresh() {
        guard let controller else { return }
        guard let session = controller.data.session else { remove(); return }
        do {
            if controller.nuclearLocked, let end = session.endDate {
                remove()
                let nuclearAgent = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/com.lockin.mac.nuclear.plist")
                let loaded = try run(["print", "gui/\(getuid())/com.lockin.mac.nuclear"]) == 0
                if !FileManager.default.fileExists(atPath: nuclearAgent.path) || !loaded {
                    try NuclearWatchdog.install(until: end)
                }
                warned = false; return
            }
            try FileManager.default.createDirectory(at: DockStore.directory, withIntermediateDirectories: true)
            NuclearWatchdog.recordProcess()
            let end = session.endDate ?? Date().addingTimeInterval(90)
            try String(Int(ceil(end.timeIntervalSince1970))).write(to: deadline, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: deadline.path)
            // Detect unloads and dead watchdogs. launchd StartInterval also restarts a killed shell.
            let loaded = try run(["print", service]) == 0
            if !installed || !FileManager.default.fileExists(atPath: agent.path) || !loaded {
                try install()
            }
            warned = false
        } catch {
            if !warned { controller.error = "Session recovery couldn't start: \(error.localizedDescription). macOS can still close the app; reopen it to recover saved state."; warned = true }
        }
    }
    private func install() throws {
        _ = try run(["bootout", service])
        let script = DockStore.directory.appendingPathComponent("session-recovery.sh")
        try Self.scriptSource.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        try FileManager.default.createDirectory(at: agent.deletingLastPathComponent(), withIntermediateDirectories: true)
        let values: [String: Any] = ["Label": label, "RunAtLoad": true, "StartInterval": 15, "ProgramArguments": ["/bin/sh", script.path, deadline.path, Bundle.main.bundleURL.path, agent.path, DockStore.directory.appendingPathComponent("app.pid").path], "ProcessType": "Background", "LimitLoadToSessionType": "Aqua"]
        try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0).write(to: agent, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: agent.path)
        guard try run(["bootstrap", "gui/\(getuid())", agent.path]) == 0 else { throw DockStore.failure("Allow LockIn's background item in System Settings.") }
        installed = true
    }
    private func remove() {
        try? FileManager.default.removeItem(at: deadline)
        guard installed || FileManager.default.fileExists(atPath: agent.path) else { return }
        try? FileManager.default.removeItem(at: agent); _ = try? run(["bootout", service]); installed = false
    }
    private func run(_ args: [String]) throws -> Int32 {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/launchctl"); p.arguments = args
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit(); return p.terminationStatus
    }
    static let scriptSource = #"""
    #!/bin/sh
    deadlinefile="$1"
    app="$2"
    plist="$3"
    pidfile="$4"
    while :; do
        deadline="$(/bin/cat "$deadlinefile" 2>/dev/null)"
        case "$deadline" in ''|*[!0-9]*) break ;; esac
        [ "$(/bin/date +%s)" -lt "$deadline" ] || break
        pid="$(/bin/cat "$pidfile" 2>/dev/null)"
        alive=false
        case "$pid" in
            ''|*[!0-9]*) ;;
            *) if /bin/kill -0 "$pid" 2>/dev/null; then
                command="$(/bin/ps -p "$pid" -o comm= 2>/dev/null)"
                [ "$command" = "$app/Contents/MacOS/LockIn" ] && alive=true
               fi ;;
        esac
        if [ "$alive" = false ] && [ -d "$app" ]; then
            /usr/bin/open -g "$app" --args --recovery-background
        fi
        /bin/sleep 2
    done
    /bin/rm -f "$plist"
    """#
}
