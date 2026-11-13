import Photos
import SwiftUI

struct RootView: View {
    @Environment(PhotoLibraryStore.self) private var library
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                switch library.authorizationStatus {
                case .notDetermined:
                    OnboardingView()
                case .authorized, .limited:
                    MainTabView()
                case .denied, .restricted:
                    PermissionDeniedView()
                @unknown default:
                    PermissionDeniedView()
                }
            }

            if scenePhase != .active {
                ZStack {
                    AppTheme.background
                    Image("ButterflyMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .opacity(0.8)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .background(AppTheme.background)
        .task {
            await library.bootstrapIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await library.refreshAuthorizationAndReload()
            }
        }
    }
}
