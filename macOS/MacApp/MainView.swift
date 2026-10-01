import SwiftUI

@MainActor struct MainView: View {
    @ObservedObject var controller: SessionController
    @State private var editing: Preset?
    @State private var editingCustom = false
    @State private var showHistory = false
    @State private var confirmEnd = false
    @State private var confirmQuit = false
    @State private var confirmNuclear = false
    var wantsNuclear: Bool { controller.preset.nuclearEnabled == true && !controller.indefinite }
    @State private var showPresets = false
    @State private var namingPreset = false
    @State private var presetName = ""
    var phaseColor: Color { controller.nuclearLocked ? .orange : controller.data.session?.phase == .shortBreak ? Color(red: 0.27, green: 0.73, blue: 0.49) : controller.data.session?.phase == .longBreak ? Color(red: 0.31, green: 0.62, blue: 0.90) : .accentColor }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Label("LOCKIN", systemImage: "lock.circle").font(.headline).tracking(2)
                        Spacer()
                        Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }.help("History")
                        SettingsLink { Image(systemName: "gearshape") }.help("Settings")
                    }.buttonStyle(.plain)
                    Picker("Timer mode", selection: Binding(get: { controller.activityMode }, set: { mode in controller.selectMode(mode) })) {
                        ForEach(ActivityMode.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).frame(maxWidth: 400).disabled(controller.data.session != nil).help("End the current session before switching timer modes")
                    Text(controller.activityMode == .focus ? "One session. No breaks." : "Focus, rest, repeat.").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(controller.title).font(.title2.weight(.medium))
                    timer(size: min(360, max(180, min(geometry.size.width - 80, geometry.size.height * 0.43))))
                    if controller.data.session == nil {
                        Picker("Session setup", selection: Binding(get: { controller.data.useCustom == true }, set: { controller.selectCustom($0) })) {
                            Text("Presets").tag(false).disabled(controller.data.presets.isEmpty)
                            Text("Custom").tag(true)
                        }.pickerStyle(.segmented).frame(maxWidth: 360)
                        if controller.activityMode == .focus {
                            Picker("Focus length", selection: Binding(get: { controller.indefinite }, set: { controller.setIndefinite($0) })) {
                                Text("Timed").tag(false); Text("Indefinite").tag(true)
                            }.pickerStyle(.segmented).frame(maxWidth: 300)
                        }
                        if controller.data.useCustom == true && !controller.indefinite {
                            HStack(spacing: 12) {
                                minuteField("Focus", key: \.focus, range: 1...180)
                                if controller.activityMode == .pomodoro {
                                    minuteField("Short break", key: \.shortBreak, range: 1...60)
                                    minuteField("Long break", key: \.longBreak, range: 1...120)
                                }
                            }.frame(maxWidth: 440)
                        }
                        if controller.data.useCustom != true {
                            Picker("Preset", selection: Binding(get: { controller.preset.id }, set: { controller.selectPreset($0) })) {
                                ForEach(controller.data.presets) { p in Text(p.name).tag(p.id) }
                            }.frame(maxWidth: 360)
                        }
                    }
                    if controller.data.session == nil && controller.data.presets.isEmpty {
                        Text("No presets yet. Set your timer and rules, then save a preset whenever you like.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    HStack(spacing: 8) {
                        Text(controller.preset.name).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        Text("·").foregroundStyle(.secondary)
                        Button {
                            editingCustom = controller.data.custom?.id == controller.preset.id
                            editing = controller.currentSetup
                        } label: { Label("Edit", systemImage: "pencil") }
                        .buttonStyle(.borderedProminent).controlSize(.regular).disabled(controller.nuclearLocked)
                        Button { showPresets = true } label: { Image(systemName: "slider.horizontal.3") }
                            .buttonStyle(.bordered).disabled(controller.nuclearLocked).help("Manage Presets")
                    }.font(.headline)
                    Text("\(controller.preset.apps.count) apps · \(controller.preset.domains.count) websites \(controller.preset.mode == .block ? "blocked" : "allowed")")
                        .font(.callout).foregroundStyle(.secondary)
                    if controller.nuclearLocked {
                        Label("Nuclear Mode · Locked until \(controller.data.session?.endDate?.formatted(date: .omitted, time: .shortened) ?? "Focus ends")", systemImage: "lock.fill")
                            .foregroundStyle(.orange).font(.callout).multilineTextAlignment(.center)
                        Text("You can close this window. Focus keeps running.").font(.caption).foregroundStyle(.secondary)
                    }
                    if let challenge = controller.exitChallenge {
                        Button("Continue Exit Check…") { controller.requestExit(challenge.progress.action) }.buttonStyle(.bordered)
                    }
                    if controller.data.session == nil && !controller.indefinite {
                        Toggle(isOn: Binding(get: { wantsNuclear }, set: { controller.setNuclearEnabled($0) })) { Label("Nuclear Mode", systemImage: "flame.fill") }
                            .toggleStyle(.switch).fixedSize()
                        if wantsNuclear { Text("No pause. Early ending requires a check and a monthly emergency exit.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { actionButtons }
                        VStack(spacing: 12) { actionButtons }
                    }.controlSize(.large)
                    Spacer(minLength: 0)
                    Text("Today · \(Int(controller.today.reduce(0) { $0 + $1.actual }) / 60) min focused · \(controller.today.filter(\.completed).count) completed")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Quit LockIn", role: .destructive) { confirmQuit=true }
                        .buttonStyle(.bordered).controlSize(.regular).padding(.top,8)
                }.padding(24).frame(maxWidth: .infinity).frame(minHeight: max(0, geometry.size.height))
            }
        }.frame(minWidth: 360, minHeight: 460).disabled(controller.authenticating)
        .sheet(item: $editing) { p in
            PresetEditor(preset: p, custom: editingCustom, running: controller.data.session != nil, activityMode: controller.activityMode, controller: controller) { p in
                if editingCustom { controller.updateCustom(p) } else { controller.update(p) }
            }
        }
        .sheet(isPresented: $showPresets) { PresetsManager(controller: controller) }
        .sheet(isPresented: $showHistory) { HistoryView(controller: controller) }
        .sheet(isPresented: Binding(get: { !controller.data.preferences.onboarded }, set: { _ in })) { OnboardingView(controller: controller) }
        .alert("Save Current as New Preset", isPresented: $namingPreset) {
            TextField("Preset name", text: $presetName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { controller.saveCustomAsPreset(name: presetName) }.disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: { Text("Save the current timer, rules and Block AI setting for later.") }
        .alert("Start Nuclear Focus?", isPresented: $confirmNuclear) {
            Button("Cancel", role: .cancel) {}
            Button("Lock In for \(controller.preset.focus) minutes", role: .destructive) { controller.startNuclear() }
        } message: {
            Text("For this session, pause and rule edits are locked. Ending early requires an attention check and uses one of two monthly emergency exits. Closing the window keeps Focus running; a background watchdog reopens LockIn if it quits. It unlocks automatically after \(controller.preset.focus) minutes. Allow the background item if macOS asks, and keep the app in this location.\n\nExtensions and background items can still be disabled in macOS. Nothing runs while your Mac is asleep or powered off; the deadline still passes.")
        }
        .alert("Quit LockIn?", isPresented: $confirmQuit) {
            Button("Cancel", role: .cancel) {}
            Button("Quit LockIn", role: .destructive) { controller.quitPermanently() }
        } message: {
            Text(controller.nuclearLocked ? "Pass the emergency exit check first. This uses one monthly exit, ends Focus and quits without reopening." : "This ends the session, restores blocked Dock shortcuts and quits without reopening. If exit checks are enabled, complete the check first.")
        }
        .alert("End Focus?", isPresented: $confirmEnd) {
            Button("Cancel", role: .cancel) {}
            Button("End Session", role: .destructive, action: controller.end)
        } message: { Text("If exit checks are enabled, complete the check and confirm in LockIn first. An unfinished timed Focus won't count as completed.") }
        .alert("LockIn needs attention", isPresented: Binding(get: { controller.error != nil }, set: { if !$0 { controller.error = nil } })) { Button("OK") { controller.error = nil } } message: { Text(controller.error ?? "") }
    }
    private func timer(size: CGFloat) -> some View {
        ZStack {
            Circle().stroke(phaseColor.opacity(0.12), lineWidth: 10)
            Circle().trim(from: 0, to: controller.indefinite ? 1 : CGFloat(min(1, max(0, controller.remaining / max(1, controller.data.session?.planned ?? controller.preset.duration(.focus))))))
                .stroke(phaseColor, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 10) {
                if controller.indefinite { Image(systemName: "infinity").font(.title).foregroundStyle(phaseColor) }
                Text(controller.clock).font(.system(size: size * 0.21, weight: .light, design: .rounded).monospacedDigit()).contentTransition(.numericText())
                Text(controller.indefinite ? (controller.data.session == nil ? "Until you’re ready to stop." : "Time focused") : controller.active ? "Stay with it." : controller.data.session == nil ? "Make room for what matters." : "Distractions unlocked")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(20)
        }.frame(width: size, height: size).padding(8)
    }
    private func minuteField(_ title: String, key: WritableKeyPath<Preset, Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            TextField("Minutes", value: Binding(get: { controller.preset[keyPath: key] }, set: { value in
                var p = controller.preset; p[keyPath: key] = min(range.upperBound, max(range.lowerBound, value)); controller.updateCustom(p)
            }), format: .number).textFieldStyle(.roundedBorder).multilineTextAlignment(.center)
            Text("min").font(.caption2).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var actionButtons: some View {
        if let s = controller.data.session {
            if s.waiting { Button("Start \(s.phase.title)", action: controller.startWaiting).buttonStyle(.borderedProminent) }
            else if !controller.nuclearLocked { Button(s.isPaused ? "Resume" : controller.requiresChallenge(.pause) ? "Pause…" : "Pause", action: controller.togglePause).buttonStyle(.borderedProminent) }
            if s.phase != .focus { Button("Skip Break", action: controller.skipBreak) }
            if controller.nuclearLocked { Button("Emergency Exit (\(controller.emergencyRemaining) left)") { controller.requestExit(.stop) }.disabled(controller.emergencyRemaining == 0) }
            else { Button("End", role: .destructive) { confirmEnd = true } }
        } else {
            Button(wantsNuclear && !controller.indefinite ? "Start Nuclear Focus" : "Start Focus") {
                if wantsNuclear && !controller.indefinite { confirmNuclear = true } else { controller.start() }
            }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(controller.authenticating)
            Menu("Presets") {
                Button("Save Current as New Preset…") { presetName = ""; namingPreset = true }
                Button("Manage Presets…") { showPresets = true }
            }.fixedSize()
        }
    }
}
@MainActor struct OnboardingView: View {
    @ObservedObject var controller: SessionController
    @State private var step = 0
    @State private var editing: Preset?
    @State private var savePreset = false
    @State private var name = ""
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: ["lock.circle", "slider.horizontal.3", "hand.raised", "timer"][step]).font(.system(size: 46)).foregroundStyle(Color.accentColor)
            Text(["Focus on what matters.", "Choose how LockIn works", "You're in control", "Make it yours"][step]).font(.title)
            Text(["Lock distracting apps and websites while you work. They return when your break starts.", "Block: choose distractions.\nOnly Allow: choose what you need.\nNever Block always takes priority.", "LockIn hides blocked apps and covers them with a focus screen. Standard Focus can be paused or ended. Nuclear Mode requires separate confirmation and locks controls until the deadline.", "Start with Custom. No preset is required."][step]).multilineTextAlignment(.center).foregroundStyle(.secondary)
            if step == 2 { Button("Enable phase notifications") { controller.requestNotifications() } }
            if step == 3 {
                Button("Set Timer & Rules…") { editing = controller.data.custom ?? Preset(name: "Custom") }
                Toggle("Save my setup as a preset", isOn: $savePreset)
                if savePreset { TextField("Preset name", text: $name).textFieldStyle(.roundedBorder) }
            }
            HStack {
                if step > 0 { Button("Back") { step -= 1 } }
                Button(step == 3 ? "Let's Go" : "Continue") {
                    if step < 3 { step += 1 }
                    else {
                        if savePreset { controller.saveCustomAsPreset(name: name) }
                        controller.selectCustom(true)
                        controller.data.preferences.onboarded = true; controller.changed()
                    }
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(step == 3 && savePreset && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(30).frame(width: 460, height: 410)
            .sheet(item: $editing) { p in PresetEditor(preset: p, custom: true, save: controller.updateCustom) }
    }
}
@MainActor struct HistoryView: View {
    @ObservedObject var controller: SessionController
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Focus History").font(.title2); Spacer(); Button("Done") { dismiss() } }
            Text("This week · \(Int(controller.data.history.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }.reduce(0) { $0 + $1.actual }) / 60) minutes focused").foregroundStyle(.secondary)
            if controller.data.history.isEmpty { ContentUnavailableView("A fresh start", systemImage: "timer", description: Text("Your Focus sessions will appear here.")) }
            List(controller.data.history.reversed()) { h in
                HStack {
                    VStack(alignment: .leading) { Text(h.preset).font(.headline); Text(h.date, style: .date).font(.caption); Text(h.mode.title).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    VStack(alignment: .trailing) { Text(h.planned == 0 ? "\(Int(h.actual / 60)) min · Indefinite" : "\(Int(h.actual / 60)) / \(Int(h.planned / 60)) min"); Text(h.completed ? "Completed" : "Ended early").foregroundStyle(h.completed ? Color.green : Color.secondary) }
                }.padding(.vertical, 4)
            }
        }.padding(24).frame(width: 540, height: 450)
    }
}
