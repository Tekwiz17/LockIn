import XCTest
@testable import LockInCore

final class CoreTests: XCTestCase {
    let app = AppRule(id: "com.example.app", name: "Example", path: "/Applications/Example.app")
    func testApplicationRuleModes() {
        XCTAssertFalse(FocusRuleEngine.allowsApp(app.id, active: true, mode: .block, selected: [app], never: []))
        XCTAssertTrue(FocusRuleEngine.allowsApp(app.id, active: true, mode: .block, selected: [], never: []))
        XCTAssertTrue(FocusRuleEngine.allowsApp(app.id, active: true, mode: .onlyAllow, selected: [app], never: []))
        XCTAssertFalse(FocusRuleEngine.allowsApp(app.id, active: true, mode: .onlyAllow, selected: [], never: []))
    }
    func testNeverBlockAndSafetyAlwaysWin() {
        for mode in RuleMode.allCases {
            XCTAssertTrue(FocusRuleEngine.allowsApp(app.id, active: true, mode: mode, selected: [app], never: [app]))
            XCTAssertTrue(FocusRuleEngine.allowsApp("com.apple.finder", active: true, mode: mode, selected: [], never: []))
            XCTAssertTrue(FocusRuleEngine.allowsApp("com.apple.SystemSettings", active: true, mode: mode, selected: [], never: []))
            XCTAssertTrue(FocusRuleEngine.allowsApp(app.id, active: false, mode: mode, selected: [app], never: []))
        }
    }
    func testDomainNormalizationAndBoundaries() {
        XCTAssertEqual(FocusRuleEngine.normalizeDomain(" https://YouTube.com:443/watch?v=2 "), "youtube.com")
        XCTAssertEqual(FocusRuleEngine.normalizeDomain("example.com."), "example.com")
        for bad in ["", "two words", "https://", "file:///tmp/a", "https://user:pass@example.com", "*.example.com", "a..com", "-a.com", "bücher.de", "example.com:99999"] { XCTAssertNil(FocusRuleEngine.normalizeDomain(bad), bad) }
        XCTAssertTrue(FocusRuleEngine.matches("m.youtube.com", "youtube.com"))
        XCTAssertFalse(FocusRuleEngine.matches("notyoutube.com", "youtube.com"))
        XCTAssertFalse(FocusRuleEngine.matches("youtube.com.evil.test", "youtube.com"))
        XCTAssertTrue(FocusRuleEngine.allowsDomain("school.youtube.com", active: true, mode: .block, selected: ["youtube.com"], never: ["school.youtube.com"]))
        XCTAssertFalse(FocusRuleEngine.allowsDomain("google.com", active: true, mode: .onlyAllow, selected: ["docs.google.com"], never: []))
    }
    func testWallClockPauseAndRecovery() throws {
        let start = Date(timeIntervalSince1970: 1000)
        var s = Session(presetID: UUID(), startedAt: start, endDate: start.addingTimeInterval(1500), planned: 1500)
        XCTAssertEqual(s.remaining(at: start.addingTimeInterval(90)), 1410)
        XCTAssertEqual(s.remaining(at: start.addingTimeInterval(9000)), 0)
        XCTAssertTrue(s.enforcing)
        s.pausedRemaining = 1410; s.endDate = nil
        XCTAssertFalse(s.enforcing)
        XCTAssertEqual(s.remaining(at: start.addingTimeInterval(9000)), 1410)
        let recovered = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(recovered.pausedRemaining, 1410)
        XCTAssertEqual(recovered.presetID, s.presetID)
        s.pausedRemaining = nil; s.waiting = true
        XCTAssertFalse(s.enforcing)
        s.waiting = false; s.phase = .shortBreak; s.endDate = start.addingTimeInterval(300)
        XCTAssertFalse(s.enforcing)
    }
    func testAddedTimeIsSavedWithoutResumingOrChangingSession() throws {
        let now=Date(timeIntervalSince1970:1000)
        var session=Session(presetID:UUID(), startedAt:now, endDate:now.addingTimeInterval(600), planned:600)
        session.nuclear=true
        let id=session.id
        XCTAssertTrue(session.addTime(minutes:5, at:now))
        XCTAssertEqual(session.endDate, now.addingTimeInterval(900))
        XCTAssertEqual(session.planned,900)
        XCTAssertEqual(session.id,id)
        session.pausedRemaining=120; session.endDate=nil
        XCTAssertTrue(session.addTime(minutes:2, at:now))
        XCTAssertEqual(session.pausedRemaining,240)
        XCTAssertNil(session.endDate)
        let saved=try JSONDecoder().decode(Session.self, from:JSONEncoder().encode(session))
        XCTAssertEqual(saved.pausedRemaining,240)
        session.pausedRemaining=nil; session.waiting=true
        XCTAssertTrue(session.addTime(minutes:1, at:now))
        session.waiting=false; session.endDate=now.addingTimeInterval(-1)
        XCTAssertFalse(session.addTime(minutes:1, at:now))
        session.activityMode = .focus; session.indefinite=true
        XCTAssertFalse(session.addTime(minutes:5, at:now))
        XCTAssertFalse(session.addTime(minutes:181, at:now))
    }
    func testLongBreakCadence() {
        XCTAssertEqual(Phase.focus.next(completed: 2, every: 4).phase, .shortBreak)
        XCTAssertEqual(Phase.focus.next(completed: 3, every: 4).phase, .longBreak)
        XCTAssertEqual(Phase.focus.next(completed: 3, every: 4).count, 0)
        XCTAssertEqual(Phase.longBreak.next(completed: 0, every: 4).phase, .focus)
        XCTAssertEqual(Phase.shortBreak.next(completed: 2, every: 4).count, 2)
    }
    func testFreshInstallStartsCustomWithoutPresets() throws {
        let state = SavedState()
        XCTAssertTrue(state.presets.isEmpty)
        XCTAssertEqual(state.custom?.name, "Custom")
        XCTAssertEqual(state.useCustom, true)
        let recovered = try JSONDecoder().decode(SavedState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(recovered.presets.isEmpty)
        XCTAssertEqual(recovered.custom, state.custom)
    }
    func testNuclearControlsLockOnlyDuringUnexpiredFocus() throws {
        let start = Date(timeIntervalSince1970: 1000)
        var session = Session(presetID: UUID(), startedAt: start, endDate: start.addingTimeInterval(60), planned: 60, nuclear: true)
        XCTAssertTrue(session.locksControls(at: start))
        XCTAssertTrue(session.locksControls(at: start.addingTimeInterval(59)))
        XCTAssertFalse(session.locksControls(at: start.addingTimeInterval(60)))
        let restored = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
        XCTAssertTrue(restored.locksControls(at: start))
        XCTAssertEqual(restored.endDate, session.endDate)
        session.phase = .shortBreak
        XCTAssertFalse(session.locksControls(at: start))
        session.phase = .focus; session.waiting = true
        XCTAssertFalse(session.locksControls(at: start))
        session.waiting = false; session.pausedRemaining = 60
        XCTAssertFalse(session.locksControls(at: start))
    }
    func testLegacySessionWithoutNuclearFieldDecodes() throws {
        let session = Session(presetID: UUID(), startedAt: Date(), endDate: Date().addingTimeInterval(60), planned: 60)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        object.removeValue(forKey: "nuclear")
        let recovered = try JSONDecoder().decode(Session.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(recovered.nuclear)
        XCTAssertFalse(recovered.locksControls(at: Date()))
    }
    func testLegacyStateMissingNewSetupFieldsDecodes() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(SavedState())) as? [String: Any])
        for key in ["custom", "useCustom", "schemaVersion"] { object.removeValue(forKey: key) }
        let recovered = try JSONDecoder().decode(SavedState.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(recovered.custom)
        XCTAssertNil(recovered.useCustom)
        XCTAssertNil(recovered.schemaVersion)
    }
    func testFocusAndPomodoroSessionIdentity() throws {
        let date = Date(timeIntervalSince1970: 1000)
        let legacy = Session(presetID: UUID(), startedAt: date, endDate: date.addingTimeInterval(60), planned: 60)
        XCTAssertEqual(legacy.kind, .pomodoro)
        XCTAssertEqual(legacy.nextPhase(every: 4)?.phase, .shortBreak)
        let focus = Session(presetID: UUID(), startedAt: date, endDate: date.addingTimeInterval(60), planned: 60, activityMode: .focus)
        let restored = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(focus))
        XCTAssertEqual(restored.kind, .focus)
        XCTAssertFalse(restored.isIndefinite)
        XCTAssertNil(restored.nextPhase(every: 4))
    }
    func testIndefiniteFocusEnforcementAndPausedElapsedTime() throws {
        let date = Date(timeIntervalSince1970: 1000)
        var session = Session(presetID: UUID(), startedAt: date, endDate: nil, planned: 0, activityMode: .focus, indefinite: true, resumedAt: date)
        XCTAssertTrue(session.enforcing)
        XCTAssertFalse(session.locksControls(at: date))
        XCTAssertEqual(session.elapsed(at: date.addingTimeInterval(60)), 60)
        session.accumulated = 60; session.pausedRemaining = 0
        XCTAssertFalse(session.enforcing)
        XCTAssertEqual(session.elapsed(at: date.addingTimeInterval(900)), 60)
        session.pausedRemaining = nil; session.resumedAt = date.addingTimeInterval(900)
        XCTAssertEqual(session.elapsed(at: date.addingTimeInterval(920)), 80)
        let restored = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored.elapsed(at: date.addingTimeInterval(930)), 90)
        XCTAssertTrue(restored.enforcing)
    }
    func testSavedStateAndSyncRoundTrip() throws {
        var data = SavedState(); data.presets = [Preset(name: "My Study")]; data.revision = 421; data.selected = data.presets[0].id
        let decoded = try JSONDecoder().decode(SavedState.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(decoded.revision, 421); XCTAssertEqual(decoded.presets, data.presets)
        let wire = SyncState(installationID: data.installationID, revision: 421, sessionMode: "focus", isFocusActive: true, ruleMode: .onlyAllow, presetName: "Homework", endDate: 1_800_000_000_000, domains: ["docs.google.com"], neverBlockDomains: [], appCount: 2)
        let result = try JSONDecoder().decode(SyncState.self, from: JSONEncoder().encode(wire))
        XCTAssertEqual(result.endDate, wire.endDate); XCTAssertEqual(result.ruleMode, .onlyAllow)
    }
    func testLegacyPresetAndAISetupRoundTrip() throws {
        let legacy = Preset(name: "Existing")
        let recovered = try JSONDecoder().decode(Preset.self, from: JSONEncoder().encode(legacy))
        XCTAssertNil(recovered.blockAI)
        XCTAssertNil(recovered.extraAIDomains)
        XCTAssertNil(recovered.savedActivityMode)
        XCTAssertNil(recovered.savedIndefinite)
        var custom = recovered
        custom.blockAI = true; custom.extraAIDomains = ["my-ai.example.com"]
        custom.savedActivityMode = .focus; custom.savedIndefinite = true
        let restored = try JSONDecoder().decode(Preset.self, from: JSONEncoder().encode(custom))
        XCTAssertEqual(restored, custom)
        XCTAssertEqual(restored.blockAI, true)
        XCTAssertEqual(restored.savedActivityMode, .focus)
        XCTAssertEqual(restored.savedIndefinite, true)
        var duplicate = restored; duplicate.id = UUID(); duplicate.name = "Copy"
        duplicate.domains.append("example.com")
        XCTAssertNotEqual(duplicate.id, restored.id)
        XCTAssertTrue(restored.domains.isEmpty)
        XCTAssertEqual(duplicate.extraAIDomains, restored.extraAIDomains)
    }

    private func dockTiles(_ keys: [String]) -> [DockTile] { keys.map { DockTile(key: $0, payload: Data($0.utf8)) } }
    func testDockExactOrderAndMetadataRecoveryAfterCrash() throws {
        let original = dockTiles(["A", "B", "C", "D", "E"])
        let journal = DockJournal(original: original, removed: ["A", "C", "D"], deadline: Date())
        let persisted = try JSONDecoder().decode(DockJournal.self, from: JSONEncoder().encode(journal))
        let restored = DockLayout.restore(current: dockTiles(["B", "E"]), journal: persisted)
        XCTAssertEqual(restored, original)
        XCTAssertEqual(DockLayout.restore(current: restored, journal: persisted), original)
    }
    func testDockRecoveryPreservesUserAdditionsAndDeletions() {
        let journal = DockJournal(original: dockTiles(["A", "B", "C", "D"]), removed: ["B"], deadline: Date())
        // C was explicitly unpinned during Focus; X was newly pinned. Neither is undone.
        let restored = DockLayout.restore(current: dockTiles(["X", "A", "D"]), journal: journal)
        XCTAssertEqual(restored.map(\.key), ["X", "A", "B", "D"])
    }
    func testDockRecoveryAllRemovedAndNoDuplicateTiles() {
        let original = dockTiles(["A", "B", "C"])
        let journal = DockJournal(original: original, removed: ["A", "B", "C"], deadline: Date())
        XCTAssertEqual(DockLayout.restore(current: [], journal: journal), original)
        // The user already re-pinned B; retain it once with its current metadata.
        let current = [DockTile(key: "B", payload: Data("new metadata".utf8))]
        let recovered = DockLayout.restore(current: current, journal: journal)
        XCTAssertEqual(recovered.map(\.key), ["A", "B", "C"])
        XCTAssertEqual(recovered[1], current[0])
    }
    func testLegacyDockToggleDefaultsOffAndPresetRoundTrip() throws {
        let original = Preset(name: "Legacy")
        let legacy = try JSONDecoder().decode(Preset.self, from: JSONEncoder().encode(original))
        XCTAssertNil(legacy.hideBlockedDockApps)
        var enabled = legacy; enabled.hideBlockedDockApps = true
        XCTAssertEqual(try JSONDecoder().decode(Preset.self, from: JSONEncoder().encode(enabled)), enabled)
    }

    func testEmergencyQuotaPersistenceAndCalendarMonthReset() throws {
        let formatter = ISO8601DateFormatter()
        let september = try XCTUnwrap(formatter.date(from: "2026-09-30T23:59:00Z"))
        let october = try XCTUnwrap(formatter.date(from: "2026-10-01T00:00:00Z"))
        var ledger = EmergencyExitLedger(timeZoneID: "UTC")
        XCTAssertEqual(ledger.remaining(at: september), 2)
        XCTAssertTrue(ledger.consume(at: september)); XCTAssertTrue(ledger.consume(at: september))
        XCTAssertFalse(ledger.consume(at: september))
        let restored = try JSONDecoder().decode(EmergencyExitLedger.self, from: JSONEncoder().encode(ledger))
        XCTAssertEqual(restored.remaining(at: september), 0)
        XCTAssertEqual(restored.remaining(at: october), 2)
    }
    func testEasierPausePoolAndTwoBackTrialCorrectness() {
        for _ in 0..<100 {
            let easy = FrictionKind.pick(easy: true)
            XCTAssertNotEqual(easy, .flash); XCTAssertNotEqual(easy, .nback)
            XCTAssertNotEqual(FrictionKind.pick(easy: false, excluding: .stroop), .stroop)
            let trial = FrictionTrial.make(.nback, easy: false)
            XCTAssertEqual(trial.stream.count, 6)
            XCTAssertEqual(trial.answer, trial.stream[5] == trial.stream[3] ? "Same" : "Different")
        }
    }
    func testFrictionAnswerNormalizationAndLegacyFields() throws {
        let trial = FrictionTrial(prompt: "Order", answer: "1 4 8", choices: [])
        XCTAssertTrue(trial.accepts(" 1, 4, 8 "))
        XCTAssertFalse(trial.accepts("8 4 1"))
        XCTAssertTrue(FrictionTrial(prompt: "Color", answer: "Red", choices: []).accepts(" red "))
        let legacy = try JSONDecoder().decode(SavedState.self, from: JSONEncoder().encode(SavedState()))
        XCTAssertNil(legacy.emergencyExits); XCTAssertNil(legacy.exitProgress)
        XCTAssertNil(legacy.custom?.exitFriction)
        var saved = legacy
        saved.exitProgress = ExitProgress(sessionID: UUID(), action: .stop, kind: .flanker, failures: 1)
        let restored = try JSONDecoder().decode(SavedState.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(restored.exitProgress?.failures, 1)
        XCTAssertEqual(restored.exitProgress?.kind, .flanker)
    }

}
