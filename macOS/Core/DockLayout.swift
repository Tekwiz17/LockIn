import Foundation

/// Full plist tile bytes preserve GUIDs, bookmarks and metadata without rebuilding shortcuts.
struct DockTile: Codable, Equatable {
    var key: String
    var payload: Data
}
struct DockJournal: Codable {
    var version = 1
    var original: [DockTile]
    var removed: Set<String>
    var deadline: Date
}
enum DockLayout {
    /// Reinsert only our missing tiles. Keep unrelated additions/deletions/reordering.
    /// With no user changes this recreates the exact original positions.
    static func restore(current: [DockTile], journal: DockJournal) -> [DockTile] {
        var result = current
        for (index, tile) in journal.original.enumerated() where journal.removed.contains(tile.key) {
            guard !result.contains(where: { $0.key == tile.key }) else { continue }
            let following = journal.original.dropFirst(index + 1).first { next in result.contains { $0.key == next.key } }
            if let next = following, let position = result.firstIndex(where: { $0.key == next.key }) {
                result.insert(tile, at: position)
            } else if let previous = journal.original.prefix(index).last(where: { prior in result.contains { $0.key == prior.key } }),
                      let position = result.firstIndex(where: { $0.key == previous.key }) {
                result.insert(tile, at: position + 1)
            } else { result.insert(tile, at: min(index, result.count)) }
        }
        return result
    }
}
