import Foundation
import SwiftUI

struct HomeView: View {
    @Environment(PhotoLibraryStore.self) private var library

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
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)

            Text("今晚，从 \(library.latestMonth?.key.shortTitle ?? "最近") 开始")
                .font(.system(size: 34, weight: .semibold))
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
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    Text(month.key.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }

                Spacer()

                Text(String(format: "%02d", month.key.month))
                    .font(.system(size: 50, weight: .ultraLight))
                    .tracking(-2)
                    .foregroundStyle(AppTheme.ink)
            }

            HStack(spacing: 8) {
                monthMetric("\(month.photoCount)", "照片")
                monthMetric("\(month.videoCount)", "视频")
                monthMetric("\(month.totalCount)", "总计")
            }

            NavigationLink {
                SortingView(month: month.key)
            } label: {
                Label("开始滑动整理", systemImage: "arrow.left")
                    .font(.headline)
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
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.raisedSurface.opacity(0.8), in: RoundedRectangle(cornerRadius: 15))
    }

    private var quickStats: some View {
        HStack(spacing: 10) {
            NavigationLink {
                PendingDeleteView()
            } label: {
                statCard(
                    value: "\(library.pendingDeleteIDs.count)",
                    label: "待删除",
                    systemImage: "trash"
                )
            }
            .buttonStyle(.plain)

            statCard(
                value: "\(library.albums.count)",
                label: "可选相簿",
                systemImage: "rectangle.stack"
            )
            .allowsHitTesting(false)
        }
    }

    private func statCard(value: String, label: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.brightRed)
                .frame(width: 38, height: 38)
                .background(AppTheme.red.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(label)
                    .font(.caption)
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
        NavigationLink {
            AlbumPickerView()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(AppTheme.brightRed)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 3) {
                    Text("下滑归档相簿")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(library.targetAlbum?.title ?? "尚未选择")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
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

#Preview("Home") {
    NavigationStack {
        HomeView()
            .environment(PhotoLibraryStore())
    }
    .preferredColorScheme(.dark)
}
