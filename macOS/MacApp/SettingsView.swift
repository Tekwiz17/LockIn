import SwiftUI
import SafariServices

@MainActor struct SettingsView: View {
    @ObservedObject var controller: SessionController
    @ObservedObject var sync: SyncServer
    @ObservedObject var blocker: ApplicationBlocker
    var body: some View {
        TabView {
            Form {
                Section("Timer & Blocking") {
                    Text("Timer lengths, automatic starts, Block / Only Allow rules, and Strict Blocking are saved per preset.")
                    Text("Use the Edit button beside your setup name to change app and website rules. Ordinary sessions can be edited while running; Nuclear sessions lock edits. Pause unlocks apps and websites.").foregroundStyle(.secondary)
                    Text("Standard Blocking uses normal macOS app hiding and a focus screen. Accessibility permission is not required.").font(.callout)
                }
                Section("Notifications") {
                    Toggle("Focus starts", isOn: pref(\.notifyFocus))
                    Toggle("Short Break starts", isOn: pref(\.notifyShort))
                    Toggle("Long Break starts", isOn: pref(\.notifyLong))
                    Toggle("One-minute warning", isOn: pref(\.warnSoon))
                    Button("Enable Notifications", action: controller.requestNotifications)
                }
            }.formStyle(.grouped).tabItem { Label("General", systemImage: "gearshape") }
            Form {
                Section {
                    Text("These always stay available, in both rule modes.").foregroundStyle(.secondary)
                    AppRuleEditor(title: "Never Block Apps", apps: Binding(get: { controller.data.preferences.neverApps }, set: { controller.data.preferences.neverApps = $0; controller.changed() }))
                    DomainEditor(title: "Never Block Websites", domains: Binding(get: { controller.data.preferences.neverDomains }, set: { controller.data.preferences.neverDomains = $0; controller.changed() }))
                }
            }.formStyle(.grouped).disabled(controller.nuclearLocked).tabItem { Label("Never Block", systemImage: "checkmark.shield") }
            Form {
                Section("Connect a browser") {
                    Text("Choose Connect Automatically in the extension and approve in LockIn. The code below remains available as a backup.")
                    Button("Create Connection Code") { sync.beginPairing() }
                    if let code = sync.pairingCode {
                        HStack { Text(code).font(.system(.title3, design: .monospaced)).textSelection(.enabled); Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(code, forType: .string) } }
                        Text("Valid for two minutes, one connection.").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Manage Safari Extension…") { SFSafariApplication.showPreferencesForExtension(withIdentifier: "com.lockin.mac.SafariExtension") { _ in } }
                    Text("For Chrome: Extensions → Developer Mode → Load unpacked → choose LockIn-Chrome.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Browsers") {
                    if sync.credentials.isEmpty { Text("Safari and Chrome are not connected yet.").foregroundStyle(.secondary) }
                    ForEach(sync.credentials) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Label(item.name, systemImage: sync.connected(item.id) ? "checkmark.circle.fill" : "circle")
                                Text(sync.connected(item.id) ? (controller.active ? "Connected · Website blocking active" : "Connected · Unlocked") : "Not connected · Will retry automatically").font(.caption).foregroundStyle(.secondary)
                                if let date = sync.lastSeen[item.id] { Text("Last seen \(date.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer(); Button("Disconnect") { sync.disconnect(item.id) }.disabled(controller.nuclearLocked)
                        }
                    }
                    Text(sync.status).font(.caption).foregroundStyle(.secondary)
                    if sync.status != "Ready" { Button("Try Again") { sync.start() } }
                    Text("If disconnected during timed Focus, cached rules last until its deadline. Indefinite Focus renews a 90-second lease while LockIn is active, so cached rules release shortly after losing the app. Disconnecting here revokes access; use Disconnect in the extension to clear its cached rules immediately.").font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).tabItem { Label("Browsers", systemImage: "globe") }
            Form {
                Section("Private by design") {
                    Text("LockIn runs entirely on this Mac. No accounts, analytics, cloud services or browsing-history uploads.")
                    Text("Browser credentials live in Keychain and the extension's local storage. Presets and Focus history live in Application Support/LockIn.").foregroundStyle(.secondary)
                    Text("LockIn 1.2 · macOS 14 or later").font(.headline)
                    Text("Nuclear Mode locks controls for one Focus and uses a background watchdog. macOS still lets you disable background items or extensions. It isn't a protected Screen Time restriction.").foregroundStyle(.secondary)
                }
                DisclosureGroup("Diagnostics") {
                    Text("Phase: \(controller.title)\nPreset: \(controller.preset.name)\nRule mode: \(controller.preset.mode.title)\nRevision: \(controller.data.revision)\nCurrent app: \(blocker.currentApp)\nDecision: \(blocker.currentDecision)\nSync: \(sync.status)").font(.system(.caption, design: .monospaced))
                    Button("Copy Diagnostics") {
                        let text = "LockIn 1.2\nPhase: \(controller.title)\nSession: \(controller.data.session?.id.uuidString ?? "none")\nMode: \(controller.preset.mode.title)\nRevision: \(controller.data.revision)\nSync: \(sync.status)\nBrowsers: \(sync.credentials.map { "\($0.name): revision \(sync.lastRevision[$0.id] ?? -1)" }.joined(separator: ", "))"
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
                    }
                }
            }.formStyle(.grouped).tabItem { Label("About", systemImage: "info.circle") }
        }.padding(12).frame(minWidth: 420, idealWidth: 630, maxWidth: .infinity, minHeight: 440, idealHeight: 590, maxHeight: .infinity)
    }
    func pref(_ key: WritableKeyPath<Preferences, Bool>) -> Binding<Bool> { Binding(get: { controller.data.preferences[keyPath: key] }, set: { controller.data.preferences[keyPath: key] = $0; controller.changed() }) }
}
