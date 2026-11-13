import Foundation

nonisolated struct AlbumMergeSuggestion: Identifiable, Hashable, Sendable {
    let id: String
    let target: PhotoAlbum
    let sources: [PhotoAlbum]
}
