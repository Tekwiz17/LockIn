import AppKit
import SwiftUI
import ApplicationServices

@MainActor final class ShieldPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class ApplicationBlocker: ObservableObject {
    private weak var controller: SessionController?
    private var observers: [NSObjectProtocol] = []
    private var panels: [NSPanel] = []
    private var previousAllowed: NSRunningApplication?
    private var blocked: NSRunningApplication?
    private var lastAttempt = Date.distantPast
    private var quittingPID: pid_t?
    private var quitGraceUntil = Date.distantPast
    private var quitTimer: Timer?
    private var visibilityTimer: Timer?
    @Published var currentApp = "None"
    @Published var currentDecision = "Allowed"
    init(controller: SessionController) {
        self.controller = controller
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                Task { @MainActor in
                    if app.isActive { self?.inspect(app) }
                    self?.hideVisibleBlockedApps()
                }
            })
        }
        observers.append(nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.controller?.tick(); self?.refresh() } })
        observers.append(nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in if self?.blocked?.isTerminated == true { self?.dismiss() } } })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self, let app = self.blocked else { return }; self.dismiss(); self.present(app) }
        })
        startVisibilityChecks()
    }
    private func startVisibilityChecks() {
        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        visibilityTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func hideVisibleBlockedApps() {
        guard controller?.active == true,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        var seen = Set<pid_t>()
        for window in windows {
            guard (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  ((window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0,
                  let owner = window[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            let pid = pid_t(owner.int32Value)
            guard seen.insert(pid).inserted, let app = NSRunningApplication(processIdentifier: pid),
                  !app.isTerminated, !allowed(app) else { continue }
            // Hide all of this app's windows, including unfocused windows on another display.
            _ = app.hide()
            if controller?.preset.strict == true { _ = app.terminate() }
        }
    }
    func allowed(_ app: NSRunningApplication) -> Bool {
        if app.processIdentifier == quittingPID && Date() < quitGraceUntil { return true }
        guard let c = controller, let id = app.bundleIdentifier, app.activationPolicy == .regular else { return true }
        return FocusRuleEngine.allowsApp(id, active: c.active, mode: c.preset.mode, selected: c.preset.apps, never: c.data.preferences.neverApps)
    }
    func refresh() {
        guard let c = controller, c.active else { dismiss(); return }
        if let app = blocked {
            if allowed(app) { dismiss() }
            else if c.preset.strict { _ = app.terminate() }
        }
        if let front = NSWorkspace.shared.frontmostApplication { inspect(front) }
        hideVisibleBlockedApps()
    }
    private func inspect(_ app: NSRunningApplication) {
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        currentApp = app.localizedName ?? "Application"
        if allowed(app) {
            currentDecision = "Allowed"; previousAllowed = app; dismiss(); return
        }
        currentDecision = "Blocked"
        if blocked?.processIdentifier == app.processIdentifier, !panels.isEmpty {
            // Hide the app once per activation; no activation observer loop.
            _ = app.hide(); panels.first?.makeKeyAndOrderFront(nil); NSApp.activate(); return
        }
        lastAttempt = Date(); dismiss()
        if controller?.preset.strict == true { _ = app.terminate() }
        present(app)
        _ = app.hide()
    }
    private func present(_ app: NSRunningApplication) {
        guard let c = controller, c.active else { return }
        blocked = app
        // One shield per display covers the blocked app even without AX/window capture permission.
        for screen in NSScreen.screens {
            let panel = ShieldPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false; panel.backgroundColor = .clear
            panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: BlockerView(controller: c, name: app.localizedName ?? "This app", goBack: { [weak self] in self?.goBack() }, quitApp: { [weak self] in self?.quitBlockedApp() }))
            panel.setFrame(screen.frame, display: true); panel.orderFrontRegardless(); panels.append(panel)
        }
        NSApp.activate()
        panels.first?.makeKeyAndOrderFront(nil)
    }
    func dismiss() { panels.forEach { $0.orderOut(nil); $0.close() }; panels.removeAll(); blocked = nil }
    func quitBlockedApp() {
        guard let app = blocked, controller?.preset.strict == false else { return }
        // Briefly expose this app's normal save prompt; cancelling cannot leave it unlocked indefinitely.
        quittingPID = app.processIdentifier; quitGraceUntil = Date().addingTimeInterval(30)
        quitTimer?.invalidate()
        quitTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.quittingPID = nil; self?.refresh() }
        }
        if let quitTimer { RunLoop.main.add(quitTimer, forMode: .common) }
        dismiss()
        _ = app.activate(options: [])
        _ = app.terminate()
    }
    func goBack() {
        dismiss()
        if let previousAllowed, !previousAllowed.isTerminated, allowed(previousAllowed) { previousAllowed.activate(options: []) }
        else { NSApp.activate(); NSApp.windows.first { $0.canBecomeMain && !($0 is NSPanel) }?.makeKeyAndOrderFront(nil) }
    }
}
@MainActor struct BlockerView: View {
    @ObservedObject var controller: SessionController
    private let purple = Color(red: 108.0/255, green: 99.0/255, blue: 1)
    var name: String
    var goBack: () -> Void
    var quitApp: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "lock.circle.fill").font(.system(size: 32)).foregroundStyle(purple)
                Text("LOCKIN").font(.headline).tracking(2)
            }
            Image(systemName: "clock").font(.system(size: 76, weight: .light)).foregroundStyle(purple).padding(.top, 24)
            Text("\(name) isn't available.").font(.system(size: 28, weight: .semibold)).multilineTextAlignment(.center)
            Text("Stay with your Focus.").foregroundStyle(.secondary)
            Text(controller.clock).font(.system(size: 64, weight: .light, design: .rounded).monospacedDigit()).foregroundStyle(purple)
            Text(controller.indefinite ? "Time elapsed" : "Time remaining").foregroundStyle(.secondary)
            if controller.nuclearLocked {
                Label("Nuclear Mode", systemImage: "lock.fill").foregroundStyle(purple)
            }
            Button("Open LockIn") {
                goBack()
                NSApp.activate()
                NotificationCenter.default.post(name: Notification.Name("LockInShowMain"), object: nil)
            }.buttonStyle(.borderedProminent).controlSize(.large)
            Button("Go Back", action: goBack).keyboardShortcut(.defaultAction).buttonStyle(.bordered).controlSize(.large)
            if !controller.preset.strict {
                Button("Quit App", action: quitApp).buttonStyle(.bordered)
                Text("Unsaved work? You'll have 30 seconds to answer the app's save prompt.").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(50).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(nsColor: .windowBackgroundColor)).tint(purple)
    }
}

@MainActor enum AppCatalog {
    static func scan() -> [AppRule] {
        var found: [String: AppRule] = [:]
        func include(_ url: URL) {
            let resolved = url.resolvingSymlinksInPath()
            guard let b = Bundle(url: resolved), let id = b.bundleIdentifier,
                  !FocusRuleEngine.protectedApps.contains(id.lowercased()), id != Bundle.main.bundleIdentifier,
                  (b.object(forInfoDictionaryKey: "LSUIElement") as? Bool) != true,
                  (b.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool) != true else { return }
            let name = (b.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? (b.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? resolved.deletingPathExtension().lastPathComponent
            found[id] = AppRule(id: id, name: name, path: resolved.path)
        }
        // Launch Services resolves Safari's sealed-system location without assuming /Applications.
        for id in ["com.apple.Safari", "com.apple.SafariTechnologyPreview", "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser", "com.apple.mail", "com.apple.Notes", "com.apple.TextEdit"] {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { include(url) }
        }
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let url = app.bundleURL { include(url) }
        }
        let roots = ["/Applications", NSHomeDirectory() + "/Applications", "/System/Applications", "/System/Applications/Utilities", "/System/Cryptexes/App/System/Applications"]
        for root in roots {
            guard let en = FileManager.default.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in en {
                if url.pathExtension == "app" { en.skipDescendants(); include(url) }
            }
        }
        return found.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
