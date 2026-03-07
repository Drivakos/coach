import SwiftUI

struct WizardStep4Activity: View {
    @Bindable var data: WizardData

    private let levels: [(level: ActivityLevel, subtitle: String, icon: String)] = [
        (.sedentary,        "Little or no exercise",             "sofa"),
        (.lightlyActive,    "Light exercise 1–3 days/week",      "figure.walk"),
        (.moderatelyActive, "Moderate exercise 3–5 days/week",   "figure.run"),
        (.veryActive,       "Hard exercise 6–7 days/week",       "figure.highintensity.intervaltraining"),
        (.extraActive,      "Very hard exercise or physical job", "bolt.fill"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardStepHeader(
                title: "Activity Level",
                subtitle: "How active are you on a typical week?"
            )

            VStack(spacing: 10) {
                ForEach(levels, id: \.level) { item in
                    ActivityCard(
                        title: item.level.label,
                        subtitle: item.subtitle,
                        icon: item.icon,
                        isSelected: data.activityLevel == item.level
                    )
                    .onTapGesture { data.activityLevel = item.level }
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
