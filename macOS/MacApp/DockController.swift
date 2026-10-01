import AppKit
import Darwin

@MainActor final class DockController {
    private weak var controller: SessionController?
    private var timer: Timer?
    private var installed = false
    private var warned = false
    private let label = "com.lockin.mac.dock-recovery"
    private var service: String { "gui/\(getuid())/\(label)" }
    private var agent: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist") }
    init(controller: SessionController) {
        self.controller = controller
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
    func refresh() {
        guard let controller else { return }
        do {
            guard controller.active, controller.preset.hideBlockedDockApps == true else {
                try DockStore.restoreIfNeeded(force: true)
                removeAgent(); warned = false; return
            }
            // Recovery must be running before we remove any shortcut.
            if !installed { try installAgent() }
            try DockStore.locked {
                let current = try DockStore.preferences()
                let old = try DockStore.readJournal()
                let restored = old.map { DockLayout.restore(current: current, journal: $0) } ?? current
                let hidden = try restored.filter { tile in
                    guard let id = try DockStore.appID(tile) else { return false }
                    return !FocusRuleEngine.allowsApp(id, active: true, mode: controller.preset.mode, selected: controller.preset.apps, never: controller.data.preferences.neverApps)
                }
                let keys = Set(hidden.map(\.key))
                let visible = restored.filter { !keys.contains($0.key) }
                if keys.isEmpty {
                    if visible.map(\.key) != current.map(\.key) { try DockStore.write(visible) }
                    if old != nil { try FileManager.default.removeItem(at: DockStore.snapshot) }
                    return
                }
                let deadline = controller.indefinite ? Date().addingTimeInterval(90) : controller.data.session?.endDate ?? Date()
                // A write-ahead union protects tiles if we crash while applying live edits.
                var journal = DockJournal(original: restored, removed: keys.union(old?.removed ?? []), deadline: deadline)
                journal.removed.formIntersection(Set(restored.map(\.key)))
                try DockStore.save(journal)
                if visible.map(\.key) != current.map(\.key) { try DockStore.write(visible) }
                journal.removed = keys
                try DockStore.save(journal)
            }
            warned = false
        } catch {
            if !warned { controller.error = "Dock hiding needs attention: \(error.localizedDescription)"; warned = true }
            // Retain the journal and agent on any failure, so recovery can retry.
        }
    }
    private func installAgent() throws {
        guard let helper = Bundle.main.url(forResource: "LockInDockRecovery", withExtension: nil), FileManager.default.isExecutableFile(atPath: helper.path) else {
            throw DockStore.failure("The Dock recovery helper is missing. Rebuild the complete LockIn project.")
        }
        _ = try run(["bootout", service])
        try FileManager.default.createDirectory(at: agent.deletingLastPathComponent(), withIntermediateDirectories: true)
        let plist: [String: Any] = ["Label": label, "ProgramArguments": [helper.path], "RunAtLoad": true, "StartInterval": 15, "ProcessType": "Background", "LimitLoadToSessionType": "Aqua"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: agent, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: agent.path)
        guard try run(["bootstrap", "gui/\(getuid())", agent.path]) == 0, try run(["print", service]) == 0 else {
            throw DockStore.failure("macOS couldn't enable Dock recovery. Allow LockIn's background item and retry.")
        }
        installed = true
    }
    private func removeAgent() {
        // Nothing to unload on ordinary ticks with no previous snapshot/agent.
        guard installed || FileManager.default.fileExists(atPath: agent.path) else { return }
        try? FileManager.default.removeItem(at: agent)
        _ = try? run(["bootout", service]); installed = false
    }
    private func run(_ args: [String]) throws -> Int32 {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/launchctl"); process.arguments = args
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit(); return process.terminationStatus
    }
    func restoreNow() {
        do { try DockStore.restoreIfNeeded(force: true); removeAgent() }
        catch { controller?.error = "Dock restoration couldn't finish: \(error.localizedDescription). Your snapshot is kept for retry." }
    }
}
