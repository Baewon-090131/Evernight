import SwiftUI

struct SmartSortView: View {
    @Environment(PhotoLibraryStore.self) private var library

    @State private var scanTask: Task<Void, Never>?

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
                    } else if library.hasCompletedSimilarScan {
                        if library.similarGroups.isEmpty {
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
                    } else {
                        scanInvitation
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
            ToolbarItem(placement: .topBarTrailing) {
                Label("整个相册", systemImage: "rectangle.stack.fill")
                    .font(AppFont.pingFang(11, weight: .semibold))
                    .foregroundStyle(AppTheme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .modifier(GlassCapsuleModifier(tint: AppTheme.red.opacity(0.16)))
            }
        }
        .task {
            await library.bootstrapIfNeeded()
            startScanIfNeeded()
        }
        .onChange(of: library.hasCompletedSimilarScan) { _, completed in
            if !completed {
                startScanIfNeeded()
            }
        }
        .onChange(of: library.isScanningSimilar) { _, isScanning in
            if !isScanning {
                startScanIfNeeded()
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("找回最值得留下的那一张")
                .font(AppFont.pingFang(30, weight: .semibold))
                .tracking(-0.9)
                .foregroundStyle(AppTheme.ink)
            Text("进入本页后自动扫描整个相册，在本机比较连拍、重复与近似照片，不再逐月询问。")
                .font(AppFont.subheadline)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var scanInvitation: some View {
        VStack(spacing: 15) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(AppFont.pingFang(42, weight: .light))
                .foregroundStyle(AppTheme.brightRed)

            Text("扫描整个相册")
                .font(AppFont.title2)
                .foregroundStyle(AppTheme.ink)

            Text("默认只触发一次全库扫描。完成后直接显示所有相似照片分组，不需要逐月确认。")
                .font(AppFont.body)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)

            PrimaryActionButton(
                title: "开始扫描",
                systemImage: "viewfinder"
            ) {
                startScan()
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
            Text("正在扫描整个相册…")
                .font(AppFont.body)
                .foregroundStyle(AppTheme.ink)
            Text("首次扫描需要读取缩略图。离开本页后扫描会继续，完成后自动刷新分组。")
                .font(AppFont.caption)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    private var emptyResult: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "没有发现相似照片",
                systemImage: "checkmark.seal",
                description: Text("整个相册中的照片差异都比较明显。")
            )
            .foregroundStyle(AppTheme.ink)

            Button("重新扫描") {
                startScan()
            }
            .modifier(AdaptivePrimaryButtonStyle())
        }
        .padding(.vertical, 28)
    }

    private var resultSummary: some View {
        HStack {
            Text("整个相册发现 \(library.similarGroups.count) 组可能重复的照片")
                .font(AppFont.pingFang(14, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Button("重扫") {
                startScan()
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
                        targetSize: CGSize(width: 540, height: 660),
                        contentMode: .fit
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

    private func startScanIfNeeded() {
        guard
            library.isAuthorized,
            !library.hasCompletedSimilarScan,
            !library.isScanningSimilar
        else {
            return
        }
        startScan()
    }

    private func startScan() {
        guard scanTask == nil else { return }
        scanTask = Task {
            await library.scanWholeLibrary()
            scanTask = nil
        }
    }
}
