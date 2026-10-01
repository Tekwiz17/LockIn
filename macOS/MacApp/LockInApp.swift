import SwiftUI
import AppKit
import UserNotifications

@MainActor final class AppModel: ObservableObject {
    let session: SessionController
    let recovery: SessionRecovery
    let dock: DockController
    let blocker: ApplicationBlocker
    let sync: SyncServer
    init() {
        session = SessionController(); recovery = SessionRecovery(controller: session); dock = DockController(controller: session); blocker = ApplicationBlocker(controller: session); sync = SyncServer(controller: session)
        session.onChange = { [weak self] in self?.objectWillChange.send(); self?.blocker.refresh(); self?.dock.refresh(); self?.recovery.refresh(); self?.sync.publish() }
        session.onShowChallenge = {
            NSApp.activate()
            NotificationCenter.default.post(name: Notification.Name("LockInShowChallenge"), object: nil)
        }
        AppDelegate.controller = session
        AppDelegate.sync = sync
        AppDelegate.dock = dock
        NuclearWatchdog.recordProcess()
        if !session.nuclearLocked { NuclearWatchdog.remove() }
        blocker.refresh(); dock.refresh(); recovery.refresh()
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static weak var controller: SessionController?
    static weak var sync: SyncServer?
    static weak var dock: DockController?
    func application(_ application: NSApplication, open urls: [URL]) { urls.forEach { Self.sync?.handleURL($0) }; application.activate(); NotificationCenter.default.post(name: Notification.Name("LockInShowMain"), object: nil) }
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        if CommandLine.arguments.contains("--nuclear-background") || CommandLine.arguments.contains("--recovery-background") {
            DispatchQueue.main.async { NSApp.hide(nil) }
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.controller?.data.session != nil {
            Self.controller?.error = "End the session through LockIn or its extension before quitting. Closing the window keeps the session running."
            sender.hide(nil); return .terminateCancel
        }
        Self.dock?.restoreNow()
        // Give waiting browser connections time to receive the authoritative unlock.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner]) }
}
@main @MainActor struct LockInApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("LockIn", id: "main") {
            MainView(controller: model.session).tint(Color(red: 0.424, green: 0.388, blue: 1))

        }.defaultSize(width: 650, height: 650).windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appTermination) {
                Button(model.session.data.session != nil ? "Hide LockIn (Session continues)" : "Quit LockIn") { if model.session.data.session != nil { NSApp.hide(nil) } else { NSApp.terminate(nil) } }.keyboardShortcut("q")
            }
        }
        Window("Exit Check", id: "exit-challenge") {
            ExitChallengeView(controller: model.session)
                .onDisappear { model.session.cancelChallenge() }
        }.defaultSize(width: 500, height: 500).windowResizability(.contentMinSize)
        Settings { SettingsView(controller: model.session, sync: model.sync, blocker: model.blocker).tint(Color(red: 0.424, green: 0.388, blue: 1)) }
        MenuBarExtra { MenuContent(controller: model.session) } label: {
            MenuLabel(controller: model.session)
        }.menuBarExtraStyle(.window)
    }
}
@MainActor struct MenuLabel: View {
    @ObservedObject var controller: SessionController
    @Environment(\.openWindow) var openWindow
    var body: some View {
        Label(controller.data.session == nil ? "LockIn" : controller.clock, systemImage: controller.active ? "lock.fill" : "timer")
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LockInShowMain"))) { _ in openWindow(id: "main"); NSApp.activate() }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LockInShowChallenge"))) { _ in openWindow(id: "exit-challenge"); NSApp.activate() }
    }
}
