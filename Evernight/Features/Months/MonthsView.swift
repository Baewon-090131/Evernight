import SwiftUI

struct MonthsView: View {
    @Environment(PhotoLibraryStore.self) private var library

    var body: some View {
        ZStack {
            EvernightBackground()

            ScrollView {
                LazyVStack(spacing: 12) {
                    if library.months.isEmpty && !library.isLoading {
                        ContentUnavailableView(
                            "还没有月份",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("相册中的照片和视频会按照拍摄时间出现在这里。")
                        )
                        .foregroundStyle(AppTheme.ink)
                        .padding(.top, 80)
                    }

                    ForEach(library.months) { month in
                        NavigationLink {
                            SortingView(month: month.key)
                        } label: {
                            monthRow(month)
                        }
                        .buttonStyle(.plain)
                    }

                    if library.undatedAssetCount > 0 {
                        Text("另有 \(library.undatedAssetCount) 个媒体没有拍摄日期，v0.1 暂不纳入按月整理。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await library.reload()
            }
        }
        .navigationTitle("逐月")
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await library.bootstrapIfNeeded()
        }
    }

    private func monthRow(_ month: PhotoMonth) -> some View {
        HStack(spacing: 15) {
            Group {
                if let preview = library.firstAsset(in: month.key) {
                    PhotoThumbnailView(
                        asset: preview,
                        targetSize: CGSize(width: 180, height: 180)
                    )
                } else {
                    AppTheme.raisedSurface
                }
            }
            .frame(width: 74, height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(month.key.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text("\(month.photoCount) 张照片 · \(month.videoCount) 个视频")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(month.totalCount)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(13)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }
}
