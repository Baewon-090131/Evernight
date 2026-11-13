import Foundation
@preconcurrency import Photos

nonisolated enum PhotoLibraryReader {
    @concurrent
    static func fetchAssets() async -> [PhotoAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]

        let result = PHAsset.fetchAssets(with: options)
        var assets: [PhotoAsset] = []
        assets.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            let kind: AssetKind = switch asset.mediaType {
            case .image: .photo
            case .video: .video
            default: .other
            }

            let pixels = max(asset.pixelWidth * asset.pixelHeight, 1)
            let estimatedBytes: Int64 = if asset.mediaType == .video {
                Int64(max(asset.duration, 0) * 500_000)
            } else {
                Int64(Double(pixels) * 0.35)
            }

            assets.append(
                PhotoAsset(
                    id: asset.localIdentifier,
                    creationDate: asset.creationDate,
                    kind: kind,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    duration: asset.duration,
                    estimatedBytes: estimatedBytes,
                    isLivePhoto: asset.mediaSubtypes.contains(.photoLive)
                )
            )
        }

        return assets
    }

    @concurrent
    static func fetchAlbums() async -> [PhotoAlbum] {
        let result = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )

        var albums: [PhotoAlbum] = []
        albums.reserveCapacity(result.count)

        result.enumerateObjects { collection, _, _ in
            let count = PHAsset.fetchAssets(in: collection, options: nil).count
            albums.append(
                PhotoAlbum(
                    id: collection.localIdentifier,
                    title: collection.localizedTitle ?? "未命名相簿",
                    assetCount: count
                )
            )
        }

        return albums.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}
