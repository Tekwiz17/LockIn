import Foundation

enum ActivityMode: String, Codable, CaseIterable, Identifiable {
    case focus, pomodoro
    var id: String { rawValue }
    var title: String { self == .focus ? "Focus" : "Pomodoro" }
}

enum RuleMode: String, Codable, CaseIterable, Identifiable {
    case block, onlyAllow
    var id: String { rawValue }
    var title: String { self == .block ? "Block" : "Only Allow" }
    var explanation: String { self == .block ? "Choose distractions to block. Everything else stays available." : "Choose what you need. Everything else stays locked until your break." }
}
enum Phase: String, Codable {
    case idle, focus, shortBreak, longBreak
    func next(completed: Int, every: Int) -> (phase: Phase, count: Int) {
        guard self == .focus else { return (.focus, completed) }
        let count = completed + 1
        return count >= max(1, every) ? (.longBreak, 0) : (.shortBreak, count)
    }
    var title: String {
        switch self { case .idle: return "Ready to Lock In?"; case .focus: return "Focus"; case .shortBreak: return "Short Break"; case .longBreak: return "Long Break" }
    }
}
struct AppRule: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var path: String
}
struct Preset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "New Preset"
    var focus = 25
    var shortBreak = 5
    var longBreak = 15
    var cycles = 4
    var mode = RuleMode.block
    var apps: [AppRule] = []
    var domains: [String] = []
    var autoStart = true
    var strict = false
    var nuclearEnabled: Bool?
    var exitFriction: Bool?
    var hideBlockedDockApps: Bool?
    var blockAI: Bool?
    var extraAIDomains: [String]?
    var savedActivityMode: ActivityMode?
    var savedIndefinite: Bool?
    func duration(_ phase: Phase) -> TimeInterval {
        TimeInterval((phase == .focus ? focus : phase == .longBreak ? longBreak : shortBreak) * 60)
    }
    static var defaults: [Preset] {
        [Preset(name: "Homework"), Preset(name: "Deep Work", focus: 50, shortBreak: 10, longBreak: 20, mode: .onlyAllow), Preset(name: "Quick Sprint", focus: 15, shortBreak: 5, longBreak: 10)]
    }
}
struct Session: Codable {
    var id = UUID()
    var presetID: UUID
    var phase = Phase.focus
    var startedAt: Date
    var endDate: Date?
    var pausedRemaining: TimeInterval?
    var waiting = false
    var completedInCycle = 0
    var planned: TimeInterval
    // Optional for compatibility with 1.0 session files. Consent applies to one Focus only.
    var exitFriction: Bool?
    var nuclear: Bool?
    var activityMode: ActivityMode?
    var indefinite: Bool?
    var accumulated: TimeInterval?
    var resumedAt: Date?
    var kind: ActivityMode { activityMode ?? .pomodoro }
    var isIndefinite: Bool { kind == .focus && indefinite == true }
    func nextPhase(every: Int) -> (phase: Phase, count: Int)? {
        kind == .pomodoro ? phase.next(completed: completedInCycle, every: every) : nil
    }
    func elapsed(at date: Date) -> TimeInterval {
        max(0, (accumulated ?? 0) + (isPaused ? 0 : date.timeIntervalSince(resumedAt ?? startedAt)))
    }
    func locksControls(at date: Date) -> Bool { nuclear == true && enforcing && remaining(at: date) > 0 }
    var isPaused: Bool { pausedRemaining != nil }
    func remaining(at now: Date) -> TimeInterval { max(0, pausedRemaining ?? endDate?.timeIntervalSince(now) ?? planned) }
    mutating func addTime(minutes: Int, at now: Date) -> Bool {
        guard (1...180).contains(minutes), !isIndefinite,
              waiting || isPaused || (endDate.map { $0 > now } ?? false) else { return false }
        let seconds=Double(minutes)*60
        planned += seconds
        if let paused=pausedRemaining { pausedRemaining=paused+seconds }
        else if let end=endDate { endDate=end.addingTimeInterval(seconds) }
        return true
    }
    var enforcing: Bool { phase == .focus && !isPaused && !waiting && (endDate != nil || isIndefinite) }
}
struct HistoryEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var preset: String
    var planned: TimeInterval
    var actual: TimeInterval
    var completed: Bool
    var mode: RuleMode
}
struct Preferences: Codable {
    var nuclearVerified: Bool?
    var requireNuclearAuthentication: Bool?
    var onboarded = false
    var neverApps: [AppRule] = []
    var neverDomains: [String] = []
    var notifyFocus = true
    var notifyShort = true
    var notifyLong = true
    var warnSoon = false
}
struct SavedState: Codable {
    var presets: [Preset] = []
    var selected: UUID?
    var custom: Preset? = Preset(name: "Custom")
    var useCustom: Bool? = true
    var schemaVersion: Int? = 2
    var activityMode: ActivityMode? = .pomodoro
    var indefiniteFocus: Bool? = false
    var session: Session?
    var history: [HistoryEntry] = []
    var preferences = Preferences()
    var revision: Int64 = 0
    var emergencyExits: EmergencyExitLedger?
    var exitProgress: ExitProgress?
    var installationID = UUID().uuidString
}
struct SyncState: Codable {
    var protocolVersion = 1
    var installationID: String
    var revision: Int64
    var sessionID: String?
    var sessionMode: String
    var isFocusActive: Bool
    var ruleMode: RuleMode
    var presetName: String
    var endDate: Double?
    var domains: [String]
    var neverBlockDomains: [String]
    var appCount: Int
    var indefinite: Bool?
    var activityMode: ActivityMode?
    var canPause: Bool?
    var canStop: Bool?
    var pauseRequiresChallenge: Bool?
    var stopRequiresChallenge: Bool?
    var nuclear: Bool?
    var emergencyExitsRemaining: Int?
    var remainingSeconds: Double?
    var elapsedSeconds: Double?
    var serverTime: Double?
    var blockAI: Bool?
    var extraAIDomains: [String]?
}
