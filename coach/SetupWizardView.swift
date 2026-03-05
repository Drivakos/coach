import SwiftUI

struct SetupWizardView: View {
    var onComplete: () -> Void

    @State private var data = WizardData()
    @State private var currentStep: Int = 0
    @State private var isSaving = false
    @State private var saveError: String? = nil

    private let totalSteps = 8

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(currentStep), total: Double(totalSteps - 1))
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // Steps via TabView (paging, no indicators)
            TabView(selection: $currentStep) {
                WizardStep1Welcome()
                    .tag(0)
                WizardStep2Name(data: data)
                    .tag(1)
                WizardStep3Body(data: data)
                    .tag(2)
                WizardStep4Activity(data: data)
                    .tag(3)
                WizardStep5Goal(data: data)
                    .tag(4)
                WizardStep6Targets(data: data)
                    .tag(5)
                WizardStep7Preferences(data: data)
                    .tag(6)
                WizardStep8Allergies(data: data)
                    .tag(7)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)

            // Error message
            if let error = saveError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }

            // Bottom navigation
            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }

                if currentStep < totalSteps - 1 {
                    Button("Next") {
                        // Recalculate TDEE when entering step 6 (Targets)
                        if currentStep == 4 {
                            data.recalculateTDEE()
                        }
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isStepValid)
                    .frame(maxWidth: .infinity)
                } else {
                    Button(isSaving ? "Saving…" : "Finish") {
                        Task { await finish() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || !isStepValid)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Validation

    private var isStepValid: Bool {
        switch currentStep {
        case 1: return !data.fullName.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    // MARK: - Save

    private func finish() async {
        isSaving = true
        saveError = nil
        do {
            try await WizardService().saveAll(data)
            onComplete()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

#Preview {
    SetupWizardView(onComplete: {})
}
