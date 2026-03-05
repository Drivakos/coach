import SwiftUI

struct WizardStep8Allergies: View {
    @Bindable var data: WizardData

    private let options = [
        "nuts", "dairy", "eggs", "gluten", "soy", "shellfish", "fish", "wheat"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            WizardStepHeader(
                title: "Allergies",
                subtitle: "Select any foods you're allergic to. You can skip this step."
            )

            SelectionGrid(options: options, selected: $data.allergies)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    WizardStep8Allergies(data: WizardData())
}
