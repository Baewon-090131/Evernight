import Foundation

nonisolated struct SortStatistics: Codable, Hashable, Sendable {
    var sortedItemCount = 0
    var queuedDeleteCount = 0
    var movedToAlbumCount = 0
    var deletedItemCount = 0
    var estimatedFreedBytes: Int64 = 0
}
