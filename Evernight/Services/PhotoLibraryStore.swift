import Foundation
import Observation
@preconcurrency import Photos
import UIKit

nonisolated enum PhotoLibraryError: LocalizedError, Sendable {
    case missingAsset
    case missingAlbum
    case emptyDeleteQueue
    case changeFailed

    var errorDescription: String? {
        switch self {
        case .missingAsset:
            "找不到这张媒体，可能已被其他操作移除。"
        case .missingAlbum:
            "找不到目标相簿，请重新选择。"
        case .emptyDeleteQueue:
            "待删除区里没有项目。"
        case .changeFailed:
            "相册操作没有完成，请稍后重试。"
        }
    }
}

struct DeleteReceipt: Hashable, Sendable {
    let count: Int
    let estimatedBytes: Int64
}

@Observable
final class PhotoLibraryStore {
    private(set) var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private(set) var assets: [PhotoAsset] = []
    private(set) var albums: [PhotoAlbum] = []
    private(set) var pendingDeleteIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var statistics = SortStatistics()
    private(set) var processedAssetIDs: Set<String> = []
    private(set) var similarGroups: [SimilarGroup] = []
    private(set) var isScanningSimilar = false
    private(set) var similarScanMonth: MonthKey?
    private(set) var recentMoves: [RecentMoveRecord] = []

    var mediaScope: MediaScope = .all
    var targetAlbumID: String? {
        didSet {
            UserDefaults.standard.set(targetAlbumID, forKey: Self.targetAlbumKey)
        }
    }

    private let imageCache = NSCache<NSString, UIImage>()
    private let imageManager = PHCachingImageManager()
    private let statisticsKey = "evernight.sortStatistics"
    private let processedKey = "evernight.processedAssetIDs"
    private let recentMovesKey = "evernight.recentMoves"
    private static let targetAlbumKey = "evernight.targetAlbumID"

    init() {
        imageCache.countLimit = 180
        imageCache.totalCostLimit = 96 * 1024 * 1024
        if
            let data = UserDefaults.standard.data(forKey: statisticsKey),
            let saved = try? JSONDecoder().decode(SortStatistics.self, from: data)
        {
            statistics = saved
        }
        processedAssetIDs = Set(UserDefaults.standard.stringArray(forKey: processedKey) ?? [])
        if
            let data = UserDefaults.standard.data(forKey: recentMovesKey),
            let saved = try? JSONDecoder().decode([RecentMoveRecord].self, from: data)
        {
            recentMoves = saved
        }
        targetAlbumID = UserDefaults.standard.string(forKey: Self.targetAlbumKey)
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    var targetAlbum: PhotoAlbum? {
        guard let targetAlbumID else { return nil }
        return albums.first { $0.id == targetAlbumID }
    }

    var pendingAssets: [PhotoAsset] {
        assets.filter { pendingDeleteIDs.contains($0.id) }
    }

    var pendingEstimatedBytes: Int64 {
        pendingAssets.reduce(0) { $0 + $1.estimatedBytes }
    }

    var months: [PhotoMonth] {
        months(for: .all)
    }

    func months(for scope: MediaScope) -> [PhotoMonth] {
        var grouped: [MonthKey: [PhotoAsset]] = [:]
        for asset in assets {
            guard let month = asset.monthKey, scope.includes(asset.kind) else { continue }
            grouped[month, default: []].append(asset)
        }

        return grouped.map { key, entries in
            PhotoMonth(
                key: key,
                photoCount: entries.count { $0.kind == .photo },
                videoCount: entries.count { $0.kind == .video }
            )
        }
        .sorted { $0.key > $1.key }
    }

    var latestMonth: PhotoMonth? {
        months.first
    }

    var undatedAssetCount: Int {
        assets.count { $0.creationDate == nil }
    }

    var albumMergeSuggestions: [AlbumMergeSuggestion] {
        let buckets = Dictionary(grouping: albums) {
            normalizedAlbumTitle($0.title)
        }

        return buckets.values.compactMap { candidates in
            guard candidates.count > 1 else { return nil }
            let sorted = candidates.sorted {
                $0.assetCount == $1.assetCount
                    ? $0.title < $1.title
                    : $0.assetCount > $1.assetCount
            }
            guard let target = sorted.first else { return nil }
            let sources = Array(sorted.dropFirst())
            return AlbumMergeSuggestion(
                id: sorted.map(\.id).sorted().joined(separator: "|"),
                target: target,
                sources: sources
            )
        }
        .sorted { $0.target.title < $1.target.title }
    }

    func bootstrapIfNeeded() async {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard isAuthorized, !hasLoaded else { return }
        await reload()
    }

    func refreshAuthorizationAndReload() async {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard isAuthorized else {
            hasLoaded = false
            assets = []
            albums = []
            return
        }
        await reload()
    }

    func requestAccess() async {
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) {
                continuation.resume(returning: $0)
            }
        }

        authorizationStatus = status
        if isAuthorized {
            await reload()
        }
    }

    func reload() async {
        guard isAuthorized, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let loadedAssets = await PhotoLibraryReader.fetchAssets()
        let loadedAlbums = await PhotoLibraryReader.fetchAlbums()

        assets = loadedAssets
        albums = loadedAlbums
        similarGroups = []
        similarScanMonth = nil
        pendingDeleteIDs.formIntersection(Set(loadedAssets.map(\.id)))
        processedAssetIDs.formIntersection(Set(loadedAssets.map(\.id)))
        persistProcessedAssets()
        recentMoves.removeAll { move in
            !loadedAssets.contains { $0.id == move.assetID }
                || !loadedAlbums.contains { $0.id == move.albumID }
        }
        persistRecentMoves()
        if let targetAlbumID, !loadedAlbums.contains(where: { $0.id == targetAlbumID }) {
            self.targetAlbumID = nil
        }
        hasLoaded = true
    }

    func sortingAssets(for month: MonthKey, scope: MediaScope) -> [PhotoAsset] {
        assets.filter { asset in
            asset.monthKey == month
                && scope.includes(asset.kind)
                && !processedAssetIDs.contains(asset.id)
                && !pendingDeleteIDs.contains(asset.id)
        }
    }

    func firstAsset(in month: MonthKey) -> PhotoAsset? {
        assets.first { $0.monthKey == month }
    }

    func queueForDeletion(_ asset: PhotoAsset) {
        pendingDeleteIDs.insert(asset.id)
    }

    func queueForDeletion(_ assets: [PhotoAsset]) {
        for asset in assets {
            pendingDeleteIDs.insert(asset.id)
        }
    }

    func removeFromDeleteQueue(_ assetID: String) {
        pendingDeleteIDs.remove(assetID)
    }

    func processedCount(in month: MonthKey) -> Int {
        processedCount(in: month, scope: .all)
    }

    func processedCount(in month: MonthKey, scope: MediaScope) -> Int {
        assets.count {
            $0.monthKey == month
                && scope.includes($0.kind)
                && processedAssetIDs.contains($0.id)
        }
    }

    func recordSort(_ action: SortingAction, assetID: String) {
        processedAssetIDs.insert(assetID)
        statistics.sortedItemCount += 1
        switch action {
        case .skip:
            break
        case .queueDeletion:
            statistics.queuedDeleteCount += 1
        case .moveToAlbum:
            statistics.movedToAlbumCount += 1
        }
        persistProcessedAssets()
        persistStatistics()
    }

    func revertSort(_ action: SortingAction, assetID: String) {
        processedAssetIDs.remove(assetID)
        statistics.sortedItemCount = max(0, statistics.sortedItemCount - 1)
        switch action {
        case .skip:
            break
        case .queueDeletion:
            statistics.queuedDeleteCount = max(0, statistics.queuedDeleteCount - 1)
        case .moveToAlbum:
            statistics.movedToAlbumCount = max(0, statistics.movedToAlbumCount - 1)
        }
        persistProcessedAssets()
        persistStatistics()
    }

    func resetProgress(for month: MonthKey) {
        let ids = Set(
            assets
                .filter { $0.monthKey == month }
                .map(\.id)
        )
        processedAssetIDs.subtract(ids)
        persistProcessedAssets()
    }

    func resetAllProgress() {
        processedAssetIDs.removeAll()
        persistProcessedAssets()
    }

    func add(_ asset: PhotoAsset, to albumID: String) async throws {
        guard
            let collection = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [albumID],
                options: nil
            ).firstObject
        else {
            throw PhotoLibraryError.missingAlbum
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [asset.id], options: nil)
        guard fetchResult.firstObject != nil else {
            throw PhotoLibraryError.missingAsset
        }

        try await performChanges {
            guard let request = PHAssetCollectionChangeRequest(for: collection) else { return }
            request.addAssets(fetchResult)
        }
        adjustAlbumCount(albumID, by: 1)
        recentMoves.insert(
            RecentMoveRecord(
                id: UUID().uuidString,
                assetID: asset.id,
                albumID: albumID,
                albumTitle: targetAlbum?.title ?? "相簿",
                movedAt: .now
            ),
            at: 0
        )
        recentMoves = Array(recentMoves.prefix(50))
        persistRecentMoves()
    }

    func remove(_ asset: PhotoAsset, from albumID: String) async throws {
        guard
            let collection = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [albumID],
                options: nil
            ).firstObject
        else {
            throw PhotoLibraryError.missingAlbum
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [asset.id], options: nil)
        try await performChanges {
            guard let request = PHAssetCollectionChangeRequest(for: collection) else { return }
            request.removeAssets(fetchResult)
        }
        adjustAlbumCount(albumID, by: -1)
        recentMoves.removeAll {
            $0.assetID == asset.id && $0.albumID == albumID
        }
        persistRecentMoves()
    }

    @discardableResult
    func createAlbum(named rawName: String) async throws -> PhotoAlbum {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw PhotoLibraryError.changeFailed
        }

        try await performChanges {
            _ = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
        }

        albums = await PhotoLibraryReader.fetchAlbums()
        guard let album = albums.first(where: { $0.title == name }) else {
            throw PhotoLibraryError.missingAlbum
        }
        targetAlbumID = album.id
        return album
    }

    func renameAlbum(_ album: PhotoAlbum, to rawName: String) async throws {
        let title = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw PhotoLibraryError.changeFailed
        }
        guard
            let collection = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [album.id],
                options: nil
            ).firstObject
        else {
            throw PhotoLibraryError.missingAlbum
        }

        try await performChanges {
            PHAssetCollectionChangeRequest(for: collection)?.title = title
        }
        albums = await PhotoLibraryReader.fetchAlbums()
    }

    func deleteAlbum(_ album: PhotoAlbum) async throws {
        let fetchResult = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [album.id],
            options: nil
        )
        guard fetchResult.count > 0 else {
            throw PhotoLibraryError.missingAlbum
        }

        try await performChanges {
            PHAssetCollectionChangeRequest.deleteAssetCollections(fetchResult)
        }
        albums = await PhotoLibraryReader.fetchAlbums()
        recentMoves.removeAll { $0.albumID == album.id }
        persistRecentMoves()
        if targetAlbumID == album.id {
            targetAlbumID = nil
        }
    }

    func mergeAlbums(_ suggestion: AlbumMergeSuggestion) async throws {
        guard
            let target = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [suggestion.target.id],
                options: nil
            ).firstObject
        else {
            throw PhotoLibraryError.missingAlbum
        }

        let sourceCollections = suggestion.sources.map { source in
            PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [source.id],
                options: nil
            ).firstObject
        }
        .compactMap { $0 }

        try await performChanges {
            guard let targetRequest = PHAssetCollectionChangeRequest(for: target) else {
                return
            }
            for source in sourceCollections {
                let sourceAssets = PHAsset.fetchAssets(in: source, options: nil)
                if sourceAssets.count > 0 {
                    targetRequest.addAssets(sourceAssets)
                }
            }
        }

        let sourceFetchResult = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: suggestion.sources.map(\.id),
            options: nil
        )
        try await performChanges {
            PHAssetCollectionChangeRequest.deleteAssetCollections(sourceFetchResult)
        }
        albums = await PhotoLibraryReader.fetchAlbums()
        let sourceIDs = Set(suggestion.sources.map(\.id))
        recentMoves = recentMoves.map { move in
            guard sourceIDs.contains(move.albumID) else { return move }
            return RecentMoveRecord(
                id: move.id,
                assetID: move.assetID,
                albumID: suggestion.target.id,
                albumTitle: suggestion.target.title,
                movedAt: move.movedAt
            )
        }
        persistRecentMoves()
        targetAlbumID = suggestion.target.id
    }

    func scanSimilar(in month: MonthKey) async {
        guard !isScanningSimilar else { return }

        isScanningSimilar = true
        similarScanMonth = month
        similarGroups = []
        defer { isScanningSimilar = false }

        let source = assets.filter {
            $0.monthKey == month
                && $0.kind == .photo
                && !pendingDeleteIDs.contains($0.id)
        }
        let result = await SimilarityScanner.scan(source)
        guard similarScanMonth == month, !Task.isCancelled else { return }
        similarGroups = result
    }

    func clearSimilarResults() {
        similarGroups = []
        similarScanMonth = nil
    }

    func removeSimilarGroup(_ id: String) {
        similarGroups.removeAll { $0.id == id }
    }

    @discardableResult
    func deletePendingAssets() async throws -> DeleteReceipt {
        guard !pendingDeleteIDs.isEmpty else {
            throw PhotoLibraryError.emptyDeleteQueue
        }

        let ids = pendingDeleteIDs
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(ids), options: nil)
        guard fetchResult.count > 0 else {
            throw PhotoLibraryError.emptyDeleteQueue
        }

        let receipt = DeleteReceipt(
            count: fetchResult.count,
            estimatedBytes: pendingEstimatedBytes
        )

        try await performChanges {
            PHAssetChangeRequest.deleteAssets(fetchResult)
        }

        pendingDeleteIDs.subtract(ids)
        assets.removeAll { ids.contains($0.id) }
        processedAssetIDs.subtract(ids)
        persistProcessedAssets()
        recentMoves.removeAll { ids.contains($0.assetID) }
        persistRecentMoves()
        similarGroups = []
        similarScanMonth = nil
        statistics.deletedItemCount += receipt.count
        statistics.estimatedFreedBytes += receipt.estimatedBytes
        persistStatistics()
        return receipt
    }

    func requestThumbnail(
        for assetID: String,
        targetSize: CGSize,
        completion: @escaping @MainActor (UIImage?) -> Void
    ) -> PHImageRequestID? {
        let cacheKey = assetID as NSString
        if let image = imageCache.object(forKey: cacheKey) {
            completion(image)
            return nil
        }

        guard
            let asset = PHAsset.fetchAssets(
                withLocalIdentifiers: [assetID],
                options: nil
            ).firstObject
        else {
            completion(nil)
            return nil
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        return imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            Task { @MainActor in
                if let image {
                    let cost = (image.cgImage?.width ?? 0) * (image.cgImage?.height ?? 0) * 4
                    self?.imageCache.setObject(image, forKey: cacheKey, cost: cost)
                }
                completion(image)
            }
        }
    }

    func cancelThumbnailRequest(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }

    private func performChanges(_ changes: @escaping () -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges(changes) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: error ?? PhotoLibraryError.changeFailed
                    )
                }
            }
        }
    }

    func resetStatistics() {
        statistics = SortStatistics()
        persistStatistics()
    }

    func undoRecentMove(_ record: RecentMoveRecord) async throws {
        guard let asset = assets.first(where: { $0.id == record.assetID }) else {
            recentMoves.removeAll { $0.id == record.id }
            persistRecentMoves()
            throw PhotoLibraryError.missingAsset
        }
        try await remove(asset, from: record.albumID)
    }

    func clearRecentMoves() {
        recentMoves = []
        persistRecentMoves()
    }

    private func persistStatistics() {
        guard let data = try? JSONEncoder().encode(statistics) else { return }
        UserDefaults.standard.set(data, forKey: statisticsKey)
    }

    private func persistProcessedAssets() {
        UserDefaults.standard.set(Array(processedAssetIDs), forKey: processedKey)
    }

    private func persistRecentMoves() {
        guard let data = try? JSONEncoder().encode(recentMoves) else { return }
        UserDefaults.standard.set(data, forKey: recentMovesKey)
    }

    private func adjustAlbumCount(_ albumID: String, by delta: Int) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else { return }
        let album = albums[index]
        albums[index] = PhotoAlbum(
            id: album.id,
            title: album.title,
            assetCount: max(0, album.assetCount + delta)
        )
    }

    private func normalizedAlbumTitle(_ title: String) -> String {
        title
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "副本", with: "")
            .replacingOccurrences(of: "复制", with: "")
            .replacingOccurrences(of: "[（(][0-9]+[）)]$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[_-][0-9]+$", with: "", options: .regularExpression)
    }
}
