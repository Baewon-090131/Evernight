import Foundation
import SwiftUI

struct SortingView: View {
    @Environment(PhotoLibraryStore.self) private var library
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let month: MonthKey

    @State private var deck = SortingDeck()
    @State private var dragOffset = CGSize.zero
    @State private var currentCardOpacity = 1.0
    @State private var currentCardScale: CGFloat = 1
    @State private var isAnimating = false
    @State private var isAdvancing = false
    @State private var isUndoing = false
    @State private var lockedDragAxis: DragAxis?
    @State private var albumRailVisible = false
    @State private var selectedAlbumIndex = 2
    @State private var albumGestureStartIndex = 2
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                mediaMenu
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(month.shortTitle)
                        .font(AppFont.pingFang(15, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(positionText)
                        .font(AppFont.pingFang(10, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                pendingDeleteButton
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
            case .pendingDelete:
                NavigationStack {
                    PendingDeleteView()
                }
                .presentationDetents([.fraction(0.8), .large])
                .presentationDragIndicator(.visible)
            case .albumMore(let asset):
                SortingAlbumMoreSheet(asset: asset) { albumID in
                    completeAlbumAdditionFromSheet(asset, albumID: albumID)
                }
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

    private var pendingDeleteButton: some View {
        Button {
            presentedSheet = .pendingDelete
        } label: {
            Label("待删除 \(library.pendingDeleteIDs.count)", systemImage: "trash")
                .font(AppFont.pingFang(11, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
        }
        .modifier(GlassCapsuleModifier(tint: AppTheme.red.opacity(0.22)))
        .accessibilityLabel("打开待删除，当前 \(library.pendingDeleteIDs.count) 项")
    }

    private var positionText: String {
        guard !deck.assets.isEmpty else { return "0 / 0" }
        return "\(min(deck.cursor + 1, deck.assets.count)) / \(deck.assets.count)"
    }

    private var albumDropTargets: [AlbumDropTarget] {
        AlbumDropTarget.orderedTargets(for: library.albums)
    }

    private var safeSelectedAlbumIndex: Int {
        guard !albumDropTargets.isEmpty else { return 0 }
        return min(max(selectedAlbumIndex, 0), albumDropTargets.count - 1)
    }

    private var albumShrinkScale: CGFloat {
        guard albumRailVisible else { return 1 }
        let progress = min(max((dragOffset.height - 22) / 190, 0), 1)
        return 1 - progress * 0.78
    }

    private var renderedCardScale: CGFloat {
        currentCardScale * albumShrinkScale
    }

    private var isPlaybackAllowed: Bool {
        presentedSheet == nil
            && dragOffset == .zero
            && !isAnimating
            && !albumRailVisible
    }

    private func cardStack(_ asset: PhotoAsset) -> some View {
        GeometryReader { proxy in
            let containerSize = proxy.size
            let currentSize = mediaCardSize(for: asset, in: containerSize)
            let currentTargetSize = imageTargetSize(for: currentSize)
            let ambientTargetSize = CGSize(
                width: containerSize.width * displayScale,
                height: containerSize.height * displayScale
            )
            let next = deck.next
            let nextSize = next.map { mediaCardSize(for: $0, in: containerSize) }
            let nextTargetSize = nextSize.map { imageTargetSize(for: $0) }

            ZStack {
                ambientCard(
                    asset,
                    targetSize: ambientTargetSize,
                    opacity: isAdvancing || isUndoing ? 0 : 0.34
                )

                if let next, let nextSize, let nextTargetSize {
                    ambientCard(
                        next,
                        targetSize: ambientTargetSize,
                        opacity: isAdvancing ? 0.34 : 0.1
                    )

                    PhotoThumbnailView(
                        asset: next,
                        targetSize: nextTargetSize,
                        contentMode: .fit
                    )
                    .id(next.id)
                    .frame(width: nextSize.width, height: nextSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .scaleEffect(isAdvancing ? 1 : 0.94)
                    .offset(y: isAdvancing ? 0 : 14)
                    .opacity(
                        isUndoing
                            ? 0
                            : (isAdvancing ? 1 : (albumRailVisible ? 0.16 : 0.56))
                    )
                    .allowsHitTesting(false)
                }

                Rectangle()
                    .fill(AppTheme.background.opacity(albumRailVisible ? 0.2 : 0))
                    .allowsHitTesting(false)

                swipeCard(
                    asset,
                    size: currentSize,
                    targetSize: currentTargetSize,
                    containerSize: containerSize
                )

                if albumRailVisible {
                    VStack {
                        Spacer()
                        AlbumDropRail(
                            albums: library.albums,
                            selectedIndex: safeSelectedAlbumIndex
                        ) { target in
                            handleAlbumTargetTap(
                                target,
                                asset: asset,
                                containerSize: containerSize
                            )
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 2)
                        .allowsHitTesting(!isAnimating)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: DragCoordinateSpace.name)
        }
    }

    private func swipeCard(
        _ asset: PhotoAsset,
        size: CGSize,
        targetSize: CGSize,
        containerSize: CGSize
    ) -> some View {
        ZStack(alignment: .bottomLeading) {
            MediaPlaybackView(
                asset: asset,
                targetSize: targetSize,
                videoAutoplayEnabled: videoAutoplayEnabled,
                livePhotoAutoplayEnabled: livePhotoAutoplayEnabled,
                isPlaybackAllowed: isPlaybackAllowed,
                contentMode: .fit
            )
            .id(asset.id)

            LinearGradient(
                colors: [.clear, AppTheme.background.opacity(0.9)],
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
            .opacity(albumRailVisible ? 0 : 1)
            .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let playbackBadge = playbackBadge(for: asset), !albumRailVisible {
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
            if let dragBadge, !albumRailVisible {
                Image(systemName: dragBadge)
                    .font(AppFont.title2)
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 54, height: 54)
                    .background(AppTheme.red, in: Circle())
                    .padding(22)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(renderedCardScale)
        .offset(dragOffset)
        .rotationEffect(.degrees(albumRailVisible ? 0 : dragOffset.width / 26))
        .shadow(
            color: AppTheme.red.opacity(abs(dragOffset.height) > 40 ? 0.34 : 0.18),
            radius: 30,
            y: 22
        )
        .highPriorityGesture(
            dragGesture(containerSize: containerSize)
        )
        .allowsHitTesting(!isAnimating)
        .accessibilityHint("向左下一项，向右撤回上一步，向上加入待删除，向下选择相簿")
        .accessibilityAction(named: "下一张") {
            Task { await advance(asset, action: .skip, off: CGSize(width: -720, height: 0)) }
        }
        .accessibilityAction(named: "撤回") {
            Task {
                await undo(containerSize: CGSize(width: 360, height: 650))
            }
        }
        .accessibilityAction(named: "加入待删除") {
            Task {
                await advance(
                    asset,
                    action: .queueDeletion,
                    off: CGSize(width: 0, height: -760)
                )
            }
        }
        .accessibilityAction(named: "放入相簿") {
            guard let albumID = library.targetAlbumID else {
                albumRailVisible = true
                selectedAlbumIndex = initialAlbumSelectionIndex()
                return
            }
            Task {
                await animateAlbumAdd(
                    asset,
                    albumID: albumID,
                    dropX: 0,
                    containerSize: CGSize(width: 360, height: 650)
                )
            }
        }
    }

    private func ambientCard(
        _ asset: PhotoAsset,
        targetSize: CGSize,
        opacity: Double
    ) -> some View {
        PhotoThumbnailView(
            asset: asset,
            targetSize: targetSize,
            contentMode: .fill
        )
        .id("ambient-\(asset.id)")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(1.16)
        .blur(radius: 30)
        .opacity(opacity)
        .allowsHitTesting(false)
        .animation(cardAnimation(duration: 0.28), value: opacity)
    }

    private func dragGesture(containerSize: CGSize) -> some Gesture {
        DragGesture(
            minimumDistance: 10,
            coordinateSpace: .named(DragCoordinateSpace.name)
        )
        .onChanged { value in
            guard !isAnimating else { return }

            let x = value.translation.width
            let y = value.translation.height

            if lockedDragAxis == nil, max(abs(x), abs(y)) > 8 {
                lockedDragAxis = abs(x) > abs(y) ? .horizontal : .vertical
            }

            dragOffset = CGSize(width: x, height: y)

            guard lockedDragAxis == .vertical else {
                if albumRailVisible {
                    withAnimation(.easeOut(duration: 0.16)) {
                        albumRailVisible = false
                    }
                }
                return
            }

            let shouldShowRail = y > 26
            if shouldShowRail != albumRailVisible {
                if shouldShowRail {
                    albumGestureStartIndex = initialAlbumSelectionIndex()
                    selectedAlbumIndex = albumGestureStartIndex
                }
                withAnimation(.easeOut(duration: 0.18)) {
                    albumRailVisible = shouldShowRail
                }
            }

            if shouldShowRail {
                let horizontalLimit = containerSize.width * 0.42
                dragOffset = CGSize(
                    width: min(max(x, -horizontalLimit), horizontalLimit),
                    height: y
                )
                let stepWidth = albumRailItemWidth(containerWidth: containerSize.width) + 8
                let steps = Int((x / max(stepWidth, 1)).rounded())
                let lastIndex = max(albumDropTargets.count - 1, 0)
                selectedAlbumIndex = min(max(albumGestureStartIndex + steps, 0), lastIndex)
            }
        }
        .onEnded { value in
            guard !isAnimating else { return }
            resolve(value, containerSize: containerSize)
        }
    }

    private var dragBadge: String? {
        guard !albumRailVisible else { return nil }
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
        if albumRailVisible {
            return AppTheme.brightRed
        }
        guard let dragBadge else { return AppTheme.hairline }
        return dragBadge == "folder.fill" ? AppTheme.brightRed : AppTheme.red
    }

    private func resolve(_ value: DragGesture.Value, containerSize: CGSize) {
        let x = value.translation.width
        let y = value.translation.height
        let predictedX = value.predictedEndTranslation.width
        let predictedY = value.predictedEndTranslation.height

        if albumRailVisible {
            if y > 84 || predictedY > 120 {
                commitSelectedAlbum(
                    dragX: x,
                    containerSize: containerSize
                )
            } else {
                returnToRest()
            }
            return
        }

        let passed = max(abs(x), abs(y)) > 105
            || max(abs(predictedX), abs(predictedY)) > 175

        guard passed else {
            returnToRest()
            return
        }

        guard let asset = deck.current else {
            returnToRest()
            return
        }

        if abs(x) > abs(y) {
            if x < 0 {
                Task {
                    await advance(
                        asset,
                        action: .skip,
                        off: CGSize(width: -max(containerSize.width * 1.35, 720), height: y)
                    )
                }
            } else {
                Task { await undo(containerSize: containerSize) }
            }
        } else if y < 0 {
            Task {
                await advance(
                    asset,
                    action: .queueDeletion,
                    off: CGSize(width: x, height: -max(containerSize.height * 1.2, 760))
                )
            }
        } else {
            commitSelectedAlbum(dragX: x, containerSize: containerSize)
        }
    }

    private func commitSelectedAlbum(dragX: CGFloat, containerSize: CGSize) {
        guard
            let asset = deck.current,
            albumDropTargets.indices.contains(safeSelectedAlbumIndex)
        else {
            returnToRest()
            return
        }

        let target = albumDropTargets[safeSelectedAlbumIndex]
        switch target {
        case .more:
            presentedSheet = .albumMore(asset)
            returnToRest()
        case .album(let album):
            Task {
                await animateAlbumAdd(
                    asset,
                    albumID: album.id,
                    dropX: dragX,
                    containerSize: containerSize
                )
            }
        }
    }

    private func handleAlbumTargetTap(
        _ target: AlbumDropTarget,
        asset: PhotoAsset,
        containerSize: CGSize
    ) {
        switch target {
        case .more:
            presentedSheet = .albumMore(asset)
            returnToRest()
        case .album(let album):
            Task {
                await animateAlbumAdd(
                    asset,
                    albumID: album.id,
                    dropX: 0,
                    containerSize: containerSize
                )
            }
        }
    }

    private func completeAlbumAdditionFromSheet(
        _ asset: PhotoAsset,
        albumID: String
    ) {
        guard deck.current?.id == asset.id else { return }
        _ = deck.completeCurrent(.moveToAlbum(albumID))
        library.recordSort(.moveToAlbum(albumID), assetID: asset.id)
        resetPresentationState()
        Haptics.success()
    }

    private func advance(
        _ asset: PhotoAsset,
        action: SortingAction,
        off: CGSize
    ) async {
        guard !isAnimating else { return }
        isAnimating = true
        lockedDragAxis = nil
        albumRailVisible = false

        withAnimation(cardAnimation(duration: 0.28)) {
            isAdvancing = true
            currentCardOpacity = 0
            currentCardScale = 1.04
            dragOffset = off
        }

        try? await Task.sleep(for: .milliseconds(reduceMotion ? 16 : 280))

        if action == .queueDeletion {
            library.queueForDeletion(asset)
        }
        _ = deck.completeCurrent(action)
        library.recordSort(action, assetID: asset.id)
        resetPresentationState()

        if action == .queueDeletion {
            Haptics.impact(.medium)
        } else {
            Haptics.impact(.light)
        }
    }

    private func animateAlbumAdd(
        _ asset: PhotoAsset,
        albumID: String,
        dropX: CGFloat,
        containerSize: CGSize
    ) async {
        guard !isAnimating else { return }
        isAnimating = true
        lockedDragAxis = nil

        withAnimation(cardAnimation(duration: 0.22)) {
            isAdvancing = true
            let horizontalLimit = containerSize.width * 0.42
            dragOffset = CGSize(
                width: min(max(dropX, -horizontalLimit), horizontalLimit),
                height: max(containerSize.height / 2 - 56, 110)
            )
        }

        try? await Task.sleep(for: .milliseconds(reduceMotion ? 16 : 220))
        withAnimation(cardAnimation(duration: 0.12)) {
            currentCardOpacity = 0.12
        }

        do {
            try await library.add(asset, to: albumID)
            withAnimation(cardAnimation(duration: 0.12)) {
                currentCardOpacity = 0
            }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 120))
            _ = deck.completeCurrent(.moveToAlbum(albumID))
            library.recordSort(.moveToAlbum(albumID), assetID: asset.id)
            resetPresentationState()
            Haptics.impact(.medium)
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            returnToRest()
        }
    }

    private func undo(containerSize: CGSize) async {
        guard !isAnimating else { return }
        guard let step = deck.previousStep else {
            errorMessage = "还没有可以撤回的整理动作。"
            Haptics.error()
            returnToRest()
            return
        }

        isAnimating = true
        isUndoing = true
        lockedDragAxis = nil
        albumRailVisible = false

        withAnimation(cardAnimation(duration: 0.18)) {
            dragOffset = CGSize(width: 32, height: 0)
            currentCardOpacity = 0.22
            currentCardScale = 0.94
        }

        try? await Task.sleep(for: .milliseconds(reduceMotion ? 16 : 150))

        do {
            switch step.action {
            case .skip:
                break
            case .queueDeletion:
                library.removeFromDeleteQueue(step.asset.id)
            case .moveToAlbum(let albumID):
                try await library.remove(step.asset, from: albumID)
            }

            _ = deck.undoLastAction()
            library.revertSort(step.action, assetID: step.asset.id)

            let entryOffset = undoEntryOffset(
                for: step.action,
                containerSize: containerSize
            )
            withoutAnimation {
                dragOffset = entryOffset
                currentCardOpacity = 0
                currentCardScale = 0.92
                isUndoing = false
            }

            await Task.yield()

            withAnimation(undoAnimation) {
                dragOffset = .zero
                currentCardOpacity = 1
                currentCardScale = 1
            }

            try? await Task.sleep(for: .milliseconds(reduceMotion ? 16 : 460))
            isAnimating = false
            Haptics.impact(.light)
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            returnToRest()
        }
    }

    private func undoEntryOffset(
        for action: SortingAction,
        containerSize: CGSize
    ) -> CGSize {
        switch action {
        case .skip:
            CGSize(
                width: -max(containerSize.width * 1.2, 640),
                height: 0
            )
        case .queueDeletion:
            CGSize(
                width: 0,
                height: -max(containerSize.height, 680)
            )
        case .moveToAlbum:
            CGSize(
                width: 0,
                height: max(containerSize.height, 680)
            )
        }
    }

    private func resetPresentationState() {
        withoutAnimation {
            dragOffset = .zero
            currentCardOpacity = 1
            currentCardScale = 1
            isAnimating = false
            isAdvancing = false
            isUndoing = false
            lockedDragAxis = nil
            albumRailVisible = false
        }
    }

    private func returnToRest() {
        lockedDragAxis = nil
        isAnimating = true
        let animation = reduceMotion
            ? Animation.linear(duration: 0.01)
            : Animation.spring(response: 0.34, dampingFraction: 0.84)
        withAnimation(animation) {
            dragOffset = .zero
            currentCardOpacity = 1
            currentCardScale = 1
            isAdvancing = false
            isUndoing = false
            albumRailVisible = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 16 : 340))
            isAnimating = false
        }
    }

    private func rebuildDeck() {
        deck.replaceAssets(
            library.sortingAssets(for: month, scope: library.mediaScope)
        )
        resetPresentationState()
    }

    private func mediaCardSize(for asset: PhotoAsset, in bounds: CGSize) -> CGSize {
        let availableWidth = min(max(bounds.width - 8, 160), 374)
        let availableHeight = max(bounds.height - 12, 180)
        let ratio = CGFloat(max(asset.pixelWidth, 1)) / CGFloat(max(asset.pixelHeight, 1))

        var width = availableWidth
        var height = width / ratio
        if height > availableHeight {
            height = availableHeight
            width = height * ratio
        }
        if width < 96 {
            height = min(availableHeight, 96 / ratio)
            width = height * ratio
        }
        if height < 72 {
            width = min(availableWidth, 72 * ratio)
            height = width / ratio
        }
        return CGSize(width: width, height: height)
    }

    private func imageTargetSize(for cardSize: CGSize) -> CGSize {
        CGSize(
            width: cardSize.width * displayScale,
            height: cardSize.height * displayScale
        )
    }

    private func albumRailItemWidth(containerWidth: CGFloat) -> CGFloat {
        let railWidth = max(containerWidth - 16, 0)
        return max(44, (railWidth - 18 - 8 * 4) / 5)
    }

    private func initialAlbumSelectionIndex() -> Int {
        return min(2, max(albumDropTargets.count - 1, 0))
    }

    private func playbackBadge(for asset: PhotoAsset) -> String? {
        if asset.kind == .video {
            return videoAutoplayEnabled ? "自动播放 · 开" : "自动播放 · 关"
        }
        guard asset.isLivePhoto else { return nil }
        return livePhotoAutoplayEnabled ? "实况 · 自动播放开" : "实况 · 按住播放"
    }

    private func metadata(for asset: PhotoAsset) -> String {
        if asset.kind == .video {
            let seconds = Int(asset.duration.rounded())
            return "\(seconds / 60):\(String(format: "%02d", seconds % 60)) · \(asset.pixelWidth)×\(asset.pixelHeight)"
        }
        return "\(asset.pixelWidth)×\(asset.pixelHeight)"
    }

    private func cardAnimation(duration: Double) -> Animation {
        if reduceMotion {
            return .linear(duration: 0.01)
        }
        return .easeInOut(duration: duration)
    }

    private var undoAnimation: Animation {
        if reduceMotion {
            return .linear(duration: 0.01)
        }
        return .spring(response: 0.52, dampingFraction: 0.84)
    }

    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            updates()
        }
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

private enum DragAxis: Equatable {
    case horizontal
    case vertical
}

private enum DragCoordinateSpace {
    static let name = "sorting-card-area"
}

private enum SortSheet: Identifiable {
    case pendingDelete
    case albumMore(PhotoAsset)
    case gestureGuide

    var id: String {
        switch self {
        case .pendingDelete:
            "pending-delete"
        case .albumMore(let asset):
            "album-more-\(asset.id)"
        case .gestureGuide:
            "gesture-guide"
        }
    }
}

#Preview("Sorting") {
    NavigationStack {
        SortingView(month: .current())
            .environment(PhotoLibraryStore())
    }
    .preferredColorScheme(.dark)
}
