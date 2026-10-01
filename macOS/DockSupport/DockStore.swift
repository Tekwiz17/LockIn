import Foundation
import CoreFoundation
import Darwin

/// Shared by the app and its small, headless recovery executable.
/// Lock serializes journal + preferences operations across both processes.
enum DockStore {
    static let domain = "com.apple.dock" as CFString
    static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LockIn")
    static let snapshot = directory.appendingPathComponent("dock-snapshot.json")
    static func locked<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fd = open(directory.appendingPathComponent("dock.lock").path, O_CREAT | O_RDWR, mode_t(0o600))
        guard fd >= 0 else { throw failure("Couldn't open the Dock recovery lock.") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw failure("Couldn't lock Dock recovery.") }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }
    static func failure(_ message: String) -> NSError { NSError(domain: "LockInDock", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    static func readJournal() throws -> DockJournal? {
        guard FileManager.default.fileExists(atPath: snapshot.path) else { return nil }
        let journal = try JSONDecoder().decode(DockJournal.self, from: Data(contentsOf: snapshot))
        guard journal.version == 1, journal.deadline.timeIntervalSince1970.isFinite,
              Set(journal.original.map(\.key)).count == journal.original.count,
              journal.removed.isSubset(of: Set(journal.original.map(\.key))) else { throw failure("The saved Dock snapshot needs manual recovery; it has been kept.") }
        return journal
    }
    static func save(_ journal: DockJournal) throws {
        try JSONEncoder().encode(journal).write(to: snapshot, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: snapshot.path)
    }
    static func preferences() throws -> [DockTile] {
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { throw failure("Couldn't read Dock preferences.") }
        if CFPreferencesAppValueIsForced("persistent-apps" as CFString, domain) {
            throw failure("This Dock layout is managed by your organization.")
        }
        if CFPreferencesCopyValue("static-only" as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Bool == true {
            throw failure("This Dock is managed by your organization.")
        }
        guard let values = CFPreferencesCopyValue("persistent-apps" as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [[String: Any]] else {
            throw failure("Dock shortcuts aren't available yet. Open the Dock and try again.")
        }
        let tiles = try values.map { tile -> DockTile in
            // Missing/duplicate GUIDs are refused rather than guessing identities.
            guard let guid = tile["GUID"] as? NSNumber else { throw failure("This Dock layout has an unsupported shortcut. No items were changed.") }
            return DockTile(key: guid.stringValue, payload: try PropertyListSerialization.data(fromPropertyList: tile, format: .binary, options: 0))
        }
        guard Set(tiles.map(\.key)).count == tiles.count else { throw failure("Dock shortcut IDs aren't unique. No items were changed.") }
        return tiles
    }
    static func dictionary(_ tile: DockTile) throws -> [String: Any] {
        guard let value = try PropertyListSerialization.propertyList(from: tile.payload, options: [], format: nil) as? [String: Any] else { throw failure("Invalid saved Dock shortcut.") }
        return value
    }
    static func appID(_ tile: DockTile) throws -> String? {
        let dictionary = try dictionary(tile)
        guard dictionary["tile-type"] as? String == "file-tile", let data = dictionary["tile-data"] as? [String: Any] else { return nil }
        if let id = data["bundle-identifier"] as? String { return id }
        if let file = data["file-data"] as? [String: Any], let path = file["_CFURLString"] as? String {
            let url = path.hasPrefix("file:") ? URL(string: path) : URL(fileURLWithPath: path)
            if let url, url.pathExtension == "app" { return Bundle(url: url)?.bundleIdentifier }
        }
        return nil // Preserve unknown tiles, spacers and non-app shortcuts.
    }
    static func write(_ tiles: [DockTile]) throws {
        let values = try tiles.map(dictionary)
        CFPreferencesSetValue("persistent-apps" as CFString, values as CFArray, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { throw failure("Couldn't save Dock changes. The recovery snapshot has been kept.") }
        // Restart only this user's Dock; no sudo, no other apps or preferences touched.
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["-u", NSUserName(), "Dock"]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
    }
    @discardableResult static func restoreIfNeeded(force: Bool = false) throws -> Bool {
        return try locked {
            guard let journal = try readJournal(), force || journal.deadline <= Date() else { return false }
            let current = try preferences()
            let restored = DockLayout.restore(current: current, journal: journal)
            if current.map(\.key) != restored.map(\.key) { try write(restored) }
            // Delete only after the write succeeds; retries never duplicate tiles.
            try FileManager.default.removeItem(at: snapshot)
            return true
        }
    }
}
