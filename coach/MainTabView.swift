import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var showCheckIn = false

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
        .sheet(isPresented: $showCheckIn) {
            DailyCheckInSheet { _ in }
                .environment(appState)
        }
        .onChange(of: appState.showCheckIn) { _, newValue in
            if newValue {
                showCheckIn = true
                appState.showCheckIn = false
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
