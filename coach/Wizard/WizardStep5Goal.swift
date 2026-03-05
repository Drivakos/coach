import SwiftUI

struct WizardStep5Goal: View {
    @Bindable var data: WizardData

    private let goals: [(id: String, title: String, subtitle: String, icon: String)] = [
        ("lose_weight", "Lose Weight",  "Calorie deficit to reduce body fat",  "arrow.down.circle"),
        ("maintain",    "Maintain",     "Stay at your current weight",         "equal.circle"),
        ("gain_muscle", "Gain Muscle",  "Calorie surplus to build lean mass",  "arrow.up.circle"),
    ]

    private let splits: [(id: String, title: String, label: String)] = [
        ("moderate_carb", "Moderate Carb", "30 / 35 / 35"),
        ("lower_carb",    "Lower Carb",    "40 / 40 / 20"),
        ("higher_carb",   "Higher Carb",   "30 / 20 / 50"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WizardStepHeader(
                    title: "Your Goal",
                    subtitle: "This adjusts your daily calorie target."
                )

                VStack(spacing: 12) {
                    ForEach(goals, id: \.id) { goal in
                        GoalCard(
                            title: goal.title,
                            subtitle: goal.subtitle,
                            icon: goal.icon,
                            isSelected: data.goal == goal.id
                        )
                        .onTapGesture { data.goal = goal.id }
                    }
                }

                CalorieSummaryCard(data: data)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Macro Split")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Protein / Fat / Carbs %")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(spacing: 8) {
                        ForEach(splits, id: \.id) { split in
                            let (pPct, fPct, cPct) = data.macroPercentages(for: split.id)
                            let cal = data.tdeeCalories
                            MacroSplitCard(
                                title: split.title,
                                label: split.label,
                                proteinG: Int((cal * pPct / 4).rounded()),
                                fatG:     Int((cal * fPct / 9).rounded()),
                                carbsG:   Int((cal * cPct / 4).rounded()),
                                isSelected: data.macroSplit == split.id
                            )
                            .onTapGesture { data.macroSplit = split.id }
                        }
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct CalorieSummaryCard: View {
    let data: WizardData

    private var adjustment: Int {
        switch data.goal {
        case "lose_weight": return -300
        case "gain_muscle": return +300
        default:            return 0
        }
    }

    private var adjustmentLabel: String {
        switch data.goal {
        case "lose_weight": return "−300 kcal deficit"
        case "gain_muscle": return "+300 kcal surplus"
        default:            return "at maintenance"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Maintenance TDEE")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(data.maintenanceCalories.rounded())) kcal")
                        .font(.headline.monospacedDigit())
                }
                Spacer()
                if adjustment != 0 {
                    Image(systemName: adjustment < 0 ? "minus" : "plus")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Your Target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(data.tdeeCalories.rounded())) kcal")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if adjustment != 0 {
                Divider()
                Text(adjustmentLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct GoalCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MacroSplitCard: View {
    let title: String
    let label: String
    let proteinG: Int
    let fatG: Int
    let carbsG: Int
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title row
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(label).font(.caption2).foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                }
            }

            // Macro grams row
            HStack(spacing: 0) {
                MacroGramColumn(grams: proteinG, label: "protein", color: isSelected ? .white : .red)
                Divider().frame(height: 28).opacity(isSelected ? 0.4 : 1)
                MacroGramColumn(grams: fatG,     label: "fat",     color: isSelected ? .white : .yellow)
                Divider().frame(height: 28).opacity(isSelected ? 0.4 : 1)
                MacroGramColumn(grams: carbsG,   label: "carbs",   color: isSelected ? .white : .blue)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct MacroGramColumn: View {
    let grams: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text("\(grams)g")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(color.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WizardStep5Goal(data: WizardData())
}
