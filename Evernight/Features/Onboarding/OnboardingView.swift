import Foundation
import SwiftUI
import UIKit

struct OnboardingView: View {
    @Environment(PhotoLibraryStore.self) private var library
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            EvernightBackground()

            VStack(alignment: .leading, spacing: 0) {
                brand

                Spacer(minLength: 28)

                hero

                Spacer(minLength: 28)

                Text("让回忆\n各归其位")
                    .font(.system(size: 44, weight: .semibold))
                    .tracking(-1.4)
                    .foregroundStyle(AppTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("按月滑动整理照片和视频。相似内容识别、相簿合并等功能将在后续版本加入。")
                    .font(.body)
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(4)
                    .padding(.top, 14)

                Spacer(minLength: 26)

                PrimaryActionButton(
                    title: isRequesting ? "正在连接…" : "连接相册",
                    systemImage: "photo.badge.plus",
                    isEnabled: !isRequesting
                ) {
                    isRequesting = true
                    Task {
                        await library.requestAccess()
                        isRequesting = false
                    }
                }

                Label("仅在本机分析，删除前由系统再次确认", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 26)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image("ButterflyMark")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)

            Text("EVERNIGHT")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(AppTheme.brightRed)
        }
    }

    private var hero: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.red.opacity(0.25), lineWidth: 1)
                .frame(width: 280, height: 280)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.surface)
                .frame(width: 214, height: 286)
                .overlay(alignment: .bottomLeading) {
                    Text("MEMORY / 01")
                        .font(.caption2.monospaced())
                        .foregroundStyle(AppTheme.muted)
                        .padding(16)
                }
                .rotationEffect(.degrees(-6))
                .offset(x: -40, y: 18)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.red.opacity(0.9))
                .frame(width: 176, height: 238)
                .overlay {
                    Image("ButterflyMark")
                        .resizable()
                        .scaledToFit()
                        .padding(30)
                        .opacity(0.82)
                }
                .rotationEffect(.degrees(7))
                .offset(x: 58, y: -20)
                .shadow(color: AppTheme.red.opacity(0.35), radius: 30, y: 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 330)
    }
}

struct PermissionDeniedView: View {
    @Environment(PhotoLibraryStore.self) private var library
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            EvernightBackground()

            VStack(spacing: 20) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(AppTheme.brightRed)

                VStack(spacing: 8) {
                    Text("需要相册权限")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)

                    Text("Evernight 需要读取和添加照片。你可以随时在系统设置中调整权限。")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.muted)
                }

                PrimaryActionButton(
                    title: "打开系统设置",
                    systemImage: "gear"
                ) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }

                Button("重新检查权限") {
                    Task {
                        await library.bootstrapIfNeeded()
                    }
                }
                .foregroundStyle(AppTheme.brightRed)
            }
            .padding(28)
        }
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .environment(PhotoLibraryStore())
        .preferredColorScheme(.dark)
}
