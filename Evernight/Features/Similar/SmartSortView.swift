import SwiftUI

struct SmartSortView: View {
    @Environment(PhotoLibraryStore.self) private var library

    @State private var selectedMonth: MonthKey?
    @State private var didScan = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            EvernightBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro

                    if library.isScanningSimilar {
                        scanningCard
                    } else if !didScan {
                        scanInvitation
                    } else if library.similarGroups.isEmpty {
                        emptyResult
                    } else {
                        resultSummary

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(library.similarGroups) { group in
                                NavigationLink {
                                    SimilarGroupDetailView(group: group)
                                } label: {
                                    similarCard(group)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("智能整理")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                monthMenu
            }
        }
        .task {
            if selectedMonth == nil {
                selectedMonth = library.latestMonth?.key
            }
        }
        .onChange(of: selectedMonth) { _, _ in
            didScan = false
            library.clearSimilarResults()
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("找回最值得留下的那一张")
                .font(AppFont.pingFang(30, weight: .semibold))
                .tracking(-0.9)
                .foregroundStyle(AppTheme.ink)
            Text("在本机比较连拍、重复与近似照片，不会上传相册内容。")
                .font(AppFont.subheadline)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var monthMenu: some View {
        Menu {
            ForEach(library.months) { month in
                Button {
                    selectedMonth = month.key
                } label: {
                    Label(
                        month.key.title,
                        systemImage: selectedMonth == month.key ? "checkmark" : "calendar"
                    )
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedMonth?.shortTitle ?? "选择月份")
                Image(systemName: "chevron.down")
                    .font(AppFont.pingFang(10, weight: .bold))
            }
            .font(AppFont.pingFang(12, weight: .semibold))
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .modifier(GlassCapsuleModifier(tint: AppTheme.red.opacity(0.18)))
        }
    }

    private var scanInvitation: some View {
        VStack(spacing: 15) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(AppFont.pingFang(42, weight: .light))
                .foregroundStyle(AppTheme.brightRed)

            Text("扫描 \(selectedMonth?.shortTitle ?? "当前月份") 的相似照片")
                .font(AppFont.title2)
                .foregroundStyle(AppTheme.ink)

            Text("只分析当前月份中的照片。扫描在本机完成，视频和没有拍摄日期的媒体暂不参与。")
                .font(AppFont.body)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)

            PrimaryActionButton(
                title: "开始扫描",
                systemImage: "viewfinder",
                isEnabled: selectedMonth != nil
            ) {
                Task { await scan() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    private var scanningCard: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(AppTheme.brightRed)
            Text("正在比较照片特征…")
                .font(AppFont.body)
                .foregroundStyle(AppTheme.ink)
            Text("首次扫描需要读取缩略图，完成后即可快速打开分组。")
                .font(AppFont.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    private var emptyResult: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "没有发现相似照片",
                systemImage: "checkmark.seal",
                description: Text("这个月份里的照片差异都比较明显。")
            )
            .foregroundStyle(AppTheme.ink)

            Button("重新扫描") {
                Task { await scan() }
            }
            .modifier(AdaptivePrimaryButtonStyle())
        }
        .padding(.vertical, 28)
    }

    private var resultSummary: some View {
        HStack {
            Text("发现 \(library.similarGroups.count) 组可能重复的照片")
                .font(AppFont.pingFang(14, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Button("重扫") {
                Task { await scan() }
            }
            .font(AppFont.caption)
            .foregroundStyle(AppTheme.brightRed)
        }
    }

    private func similarCard(_ group: SimilarGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(Array(group.assets.prefix(3))) { asset in
                    PhotoThumbnailView(
                        asset: asset,
                        targetSize: CGSize(width: 180, height: 180)
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(0.82, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.assets.first?.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "未知日期")
                        .font(AppFont.pingFang(13, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("\(group.assets.count) 张相似照片")
                        .font(AppFont.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AppFont.pingFang(11, weight: .bold))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(11)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    private func scan() async {
        guard let selectedMonth else { return }
        didScan = true
        await library.scanSimilar(in: selectedMonth)
    }
}
