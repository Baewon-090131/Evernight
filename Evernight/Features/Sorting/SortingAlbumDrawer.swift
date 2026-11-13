import Photos
import SwiftUI
import UIKit

enum AlbumDropTarget: Identifiable {
    case album(PhotoAlbum)
    case more

    var id: String {
        switch self {
        case .album(let album): "album-\(album.id)"
        case .more: "more"
        }
    }

    var photoAlbum: PhotoAlbum? {
        guard case .album(let album) = self else { return nil }
        return album
    }

    static func orderedTargets(for albums: [PhotoAlbum]) -> [AlbumDropTarget] {
        let initialAlbums = albums.prefix(4).map { AlbumDropTarget.album($0) }
        let remainingAlbums = albums.dropFirst(4).map { AlbumDropTarget.album($0) }
        return initialAlbums + [.more] + remainingAlbums
    }
}

struct AlbumDropRail: View {
    let albums: [PhotoAlbum]
    let selectedIndex: Int
    let onTap: (AlbumDropTarget) -> Void

    private var targets: [AlbumDropTarget] {
        AlbumDropTarget.orderedTargets(for: albums)
    }

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 8
            let horizontalPadding: CGFloat = 18
            let itemWidth = max(
                44,
                (proxy.size.width - horizontalPadding - spacing * 4) / 5
            )

            ScrollViewReader { reader in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: spacing) {
                        ForEach(targets.indices, id: \.self) { index in
                            let target = targets[index]
                            targetButton(
                                target,
                                selected: index == selectedIndex,
                                width: itemWidth
                            )
                            .id(target.id)
                        }
                    }
                    .padding(.horizontal, horizontalPadding / 2)
                    .padding(.vertical, 9)
                }
                .scrollIndicators(.hidden)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                }
                .onAppear {
                    guard targets.indices.contains(selectedIndex) else { return }
                    reader.scrollTo(targets[selectedIndex].id, anchor: .center)
                }
                .onChange(of: selectedIndex) { _, newValue in
                    guard targets.indices.contains(newValue) else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        reader.scrollTo(targets[newValue].id, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 96)
    }

    private func targetButton(
        _ target: AlbumDropTarget,
        selected: Bool,
        width: CGFloat
    ) -> some View {
        Button {
            onTap(target)
        } label: {
            VStack(spacing: 5) {
                albumCover(for: target)
                    .frame(width: 48, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                selected ? AppTheme.brightRed : AppTheme.hairline,
                                lineWidth: selected ? 2 : 1
                            )
                    }
                    .shadow(
                        color: selected ? AppTheme.red.opacity(0.42) : .clear,
                        radius: 14,
                        y: 6
                    )

                Text(targetTitle(target))
                    .font(AppFont.pingFang(9, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? AppTheme.brightRed : AppTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: width)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(targetTitle(target))
    }

    @ViewBuilder
    private func albumCover(for target: AlbumDropTarget) -> some View {
        switch target {
        case .album(let album):
            AlbumCoverView(
                assetID: album.coverAssetID,
                targetSize: CGSize(width: 144, height: 174)
            )
        case .more:
            ZStack {
                AppTheme.raisedSurface
                Image(systemName: "ellipsis")
                    .font(AppFont.pingFang(18, weight: .semibold))
                    .foregroundStyle(AppTheme.brightRed)
            }
        }
    }

    private func targetTitle(_ target: AlbumDropTarget) -> String {
        target.photoAlbum?.title ?? "更多"
    }
}

struct SortingAlbumMoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoLibraryStore.self) private var library

    let asset: PhotoAsset
    let onAdded: (String) -> Void

    @State private var addingAlbumID: String?
    @State private var addedAlbumID: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                EvernightBackground()

                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(library.albums) { album in
                            albumRow(album)
                        }
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("更多相簿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.8), .large])
        .presentationDragIndicator(.visible)
        .alert(
            "添加未完成",
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

    private func albumRow(_ album: PhotoAlbum) -> some View {
        HStack(spacing: 12) {
            AlbumCoverView(
                assetID: album.coverAssetID,
                targetSize: CGSize(width: 156, height: 186)
            )
            .frame(width: 52, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(AppFont.pingFang(16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text("\(album.assetCount) 项")
                    .font(AppFont.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer(minLength: 8)

            Button {
                Task { await add(asset, to: album) }
            } label: {
                Group {
                    if addingAlbumID == album.id {
                        ProgressView()
                            .tint(AppTheme.brightRed)
                    } else {
                        Image(systemName: addedAlbumID == album.id ? "checkmark" : "plus")
                            .font(AppFont.pingFang(14, weight: .bold))
                            .foregroundStyle(AppTheme.brightRed)
                    }
                }
                .frame(width: 44, height: 44)
                .background(AppTheme.red.opacity(0.14), in: Circle())
                .overlay {
                    Circle().stroke(AppTheme.red.opacity(0.42), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(addingAlbumID != nil)
            .accessibilityLabel("添加到\(album.title)")
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    private func add(_ asset: PhotoAsset, to album: PhotoAlbum) async {
        guard addingAlbumID == nil else { return }
        addingAlbumID = album.id
        defer { addingAlbumID = nil }

        do {
            try await library.add(asset, to: album.id)
            addedAlbumID = album.id
            onAdded(album.id)
            try? await Task.sleep(for: .milliseconds(260))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }
}

private struct AlbumCoverView: View {
    @Environment(PhotoLibraryStore.self) private var library

    let assetID: String?
    let targetSize: CGSize

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        ZStack {
            AppTheme.raisedSurface

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "rectangle.stack.fill")
                    .font(AppFont.pingFang(18, weight: .light))
                    .foregroundStyle(AppTheme.brightRed)
            }
        }
        .clipped()
        .onAppear(perform: load)
        .onChange(of: assetID) { _, _ in
            cancelRequest()
            image = nil
            load()
        }
        .onDisappear(perform: cancelRequest)
    }

    private func load() {
        guard let assetID, image == nil, requestID == nil else { return }
        requestID = library.requestThumbnail(
            for: assetID,
            targetSize: targetSize,
            contentMode: .aspectFill
        ) { loadedImage in
            image = loadedImage
            requestID = nil
        }
    }

    private func cancelRequest() {
        guard let requestID else { return }
        library.cancelThumbnailRequest(requestID)
        self.requestID = nil
    }
}
