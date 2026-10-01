// LockIn 1.6.1: Combine must be imported directly for Timer.Autoconnect.
import SwiftUI
import Combine
import AppKit

struct ExitChallenge: Identifiable {
    let id = UUID()
    var progress: ExitProgress
    var nuclear: Bool
    let started = Date()
    var trialStarted = Date()
    var trial: FrictionTrial
    var completed = 0
    var passed = false
    var message = ""
    var flashAt = Double.random(in: 10...45)
    var flashSeen = false
    var target: Int { progress.kind == .flash ? 1 : progress.action == .pause ? 5 : nuclear ? 16 : 12 }
    var minimumDuration: Double { progress.kind == .flash ? 60 : progress.action == .pause ? 20 : nuclear ? 120 : 90 }
    init(progress: ExitProgress, nuclear: Bool) {
        self.progress = progress; self.nuclear = nuclear
        trial = FrictionTrial.make(progress.kind, easy: progress.action == .pause)
    }
    var responseLimit: Double {
        if progress.kind == .flash { return .infinity }
        if progress.kind == .nback { return 12 }
        if progress.kind == .sequence { return progress.action == .pause ? 22 : 18 }
        if progress.kind == .arithmetic { return progress.action == .pause ? 15 : nuclear ? 10 : 12 }
        return progress.action == .pause ? 8 : 5
    }
    func canAnswer(at date: Date) -> Bool {
        let elapsed = date.timeIntervalSince(trialStarted)
        return !passed && elapsed < responseLimit && elapsed >= (progress.kind == .flash ? 60 : progress.kind == .nback ? 6 : 1.5)
    }
    mutating func nextTrial(at date: Date) {
        trial = FrictionTrial.make(progress.kind, easy: progress.action == .pause); trialStarted = date
    }
}
@MainActor struct ExitChallengeView: View {
    @ObservedObject var controller: SessionController
    @Environment(\.dismissWindow) var dismissWindow
    @State private var input = ""
    @State private var now = Date()
    private let heartbeat = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let inks: [Color] = [.red, .blue, .green, .orange]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let challenge = controller.exitChallenge {
                HStack {
                    Text(challenge.progress.action == .pause ? "Pause Check" : challenge.nuclear ? "Emergency Exit" : "Stop Check").font(.title2.weight(.semibold))
                    Spacer()
                    Button("Keep Focusing") { controller.cancelChallenge() }
                }
                if challenge.nuclear { Text("\(controller.emergencyRemaining) of 2 emergency exits left this month. An exit is used only after you pass and confirm.").font(.callout).foregroundStyle(.secondary) }
                Text(challenge.progress.kind.title).font(.headline)
                Text(instructions(challenge)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if !challenge.message.isEmpty { Text(challenge.message).foregroundStyle(.orange).font(.callout) }
                if challenge.passed {
                    Label("Challenge passed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    let wait = max(0, Int(ceil(challenge.minimumDuration - now.timeIntervalSince(challenge.started))))
                    if wait > 0 { Text("Take a breath. Continue in \(wait) seconds.") }
                    Button(challenge.progress.action == .pause ? "Pause Session" : "End Session") { controller.completeChallenge(challenge.id) }
                        .buttonStyle(.borderedProminent).disabled(wait > 0)
                } else {
                    stimulus(challenge).frame(maxWidth: .infinity, minHeight: 110)
                        .padding(12).background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    if challenge.responseLimit.isFinite {
                        Text("\(max(0, Int(ceil(challenge.responseLimit - now.timeIntervalSince(challenge.trialStarted))))) seconds left")
                            .font(.headline.monospacedDigit()).foregroundStyle(.orange)
                    }
                    Text("Round \(challenge.completed + 1) of \(challenge.target)").font(.caption).foregroundStyle(.secondary)
                    if challenge.trial.choices.isEmpty {
                        TextField(challenge.progress.kind == .sequence ? "Numbers separated by spaces" : "Your answer", text: $input)
                            .textFieldStyle(.roundedBorder).onSubmit { submit(challenge, input) }
                        Button("Submit") { submit(challenge, input) }.buttonStyle(.borderedProminent)
                            .disabled(!challenge.canAnswer(at: now) || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        HStack {
                            ForEach(challenge.trial.choices, id: \.self) { choice in
                                Button(choice) { submit(challenge, choice) }.buttonStyle(.bordered).disabled(!challenge.canAnswer(at: now))
                            }
                        }
                    }
                    if challenge.progress.kind == .flash && now.timeIntervalSince(challenge.trialStarted) >= 60 && !challenge.flashSeen {
                        Text("The number wasn't shown while LockIn was active. Submit an answer to start a new attempt.").font(.caption).foregroundStyle(.orange)
                    }
                }
                Text("Focus continues until the check is passed and you confirm. These are attention checks, not clinical tests.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("This session has changed or ended.").foregroundStyle(.secondary)
                Button("Done") { controller.cancelChallenge() }
            }
        }.padding(26).frame(minWidth: 420, idealWidth: 500, minHeight: 440)
        .onReceive(heartbeat) { date in
            now = date
            if let c=controller.exitChallenge, !c.passed, date.timeIntervalSince(c.trialStarted) >= c.responseLimit, NSApp.isActive {
                controller.failChallenge(c.id, timeout: true)
            }
            if var c = controller.exitChallenge, c.progress.kind == .flash,
               date.timeIntervalSince(c.trialStarted) >= c.flashAt,
               date.timeIntervalSince(c.trialStarted) < c.flashAt + 1, NSApp.isActive, NSApp.keyWindow != nil {
                c.flashSeen = true; controller.exitChallenge = c
            }
        }
        .onChange(of: controller.exitChallenge?.id) { _, value in input = ""; if value == nil { dismissWindow(id: "exit-challenge") } }
    }
    private func submit(_ challenge: ExitChallenge, _ answer: String) {
        controller.submitChallenge(answer, id: challenge.id); input = ""
    }
    private func instructions(_ c: ExitChallenge) -> String {
        switch c.progress.kind {
        case .stroop: return "Choose the ink color. Ignore what the word says."
        case .flanker: return "Choose the direction of the center arrow. Ignore its neighbors."
        case .nback: return "Watch six digits, one each second. Decide whether the last digit matches the digit two steps before it."
        case .flash: return "Stay here for one minute. A three-digit number appears once for one second at a random time. Enter it when the minute ends."
        case .arithmetic: return "Work out the expression before the countdown ends. Multiplication comes first. A timeout fails the attempt."
        case .sequence: return "Enter the numbers from smallest to largest, separated by spaces."
        }
    }
    @ViewBuilder private func stimulus(_ c: ExitChallenge) -> some View {
        let elapsed = now.timeIntervalSince(c.trialStarted)
        if c.progress.kind == .flash {
            if elapsed >= c.flashAt && elapsed < c.flashAt + 1 && NSApp.isActive {
                Text(c.trial.answer).font(.system(size: 46, weight: .semibold, design: .monospaced))
            } else { Text(elapsed < 60 ? "Watch carefully · \(max(0, 60 - Int(elapsed)))s" : "Enter the number").font(.title3) }
        } else if c.progress.kind == .nback && elapsed < 6 {
            Text(c.trial.stream[min(5, max(0, Int(elapsed)))]).font(.system(size: 46, weight: .semibold, design: .monospaced))
        } else {
            Text(c.trial.prompt).font(.system(size: c.progress.kind == .stroop ? 42 : 24, weight: .semibold))
                .foregroundStyle(c.progress.kind == .stroop ? inks[c.trial.ink] : .primary)
                .multilineTextAlignment(.center)
        }
    }
}
