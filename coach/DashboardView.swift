import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Dashboard",
                systemImage: "house.fill",
                description: Text("Your daily summary will appear here.")
            )
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView()
}
