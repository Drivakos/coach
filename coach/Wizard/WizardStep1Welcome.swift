import SwiftUI

struct WizardStep1Welcome: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "figure.walk.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Welcome to Coach")
                    .font(.largeTitle.bold())
                Text("Let's personalise your experience.\nThis will only take a minute.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    WizardStep1Welcome()
}
