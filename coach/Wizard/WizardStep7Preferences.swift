import SwiftUI

struct WizardStep7Preferences: View {
    @Bindable var data: WizardData

    private let options = [
        "vegan", "vegetarian", "keto", "paleo", "gluten-free", "dairy-free"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            WizardStepHeader(
                title: "Diet Preferences",
                subtitle: "Select all that apply. You can skip this step."
            )

            SelectionGrid(options: options, selected: $data.preferences)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    WizardStep7Preferences(data: WizardData())
}
