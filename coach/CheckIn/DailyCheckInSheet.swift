import SwiftUI
import Supabase
import PhotosUI

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
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?

    var existing: DailyCheckIn? = nil
    var onSaved: (DailyCheckIn) -> Void

    private let checkInService = CheckInService()
    private let photosBucket = "progress-photos"

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
        Section("Progress Photo") {
            if let data = selectedPhotoData, let uiImage = UIImage(data: data) {
                HStack(spacing: 12) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Photo selected")
                            .font(.subheadline)
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Text("Change")
                                .font(.caption)
                        }
                    }
                    Spacer()
                    Button(role: .destructive) {
                        selectedPhotoItem = nil
                        selectedPhotoData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else if let existingUrl = existing?.photoUrl {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: existingUrl)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color(.secondarySystemBackground)
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Current photo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text("Replace")
                            .font(.caption)
                    }
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Add Progress Photo", systemImage: "camera.fill")
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                if let image = UIImage(data: data) {
                    selectedPhotoData = image.jpegData(compressionQuality: 0.75)
                } else {
                    selectedPhotoData = data
                }
            }
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
            let userId = session.user.id
            let date = CheckInService.todayString()
            let weightKg: Double? = Double(weightInput).map { appState.weightUnit.toKg($0) }

            let payload = DailyCheckInUpsert(
                userId: userId,
                date: date,
                weightKg: weightKg,
                workoutCompleted: workoutCompleted,
                workoutNotes: workoutNotes.isEmpty ? nil : workoutNotes,
                steps: Int(steps)
            )

            let saved = try await checkInService.upsert(payload)

            // Upload photo if one was selected
            if let photoData = selectedPhotoData {
                let path = "\(userId)/\(date).jpg"
                try await supabase.storage
                    .from(photosBucket)
                    .upload(path, data: photoData, options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    ))
                let publicURL = try supabase.storage
                    .from(photosBucket)
                    .getPublicURL(path: path)
                struct PhotoUpdate: Encodable { let photo_url: String }
                try await supabase
                    .from("daily_checkins")
                    .update(PhotoUpdate(photo_url: publicURL.absoluteString))
                    .eq("user_id", value: userId)
                    .eq("date", value: date)
                    .execute()
            }

            onSaved(saved)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}
