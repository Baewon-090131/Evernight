import Photos
import SwiftUI
import UIKit

struct PhotoThumbnailView: View {
    @Environment(PhotoLibraryStore.self) private var library

    let asset: PhotoAsset
    let targetSize: CGSize
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    private var requestContentMode: PHImageContentMode {
        switch contentMode {
        case .fill:
            return .aspectFill
        case .fit:
            return .aspectFit
        @unknown default:
            return .aspectFill
        }
    }

    var body: some View {
        ZStack {
            AppTheme.raisedSurface

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: asset.kind.systemImage)
                    .font(AppFont.pingFang(24, weight: .light))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .clipped()
        .onAppear(perform: load)
        .onDisappear {
            if let requestID {
                library.cancelThumbnailRequest(requestID)
            }
        }
        .accessibilityLabel("\(asset.mediaLabel)，创建于 \(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "未知时间")")
    }

    private func load() {
        guard image == nil, requestID == nil else { return }
        requestID = library.requestThumbnail(
            for: asset.id,
            targetSize: targetSize,
            contentMode: requestContentMode
        ) { loadedImage in
            image = loadedImage
            requestID = nil
        }
    }
}
