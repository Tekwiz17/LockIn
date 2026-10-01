import Foundation

enum ExitAction: String, Codable { case pause, stop }
enum FrictionKind: String, Codable, CaseIterable {
    case stroop, flanker, nback, flash, arithmetic, sequence
    var title: String {
        switch self { case .stroop: return "Ink Color"; case .flanker: return "Center Arrow"; case .nback: return "Two Back"; case .flash: return "Watch & Remember"; case .arithmetic: return "Mental Math"; case .sequence: return "Number Order" }
    }
    static func pick(easy: Bool, excluding: FrictionKind? = nil) -> FrictionKind {
        let pool = allCases.filter { $0 != excluding && (!easy || ($0 != .flash && $0 != .nback)) }
        return pool.randomElement() ?? .flanker
    }
}
struct ExitProgress: Codable {
    var sessionID: UUID
    var action: ExitAction
    var kind: FrictionKind
    var failures = 0
}
struct EmergencyExitLedger: Codable {
    // Calendar month in the fixed zone chosen on first use; changing time zone doesn't refill.
    var timeZoneID: String
    var counts: [String: Int] = [:]
    func month(at date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }
    func remaining(at date: Date) -> Int { max(0, 2 - (counts[month(at: date)] ?? 0)) }
    mutating func consume(at date: Date) -> Bool {
        guard remaining(at: date) > 0 else { return false }
        counts[month(at: date), default: 0] += 1; return true
    }
}
struct FrictionTrial {
    var prompt: String
    var answer: String
    var choices: [String]
    var ink = 0
    var stream: [String] = []
    static func make(_ kind: FrictionKind, easy: Bool) -> FrictionTrial {
        switch kind {
        case .stroop:
            let colors = ["Red", "Blue", "Green", "Orange"]
            let ink = Int.random(in: 0..<4), word = Int.random(in: 1..<4)
            return FrictionTrial(prompt: colors[(ink + word) % 4].uppercased(), answer: colors[ink], choices: colors.shuffled(), ink: ink)
        case .flanker:
            let right = Bool.random(), surround = Bool.random()
            let outer = surround ? "→" : "←", center = right ? "→" : "←"
            return FrictionTrial(prompt: "\(outer) \(outer)  \(center)  \(outer) \(outer)", answer: right ? "Right" : "Left", choices: ["Left", "Right"])
        case .nback:
            var digits = (0..<6).map { _ in String(Int.random(in: 0...9)) }
            let match = Bool.random(); digits[5] = match ? digits[3] : String((Int(digits[3])! + Int.random(in: 1...9)) % 10)
            return FrictionTrial(prompt: "Did the last digit match the digit two places before it?", answer: match ? "Same" : "Different", choices: ["Same", "Different"], stream: digits)
        case .flash:
            return FrictionTrial(prompt: "Watch for the three-digit number. Enter it after one minute.", answer: String(Int.random(in: 100...999)), choices: [])
        case .arithmetic:
            let a = Int.random(in: easy ? 12...35 : 12...29), b = Int.random(in: easy ? 7...19 : 3...9)
            let c = Int.random(in: easy ? 2...9 : 11...49), d = Int.random(in: 7...19)
            return easy ? FrictionTrial(prompt: "\(a) + \(b) − \(c) = ?", answer: String(a + b - c), choices: []) : FrictionTrial(prompt: "(\(a) × \(b)) − \(c) + \(d) = ?", answer: String(a * b - c + d), choices: [])
        case .sequence:
            let values = Array((easy ? 1...12 : 10...70)).shuffled().prefix(easy ? 4 : 8)
            let answer = values.sorted().map(String.init).joined(separator: " ")
            return FrictionTrial(prompt: "Put these in ascending order:\n" + values.map(String.init).joined(separator: "  "), answer: answer, choices: [])
        }
    }
    func accepts(_ input: String) -> Bool {
        input.split(whereSeparator: { $0.isWhitespace || $0 == "," }).joined(separator: " ").lowercased() == answer.lowercased()
    }
}
