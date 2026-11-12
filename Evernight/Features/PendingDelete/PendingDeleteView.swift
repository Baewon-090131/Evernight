import Foundation
import SwiftUI

struct PendingDeleteView: View {
    @Environment(PhotoLibraryStore.self) private var library

    @State private var progress: CGFloat = 0
    @State private var isDeleting = false
    @State private var receipt: DeleteReceipt?
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack {
            EvernightBackground()

            VStack(spacing: 16) {
                header

                if let receipt {
                    successState(receipt)
                    Spacer(minLength: 0)
                    deleteRail
                } else if library.pendingAssets.isEmpty {
                    ContentUnavailableView(
                        "待删除区是空的",
                        systemImage: "trash.slash",
                        description: Text("在滑动整理时向上滑，项目会先来到这里等待复核。")
                    )
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(library.pendingAssets) { asset in
                                pendingTile(asset)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .scrollIndicators(.hidden)

                    deleteRail
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .navigationTitle("待删除")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: library.pendingAssets.count) { _, _ in
            if receipt == nil {
                progress = 0
            }
        }
        .alert(
            "删除未完成",
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

    private func successState(_ receipt: DeleteReceipt) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(AppTheme.brightRed)

            Text("已完成删除")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            Text("\(receipt.count) 项已交给系统相册处理，可在“最近删除”中恢复。")
                .font(.body)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(library.pendingAssets.count) 项待复核")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text("删除前还会经过 iOS 系统确认")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            Text(ByteCountFormatter.string(
                fromByteCount: library.pendingEstimatedBytes,
                countStyle: .file
            ))
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
        }
    }

    private func pendingTile(_ asset: PhotoAsset) -> some View {
        ZStack(alignment: .topTrailing) {
            PhotoThumbnailView(
                asset: asset,
                targetSize: CGSize(width: 240, height: 320)
            )
            .aspectRatio(0.78, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                library.removeFromDeleteQueue(asset.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(AppTheme.ink)
                    .background(AppTheme.red, in: Circle())
            }
            .padding(7)
            .accessibilityLabel("移出待删除区")
        }
    }

    private var deleteRail: some View {
        GeometryReader { proxy in
            let knob: CGFloat = 54
            let travel = max(proxy.size.width - knob - 12, 1)
            let x = progress * travel
            let completed = receipt != nil

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.surface)
                    .overlay {
                        Capsule().stroke(AppTheme.red.opacity(completed ? 0.8 : 0.38), lineWidth: 1)
                    }

                Capsule()
                    .fill(AppTheme.red)
                    .frame(width: max(knob + x, 1))

                Text(railLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 64)

                if isDeleting {
                    ProgressView()
                        .tint(AppTheme.ink)
                        .offset(x: x + 17)
                } else {
                    Image(systemName: completed ? "checkmark" : "arrow.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.red)
                        .frame(width: knob, height: knob)
                        .background(AppTheme.ink, in: Circle())
                        .offset(x: x + 6)
                }
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !isDeleting, receipt == nil else { return }
                        let raw = (value.location.x - knob / 2 - 6) / travel
                        progress = min(max(raw, 0), 1)
                    }
                    .onEnded { _ in
                        guard !isDeleting, receipt == nil else { return }
                        if progress >= 0.94 {
                            progress = 1
                            Task { await performDeletion() }
                        } else {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                progress = 0
                            }
                        }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(railLabel)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    progress = min(progress + 0.2, 1)
                case .decrement:
                    progress = max(progress - 0.2, 0)
                @unknown default:
                    break
                }
            }
            .accessibilityAction(named: "确认删除") {
                guard !isDeleting, receipt == nil else { return }
                progress = 1
                Task { await performDeletion() }
            }
        }
        .frame(height: 62)
    }

    private var railLabel: String {
        if let receipt {
            return "已完成 · 删除 \(receipt.count) 项 · 释放 \(formattedBytes(receipt.estimatedBytes))"
        }
        if isDeleting {
            return "正在交给系统相册处理…"
        }
        return "向右拖动确认删除 \(library.pendingAssets.count) 项"
    }

    private func performDeletion() async {
        isDeleting = true
        errorMessage = nil

        do {
            let result = try await library.deletePendingAssets()
            receipt = result
            progress = 1
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                progress = 0
            }
        }

        isDeleting = false
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#Preview("Pending Delete") {
    NavigationStack {
        PendingDeleteView()
            .environment(PhotoLibraryStore())
    }
    .preferredColorScheme(.dark)
}
