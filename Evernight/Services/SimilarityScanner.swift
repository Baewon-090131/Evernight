import Foundation
@preconcurrency import Photos
import UIKit

nonisolated enum SimilarityScanner {
    static func scan(_ assets: [PhotoAsset]) async -> [SimilarGroup] {
        let photos = assets.filter {
            $0.kind == .photo && $0.creationDate != nil
        }
        guard photos.count >= 2 else { return [] }

        var fingerprints: [Fingerprint] = []
        for start in stride(from: 0, to: photos.count, by: 24) {
            if Task.isCancelled { return [] }
            let chunk = Array(photos[start..<min(start + 24, photos.count)])
            let chunkFingerprints = await withTaskGroup(of: Fingerprint?.self) { group in
                for asset in chunk {
                    group.addTask {
                        await fingerprint(for: asset)
                    }
                }

                var results: [Fingerprint] = []
                for await result in group {
                    if let result {
                        results.append(result)
                    }
                }
                return results
            }
            fingerprints.append(contentsOf: chunkFingerprints)
        }

        let sorted = fingerprints.sorted {
            ($0.asset.creationDate ?? .distantPast) > ($1.asset.creationDate ?? .distantPast)
        }
        var clusters: [[Fingerprint]] = []

        for item in sorted {
            if let clusterIndex = clusters.firstIndex(where: { cluster in
                cluster.contains { candidate in
                    matches(item, candidate)
                }
            }) {
                clusters[clusterIndex].append(item)
            } else {
                clusters.append([item])
            }
        }

        return clusters
            .filter { $0.count >= 2 }
            .map { cluster in
                let assets = cluster.map(\.asset)
                let suggested = cluster.max {
                    qualityScore($0.asset) < qualityScore($1.asset)
                }?.asset.id ?? assets[0].id

                return SimilarGroup(
                    id: assets.map(\.id).sorted().joined(separator: "|"),
                    assets: assets,
                    suggestedKeepID: suggested
                )
            }
            .sorted {
                ($0.assets.first?.creationDate ?? .distantPast)
                    > ($1.assets.first?.creationDate ?? .distantPast)
            }
    }

    private static func matches(_ lhs: Fingerprint, _ rhs: Fingerprint) -> Bool {
        guard
            let lhsDate = lhs.asset.creationDate,
            let rhsDate = rhs.asset.creationDate
        else {
            return false
        }

        return abs(lhsDate.timeIntervalSince(rhsDate)) <= 30 * 60
            && abs(lhs.aspectRatio - rhs.aspectRatio) <= 0.12
            && (lhs.hash ^ rhs.hash).nonzeroBitCount <= 7
    }

    private static func qualityScore(_ asset: PhotoAsset) -> Int {
        let area = asset.pixelWidth * asset.pixelHeight
        let recentBias = Int(
            max(0, asset.creationDate?.timeIntervalSince1970 ?? 0) / 1_000_000
        )
        return area + recentBias
    }

    private static func fingerprint(for asset: PhotoAsset) async -> Fingerprint? {
        guard
            let creationDate = asset.creationDate,
            let photoAsset = PHAsset.fetchAssets(
                withLocalIdentifiers: [asset.id],
                options: nil
            ).firstObject
        else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let gate = FingerprintGate(continuation)
            let imageManager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false

            imageManager.requestImage(
                for: photoAsset,
                targetSize: CGSize(width: 80, height: 80),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard let image, let hash = differenceHash(image) else {
                    gate.resume(nil)
                    return
                }

                gate.resume(
                    Fingerprint(
                        asset: asset,
                        hash: hash,
                        creationDate: creationDate,
                        aspectRatio: Double(asset.pixelWidth)
                            / Double(max(asset.pixelHeight, 1))
                    )
                )
            }
        }
    }

    private static func differenceHash(_ image: UIImage) -> UInt64? {
        guard let source = image.cgImage else { return nil }

        let width = 9
        let height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                )
            else {
                return false
            }

            context.interpolationQuality = .low
            context.draw(
                source,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
            return true
        }

        guard rendered else { return nil }

        var hash: UInt64 = 0
        for row in 0..<height {
            for column in 0..<(width - 1) {
                hash <<= 1
                if pixels[row * width + column] > pixels[row * width + column + 1] {
                    hash |= 1
                }
            }
        }
        return hash
    }
}

private nonisolated struct Fingerprint: Sendable {
    let asset: PhotoAsset
    let hash: UInt64
    let creationDate: Date
    let aspectRatio: Double
}

private final class FingerprintGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Fingerprint?, Never>?

    init(_ continuation: CheckedContinuation<Fingerprint?, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Fingerprint?) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }
}
