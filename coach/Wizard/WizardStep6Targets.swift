import SwiftUI

struct WizardStep6Targets: View {
    @Bindable var data: WizardData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WizardStepHeader(
                    title: "Nutrition Targets",
                    subtitle: "Based on your stats. You can adjust these any time."
                )

                // Calories
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Daily Calories")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(data.calorieTarget)) kcal")
                            .font(.subheadline.bold())
                            .monospacedDigit()
                    }
                    Slider(value: $data.calorieTarget, in: 1000...5000, step: 50)
                        .tint(.orange)
                }

                Divider()

                // Protein
                MacroSlider(
                    label: "Protein",
                    value: $data.proteinG,
                    range: 50...400,
                    unit: "g",
                    color: .red
                )

                // Carbs
                MacroSlider(
                    label: "Carbs",
                    value: $data.carbsG,
                    range: 50...600,
                    unit: "g",
                    color: .blue
                )

                // Fat
                MacroSlider(
                    label: "Fat",
                    value: $data.fatG,
                    range: 20...200,
                    unit: "g",
                    color: .yellow
                )

                // Macro summary
                MacroBreakdownBar(
                    protein: data.proteinG,
                    carbs: data.carbsG,
                    fat: data.fatG
                )

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct MacroSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value))\(unit)")
                    .font(.subheadline.bold())
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: 1)
                .tint(color)
        }
    }
}

private struct MacroBreakdownBar: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    private var total: Double { protein * 4 + carbs * 4 + fat * 9 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Macro breakdown")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red)
                        .frame(width: total > 0 ? geo.size.width * (protein * 4 / total) : 0)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue)
                        .frame(width: total > 0 ? geo.size.width * (carbs * 4 / total) : 0)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.yellow)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 10)
            }
            .frame(height: 10)
            HStack {
                Label("Protein", systemImage: "circle.fill").foregroundStyle(.red)
                Label("Carbs", systemImage: "circle.fill").foregroundStyle(.blue)
                Label("Fat", systemImage: "circle.fill").foregroundStyle(.yellow)
            }
            .font(.caption2)
        }
    }
}

#Preview {
    WizardStep6Targets(data: WizardData())
}
