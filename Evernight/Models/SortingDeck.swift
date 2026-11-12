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

    mutating func replaceAssets(_ newAssets: [PhotoAsset]) {
        assets = newAssets
        history = []
        cursor = 0
    }

    mutating func completeCurrent(_ action: SortingAction) -> SortingStep? {
        guard let current else { return nil }

        let step = SortingStep(asset: current, index: cursor, action: action)
        history.append(step)
        cursor += 1
        return step
    }

    mutating func undoLastAction() -> SortingStep? {
        guard let step = history.popLast() else { return nil }
        cursor = step.index
        return step
    }
}
