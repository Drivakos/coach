import SwiftUI

struct WizardStep5Goal: View {
    @Bindable var data: WizardData

    private let goals: [(goal: Goal, subtitle: String, icon: String)] = [
        (.loseWeight, "Calorie deficit to reduce body fat",  "arrow.down.circle"),
        (.maintain,   "Stay at your current weight",         "equal.circle"),
        (.gainMuscle, "Calorie surplus to build lean mass",  "arrow.up.circle"),
    ]

    private let splits: [(split: MacroSplit, label: String)] = [
        (.moderateCarb, "30 / 35 / 35"),
        (.lowerCarb,    "40 / 40 / 20"),
        (.higherCarb,   "30 / 20 / 50"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WizardStepHeader(
                    title: "Your Goal",
                    subtitle: "This adjusts your daily calorie target."
                )

                VStack(spacing: 12) {
                    ForEach(goals, id: \.goal) { item in
                        GoalCard(
                            title: item.goal.label,
                            subtitle: item.subtitle,
                            icon: item.icon,
                            isSelected: data.goal == item.goal
                        )
                        .onTapGesture { data.goal = item.goal }
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
                        ForEach(splits, id: \.split) { item in
                            let (pPct, fPct, cPct) = data.macroPercentages(for: item.split)
                            let cal = data.tdeeCalories
                            MacroSplitCard(
                                title: item.split.label,
                                label: item.label,
                                proteinG: Int((cal * pPct / 4).rounded()),
                                fatG:     Int((cal * fPct / 9).rounded()),
                                carbsG:   Int((cal * cPct / 4).rounded()),
                                isSelected: data.macroSplit == item.split
                            )
                            .onTapGesture { data.macroSplit = item.split }
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

    private var adjustment: Int { Int(data.goal.calorieAdjustment) }

    private var adjustmentLabel: String {
        switch data.goal {
        case .loseWeight: return "−300 kcal deficit"
        case .gainMuscle: return "+300 kcal surplus"
        case .maintain:   return "at maintenance"
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
