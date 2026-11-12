import Photos
import SwiftUI

struct RootView: View {
    @Environment(PhotoLibraryStore.self) private var library

    var body: some View {
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
        .background(AppTheme.background)
        .task {
            await library.bootstrapIfNeeded()
        }
    }
}
