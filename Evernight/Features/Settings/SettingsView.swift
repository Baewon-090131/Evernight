import Foundation
import Photos
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(PhotoLibraryStore.self) private var library
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            EvernightBackground()

            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppRelease.displayVersion)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text("首版只保留整理相册所需的核心能力。")
                            .font(.footnote)
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
                }

                Section("隐私") {
                    Label("媒体在本机读取与索引", systemImage: "iphone")
                    Label("删除前由 iOS 系统再次确认", systemImage: "checkmark.shield")
                    Label("v0.1 不包含云端分析", systemImage: "icloud.slash")
                }

                Section("权限") {
                    LabeledContent("相册权限", value: permissionTitle)
                    Button("打开系统设置") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
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
