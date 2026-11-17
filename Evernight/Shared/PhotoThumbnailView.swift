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
    @State private var hasFinalImage = false
    @State private var isVisible = false

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
                    .transition(.opacity)
            } else {
                Image(systemName: asset.kind.systemImage)
                    .font(AppFont.pingFang(24, weight: .light))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .clipped()
        .onAppear {
            isVisible = true
            load()
        }
        .onChange(of: asset.id) { _, _ in
            cancelRequest()
            image = nil
            hasFinalImage = false
            if isVisible {
                load()
            }
        }
        .onDisappear {
            isVisible = false
            cancelRequest()
        }
        .accessibilityLabel("\(asset.mediaLabel)，创建于 \(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "未知时间")")
    }

    private func load() {
        guard image == nil, requestID == nil else { return }
        let request = library.requestThumbnail(
            for: asset.id,
            targetSize: targetSize,
            contentMode: requestContentMode,
            preview: { previewImage in
                guard isVisible, !hasFinalImage else { return }
                image = previewImage
            }
        ) { finalImage in
            requestID = nil
            guard isVisible else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                hasFinalImage = true
                image = finalImage
            }
        }
        if !hasFinalImage {
            requestID = request
        }
    }

    private func cancelRequest() {
        guard let requestID else { return }
        library.cancelThumbnailRequest(requestID)
        self.requestID = nil
    }
}
