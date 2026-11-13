import SwiftUI

struct SimilarGroupDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoLibraryStore.self) private var library

    let group: SimilarGroup
    @State private var selectedIDs: Set<String>
    @State private var showsConfirmation = false

    private let columns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9)
    ]

    init(group: SimilarGroup) {
        self.group = group
        _selectedIDs = State(
            initialValue: Set(
                group.assets
                    .filter { $0.id != group.suggestedKeepID }
                    .map(\.id)
            )
        )
    }

    var body: some View {
        ZStack {
            EvernightBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("推荐项综合分辨率与拍摄时间生成。你可以逐张修改选择，最终只移入待删除区。")
                        .font(AppFont.caption)
                        .foregroundStyle(AppTheme.muted)

                    LazyVGrid(columns: columns, spacing: 9) {
                        ForEach(group.assets) { asset in
                            assetTile(asset)
                        }
                    }
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("相似照片")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .confirmationDialog(
            "将 \(selectedIDs.count) 个项目放入待删除区？",
            isPresented: $showsConfirmation,
            titleVisibility: .visible
        ) {
            Button("放入待删除区", role: .destructive) {
                queueSelected()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("它们仍可在待删除区复核，不会立即删除。")
        }
    }

    private func assetTile(_ asset: PhotoAsset) -> some View {
        let isSelected = selectedIDs.contains(asset.id)
        let isRecommended = asset.id == group.suggestedKeepID

        return Button {
            if isSelected {
                selectedIDs.remove(asset.id)
            } else {
                selectedIDs.insert(asset.id)
            }
            Haptics.impact(.light)
        } label: {
            ZStack(alignment: .topLeading) {
                PhotoThumbnailView(
                    asset: asset,
                    targetSize: CGSize(width: 440, height: 560)
                )
                .aspectRatio(0.78, contentMode: .fill)

                LinearGradient(
                    colors: [AppTheme.background.opacity(0.62), .clear],
                    startPoint: .top,
                    endPoint: .center
                )

                HStack(spacing: 6) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AppTheme.brightRed : AppTheme.ink)

                    if isRecommended {
                        Text("推荐保留")
                            .font(AppFont.pingFang(11, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                    }
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isRecommended ? AppTheme.brightRed : AppTheme.hairline,
                        lineWidth: isRecommended ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(isRecommended ? "推荐保留，" : "")\(asset.kind.title)，\(isSelected ? "已选择" : "未选择")"
        )
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("按推荐选择") {
                selectedIDs = Set(
                    group.assets
                        .filter { $0.id != group.suggestedKeepID }
                        .map(\.id)
                )
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.brightRed)

            Button("加入待删除 \(selectedIDs.count)") {
                showsConfirmation = true
            }
            .modifier(AdaptivePrimaryButtonStyle())
            .disabled(selectedIDs.isEmpty)
        }
        .font(AppFont.pingFang(14, weight: .semibold))
        .padding(12)
        .background(AppTheme.surface.opacity(0.96))
    }

    private func queueSelected() {
        for asset in group.assets where selectedIDs.contains(asset.id) {
            library.queueForDeletion(asset)
            library.recordSort(.queueDeletion, assetID: asset.id)
        }
        library.removeSimilarGroup(group.id)
        dismiss()
    }
}
