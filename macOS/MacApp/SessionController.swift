import SwiftUI
import UserNotifications
import AppKit

@MainActor final class SessionController: ObservableObject {
    @Published var data: SavedState
    @Published var now = Date()
    @Published var authenticating = false
    @Published var error: String?
    @Published var exitChallenge: ExitChallenge?
    var onShowChallenge: (() -> Void)?
    var onChange: (() -> Void)?
    private var quitAfterExit = false
    private var timer: Timer?
    private var lastHeartbeat = Date.distantPast
    private var warnedID: String?
    private let file: URL
    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LockIn", isDirectory: true)
        file = dir.appendingPathComponent("state.json")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) {
                data = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: file))
            } else { data = SavedState() }
        } catch {
            data = SavedState()
            self.error = "LockIn couldn't read its saved data. A fresh session is available. Your old file has been kept as state-recovery.json."
            try? FileManager.default.copyItem(at: file, to: dir.appendingPathComponent("state-recovery.json"))
        }
        let migrating = data.schemaVersion == nil
        if migrating {
            // Remove untouched shipped examples, preserving edited/user-created presets and active rules.
            let shipped = Preset.defaults
            data.presets.removeAll { p in
                guard data.session?.presetID != p.id else { return false }
                return shipped.contains { example in var copy = p; copy.id = example.id; return copy == example }
            }
            data.schemaVersion = 2
        }
        if data.custom == nil { data.custom = Preset(name: "Custom") }
        if data.presets.isEmpty { data.useCustom = true; data.selected = nil }
        if data.useCustom == true {
            if data.custom?.savedActivityMode == nil { data.custom?.savedActivityMode = data.activityMode ?? .pomodoro }
            if data.custom?.savedIndefinite == nil { data.custom?.savedIndefinite = data.indefiniteFocus ?? false }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        tick()
        if migrating { changed() }
    }
    var preset: Preset {
        if let id = data.session?.presetID {
            if let custom = data.custom, custom.id == id { return custom }
            return data.presets.first { $0.id == id } ?? data.custom ?? Preset(name: "Custom")
        }
        if data.useCustom == true, let custom = data.custom { return custom }
        return data.presets.first { $0.id == data.selected } ?? data.custom ?? Preset(name: "Custom")
    }
    var activityMode: ActivityMode { data.session?.kind ?? data.activityMode ?? .pomodoro }
    var indefinite: Bool { data.session?.isIndefinite ?? (activityMode == .focus && data.indefiniteFocus == true) }
    func selectMode(_ mode: ActivityMode) {
        guard data.session == nil else { return }
        data.activityMode = mode
        if data.useCustom == true { data.custom?.savedActivityMode = mode }
        changed()
    }
    func setIndefinite(_ value: Bool) {
        guard data.session == nil else { return }
        data.indefiniteFocus = value
        if data.useCustom == true { data.custom?.savedIndefinite = value }
        changed()
    }
    var nuclearLocked: Bool { data.session?.locksControls(at: Date()) == true }
    func selectCustom(_ custom: Bool) {
        guard data.session == nil else { return }
        if custom && data.custom == nil {
            var draft = preset; draft.id = UUID(); draft.name = "Custom"; data.custom = draft
        }
        data.useCustom = custom || data.presets.isEmpty
        if data.useCustom == true {
            data.activityMode = data.custom?.savedActivityMode ?? .pomodoro
            data.indefiniteFocus = data.custom?.savedIndefinite ?? false
        } else if let p = data.presets.first(where: { $0.id == data.selected }) ?? data.presets.first {
            data.selected = p.id
            data.activityMode = p.savedActivityMode ?? .pomodoro
            data.indefiniteFocus = p.savedIndefinite ?? false
        }
        changed()
    }
    func selectPreset(_ id: UUID) {
        guard data.session == nil else { return }
        data.selected = id; data.useCustom = false
        if let p = data.presets.first(where: { $0.id == id }) {
            data.activityMode = p.savedActivityMode ?? .pomodoro
            data.indefiniteFocus = p.savedIndefinite ?? false
        }
        changed()
    }
    func saveCustomAsPreset(name: String) {
        guard data.session == nil else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var p = currentSetup; p.id = UUID(); p.name = name
        data.presets.append(p); data.selected = p.id
        changed()
    }
    func deletePreset(_ id: UUID) {
        guard !nuclearLocked, data.session?.presetID != id else { return }
        data.presets.removeAll { $0.id == id }
        if data.selected == id { data.selected = data.presets.first?.id }
        if data.presets.isEmpty { data.useCustom = true }
        if data.session == nil {
            let p = data.useCustom == true ? data.custom : data.presets.first(where: { $0.id == data.selected })
            data.activityMode = p?.savedActivityMode ?? .pomodoro
            data.indefiniteFocus = p?.savedIndefinite ?? false
        }
        changed()
    }
    var currentSetup: Preset {
        var p = preset; p.savedActivityMode = activityMode; p.savedIndefinite = indefinite; return p
    }
    func setBlockAI(_ enabled: Bool) {
        guard !nuclearLocked else { return }
        var p = currentSetup; p.blockAI = enabled
        if data.custom?.id == p.id { updateCustom(p) } else { update(p) }
    }
    func renamePreset(_ id: UUID, name: String) {
        guard !nuclearLocked, let index = data.presets.firstIndex(where: { $0.id == id }) else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        data.presets[index].name = name; changed()
    }
    func duplicatePreset(_ id: UUID) {
        guard !nuclearLocked, var p = data.presets.first(where: { $0.id == id }) else { return }
        p.id = UUID(); p.name += " Copy"; data.presets.append(p); changed()
    }
    func replacePresetWithCurrent(_ id: UUID) {
        guard !nuclearLocked, let index = data.presets.firstIndex(where: { $0.id == id }) else { return }
        var p = currentSetup; p.id = id; p.name = data.presets[index].name
        data.presets[index] = p; changed()
    }
    func updateCustom(_ p: Preset) {
        if p.nuclearEnabled == true && data.preferences.nuclearVerified != true {
            verifyFirstNuclear { self.applyCustom(p) }; return
        }
        applyCustom(p)
    }
    private func applyCustom(_ p: Preset) {
        guard !nuclearLocked else { return }
        var p = p; p.name = "Custom"; data.custom = p
        if data.session == nil && data.useCustom == true {
            if let mode = p.savedActivityMode { data.activityMode = mode }
            if let value = p.savedIndefinite { data.indefiniteFocus = value }
        }
        changed()
    }
    var remaining: TimeInterval { data.session?.remaining(at: now) ?? preset.duration(.focus) }
    var clock: String { let n = indefinite ? Int(data.session?.elapsed(at: now) ?? 0) : Int(ceil(remaining)); return String(format: "%02d:%02d", n / 60, n % 60) }
    var active: Bool { data.session?.enforcing == true && (indefinite || remaining > 0) }
    var title: String { guard let s = data.session else { return "Ready to Lock In?" }; return s.waiting ? "Ready for \(s.phase.title)?" : s.isPaused ? "Paused" : s.phase.title }
    var today: [HistoryEntry] { data.history.filter { Calendar.current.isDateInToday($0.date) } }
    func changed() {
        data.revision += 1
        do { try JSONEncoder().encode(data).write(to: file, options: .atomic) }
        catch { self.error = "Your latest changes couldn't be saved. Check available disk space." }
        onChange?()
    }
    func tick() {
        now = Date()
        if let s = data.session, !s.isPaused, !s.waiting, let end = s.endDate, end <= now {
            // One transition at wake/relaunch. Never invent sessions completed while asleep.
            finishPhase(at: end)
        }
        if exitChallenge?.progress.sessionID != data.session?.id { exitChallenge = nil }
        if active && indefinite && now.timeIntervalSince(lastHeartbeat) >= 30 { lastHeartbeat = now; changed() }
        if let s = data.session, !s.isIndefinite, !s.waiting, !s.isPaused, remaining > 0, remaining <= 60, data.preferences.warnSoon {
            let key = "\(s.id)-\(s.phase)-\(s.startedAt)"
            if warnedID != key { warnedID = key; notify("One minute left", body: "Your \(s.phase.title.lowercased()) is ending soon.") }
        }
    }
    func start() {
        guard data.session == nil, !authenticating else { return }
        if preset.nuclearEnabled == true && !indefinite {
            let alert = NSAlert(); alert.messageText = "Start Nuclear Focus?"
            alert.informativeText = "No pause or rule edits. Early ending requires a check and one of two monthly emergency exits. Focus lasts \(preset.focus) minutes."
            alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Start Nuclear Focus")
            if alert.runModal() == .alertSecondButtonReturn { startNuclear() }; return
        }
        let p = preset
        let date = Date(), unlimited = indefinite, mode = activityMode
        data.session = Session(presetID: p.id, startedAt: date, endDate: unlimited ? nil : date.addingTimeInterval(p.duration(.focus)), planned: unlimited ? 0 : p.duration(.focus), exitFriction: !unlimited && p.exitFriction == true, activityMode: mode, indefinite: unlimited, resumedAt: date)
        now = Date(); changed(); phaseNotification()
    }
    func startNuclear() {
        guard data.session == nil, !indefinite, !authenticating else { return }
        if data.preferences.nuclearVerified != true { verifyFirstNuclear { self.beginNuclear() }; return }
        if data.preferences.requireNuclearAuthentication != false {
            authenticating = true
            Task { @MainActor in
                defer { authenticating = false }
                do { try await MacAuthentication.verify(); beginNuclear() }
                catch { self.error = "Nuclear Mode wasn't started: \(error.localizedDescription)" }
            }
        } else { beginNuclear() }
    }
    private func beginNuclear() {
        guard data.session == nil, !indefinite else { return }
        let previous = data
        let start = Date(), duration = preset.duration(.focus)
        let deadline = start.addingTimeInterval(duration)
        data.session = Session(presetID: preset.id, startedAt: start, endDate: deadline, planned: duration, exitFriction: true, nuclear: true, activityMode: activityMode)
        do {
            // Persist before installing: the watchdog must never recover an uncommitted session.
            data.revision += 1
            try JSONEncoder().encode(data).write(to: file, options: .atomic)
            try NuclearWatchdog.install(until: deadline)
            now = Date(); onChange?(); phaseNotification()
        } catch {
            data = previous
            NuclearWatchdog.remove()
            changed()
            self.error = "Nuclear Mode couldn't start: \(error.localizedDescription). No locked Focus was started."
        }
    }
    func togglePause() {
        tick()
        if data.session?.isPaused == false && requiresChallenge(.pause) { requestExit(.pause); return }
        performPause()
    }
    private func performPause() {
        tick()
        guard !nuclearLocked else { return }
        guard var s = data.session, !s.waiting else { return }
        if s.isIndefinite {
            if s.isPaused { s.pausedRemaining = nil; s.resumedAt = Date() }
            else { s.accumulated = s.elapsed(at: Date()); s.pausedRemaining = 0 }
            data.session = s; now = Date(); changed(); return
        }
        if let paused = s.pausedRemaining { s.endDate = Date().addingTimeInterval(paused); s.pausedRemaining = nil }
        else { s.pausedRemaining = s.remaining(at: Date()); s.endDate = nil }
        data.session = s; now = Date(); changed()
    }
    func addTime(minutes: Int) {
        tick()
        guard let session=data.session, !session.isIndefinite, (1...180).contains(minutes), !authenticating else { return }
        let id=session.id; let phase=session.phase; let started=session.startedAt
        if nuclearLocked && data.preferences.requireNuclearAuthentication != false {
            authenticating=true
            Task { @MainActor in
                defer { authenticating=false }
                do { try await MacAuthentication.verify(); applyAddedTime(minutes:minutes, sessionID:id, phase:phase, started:started) }
                catch { self.error="Time wasn't added: \(error.localizedDescription)" }
            }
        } else { applyAddedTime(minutes:minutes, sessionID:id, phase:phase, started:started) }
    }
    private func applyAddedTime(minutes: Int, sessionID: UUID, phase: Phase, started: Date) {
        tick()
        guard var session=data.session, session.id==sessionID, session.phase==phase, session.startedAt==started, !session.isIndefinite else { return }
        let previous=data
        guard session.addTime(minutes:minutes, at:Date()) else { return }
        data.session=session; data.revision += 1
        do {
            try JSONEncoder().encode(data).write(to:file,options:.atomic)
            if session.nuclear == true, let end=session.endDate { try NuclearWatchdog.install(until:end) }
            now=Date(); onChange?()
        } catch {
            data=previous
            try? JSONEncoder().encode(previous).write(to:file,options:.atomic)
            if previous.session?.nuclear == true, let end=previous.session?.endDate { try? NuclearWatchdog.install(until:end) }
            self.error="Time couldn't be saved: \(error.localizedDescription)"
        }
    }
    func startWaiting() {
        guard var s = data.session, s.waiting else { return }
        s.waiting = false; s.startedAt = Date(); s.endDate = Date().addingTimeInterval(s.planned)
        data.session = s; now = Date(); changed(); phaseNotification()
    }
    func quitPermanently() {
        guard data.session == nil else { error="End the session before quitting LockIn."; return }
        quitAfterExit=true
        end()
    }
    private func finishPendingQuit() {
        guard quitAfterExit, data.session==nil else{return}
        quitAfterExit=false
        NSApp.terminate(nil)
    }
    func end() {
        tick()
        if requiresChallenge(.stop) { requestExit(.stop); return }
        finishRequestedExit()
    }
    private func finishRequestedExit() {
        if let s = data.session, s.phase == .focus, !s.waiting { record(s, completed: s.isIndefinite, at: Date()) }
        NuclearWatchdog.remove()
        data.session = nil; data.exitProgress = nil; exitChallenge = nil; changed(); finishPendingQuit()
    }
    func skipBreak() {
        guard let s = data.session, s.phase != .focus else { return }
        transition(to: .focus, count: s.completedInCycle, forceStart: true)
    }
    private func record(_ s: Session, completed: Bool, at date: Date) {
        data.history.append(HistoryEntry(date: date, preset: preset.name, planned: s.planned, actual: s.isIndefinite ? s.elapsed(at: date) : completed ? s.planned : max(0, s.planned - s.remaining(at: date)), completed: completed, mode: preset.mode))
    }
    private func finishPhase(at date: Date) {
        guard let s = data.session else { return }
        if s.nuclear == true { NuclearWatchdog.remove() }
        if s.phase == .focus { record(s, completed: true, at: date) }
        guard let next = s.nextPhase(every: preset.cycles) else {
            data.session = nil; now = Date(); changed()
            notify("Focus complete", body: "Everything is unlocked. Nice work.")
            return
        }
        transition(to: next.phase, count: next.count)
    }
    private func transition(to phase: Phase, count: Int, forceStart: Bool = false) {
        let p = preset; let duration = p.duration(phase)
        // Nuclear consent ends at the deadline. A new Focus always needs a new decision.
        let running = data.session?.nuclear == true ? false : (forceStart || p.autoStart)
        data.session = Session(presetID: p.id, phase: phase, startedAt: Date(), endDate: running ? Date().addingTimeInterval(duration) : nil, waiting: !running, completedInCycle: count, planned: duration, exitFriction: p.exitFriction == true, activityMode: .pomodoro)
        now = Date(); changed()
        if running { phaseNotification() }
        else { notify("Ready for \(phase.title)?", body: "Open LockIn when you're ready. Everything is unlocked.") }
    }
    func update(_ p: Preset) {
        if p.nuclearEnabled == true && data.preferences.nuclearVerified != true {
            verifyFirstNuclear { self.applyPreset(p) }; return
        }
        applyPreset(p)
    }
    private func applyPreset(_ p: Preset) {
        guard !nuclearLocked else { return }
        if let i = data.presets.firstIndex(where: { $0.id == p.id }) { data.presets[i] = p }
        else { data.presets.append(p) }
        if data.session == nil && data.useCustom != true && data.selected == p.id {
            if let mode = p.savedActivityMode { data.activityMode = mode }
            if let value = p.savedIndefinite { data.indefiniteFocus = value }
        }
        changed()
    }
    var emergencyRemaining: Int { data.emergencyExits?.remaining(at: Date()) ?? 2 }
    func requiresChallenge(_ action: ExitAction) -> Bool {
        guard let s = data.session, s.phase == .focus, !s.waiting, !s.isIndefinite else { return false }
        if s.nuclear == true { return action == .stop && nuclearLocked }
        return s.exitFriction == true && (action == .stop || !s.isPaused)
    }
    func requestExit(_ action: ExitAction) {
        tick()
        guard let session = data.session else { return }
        guard action != .pause || !nuclearLocked else { return }
        if !requiresChallenge(action) {
            if action == .pause { performPause() } else { finishRequestedExit() }; return
        }
        guard !nuclearLocked || emergencyRemaining > 0 else { error = "Both Nuclear emergency exits have been used this month."; return }
        if exitChallenge != nil { onShowChallenge?(); return }
        if data.exitProgress?.sessionID != session.id || data.exitProgress?.action != action {
            data.exitProgress = ExitProgress(sessionID: session.id, action: action, kind: FrictionKind.pick(easy: action == .pause))
        }
        changed()
        if let progress = data.exitProgress { exitChallenge = ExitChallenge(progress: progress, nuclear: nuclearLocked) }
        onShowChallenge?()
    }
    func submitChallenge(_ input: String, id: UUID, at instant: Date = Date()) {
        tick()
        guard var challenge = exitChallenge, challenge.id == id,
              data.session?.id == challenge.progress.sessionID, challenge.canAnswer(at: instant),
              data.exitProgress != nil else { return }
        if challenge.trial.accepts(input) && (challenge.progress.kind != .flash || challenge.flashSeen) {
            challenge.completed += 1
            if challenge.completed >= challenge.target {
                challenge.passed = true; exitChallenge = challenge
            } else { challenge.nextTrial(at: instant); exitChallenge = challenge }
        } else { failChallenge(id) }
    }
    func failChallenge(_ id: UUID, timeout: Bool = false) {
        guard let challenge = exitChallenge, challenge.id == id,
              data.session?.id == challenge.progress.sessionID,
              var progress = data.exitProgress else { return }
            progress.failures += 1
            if progress.failures >= 2 { progress.kind = FrictionKind.pick(easy: progress.action == .pause, excluding: progress.kind); progress.failures = 0 }
            data.exitProgress = progress; changed()
            var retry = ExitChallenge(progress: progress, nuclear: nuclearLocked)
            retry.message = progress.kind == challenge.progress.kind ? "That answer wasn't correct. Try a fresh round." : "Two failed attempts. A different task has been chosen."
            if timeout { retry.message = "Time ran out. " + retry.message }
            exitChallenge = retry
    }
    func completeChallenge(_ id: UUID) {
        tick()
        guard let challenge = exitChallenge, challenge.id == id, challenge.passed,
              Date().timeIntervalSince(challenge.started) >= challenge.minimumDuration,
              data.session?.id == challenge.progress.sessionID else { return }
        if challenge.progress.action == .stop && nuclearLocked {
            // Charge and end in one atomic state write. Failure leaves the session and quota intact.
            let previous = data
            var ledger = data.emergencyExits ?? EmergencyExitLedger(timeZoneID: TimeZone.current.identifier)
            guard ledger.consume(at: Date()) else { error = "No Nuclear emergency exits remain this month."; return }
            data.emergencyExits = ledger
            if let s = data.session { record(s, completed: false, at: Date()) }
            data.session = nil; data.exitProgress = nil; data.revision += 1
            do { try JSONEncoder().encode(data).write(to: file, options: .atomic) }
            catch { data = previous; self.error = "The emergency exit couldn't be saved. Your exit allowance is unchanged."; return }
            exitChallenge = nil; NuclearWatchdog.remove(); onChange?(); finishPendingQuit()
        } else {
            let action = challenge.progress.action
            exitChallenge = nil; data.exitProgress = nil
            if action == .pause { performPause() } else { finishRequestedExit() }
        }
    }
    func cancelChallenge() { exitChallenge = nil; quitAfterExit=false } // Persist task/failures; cancellation cannot choose a different task.
    func setNuclearEnabled(_ enabled: Bool) {
        guard data.session == nil, !indefinite else { return }
        var p = currentSetup; p.nuclearEnabled = enabled
        if data.custom?.id == p.id { updateCustom(p) } else { update(p) }
    }
    private func verifyFirstNuclear(_ completion: @escaping @MainActor () -> Void) {
        guard data.session == nil, !authenticating else { return }
        authenticating = true
        Task { @MainActor in
            defer { authenticating = false }
            do {
                try await MacAuthentication.verify()
                guard data.session == nil else { return }
                data.preferences.requireNuclearAuthentication = MacAuthentication.askFutureAuthentication()
                data.preferences.nuclearVerified = true; changed(); completion()
            } catch { self.error = "Nuclear Mode wasn't enabled: \(error.localizedDescription)" }
        }
    }
    func setNuclearAuthentication(_ enabled: Bool) {
        guard !nuclearLocked, !authenticating else { return }
        authenticating = true
        Task { @MainActor in
            defer { authenticating = false }
            do {
                try await MacAuthentication.verify()
                guard !nuclearLocked else { return }
                data.preferences.requireNuclearAuthentication = enabled; changed()
            } catch { self.error = "Authentication preference wasn't changed: \(error.localizedDescription)" }
        }
    }
    func requestNotifications() { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
    private func phaseNotification() {
        guard let phase = data.session?.phase else { return }
        let pref = data.preferences
        guard (phase == .focus && pref.notifyFocus) || (phase == .shortBreak && pref.notifyShort) || (phase == .longBreak && pref.notifyLong) else { return }
        notify(phase.title, body: phase == .focus ? "Your focus rules are active. Stay with it." : "Everything is unlocked. Enjoy your break.")
    }
    private func notify(_ title: String, body: String) {
        let content = UNMutableNotificationContent(); content.title = title; content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
    func syncState() -> SyncState {
        SyncState(installationID: data.installationID, revision: data.revision, sessionID: data.session?.id.uuidString, sessionMode: data.session?.isPaused == true ? "paused" : data.session?.waiting == true ? "waiting" : data.session?.phase.rawValue ?? "idle", isFocusActive: active, ruleMode: preset.mode, presetName: preset.name, endDate: active && indefinite ? Date().addingTimeInterval(90).timeIntervalSince1970 * 1000 : data.session?.endDate.map { $0.timeIntervalSince1970 * 1000 }, domains: preset.domains, neverBlockDomains: data.preferences.neverDomains, appCount: preset.apps.count, indefinite: indefinite, activityMode: activityMode, canPause: data.session != nil && data.session?.waiting == false && !nuclearLocked, canStop: data.session != nil && (!nuclearLocked || emergencyRemaining > 0), pauseRequiresChallenge: requiresChallenge(.pause), stopRequiresChallenge: requiresChallenge(.stop), nuclear: nuclearLocked, emergencyExitsRemaining: emergencyRemaining, remainingSeconds: remaining, elapsedSeconds: data.session?.elapsed(at: Date()), serverTime: Date().timeIntervalSince1970 * 1000, blockAI: preset.blockAI == true, extraAIDomains: preset.extraAIDomains ?? [])
    }
}
