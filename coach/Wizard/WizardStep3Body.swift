import SwiftUI

struct WizardStep3Body: View {
    @Bindable var data: WizardData
    @State private var bodyFatText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WizardStepHeader(
                    title: "Body Stats",
                    subtitle: "Used to calculate your personalised calorie target."
                )

                // Sex
                VStack(alignment: .leading, spacing: 8) {
                    Text("Biological Sex").font(.subheadline).foregroundStyle(.secondary)
                    Picker("Sex", selection: $data.sex) {
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                    }
                    .pickerStyle(.segmented)
                }

                // Height
                VStack(alignment: .leading, spacing: 8) {
                    Text("Height").font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        Slider(value: $data.heightCm, in: 100...250, step: 1)
                        Text("\(Int(data.heightCm)) cm")
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }

                // Date of birth
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date of Birth").font(.subheadline).foregroundStyle(.secondary)
                    DatePicker(
                        "",
                        selection: $data.dateOfBirth,
                        in: dobRange,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }

                // Weight
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight").font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        Slider(value: $data.weightKg, in: 30...250, step: 0.5)
                        Text(String(format: "%.1f kg", data.weightKg))
                            .monospacedDigit()
                            .frame(width: 70, alignment: .trailing)
                    }
                }

                // Body fat % (optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Body Fat % (optional)").font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        TextField("e.g. 20", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: bodyFatText) {
                                data.bodyFatPct = Double(bodyFatText)
                            }
                        Text("%")
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
    }

    private var dobRange: ClosedRange<Date> {
        let min = Calendar.current.date(byAdding: .year, value: -100, to: Date())!
        let max = Calendar.current.date(byAdding: .year, value: -10, to: Date())!
        return min...max
    }
}

#Preview {
    WizardStep3Body(data: WizardData())
}
