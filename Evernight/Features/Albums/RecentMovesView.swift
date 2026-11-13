import SwiftUI

struct RecentMovesView: View {
    @Environment(PhotoLibraryStore.self) private var library

    @State private var workingID: String?
    @State private var showsClearConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            EvernightBackground()

            if library.recentMoves.isEmpty {
                ContentUnavailableView(
                    "还没有移动记录",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("从滑卡页向下归档后，可以在这里撤销最近操作。")
                )
                .foregroundStyle(AppTheme.ink)
            } else {
                List {
                    ForEach(library.recentMoves) { move in
                        moveRow(move)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("最近移动")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !library.recentMoves.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空") {
                        showsClearConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog(
            "清空移动记录？",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空", role: .destructive) {
                library.clearRecentMoves()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会清除撤销记录，不会改变相簿里的照片。")
        }
        .alert(
            "撤销失败",
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

    private func moveRow(_ move: RecentMoveRecord) -> some View {
        HStack(spacing: 12) {
            if let asset = library.assets.first(where: { $0.id == move.assetID }) {
                PhotoThumbnailView(
                    asset: asset,
                    targetSize: CGSize(width: 160, height: 160)
                )
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundStyle(AppTheme.muted)
                    .frame(width: 58, height: 58)
                    .background(AppTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(move.albumTitle)
                    .font(AppFont.pingFang(14, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(move.movedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            Button(workingID == move.id ? "撤销中…" : "撤销") {
                Task { await undo(move) }
            }
            .font(AppFont.pingFang(12, weight: .semibold))
            .foregroundStyle(AppTheme.brightRed)
            .disabled(workingID != nil)
        }
        .padding(.vertical, 4)
    }

    private func undo(_ move: RecentMoveRecord) async {
        workingID = move.id
        errorMessage = nil
        do {
            try await library.undoRecentMove(move)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
        workingID = nil
    }
}
