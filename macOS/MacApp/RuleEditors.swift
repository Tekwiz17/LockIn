import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor struct PresetEditor: View {
    @State var preset: Preset
    var custom = false
    var running = false
    var activityMode = ActivityMode.pomodoro
    var controller: SessionController? = nil
    var save: (Preset) -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(custom ? "Edit Setup" : "Edit Preset").font(.title2).lineLimit(2); Spacer(); Button("Cancel") { dismiss() }; Button("Save") { preset.name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines); save(preset); dismiss() }.buttonStyle(.borderedProminent).disabled(preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.padding(20)
            Form {
                if !custom { TextField("Name", text: $preset.name) }
                if !running { Section("Timer") {
                    if !custom {
                        Picker("Timer mode", selection: Binding(get: { preset.savedActivityMode ?? .pomodoro }, set: { preset.savedActivityMode = $0 })) {
                            ForEach(ActivityMode.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented)
                        if preset.savedActivityMode == .focus {
                            Toggle("Indefinite Focus", isOn: Binding(get: { preset.savedIndefinite == true }, set: { preset.savedIndefinite = $0 }))
                        }
                    }
                    if !((custom ? activityMode : preset.savedActivityMode ?? .pomodoro) == .focus && preset.savedIndefinite == true) {
                        Stepper("Focus: \(preset.focus) min", value: $preset.focus, in: 1...180)
                    }
                    if (custom ? activityMode : preset.savedActivityMode ?? .pomodoro) == .pomodoro {
                    Stepper("Short Break: \(preset.shortBreak) min", value: $preset.shortBreak, in: 1...60)
                    Stepper("Long Break: \(preset.longBreak) min", value: $preset.longBreak, in: 1...120)
                    Stepper("Long Break after \(preset.cycles) sessions", value: $preset.cycles, in: 1...12)
                    Toggle("Automatically start next phase", isOn: $preset.autoStart)
                    }
                    Text("Timer changes apply to the next phase. Rule changes apply immediately when saved.").font(.caption).foregroundStyle(.secondary)
                }
                }
                if !(preset.savedActivityMode == .focus && preset.savedIndefinite == true) {
                    Section("Nuclear Mode") {
                        Toggle("Nuclear Mode", isOn: Binding(get: { preset.nuclearEnabled == true }, set: { preset.nuclearEnabled = $0 })).disabled(running)
                        Text("Shown on the main screen too. First enable requires macOS authentication on Save, then you choose whether to require it for future starts.").font(.caption).foregroundStyle(.secondary)
                        if let controller, controller.data.preferences.nuclearVerified == true {
                            Toggle("Require Mac authentication each time", isOn: Binding(get: { controller.data.preferences.requireNuclearAuthentication != false }, set: { controller.setNuclearAuthentication($0) })).disabled(controller.authenticating || running)
                        }
                    }
                }
                Section("Rules") {
                    if running { Text("Changes apply to this session as soon as you save.").font(.callout).foregroundStyle(.secondary) }
                    Picker("Rules", selection: $preset.mode) { ForEach(RuleMode.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                    Text(preset.mode.explanation).foregroundStyle(.secondary)
                    AppRuleEditor(title: preset.mode == .block ? "Blocked Apps" : "Allowed Apps", apps: $preset.apps)
                    DomainEditor(title: preset.mode == .block ? "Blocked Websites" : "Allowed Websites", domains: $preset.domains)
                    Text("Google searches use Web results to avoid AI Overviews. Images and other search filters stay available.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Toggle("Block AI", isOn: Binding(get: { preset.blockAI == true }, set: { preset.blockAI = $0 }))
                    Text("Hides detected Google AI Overviews and AI Mode links; blocks known AI sites during Focus. Never Block exceptions still apply. Coverage is best effort and may change as sites update.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if preset.blockAI == true {
                        DisclosureGroup("Additional AI Websites") {
                            DomainEditor(title: "Also block these AI services", domains: Binding(get: { preset.extraAIDomains ?? [] }, set: { preset.extraAIDomains = $0 }))
                        }
                    }
                    if !(preset.savedActivityMode == .focus && preset.savedIndefinite == true) {
                        Toggle("Require Exit Checks", isOn: Binding(get: { preset.exitFriction == true }, set: { preset.exitFriction = $0 })).disabled(running)
                        Text("Timed ordinary Focus: unlimited pauses and stops, with a short check for Pause and a longer check for Stop. This setting applies when the next Focus starts. Nuclear always requires a check and allows only two emergency ends per calendar month.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Toggle("Hide Blocked Apps from Dock", isOn: Binding(get: { preset.hideBlockedDockApps == true }, set: { preset.hideBlockedDockApps = $0 }))
                    Text("Temporarily removes blocked apps’ pinned shortcuts during Focus and restores their positions on pause, break or end. A saved snapshot and background helper recover after crashes. Running apps can still appear in the Dock; apps are never closed by this option. The Dock briefly restarts when its shortcuts change.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Toggle("Strict Blocking", isOn: $preset.strict)
                    Text("Strict Blocking attempts to close unavailable apps. Standard hides them and shows a focus screen. Unsaved work may prevent an app from closing.").font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped)
        }.frame(minWidth: 360, idealWidth: 610, maxWidth: .infinity, minHeight: 420, idealHeight: 640, maxHeight: .infinity)
    }
}
@MainActor struct AppRuleEditor: View {
    var title: String
    @Binding var apps: [AppRule]
    @State private var picking = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Button("Choose Apps…") { picking = true } }
            if apps.isEmpty { Text("No apps selected").foregroundStyle(.secondary).font(.caption) }
            ForEach(apps) { app in
                HStack { Image(nsImage: NSWorkspace.shared.icon(forFile: app.path)).resizable().frame(width: 22, height: 22); Text(app.name).fixedSize(horizontal: false, vertical: true); Spacer(); Button { apps.removeAll { $0.id == app.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("Remove \(app.name)") }
            }
            Text("Finder, System Settings and essential macOS components always remain available.").font(.caption).foregroundStyle(.secondary)
        }.sheet(isPresented: $picking) { AppPicker(selection: $apps) }
    }
}
@MainActor struct AppPicker: View {
    @Binding var selection: [AppRule]
    @State private var catalog: [AppRule] = []
    @State private var query = ""
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack {
            HStack { Text("Choose Apps").font(.title2); Spacer(); Button("Done") { dismiss() } }.padding(.bottom, 8)
            TextField("Search apps", text: $query).textFieldStyle(.roundedBorder)
            List(catalog.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { app in
                Toggle(isOn: Binding(get: { selection.contains { $0.id == app.id } }, set: { checked in if checked { selection.append(app) } else { selection.removeAll { $0.id == app.id } } })) {
                    HStack { Image(nsImage: NSWorkspace.shared.icon(forFile: app.path)).resizable().frame(width: 28, height: 28); Text(app.name).fixedSize(horizontal: false, vertical: true) }
                }.toggleStyle(.checkbox)
            }
            Button("Choose another app…") {
                let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowedContentTypes = [.application]; panel.allowsMultipleSelection = true
                if panel.runModal() == .OK {
                    for url in panel.urls {
                        guard let b = Bundle(url: url), let id = b.bundleIdentifier, !FocusRuleEngine.protectedApps.contains(id.lowercased()), id != Bundle.main.bundleIdentifier, !selection.contains(where: { $0.id == id }) else { continue }
                        let app = AppRule(id: id, name: (b.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? url.deletingPathExtension().lastPathComponent, path: url.path)
                        selection.append(app); if !catalog.contains(where: { $0.id == id }) { catalog.append(app) }
                    }
                }
            }
        }.padding(22).frame(width: 450, height: 520).onAppear { catalog = AppCatalog.scan(); for app in selection where !catalog.contains(where: { $0.id == app.id }) { catalog.append(app) } }
    }
}
@MainActor struct DomainEditor: View {
    var title: String
    @Binding var domains: [String]
    @State private var input = ""
    @State private var validationMessage: String?
    var normalized: String? { FocusRuleEngine.normalizeDomain(input) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(domains, id: \.self) { domain in
                HStack { Text(domain).textSelection(.enabled).fixedSize(horizontal: false, vertical: true); Spacer(); Button { domains.removeAll { $0 == domain } } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("Remove \(domain)") }
            }
            Text("Enter a domain (example.com) or paste a full website URL.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                TextField("", text: $input, prompt: Text("example.com"))
                    .textFieldStyle(.roundedBorder).labelsHidden().frame(minWidth: 100, maxWidth: .infinity).onSubmit(add)
                Button("Add", action: add).disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || domains.count >= 400)
            }
            if let validationMessage { Text(validationMessage).font(.caption).foregroundStyle(.orange) }
            Text(input.isEmpty ? "Includes subdomains. App and website rules are independent." : normalized.map { "\($0) · Includes subdomains" } ?? "Enter a valid website, such as example.com. Use punycode for international domains.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    func add() {
        guard domains.count < 400 else { validationMessage = "This list has reached 400 websites."; return }
        guard let domain = normalized else { validationMessage = "Enter a website address such as youtube.com. Add one website at a time."; return }
        guard !domains.contains(domain) else { validationMessage = "That website is already in the list."; return }
        domains.append(domain); input = ""; validationMessage = nil
    }
}

