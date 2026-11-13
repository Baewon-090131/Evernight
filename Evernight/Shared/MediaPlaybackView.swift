import AVFoundation
import AVKit
import Photos
import PhotosUI
import SwiftUI
import UIKit

nonisolated enum PlaybackPreferences {
    static let videoAutoplayKey = "evernight.playback.videoAutoplay"
    static let livePhotoAutoplayKey = "evernight.playback.livePhotoAutoplay"
    static let videoAutoplayDefault = true
    static let livePhotoAutoplayDefault = false
}

struct MediaPlaybackView: View {
    let asset: PhotoAsset
    let targetSize: CGSize
    let videoAutoplayEnabled: Bool
    let livePhotoAutoplayEnabled: Bool
    let isPlaybackAllowed: Bool
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            switch asset.kind {
            case .video:
                VideoAssetPlaybackView(
                    asset: asset,
                    targetSize: targetSize,
                    autoplayEnabled: videoAutoplayEnabled,
                    isPlaybackAllowed: isPlaybackAllowed,
                    contentMode: contentMode
                )
            case .photo where asset.isLivePhoto:
                LivePhotoAssetPlaybackView(
                    asset: asset,
                    targetSize: targetSize,
                    autoplayEnabled: livePhotoAutoplayEnabled,
                    isPlaybackAllowed: isPlaybackAllowed,
                    contentMode: contentMode
                )
            case .photo, .other:
                PhotoThumbnailView(
                    asset: asset,
                    targetSize: targetSize,
                    contentMode: contentMode
                )
            }
        }
    }
}

private struct VideoAssetPlaybackView: View {
    @Environment(PhotoLibraryStore.self) private var library
    @Environment(\.scenePhase) private var scenePhase

    let asset: PhotoAsset
    let targetSize: CGSize
    let autoplayEnabled: Bool
    let isPlaybackAllowed: Bool
    let contentMode: ContentMode

    @State private var player: AVPlayer?
    @State private var requestID: PHImageRequestID?
    @State private var hasAutoPlayed = false
    @State private var isVisible = false

    var body: some View {
        ZStack {
            AppTheme.background

            if let player {
                VideoPlayer(player: player)
            } else {
                PhotoThumbnailView(
                    asset: asset,
                    targetSize: targetSize,
                    contentMode: contentMode
                )
            }
        }
        .onAppear {
            isVisible = true
            load()
        }
        .onDisappear {
            isVisible = false
            stopAndRelease()
        }
        .onChange(of: isPlaybackAllowed) { _, _ in
            syncPlayback()
        }
        .onChange(of: scenePhase) { _, _ in
            syncPlayback()
        }
        .onChange(of: autoplayEnabled) { _, _ in
            syncPlayback()
        }
    }

    private func load() {
        guard player == nil, requestID == nil else { return }

        let request = library.requestVideoPlayerItem(for: asset.id) { item in
            requestID = nil
            guard isVisible, let item else { return }
            player = AVPlayer(playerItem: item)
            syncPlayback()
        }
        if player == nil {
            requestID = request
        }
    }

    private func syncPlayback() {
        guard let player else { return }

        guard isVisible, scenePhase == .active, isPlaybackAllowed else {
            player.pause()
            return
        }

        guard autoplayEnabled, !hasAutoPlayed else { return }
        hasAutoPlayed = true
        player.play()
    }

    private func stopAndRelease() {
        player?.pause()
        player = nil
        if let requestID {
            library.cancelMediaRequest(requestID)
            self.requestID = nil
        }
    }
}

private struct LivePhotoAssetPlaybackView: View {
    @Environment(PhotoLibraryStore.self) private var library
    @Environment(\.scenePhase) private var scenePhase

    let asset: PhotoAsset
    let targetSize: CGSize
    let autoplayEnabled: Bool
    let isPlaybackAllowed: Bool
    let contentMode: ContentMode

    @State private var livePhoto: PHLivePhoto?
    @State private var requestID: PHImageRequestID?
    @State private var autoPlayToken = 0
    @State private var hasAutoPlayed = false
    @State private var isVisible = false

    private var canPlayNow: Bool {
        scenePhase == .active && isPlaybackAllowed
    }

    var body: some View {
        ZStack {
            if let livePhoto {
                LivePhotoRepresentable(
                    livePhoto: livePhoto,
                    isPlaybackAllowed: canPlayNow,
                    autoPlayToken: autoPlayToken
                )
                .accessibilityLabel("实况照片")
                .accessibilityHint("按住播放实况")
            } else {
                PhotoThumbnailView(
                    asset: asset,
                    targetSize: targetSize,
                    contentMode: contentMode
                )
            }
        }
        .onAppear {
            isVisible = true
            load()
        }
        .onDisappear {
            isVisible = false
            stopAndRelease()
        }
        .onChange(of: isPlaybackAllowed) { _, _ in
            maybeAutoPlay()
        }
        .onChange(of: scenePhase) { _, _ in
            maybeAutoPlay()
        }
        .onChange(of: autoplayEnabled) { _, _ in
            maybeAutoPlay()
        }
    }

    private func load() {
        guard livePhoto == nil, requestID == nil else { return }

        let request = library.requestLivePhoto(
            for: asset.id,
            targetSize: targetSize
        ) { loadedPhoto in
            requestID = nil
            guard isVisible else { return }
            livePhoto = loadedPhoto
            maybeAutoPlay()
        }
        if livePhoto == nil {
            requestID = request
        }
    }

    private func maybeAutoPlay() {
        guard
            isVisible,
            livePhoto != nil,
            canPlayNow,
            autoplayEnabled,
            !hasAutoPlayed
        else {
            return
        }

        hasAutoPlayed = true
        autoPlayToken += 1
    }

    private func stopAndRelease() {
        livePhoto = nil
        if let requestID {
            library.cancelMediaRequest(requestID)
            self.requestID = nil
        }
    }
}

private struct LivePhotoRepresentable: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    let isPlaybackAllowed: Bool
    let autoPlayToken: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        view.isMuted = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        if view.livePhoto !== livePhoto {
            view.livePhoto = livePhoto
        }
        view.playbackGestureRecognizer.isEnabled = isPlaybackAllowed

        guard isPlaybackAllowed else {
            view.stopPlayback()
            return
        }

        if autoPlayToken != context.coordinator.lastAutoPlayToken {
            context.coordinator.lastAutoPlayToken = autoPlayToken
            if autoPlayToken > 0 {
                view.startPlayback(with: .full)
            }
        }
    }

    static func dismantleUIView(_ view: PHLivePhotoView, coordinator: Coordinator) {
        view.stopPlayback()
        view.livePhoto = nil
    }

    final class Coordinator: NSObject {
        var lastAutoPlayToken = 0
    }
}
