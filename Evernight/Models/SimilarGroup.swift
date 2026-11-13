import Foundation

nonisolated struct SimilarGroup: Identifiable, Hashable, Sendable {
    let id: String
    let assets: [PhotoAsset]
    let suggestedKeepID: String

    var suggestedKeep: PhotoAsset? {
        assets.first { $0.id == suggestedKeepID } ?? assets.first
    }

    var estimatedBytes: Int64 {
        assets.reduce(0) { $0 + $1.estimatedBytes }
    }
}
