import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "house.fill") {
                DashboardView()
            }
            Tab("Diary", systemImage: "fork.knife") {
                ContentView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressTabView()
            }
            Tab("More", systemImage: "ellipsis.circle.fill") {
                ProfileView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
