import Foundation
import SwiftUI

struct SortingView: View {
    @Environment(PhotoLibraryStore.self) private var library

    let month: MonthKey

    @State private var deck = SortingDeck()
    @State private var dragOffset = CGSize.zero
    @State private var isAnimating = false
    @State private var presentedSheet: SortSheet?
    @State private var errorMessage: String?
    @AppStorage(PlaybackPreferences.videoAutoplayKey) private var videoAutoplayEnabled =
        PlaybackPreferences.videoAutoplayDefault
    @AppStorage(PlaybackPreferences.livePhotoAutoplayKey) private var livePhotoAutoplayEnabled =
        PlaybackPreferences.livePhotoAutoplayDefault
    @AppStorage("evernight.hasSeenGestureGuide") private var hasSeenGestureGuide = false

    var body: some View {
        ZStack {
            EvernightBackground()

            VStack(spacing: 14) {
                if library.isLoading && !library.hasLoaded {
                    ProgressView("正在读取相册…")
                        .tint(AppTheme.brightRed)
                        .foregroundStyle(AppTheme.muted)
                } else if let asset = deck.current {
                    cardStack(asset)
                } else {
                    finishedState
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .navigationTitle(month.shortTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                mediaMenu
            }

            ToolbarItem(placement: .topBarTrailing) {
                Text(positionText)
                    .font(AppFont.pingFang(12, weight: .semibold))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .task {
            if !library.hasLoaded {
                await library.reload()
            }
            rebuildDeck()
            if !hasSeenGestureGuide {
                hasSeenGestureGuide = true
                presentedSheet = .gestureGuide
            }
        }
        .onChange(of: library.mediaScope) { _, _ in
            rebuildDeck()
        }
        .onChange(of: library.assets.count) { _, _ in
            rebuildDeck()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .albumPicker:
                NavigationStack {
                    AlbumPickerView(showsCloseButton: true)
                }
                .presentationDetents([.fraction(0.8), .large])
                .presentationDragIndicator(.visible)
            case .gestureGuide:
                GestureGuideView()
            }
        }
        .alert(
            "操作未完成",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var mediaMenu: some View {
        Menu {
            ForEach(MediaScope.allCases) { scope in
                Button {
                    library.mediaScope = scope
                } label: {
                    Label(
                        scope.title,
                        systemImage: scope == library.mediaScope
                            ? "checkmark"
                            : scope.systemImage
                    )
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(library.mediaScope.title)
                Image(systemName: "chevron.down")
                    .font(AppFont.pingFang(11, weight: .bold))
            }
            .font(AppFont.pingFang(12, weight: .semibold))
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .modifier(GlassCapsuleModifier(tint: AppTheme.red.opacity(0.18)))
        .accessibilityLabel("选择媒体类型")
    }

    private var positionText: String {
        guard !deck.assets.isEmpty else { return "0 / 0" }
        return "\(min(deck.cursor + 1, deck.assets.count)) / \(deck.assets.count)"
    }

    private var finishedState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(AppFont.pingFang(54, weight: .thin))
                .foregroundStyle(AppTheme.brightRed)
            Text(finishedTitle)
                .font(AppFont.title2)
                .foregroundStyle(AppTheme.ink)
            Text(finishedMessage)
                .font(AppFont.body)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)

            if library.processedCount(in: month, scope: library.mediaScope) > 0 {
                Button("重新整理本月") {
                    library.resetProgress(for: month)
                    rebuildDeck()
                }
                .modifier(AdaptivePrimaryButtonStyle())
                .padding(.top, 6)
            } else if !deck.assets.isEmpty {
                Button("重新查看") {
                    rebuildDeck()
                }
                .modifier(AdaptivePrimaryButtonStyle())
                .padding(.top, 6)
            }
            Spacer()
        }
        .padding(28)
    }

    private func cardStack(_ asset: PhotoAsset) -> some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 8, 374)
            let height = min(proxy.size.height - 12, width * 1.43)
            let targetSize = CGSize(width: width * 2.5, height: height * 2.5)

            ZStack {
                if let next = deck.next {
                    PhotoThumbnailView(asset: next, targetSize: targetSize)
                        .id(next.id)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .scaleEffect(0.94)
                        .offset(y: 14)
                        .opacity(0.56)
                }

                swipeCard(
                    asset,
                    width: width,
                    height: height,
                    targetSize: targetSize
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func swipeCard(
        _ asset: PhotoAsset,
        width: CGFloat,
        height: CGFloat,
        targetSize: CGSize
    ) -> some View {
        ZStack(alignment: .bottomLeading) {
            MediaPlaybackView(
                asset: asset,
                targetSize: targetSize,
                videoAutoplayEnabled: videoAutoplayEnabled,
                livePhotoAutoplayEnabled: livePhotoAutoplayEnabled,
                isPlaybackAllowed: isPlaybackAllowed
            )
                .id(asset.id)

            LinearGradient(
                colors: [.clear, AppTheme.background.opacity(0.88)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 5) {
                Text(asset.mediaLabel)
                    .font(AppFont.pingFang(11, weight: .semibold))
                    .foregroundStyle(AppTheme.brightRed)
                Text(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "未知时间")
                    .font(AppFont.pingFang(15, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(metadata(for: asset))
                    .font(AppFont.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, asset.kind == .video ? 50 : 20)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let playbackBadge = playbackBadge(for: asset) {
                Text(playbackBadge)
                    .font(AppFont.pingFang(10, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule().stroke(AppTheme.hairline, lineWidth: 1)
                    }
                    .padding(14)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(dragAccent, lineWidth: dragBadge == nil ? 1 : 2)
        }
        .overlay(alignment: dragBadgeAlignment) {
            if let dragBadge {
                Image(systemName: dragBadge)
                    .font(AppFont.title2)
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 54, height: 54)
                    .background(AppTheme.red, in: Circle())
                    .padding(22)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .offset(dragOffset)
        .rotationEffect(.degrees(dragOffset.width / 26))
        .shadow(
            color: AppTheme.red.opacity(abs(dragOffset.height) > 40 ? 0.34 : 0.18),
            radius: 30,
            y: 22
        )
        .highPriorityGesture(dragGesture)
        .allowsHitTesting(!isAnimating)
        .accessibilityHint("向左下一项，向右撤回，向上加入待删除，向下放入目标相簿")
        .accessibilityAction(named: "下一张") {
            guard let asset = deck.current else { return }
            _ = deck.completeCurrent(.skip)
            library.recordSort(.skip, assetID: asset.id)
            Haptics.impact(.light)
        }
        .accessibilityAction(named: "撤回") {
            Task { await undo() }
        }
        .accessibilityAction(named: "加入待删除") {
            guard let asset = deck.current else { return }
            library.queueForDeletion(asset)
            _ = deck.completeCurrent(.queueDeletion)
            library.recordSort(.queueDeletion, assetID: asset.id)
            Haptics.impact(.medium)
        }
        .accessibilityAction(named: "放入相簿") {
            guard let asset = deck.current, let albumID = library.targetAlbumID else {
                presentedSheet = .albumPicker
                return
            }
            Task {
                do {
                    try await library.add(asset, to: albumID)
                    _ = deck.completeCurrent(.moveToAlbum(albumID))
                    library.recordSort(.moveToAlbum(albumID), assetID: asset.id)
                    Haptics.impact(.medium)
                } catch {
                    errorMessage = error.localizedDescription
                    Haptics.error()
                }
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isAnimating else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isAnimating else { return }
                resolve(value)
            }
    }

    private var isPlaybackAllowed: Bool {
        presentedSheet == nil && dragOffset == .zero && !isAnimating
    }

    private func playbackBadge(for asset: PhotoAsset) -> String? {
        if asset.kind == .video {
            return videoAutoplayEnabled ? "自动播放 · 开" : "自动播放 · 关"
        }
        guard asset.isLivePhoto else { return nil }
        return livePhotoAutoplayEnabled ? "实况 · 自动播放开" : "实况 · 按住播放"
    }

    private var dragBadge: String? {
        if dragOffset.height < -44 {
            return "trash.fill"
        }
        if dragOffset.height > 44 {
            return "folder.fill"
        }
        if dragOffset.width > 44 {
            return "arrow.uturn.backward"
        }
        if dragOffset.width < -44 {
            return "arrow.left"
        }
        return nil
    }

    private var dragBadgeAlignment: Alignment {
        if dragOffset.height < -44 { return .top }
        if dragOffset.height > 44 { return .bottom }
        if dragOffset.width > 44 { return .trailing }
        if dragOffset.width < -44 { return .leading }
        return .center
    }

    private var dragAccent: Color {
        guard let dragBadge else { return AppTheme.hairline }
        return dragBadge == "folder.fill" ? AppTheme.brightRed : AppTheme.red
    }

    private func resolve(_ value: DragGesture.Value) {
        let x = value.translation.width
        let y = value.translation.height
        let predictedX = value.predictedEndTranslation.width
        let predictedY = value.predictedEndTranslation.height
        let passed = max(abs(x), abs(y)) > 105
            || max(abs(predictedX), abs(predictedY)) > 175

        guard passed else {
            returnToRest()
            return
        }

        if abs(x) > abs(y) {
            if x < 0 {
                let asset = deck.current
                settle(off: CGSize(width: -720, height: y)) {
                    deck.completeCurrent(.skip)
                    if let asset {
                        library.recordSort(.skip, assetID: asset.id)
                    }
                    Haptics.impact(.light)
                }
            } else {
                settle(off: CGSize(width: 720, height: y)) {
                    await undo()
                }
            }
        } else if y < 0 {
            if let asset = deck.current {
                settle(off: CGSize(width: x, height: -900)) {
                    library.queueForDeletion(asset)
                    _ = deck.completeCurrent(.queueDeletion)
                    library.recordSort(.queueDeletion, assetID: asset.id)
                    Haptics.impact(.medium)
                }
            }
        } else {
            guard let asset = deck.current, let albumID = library.targetAlbumID else {
                returnToRest()
                presentedSheet = .albumPicker
                return
            }
            settle(off: CGSize(width: x, height: 900)) {
                do {
                    try await library.add(asset, to: albumID)
                    _ = deck.completeCurrent(.moveToAlbum(albumID))
                    library.recordSort(.moveToAlbum(albumID), assetID: asset.id)
                    Haptics.impact(.medium)
                } catch {
                    errorMessage = error.localizedDescription
                    Haptics.error()
                }
            }
        }
    }

    private func settle(off: CGSize, action: @escaping @MainActor () async -> Void) {
        isAnimating = true
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = off
        }

        Task {
            try? await Task.sleep(for: .milliseconds(190))
            await action()
            dragOffset = .zero
            isAnimating = false
        }
    }

    private func returnToRest() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            dragOffset = .zero
        }
    }

    private func undo() async {
        guard let step = deck.undoLastAction() else {
            errorMessage = "还没有可以撤回的整理动作。"
            Haptics.error()
            return
        }

        do {
            switch step.action {
            case .skip:
                break
            case .queueDeletion:
                library.removeFromDeleteQueue(step.asset.id)
            case .moveToAlbum(let albumID):
                try await library.remove(step.asset, from: albumID)
            }
            library.revertSort(step.action, assetID: step.asset.id)
            Haptics.impact(.light)
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    private func rebuildDeck() {
        deck.replaceAssets(
            library.sortingAssets(for: month, scope: library.mediaScope)
        )
        dragOffset = .zero
        isAnimating = false
    }

    private func metadata(for asset: PhotoAsset) -> String {
        if asset.kind == .video {
            let seconds = Int(asset.duration.rounded())
            return "\(seconds / 60):\(String(format: "%02d", seconds % 60)) · \(asset.pixelWidth)×\(asset.pixelHeight)"
        }
        return "\(asset.pixelWidth)×\(asset.pixelHeight)"
    }

    private var finishedTitle: String {
        if library.processedCount(in: month, scope: library.mediaScope) > 0 {
            return "本月已整理完"
        }
        return "这个范围没有待整理媒体"
    }

    private var finishedMessage: String {
        if library.processedCount(in: month, scope: library.mediaScope) > 0 {
            return "待删除项目会先进入复核区，不会直接删除。"
        }
        return "切换媒体类型，或前往逐月选择其他月份。"
    }
}

private enum SortSheet: String, Identifiable {
    case albumPicker
    case gestureGuide

    var id: String { rawValue }
}

#Preview("Sorting") {
    NavigationStack {
        SortingView(month: .current())
            .environment(PhotoLibraryStore())
    }
    .preferredColorScheme(.dark)
}
