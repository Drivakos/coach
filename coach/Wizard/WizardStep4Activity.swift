import SwiftUI

struct WizardStep4Activity: View {
    @Bindable var data: WizardData

    private let levels: [(id: String, title: String, subtitle: String, icon: String)] = [
        ("sedentary",         "Sedentary",          "Little or no exercise",            "sofa"),
        ("lightly_active",    "Lightly Active",     "Light exercise 1–3 days/week",     "figure.walk"),
        ("moderately_active", "Moderately Active",  "Moderate exercise 3–5 days/week",  "figure.run"),
        ("very_active",       "Very Active",        "Hard exercise 6–7 days/week",      "figure.highintensity.intervaltraining"),
        ("extra_active",      "Extra Active",       "Very hard exercise or physical job","bolt.fill"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardStepHeader(
                title: "Activity Level",
                subtitle: "How active are you on a typical week?"
            )

            VStack(spacing: 10) {
                ForEach(levels, id: \.id) { level in
                    ActivityCard(
                        title: level.title,
                        subtitle: level.subtitle,
                        icon: level.icon,
                        isSelected: data.activityLevel == level.id
                    )
                    .onTapGesture { data.activityLevel = level.id }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct ActivityCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    WizardStep4Activity(data: WizardData())
}
