import SwiftUI
import AppKit

@MainActor struct MenuContent: View {
    @ObservedObject var controller: SessionController
    @Environment(\.openWindow) var openWindow
    @State private var confirmEnd = false
    private var accent: Color { controller.nuclearLocked ? .orange : Color(red: 0.424, green: 0.388, blue: 1) }
    private var phase: String {
        guard let session = controller.data.session else { return "READY TO FOCUS" }
        if controller.nuclearLocked { return "NUCLEAR FOCUS" }
        if session.isPaused { return "PAUSED" }
        if session.waiting { return "READY FOR \(session.phase.title.uppercased())" }
        return session.isIndefinite ? "INDEFINITE FOCUS" : session.phase.title.uppercased()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "lock.circle.fill").font(.system(size: 30)).foregroundStyle(accent)
                Text("LockIn").font(.title3.weight(.semibold))
                Spacer()
                SettingsLink { Image(systemName: "gearshape") }.buttonStyle(.bordered).help("Settings")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(phase).font(.caption.weight(.semibold)).tracking(1.4).foregroundStyle(accent)
                Text(controller.data.session == nil ? "Make room\nfor focus." : controller.clock)
                    .font(.system(size: controller.data.session == nil ? 30 : 46, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                Text("\(controller.activityMode.title) · \(controller.preset.name)")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                if controller.data.session != nil {
                    ProgressView(value: controller.indefinite ? 1 : min(1, max(0, 1 - controller.remaining / max(1, controller.data.session?.planned ?? 1))))
                        .tint(accent).accessibilityLabel(controller.indefinite ? "Indefinite Focus" : "Session progress")
                }
                Label(controller.active ? "Focus rules active" : "Everything unlocked", systemImage: controller.active ? "lock.fill" : "lock.open")
                    .font(.caption).foregroundStyle(.secondary)
                if controller.active {
                    Text("\(controller.preset.apps.count) apps · \(controller.preset.domains.count) websites\(controller.preset.blockAI == true ? " · Block AI" : "")")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if controller.nuclearLocked {
                    Label("Locked until \(controller.data.session?.endDate?.formatted(date: .omitted, time: .shortened) ?? "Focus ends")", systemImage: "flame.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            if let session = controller.data.session {
                if !controller.nuclearLocked {
                    HStack(spacing: 10) {
                        if session.waiting {
                            Button { controller.startWaiting() } label: { Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity) }
                                .buttonStyle(.borderedProminent)
                        } else {
                            Button { controller.togglePause() } label: { Label(session.isPaused ? "Resume" : controller.requiresChallenge(.pause) ? "Pause…" : "Pause", systemImage: session.isPaused ? "play.fill" : "pause.fill").frame(maxWidth: .infinity) }
                                .buttonStyle(.borderedProminent)
                        }
                        Button { confirmEnd = true } label: { Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    }
                    if session.phase != .focus { Button("Skip Break", action: controller.skipBreak).buttonStyle(.bordered).frame(maxWidth: .infinity) }
                }
            } else {
                Button { controller.start() } label: { Label("Start Focus", systemImage: "play.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
            }
            if let error = controller.error {
                Text(error).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if controller.nuclearLocked {
                Button("Emergency Exit (\(controller.emergencyRemaining) left)") { controller.requestExit(.stop) }
                    .buttonStyle(.bordered).disabled(controller.emergencyRemaining == 0)
            }
            Button { openWindow(id: "main"); NSApp.activate() } label: { Label("Open LockIn", systemImage: "arrow.up.forward.app").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
            HStack {
                Text("Today · \(Int(controller.today.reduce(0) { $0 + $1.actual }) / 60) min").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !controller.nuclearLocked { Button(controller.data.session == nil ? "Quit" : "Hide") { if controller.data.session != nil { NSApp.hide(nil) } else { NSApp.terminate(nil) } }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary) }
            }
        }.padding(20).frame(width: 340).tint(accent)
        .alert("Stop this session?", isPresented: $confirmEnd) {
            Button("Keep Going", role: .cancel) {}
            Button("Stop", role: .destructive, action: controller.end)
        } message: { Text("Complete any required exit check first. After confirmation, everything unlocks and Dock shortcuts return.") }
    }
}
