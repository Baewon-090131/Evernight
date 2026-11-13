import Foundation

nonisolated struct RecentMoveRecord: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let assetID: String
    let albumID: String
    let albumTitle: String
    let movedAt: Date
}
