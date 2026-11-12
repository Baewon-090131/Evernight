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

    var mediaScope: MediaScope = .all
    var targetAlbumID: String?

    private let imageCache = NSCache<NSString, UIImage>()
    private let imageManager = PHCachingImageManager()

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
        var grouped: [MonthKey: [PhotoAsset]] = [:]
        for asset in assets {
            guard let month = asset.monthKey else { continue }
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

    func bootstrapIfNeeded() async {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard isAuthorized, !hasLoaded else { return }
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
        pendingDeleteIDs.formIntersection(Set(loadedAssets.map(\.id)))
        if let targetAlbumID, !loadedAlbums.contains(where: { $0.id == targetAlbumID }) {
            self.targetAlbumID = nil
        }
        hasLoaded = true
    }

    func sortingAssets(for month: MonthKey, scope: MediaScope) -> [PhotoAsset] {
        assets.filter { asset in
            asset.monthKey == month
                && scope.includes(asset.kind)
                && !pendingDeleteIDs.contains(asset.id)
        }
    }

    func firstAsset(in month: MonthKey) -> PhotoAsset? {
        assets.first { $0.monthKey == month }
    }

    func queueForDeletion(_ asset: PhotoAsset) {
        pendingDeleteIDs.insert(asset.id)
    }

    func removeFromDeleteQueue(_ assetID: String) {
        pendingDeleteIDs.remove(assetID)
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
                    self?.imageCache.setObject(image, forKey: cacheKey)
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
}
