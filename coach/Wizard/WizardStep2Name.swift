import SwiftUI

struct WizardStep2Name: View {
    @Bindable var data: WizardData

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            WizardStepHeader(
                title: "What's your name?",
                subtitle: "We'll use this to personalise your experience."
            )

            TextField("Full name", text: $data.fullName)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .textContentType(.name)
                .submitLabel(.next)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    WizardStep2Name(data: WizardData())
}
