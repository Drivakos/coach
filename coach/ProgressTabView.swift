import SwiftUI

struct ProgressTabView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Progress",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Your weight and body metrics will appear here.")
            )
            .navigationTitle("Progress")
        }
    }
}

#Preview {
    ProgressTabView()
}
