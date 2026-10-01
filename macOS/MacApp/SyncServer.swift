import Foundation
import Network
import Security
import AppKit

struct BrowserCredential: Codable, Identifiable {
    var id: String
    var name: String
    var token: String
}
enum CredentialStore {
    static let service = "com.lockin.browser-pairing"
    static func load() -> [BrowserCredential] {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "connections", kSecReturnData as String: true]
        var value: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &value) == errSecSuccess, let data = value as? Data else { return [] }
        return (try? JSONDecoder().decode([BrowserCredential].self, from: data)) ?? []
    }
    static func save(_ items: [BrowserCredential]) -> Bool {
        guard let bytes = try? JSONEncoder().encode(items) else { return false }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "connections"]
        let status = SecItemUpdate(q as CFDictionary, [kSecValueData as String: bytes] as CFDictionary)
        if status == errSecItemNotFound { var add = q; add[kSecValueData as String] = bytes; return SecItemAdd(add as CFDictionary, nil) == errSecSuccess }
        return status == errSecSuccess
    }
    static func secret() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return UUID().uuidString + UUID().uuidString }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

/// Authenticated state feed and narrowly scoped session controls. Pairing requires native consent.
@MainActor final class SyncServer: ObservableObject {
    @Published var status = "Starting…"
    @Published var credentials: [BrowserCredential] = []
    @Published var lastSeen: [String: Date] = [:]
    @Published var lastRevision: [String: Int64] = [:]
    @Published var pairingCode: String?
    private var pairingDeadline = Date.distantPast
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private var waiting: [UUID: (NWConnection, String)] = [:]
    private weak var controller: SessionController?
    private var pairingInProgress = false
    private var linkApprovals: [String: (BrowserCredential, Date)] = [:]
    init(controller: SessionController) { self.controller = controller; credentials = CredentialStore.load(); start() }
    func beginPairing() { pairingCode = String(CredentialStore.secret().prefix(12)); pairingDeadline = Date().addingTimeInterval(120) }
    func handleURL(_ url: URL) {
        NSApp.activate()
        guard url.scheme?.lowercased() == "lockin", url.host == "pair",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let challenge = components.queryItems?.first(where: { $0.name == "challenge" })?.value,
              challenge.count == 64, challenge.allSatisfy({ $0.isHexDigit && $0.isASCII }),
              let name = components.queryItems?.first(where: { $0.name == "browser" })?.value,
              ["Chrome", "Safari", "Chromium"].contains(name), !pairingInProgress else { return }
        linkApprovals = linkApprovals.filter { Date() < $0.value.1 }
        guard linkApprovals[challenge] == nil, linkApprovals.count < 8 else { return }
        pairingInProgress = true
        let alert = NSAlert(); alert.messageText = "Connect \(name) to LockIn?"
        alert.informativeText = "This browser extension can sync website rules and pause or stop ordinary sessions. Nuclear sessions remain locked. Only approve if you just selected Connect Automatically in your extension."
        alert.addButton(withTitle: "Connect"); alert.addButton(withTitle: "Cancel")
        let approved = alert.runModal() == .alertFirstButtonReturn; pairingInProgress = false
        if approved { linkApprovals[challenge] = (BrowserCredential(id: UUID().uuidString, name: name, token: CredentialStore.secret()), Date().addingTimeInterval(120)) }
    }
    func disconnect(_ id: String) {
        let updated = credentials.filter { $0.id != id }
        guard CredentialStore.save(updated) else { status = "Couldn't update saved browser connections."; return }
        credentials = updated; lastSeen[id] = nil; lastRevision[id] = nil
        let pending = waiting.filter { $0.value.1 == id }
        for (key, value) in pending { waiting[key] = nil; reply(value.0, key, code: 401, object: ["error": "Connection removed. Pair again."]) }
    }
    func connected(_ id: String) -> Bool { Date().timeIntervalSince(lastSeen[id] ?? .distantPast) < 50 }
    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: 19287)
            let listener = try NWListener(using: params)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self] state in Task { @MainActor in
                switch state { case .ready: self?.status = "Ready"; case .failed: self?.status = "Browser sync couldn't start. Quit any other LockIn copy, then retry."; self?.listener?.cancel(); self?.listener = nil; default: break }
            } }
            listener.newConnectionHandler = { [weak self] connection in Task { @MainActor in self?.accept(connection) } }
            listener.start(queue: .main)
        } catch { status = "Browser sync couldn't start. Try again."; listener = nil }
    }
    func publish() {
        let pending = waiting; waiting.removeAll()
        for (id, value) in pending { stateReply(value.0, id, credentialID: value.1) }
    }
    private func accept(_ c: NWConnection) {
        guard connections.count < 32 else { c.cancel(); return }
        let id = UUID(); connections[id] = c
        c.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state { Task { @MainActor in self?.connections[id] = nil; self?.waiting[id] = nil } }
        }
        c.start(queue: .main); receive(c, id, data: Data())
        DispatchQueue.main.asyncAfter(deadline: .now() + 28) { [weak self, weak c] in self?.connections[id] = nil; self?.waiting[id] = nil; c?.cancel() }
    }
    private func receive(_ c: NWConnection, _ id: UUID, data: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] bytes, _, done, error in Task { @MainActor in
            guard let self else { return }
            var buffer = data; if let bytes { buffer.append(bytes) }
            guard buffer.count <= 16384, error == nil else { c.cancel(); return }
            if let boundary = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let header = String(decoding: buffer[..<boundary.lowerBound], as: UTF8.self)
                let lines = header.components(separatedBy: "\r\n")
                var fields: [String: String] = [:]
                for line in lines.dropFirst() { let pair = line.split(separator: ":", maxSplits: 1); if pair.count == 2 { fields[String(pair[0]).lowercased()] = pair[1].trimmingCharacters(in: .whitespaces) } }
                guard fields["transfer-encoding"] == nil else { c.cancel(); return }
                let count = Int(fields["content-length"] ?? "0") ?? -1
                guard count >= 0, count <= 4096 else { c.cancel(); return }
                let body = buffer[boundary.upperBound...]
                if body.count >= count { self.handle(c, id, line: lines.first ?? "", headers: fields, body: Data(body.prefix(count))); return }
            }
            if done { c.cancel() } else { self.receive(c, id, data: buffer) }
        } }
    }
    private func handle(_ c: NWConnection, _ id: UUID, line: String, headers: [String: String], body: Data) {
        let parts = line.split(separator: " ")
        guard parts.count == 3, let host = headers["host"], ["127.0.0.1:19287", "localhost:19287"].contains(host) else { reply(c, id, code: 400, object: ["error": "Invalid request"]); return }
        let method = String(parts[0]); let target = String(parts[1])
        // No browser-site CORS, no permissive preflight, no DNS-rebinding Host names.
        if let origin = headers["origin"], !origin.hasPrefix("chrome-extension://"), !origin.hasPrefix("safari-web-extension://") {
            reply(c, id, code: 403, object: ["error": "Extension access only"]); return
        }
        guard let url = URLComponents(string: "http://127.0.0.1" + target) else { c.cancel(); return }
        if method == "POST", url.path == "/pair-link" {
            guard let input = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let challenge = input["challenge"], challenge.count == 64, challenge.allSatisfy({ $0.isHexDigit && $0.isASCII }) else {
                reply(c, id, code: 400, object: ["error": "Invalid pairing request"]); return
            }
            linkApprovals = linkApprovals.filter { Date() < $0.value.1 }
            guard let approval = linkApprovals.removeValue(forKey: challenge) else { reply(c, id, code: 202, object: ["pending": "true"]); return }
            let updated = credentials + [approval.0]
            guard CredentialStore.save(updated) else { reply(c, id, code: 500, object: ["error": "Couldn't save pairing. Use the backup code."]); return }
            credentials = updated; reply(c, id, code: 200, object: ["token": approval.0.token]); return
        }
        if method == "POST", url.path == "/pair" {
            guard !pairingInProgress, let code = pairingCode, Date() < pairingDeadline,
                  let input = try? JSONSerialization.jsonObject(with: body) as? [String: String], input["code"] == code,
                  let name = input["name"], ["Chrome", "Safari", "Chromium"].contains(name) else {
                reply(c, id, code: 403, object: ["error": "Open LockIn → Settings → Browsers and create a new connection code."]); return
            }
            pairingInProgress = true; pairingCode = nil
            let alert = NSAlert(); alert.messageText = "\(name) wants to connect"; alert.informativeText = "Allow this browser to sync website rules and pause/stop ordinary sessions? Nuclear sessions remain locked."; alert.addButton(withTitle: "Connect"); alert.addButton(withTitle: "Cancel")
            NSApp.activate()
            let approved = alert.runModal() == .alertFirstButtonReturn; pairingInProgress = false
            guard approved else { reply(c, id, code: 403, object: ["error": "Connection cancelled"]); return }
            let credential = BrowserCredential(id: UUID().uuidString, name: name, token: CredentialStore.secret())
            let updated = credentials + [credential]
            guard CredentialStore.save(updated) else { reply(c, id, code: 500, object: ["error": "LockIn couldn't save this connection in Keychain."]); return }
            credentials = updated
            reply(c, id, code: 200, object: ["token": credential.token]); return
        }
        guard let auth = headers["authorization"], let credential = credentials.first(where: { auth == "Bearer " + $0.token }) else { reply(c, id, code: 401, object: ["error": "Connect this extension to LockIn again."]); return }
        if method == "POST", url.path == "/control" {
            controller?.tick()
            guard let controller, let input = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let session = controller.data.session, input["sessionID"] == session.id.uuidString else {
                reply(c, id, code: 409, object: ["error": "Session changed. Refresh the popup."]); return
            }
            if controller.nuclearLocked && input["action"] != "stop" { reply(c, id, code: 403, object: ["error": "Nuclear Mode cannot be paused."]); return }
            if controller.nuclearLocked && controller.emergencyRemaining == 0 { reply(c, id, code: 403, object: ["error": "Both emergency exits have been used this month."]); return }
            switch input["action"] {
            case "pause": if !session.isPaused && !session.waiting { controller.togglePause() }
            case "resume": if session.isPaused && !session.waiting { controller.togglePause() }
            case "stop": controller.end()
            default: reply(c, id, code: 400, object: ["error": "Unknown control"]); return
            }
            stateReply(c, id, credentialID: credential.id); return
        }
        guard method == "GET", url.path == "/state" else { reply(c, id, code: 400, object: ["error": "Unknown endpoint"]); return }
        lastSeen[credential.id] = Date()
        let revision = Int64(url.queryItems?.first { $0.name == "revision" }?.value ?? "")
        let instance = url.queryItems?.first { $0.name == "installation" }?.value
        if revision == controller?.data.revision, instance == controller?.data.installationID {
            waiting[id] = (c, credential.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in guard let self, let value = self.waiting.removeValue(forKey: id) else { return }; self.stateReply(value.0, id, credentialID: value.1) }
        } else { stateReply(c, id, credentialID: credential.id) }
    }
    private func stateReply(_ c: NWConnection, _ id: UUID, credentialID: String) {
        guard let state = controller?.syncState(), let bytes = try? JSONEncoder().encode(state) else { c.cancel(); return }
        lastRevision[credentialID] = state.revision; send(c, id, code: 200, bytes: bytes)
    }
    private func reply(_ c: NWConnection, _ id: UUID, code: Int, object: [String: String]) { send(c, id, code: code, bytes: (try? JSONSerialization.data(withJSONObject: object)) ?? Data()) }
    private func send(_ c: NWConnection, _ id: UUID, code: Int, bytes: Data) {
        let header = "HTTP/1.1 \(code) \(code == 200 ? "OK" : "Error")\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\nContent-Length: \(bytes.count)\r\n\r\n"
        c.send(content: Data(header.utf8) + bytes, completion: .contentProcessed { _ in c.cancel() })
        connections[id] = nil; waiting[id] = nil
    }
}
