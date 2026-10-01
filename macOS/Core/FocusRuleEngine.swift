import Foundation

enum FocusRuleEngine {
    static let protectedApps: Set<String> = ["com.lockin.mac", "com.apple.finder", "com.apple.dock", "com.apple.loginwindow", "com.apple.windowmanager", "com.apple.systemuiserver", "com.apple.controlcenter", "com.apple.systemsettings", "com.apple.systempreferences", "com.apple.securityagent", "com.apple.notificationcenterui"]
    static func allowsApp(_ id: String, active: Bool, mode: RuleMode, selected: [AppRule], never: [AppRule]) -> Bool {
        if !active || protectedApps.contains(id.lowercased()) || id == Bundle.main.bundleIdentifier { return true }
        if never.contains(where: { $0.id == id }) { return true }
        let listed = selected.contains { $0.id == id }
        return mode == .block ? !listed : listed
    }
    /// ASCII/punycode DNS names and IPv4, exact host plus dot-delimited subdomains.
    static func normalizeDomain(_ input: String) -> String? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.unicodeScalars.allSatisfy({ $0.isASCII }), !raw.isEmpty, !raw.contains(where: { $0.isWhitespace }), !raw.contains("\\") else { return nil }
        let withScheme = raw.contains("://") ? raw : "https://" + raw
        guard let c = URLComponents(string: withScheme), ["http", "https"].contains(c.scheme?.lowercased() ?? ""), c.user == nil, c.password == nil,
              var host = c.host?.lowercased(), c.port == nil || (1...65535).contains(c.port!) else { return nil }
        if host.hasSuffix(".") { host.removeLast() }
        guard host.count <= 253, host.unicodeScalars.allSatisfy({ $0.isASCII }), !host.isEmpty else { return nil }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.allSatisfy({ label in
            !label.isEmpty && label.count <= 63 && label.first != "-" && label.last != "-" && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }) else { return nil }
        return host
    }
    static func matches(_ host: String, _ domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }
    static func allowsDomain(_ host: String, active: Bool, mode: RuleMode, selected: [String], never: [String]) -> Bool {
        if !active || never.contains(where: { matches(host, $0) }) { return true }
        let listed = selected.contains { matches(host, $0) }
        return mode == .block ? !listed : listed
    }
}
