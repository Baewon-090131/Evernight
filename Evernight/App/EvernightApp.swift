import SwiftUI

@main
struct EvernightApp: App {
    @State private var library = PhotoLibraryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .preferredColorScheme(.dark)
                .tint(AppTheme.red)
        }
    }
}
