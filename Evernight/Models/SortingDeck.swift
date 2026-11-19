import Foundation

nonisolated enum SortingAction: Hashable, Sendable {
    case skip
    case queueDeletion
    case moveToAlbum(String)
}

nonisolated struct SortingStep: Identifiable, Hashable, Sendable {
    let asset: PhotoAsset
    let index: Int
    let action: SortingAction

    var id: String { "\(asset.id)-\(index)" }
}

nonisolated struct SortingDeck: Sendable {
    static let maximumUndoDepth = 10

    private(set) var assets: [PhotoAsset]
    private(set) var history: [SortingStep] = []
    private(set) var cursor = 0

    init(assets: [PhotoAsset] = []) {
        self.assets = assets
    }

    var current: PhotoAsset? {
        guard assets.indices.contains(cursor) else { return nil }
        return assets[cursor]
    }

    var next: PhotoAsset? {
        let nextIndex = cursor + 1
        guard assets.indices.contains(nextIndex) else { return nil }
        return assets[nextIndex]
    }

    var isFinished: Bool {
        cursor >= assets.count
    }

    var previousStep: SortingStep? {
        history.last
    }

    func cardWindow(previousCount: Int = 2, nextCount: Int = 2) -> [PhotoAsset] {
        guard assets.indices.contains(cursor) else { return [] }

        let lowerBound = max(0, cursor - max(previousCount, 0))
        let upperBound = min(
            assets.count,
            cursor + max(nextCount, 0) + 1
        )
        return Array(assets[lowerBound..<upperBound])
    }

    mutating func replaceAssets(_ newAssets: [PhotoAsset]) {
        assets = newAssets
        history = []
        cursor = 0
    }

    mutating func completeCurrent(_ action: SortingAction) -> SortingStep? {
        guard let current else { return nil }

        let step = SortingStep(asset: current, index: cursor, action: action)
        history.append(step)
        if history.count > Self.maximumUndoDepth {
            history.removeFirst(history.count - Self.maximumUndoDepth)
        }
        cursor += 1
        return step
    }

    mutating func undoLastAction() -> SortingStep? {
        guard let step = history.popLast() else { return nil }
        cursor = step.index
        return step
    }
}
