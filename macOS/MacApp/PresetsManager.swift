import SwiftUI

@MainActor struct PresetsManager: View {
    @ObservedObject var controller: SessionController
    @Environment(\.dismiss) var dismiss
    @State private var selection: UUID?
    @State private var editing: Preset?
    @State private var renameID: UUID?
    @State private var name = ""
    @State private var renaming = false
    @State private var savingNew = false
    @State private var deleting = false
    @State private var replacing = false
    var chosen: Preset? { controller.data.presets.first { $0.id == selection } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Manage Presets").font(.title2); Spacer(); Button("Done") { dismiss() } }
            Text("Save timers, rules and Block AI together. Replace a preset with your current setup whenever you want.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            List(selection: $selection) {
                ForEach(controller.data.presets) { p in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.name).font(.headline).lineLimit(2)
                        Text("\((p.savedActivityMode ?? .pomodoro).title) · \(p.savedIndefinite == true && p.savedActivityMode == .focus ? "Indefinite" : "\(p.focus) min") · \(p.apps.count) apps · \(p.domains.count) sites\(p.blockAI == true ? " · Block AI" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4).tag(p.id)
                }
            }.frame(minHeight: 160)
            if controller.data.presets.isEmpty { Text("No presets yet. Save your current setup to get started.").foregroundStyle(.secondary) }
            HStack {
                Button("Save Current as New…") { name = ""; savingNew = true }.disabled(controller.data.session != nil)
                Button("Use Custom") { controller.selectCustom(true); dismiss() }.disabled(controller.data.session != nil)
            }
            if let p = chosen {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button("Use Preset") { controller.selectPreset(p.id); dismiss() }.buttonStyle(.borderedProminent).disabled(controller.data.session != nil)
                        Button("Edit…") { editing = p }
                        Button("Rename…") { renameID = p.id; name = p.name; renaming = true }
                    }
                    HStack {
                        Button("Duplicate") { controller.duplicatePreset(p.id) }
                        Button("Replace with Current…") { replacing = true }
                        Button("Delete…", role: .destructive) { deleting = true }.disabled(controller.data.session?.presetID == p.id)
                    }
                }
            }
            if controller.data.session != nil { Text("You can edit ordinary session rules. End the session before selecting another setup or deleting its active preset.").font(.caption).foregroundStyle(.secondary) }
        }.padding(24).frame(minWidth: 520, idealWidth: 620, maxWidth: .infinity, minHeight: 470, idealHeight: 540, maxHeight: .infinity)
        .disabled(controller.nuclearLocked)
        .sheet(item: $editing) { p in
            PresetEditor(preset: p, running: controller.data.session?.presetID == p.id, activityMode: p.savedActivityMode ?? .pomodoro, controller: controller, save: controller.update)
        }
        .alert("Rename Preset", isPresented: $renaming) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { if let renameID { controller.renamePreset(renameID, name: name) } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert("Save Current as New Preset", isPresented: $savingNew) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button("Save") { controller.saveCustomAsPreset(name: name); selection = controller.data.selected }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert("Replace this preset?", isPresented: $replacing) {
            Button("Cancel", role: .cancel) {}
            Button("Replace") { if let selection { controller.replacePresetWithCurrent(selection) } }
        } message: { Text("Replace its timer and rules with your current setup. The preset keeps its name. If it is in use, rule changes apply now.") }
        .alert("Delete this preset?", isPresented: $deleting) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { if let selection { controller.deletePreset(selection); self.selection = nil } }
        } message: { Text("Your history is kept. Custom remains available.") }
    }
}
