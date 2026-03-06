import SwiftUI
import Supabase

struct DailyCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var weightInput: String = ""
    @State private var workoutCompleted = false
    @State private var workoutNotes = ""
    @State private var steps: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var isLoadingSteps = true

    var existing: DailyCheckIn? = nil
    var onSaved: (DailyCheckIn) -> Void

    private let checkInService = CheckInService()

    var body: some View {
        NavigationStack {
            Form {
                weightSection
                workoutSection
                stepsSection
                photoSection

                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Morning Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .fontWeight(.semibold)
                        .disabled(weightInput.isEmpty)
                    }
                }
            }
            .task {
                populateFromExisting()
                await requestAndFetchSteps()
            }
        }
    }

    // MARK: - Sections

    private var weightSection: some View {
        Section {
            HStack {
                Image(systemName: "scalemass.fill")
                    .foregroundStyle(.tint)
                Text("Fasted Weight")
                Spacer()
                TextField("0.0", text: $weightInput)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                Text(appState.weightUnit.rawValue)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Morning Weight")
        } footer: {
            Text("Weigh yourself before eating or drinking anything.")
        }
    }

    private var workoutSection: some View {
        Section("Workout") {
            Toggle(isOn: $workoutCompleted) {
                Label("Worked out today", systemImage: "dumbbell.fill")
            }
            if workoutCompleted {
                TextField("Notes (optional — e.g. Push day, 45 min)", text: $workoutNotes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var stepsSection: some View {
        Section {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.tint)
                Text("Steps")
                Spacer()
                if isLoadingSteps {
                    ProgressView().scaleEffect(0.8)
                } else {
                    TextField("0", text: $steps)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
        } header: {
            Text("Activity")
        } footer: {
            Text("Auto-read from Apple Health. You can adjust if needed.")
        }
    }

    private var photoSection: some View {
        // TODO: Supabase Storage — add photo upload here
        Section {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundStyle(.secondary)
                Text("Progress Photo")
                Spacer()
                Text("Coming soon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Logic

    private func populateFromExisting() {
        guard let e = existing else { return }
        if let wkg = e.weightKg {
            let display = appState.weightUnit.convert(wkg)
            weightInput = String(format: "%.1f", display)
        }
        workoutCompleted = e.workoutCompleted
        workoutNotes = e.workoutNotes ?? ""
        if let s = e.steps { steps = "\(s)" }
    }

    private func requestAndFetchSteps() async {
        await HealthKitService.shared.requestPermission()
        if steps.isEmpty, let fetched = await HealthKitService.shared.fetchTodaySteps() {
            steps = "\(fetched)"
        }
        isLoadingSteps = false
    }

    private func save() async {
        isSaving = true
        saveError = nil
        do {
            let session = try await supabase.auth.session
            let weightKg: Double? = Double(weightInput).map { appState.weightUnit.toKg($0) }

            let payload = DailyCheckInUpsert(
                userId: session.user.id,
                date: CheckInService.todayString(),
                weightKg: weightKg,
                workoutCompleted: workoutCompleted,
                workoutNotes: workoutNotes.isEmpty ? nil : workoutNotes,
                steps: Int(steps)
            )

            let saved = try await checkInService.upsert(payload)
            onSaved(saved)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}
