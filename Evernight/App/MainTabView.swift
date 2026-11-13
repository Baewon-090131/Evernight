import SwiftUI

enum AppTab: Hashable {
    case tonight
    case months
    case smart
    case albums
    case settings
}

struct MainTabView: View {
    @State private var selection: AppTab = .tonight

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("今夜", systemImage: "moon.stars.fill")
            }
            .tag(AppTab.tonight)

            NavigationStack {
                MonthsView()
            }
            .tabItem {
                Label("逐月", systemImage: "calendar")
            }
            .tag(AppTab.months)

            NavigationStack {
                SmartSortView()
            }
            .tabItem {
                Label("智能", systemImage: "sparkles")
            }
            .tag(AppTab.smart)

            NavigationStack {
                AlbumsView()
            }
            .tabItem {
                Label("相簿", systemImage: "rectangle.stack.fill")
            }
            .tag(AppTab.albums)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("我的", systemImage: "person.crop.circle")
            }
            .tag(AppTab.settings)
        }
        .tint(AppTheme.red)
    }
}
