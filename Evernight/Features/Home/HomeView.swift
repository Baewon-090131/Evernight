import Foundation
import SwiftUI

struct HomeView: View {
    @Environment(PhotoLibraryStore.self) private var library
    @State private var presentedSheet: HomeSheet?

    var body: some View {
        ZStack {
            EvernightBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    greeting

                    if library.isLoading && !library.hasLoaded {
                        loadingCard
                    } else if let month = library.latestMonth {
                        currentMonthCard(month)
                        quickStats
                        targetAlbumCard
                    } else {
                        emptyLibraryCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await library.reload()
            }
        }
        .navigationTitle("今夜")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            if library.isAuthorized && !library.hasLoaded {
                await library.reload()
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .pendingDelete:
                    PendingDeleteView()
                case .albumPicker:
                    AlbumPickerView(showsCloseButton: true)
                }
            }
            .presentationDetents([.fraction(0.8), .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                .font(AppFont.pingFang(12, weight: .semibold))
                .foregroundStyle(AppTheme.muted)

            Text("今晚，从 \(library.latestMonth?.key.shortTitle ?? "最近") 开始")
                .font(AppFont.pingFang(34, weight: .semibold))
                .tracking(-1.1)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func currentMonthCard(_ month: PhotoMonth) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("当前整理")
                        .font(AppFont.caption)
                        .foregroundStyle(AppTheme.muted)
                    Text(month.key.title)
                        .font(AppFont.title2)
                        .foregroundStyle(AppTheme.ink)
                }

                Spacer()

                Text(String(format: "%02d", month.key.month))
                    .font(AppFont.pingFang(50, weight: .ultraLight))
                    .tracking(-2)
                    .foregroundStyle(AppTheme.ink)
            }

            HStack(spacing: 8) {
                monthMetric("\(month.photoCount)", "照片")
                monthMetric("\(month.videoCount)", "视频")
                monthMetric("\(month.totalCount)", "总计")
            }

            let processed = library.processedCount(in: month.key)
            VStack(spacing: 6) {
                ProgressView(
                    value: Double(processed),
                    total: Double(max(month.totalCount, 1))
                )
                .tint(AppTheme.brightRed)

                HStack {
                    Text("已处理 \(processed) / \(month.totalCount)")
                    Spacer()
                    Text("还剩 \(max(month.totalCount - processed, 0))")
                }
                .font(AppFont.caption2)
                .foregroundStyle(AppTheme.muted)
            }

            NavigationLink {
                SortingView(month: month.key)
            } label: {
                Label("开始滑动整理", systemImage: "arrow.left")
                    .font(AppFont.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.red)
        }
        .padding(20)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    private func monthMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(AppFont.title3)
                .foregroundStyle(AppTheme.ink)
            Text(label)
                .font(AppFont.caption2)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.raisedSurface.opacity(0.8), in: RoundedRectangle(cornerRadius: 15))
    }

    private var quickStats: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            statCard(
                value: "\(library.statistics.sortedItemCount)",
                label: "已整理",
                systemImage: "checkmark.circle"
            )

            Button {
                presentedSheet = .pendingDelete
            } label: {
                statCard(
                    value: "\(library.pendingDeleteIDs.count)",
                    label: "待删除",
                    systemImage: "trash"
                )
            }
            .buttonStyle(.plain)

            statCard(
                value: "\(library.statistics.movedToAlbumCount)",
                label: "已归档",
                systemImage: "folder"
            )

            statCard(
                value: "\(library.statistics.deletedItemCount)",
                label: "已删除",
                systemImage: "delete.left"
            )
        }
    }

    private func statCard(value: String, label: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(AppFont.pingFang(17, weight: .medium))
                .foregroundStyle(AppTheme.brightRed)
                .frame(width: 38, height: 38)
                .background(AppTheme.red.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(AppFont.title3)
                    .foregroundStyle(AppTheme.ink)
                Text(label)
                    .font(AppFont.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    private var targetAlbumCard: some View {
        Button {
            presentedSheet = .albumPicker
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(AppTheme.brightRed)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 3) {
                    Text("下滑归档相簿")
                        .font(AppFont.pingFang(15, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(library.targetAlbum?.title ?? "尚未选择")
                        .font(AppFont.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppFont.pingFang(12, weight: .semibold))
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(15)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.brightRed)
            Text("正在读取相册索引…")
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private var emptyLibraryCard: some View {
        ContentUnavailableView(
            "还没有可整理的媒体",
            systemImage: "photo.on.rectangle.angled",
            description: Text("先在系统相册中保存一些照片或视频，再回来开始整理。")
        )
        .foregroundStyle(AppTheme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}

private enum HomeSheet: String, Identifiable {
    case pendingDelete
    case albumPicker

    var id: String { rawValue }
}

#Preview("Home") {
    NavigationStack {
        HomeView()
            .environment(PhotoLibraryStore())
    }
    .preferredColorScheme(.dark)
}
