import Foundation
import Photos
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(PhotoLibraryStore.self) private var library
    @Environment(\.openURL) private var openURL
    @State private var showsResetConfirmation = false
    @State private var showsProgressResetConfirmation = false
    @State private var showsGestureGuide = false

    var body: some View {
        ZStack {
            EvernightBackground()

            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppRelease.displayVersion)
                            .font(AppFont.title2)
                            .foregroundStyle(AppTheme.ink)
                        Text("逐月整理、相似照片、相簿管理与安全删除均在本机完成。")
                            .font(AppFont.footnote)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(.vertical, 8)
                }

                Section("整理") {
                    LabeledContent("可访问媒体", value: "\(library.assets.count)")
                    LabeledContent("用户相簿", value: "\(library.albums.count)")
                    LabeledContent("默认归档相簿", value: library.targetAlbum?.title ?? "未选择")
                    NavigationLink("管理相簿") {
                        AlbumsView()
                    }
                    Button("重置全部月份进度", role: .destructive) {
                        showsProgressResetConfirmation = true
                    }
                }

                Section("累计整理") {
                    LabeledContent("已处理项目", value: "\(library.statistics.sortedItemCount)")
                    LabeledContent("移入相簿", value: "\(library.statistics.movedToAlbumCount)")
                    LabeledContent("删除项目", value: "\(library.statistics.deletedItemCount)")
                    LabeledContent(
                        "预计释放空间",
                        value: ByteCountFormatter.string(
                            fromByteCount: library.statistics.estimatedFreedBytes,
                            countStyle: .file
                        )
                    )
                    Button("重置整理统计", role: .destructive) {
                        showsResetConfirmation = true
                    }
                }

                Section("隐私") {
                    Label("媒体在本机读取与索引", systemImage: "iphone")
                    Label("删除前由 iOS 系统再次确认", systemImage: "checkmark.shield")
                    Label("相似特征在本机比较", systemImage: "icloud.slash")
                }

                Section("权限") {
                    LabeledContent("相册权限", value: permissionTitle)
                    Button("打开系统设置") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                }

                Section("帮助") {
                    Button("手势说明") {
                        showsGestureGuide = true
                    }
                }

                Section("版本") {
                    LabeledContent("版本号", value: "0.1")
                    LabeledContent("发布名称", value: "Fall Asleep Beta")
                    LabeledContent("构建", value: "1")
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("我的")
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog(
            "重置整理统计？",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重置", role: .destructive) {
                library.resetStatistics()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会清除本地统计，不会修改相册或待删除项目。")
        }
        .confirmationDialog(
            "重置全部整理进度？",
            isPresented: $showsProgressResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重置进度", role: .destructive) {
                library.resetAllProgress()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("不会删除照片，只会让所有月份重新显示在滑动整理中。")
        }
        .sheet(isPresented: $showsGestureGuide) {
            GestureGuideView()
        }
    }

    private var permissionTitle: String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: "完全访问"
        case .limited: "受限访问"
        case .denied: "已拒绝"
        case .restricted: "受限制"
        case .notDetermined: "未选择"
        @unknown default: "未知"
        }
    }
}
