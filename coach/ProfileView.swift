import SwiftUI
import Supabase

// MARK: - Decodable models

private struct UserProfile: Decodable {
    let email: String
    let full_name: String?
    let height_cm: Double?
    let date_of_birth: String?
    let sex: String?
    let activity_level: String?
}

private struct BodyMetric: Decodable {
    let weight_kg: Double?
    let body_fat_pct: Double?
    let recorded_at: String
}

private struct NutritionTarget: Decodable {
    let calories: Double
    let protein_g: Double
    let carbs_g: Double
    let fat_g: Double
    let effective_from: String
}

private struct FoodPreference: Decodable {
    let preference: String
}

private struct AllergyRow: Decodable {
    let allergen: String
}

// MARK: - View

struct ProfileView: View {
    @State private var profile: UserProfile? = nil
    @State private var latestMetric: BodyMetric? = nil
    @State private var latestTarget: NutritionTarget? = nil
    @State private var preferences: [String] = []
    @State private var allergies: [String] = []
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var showEditSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = loadError {
                    ContentUnavailableView("Couldn't load profile", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    profileContent
                }
            }
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Sign Out", role: .destructive) {
                        Task { try? await supabase.auth.signOut() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEditSheet = true }
                        .disabled(isLoading || profile == nil)
                }
            }
            .sheet(isPresented: $showEditSheet) {
                ProfileEditSheet(
                    fullName: profile?.full_name ?? "",
                    email: profile?.email ?? "",
                    heightCm: profile?.height_cm ?? 170,
                    weightKg: latestMetric?.weight_kg ?? 70,
                    dateOfBirth: parsedDOB(profile?.date_of_birth),
                    activityLevel: profile?.activity_level ?? "moderately_active",
                    initialPreferences: Set(preferences),
                    initialAllergies: Set(allergies),
                    onSaved: { await loadAll() }
                )
            }
            .task { await loadAll() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var profileContent: some View {
        List {
            // Header
            if let profile {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.full_name ?? "—")
                                .font(.title3.bold())
                            Text(profile.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            // Body stats
            Section("Body Stats") {
                if let h = profile?.height_cm {
                    ProfileRow(label: "Height", value: "\(Int(h)) cm")
                }
                if let w = latestMetric?.weight_kg {
                    ProfileRow(label: "Weight", value: String(format: "%.1f kg", w))
                }
                if let bf = latestMetric?.body_fat_pct {
                    ProfileRow(label: "Body Fat", value: String(format: "%.1f%%", bf))
                }
                if let dob = profile?.date_of_birth, let age = age(from: dob) {
                    ProfileRow(label: "Age", value: "\(age) yrs  ·  \(formattedDate(dob))")
                }
                if let sex = profile?.sex {
                    ProfileRow(label: "Biological Sex", value: sex.capitalized)
                }
            }

            // Activity & goal
            Section("Activity") {
                if let level = profile?.activity_level {
                    ProfileRow(label: "Activity Level", value: activityLabel(level))
                }
            }

            // Nutrition targets
            if let target = latestTarget {
                Section("Nutrition Targets") {
                    ProfileRow(label: "Calories",  value: "\(Int(target.calories)) kcal")
                    ProfileRow(label: "Protein",   value: "\(Int(target.protein_g)) g")
                    ProfileRow(label: "Carbs",     value: "\(Int(target.carbs_g)) g")
                    ProfileRow(label: "Fat",       value: "\(Int(target.fat_g)) g")
                }
            }

            // Diet preferences
            if !preferences.isEmpty {
                Section("Diet Preferences") {
                    FlowTagRow(tags: preferences)
                }
            }

            // Allergies
            if !allergies.isEmpty {
                Section("Allergies") {
                    FlowTagRow(tags: allergies)
                }
            }
        }
    }

    // MARK: - Data loading

    private func loadAll() async {
        isLoading = true
        loadError = nil
        do {
            async let profileFetch: UserProfile = supabase
                .from("users")
                .select("email, full_name, height_cm, date_of_birth, sex, activity_level")
                .single()
                .execute()
                .value

            async let metricFetch: [BodyMetric] = supabase
                .from("body_metrics")
                .select("weight_kg, body_fat_pct, recorded_at")
                .order("recorded_at", ascending: false)
                .limit(1)
                .execute()
                .value

            async let targetFetch: [NutritionTarget] = supabase
                .from("nutrition_targets")
                .select("calories, protein_g, carbs_g, fat_g, effective_from")
                .order("effective_from", ascending: false)
                .limit(1)
                .execute()
                .value

            async let prefFetch: [FoodPreference] = supabase
                .from("food_preferences")
                .select("preference")
                .execute()
                .value

            async let allergyFetch: [AllergyRow] = supabase
                .from("allergies")
                .select("allergen")
                .execute()
                .value

            let (p, metrics, targets, prefs, allergyRows) = try await (
                profileFetch, metricFetch, targetFetch, prefFetch, allergyFetch
            )

            profile = p
            latestMetric = metrics.first
            latestTarget = targets.first
            preferences = prefs.map(\.preference)
            allergies = allergyRows.map(\.allergen)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Helpers

    private func parsedDOB(_ str: String?) -> Date {
        guard let str else {
            return Calendar.current.date(byAdding: .year, value: -30, to: Date())!
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str) ?? Calendar.current.date(byAdding: .year, value: -30, to: Date())!
    }

    private func activityLabel(_ id: String) -> String {
        switch id {
        case "sedentary":          return "Sedentary"
        case "lightly_active":     return "Lightly Active"
        case "moderately_active":  return "Moderately Active"
        case "very_active":        return "Very Active"
        case "extra_active":       return "Extra Active"
        default:                   return id
        }
    }

    private func age(from dobString: String) -> Int? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let dob = f.date(from: dobString) else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    private func formattedDate(_ dobString: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dobString) else { return dobString }
        let out = DateFormatter()
        out.dateStyle = .medium
        return out.string(from: date)
    }
}

// MARK: - Edit Sheet

private struct ProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var fullName: String
    @State private var email: String
    private let originalEmail: String

    @State private var heightCm: Double
    @State private var weightKg: Double
    @State private var dateOfBirth: Date
    @State private var activityLevel: String
    @State private var preferences: Set<String>
    @State private var allergies: Set<String>

    @State private var isSaving = false
    @State private var saveError: String?
    @State private var emailVerificationSent = false

    private let activityLevels: [(id: String, label: String, icon: String)] = [
        ("sedentary",         "Sedentary",          "sofa"),
        ("lightly_active",    "Lightly Active",     "figure.walk"),
        ("moderately_active", "Moderately Active",  "figure.run"),
        ("very_active",       "Very Active",        "figure.highintensity.intervaltraining"),
        ("extra_active",      "Extra Active",       "bolt.fill"),
    ]

    private let preferenceOptions = ["vegan", "vegetarian", "keto", "paleo", "gluten-free", "dairy-free"]
    private let allergyOptions = ["nuts", "dairy", "eggs", "gluten", "soy", "shellfish", "fish", "wheat"]

    let onSaved: () async -> Void

    init(fullName: String, email: String, heightCm: Double, weightKg: Double, dateOfBirth: Date,
         activityLevel: String, initialPreferences: Set<String>, initialAllergies: Set<String>,
         onSaved: @escaping () async -> Void) {
        _fullName = State(initialValue: fullName)
        _email = State(initialValue: email)
        originalEmail = email
        _heightCm = State(initialValue: heightCm)
        _weightKg = State(initialValue: weightKg)
        _dateOfBirth = State(initialValue: dateOfBirth)
        _activityLevel = State(initialValue: activityLevel)
        _preferences = State(initialValue: initialPreferences)
        _allergies = State(initialValue: initialAllergies)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Full name", text: $fullName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Email")
                            Spacer()
                            TextField("Email address", text: $email)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        if email != originalEmail {
                            Text("A verification link will be sent to this address. Your email changes after you confirm it.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if emailVerificationSent {
                        Label("Verification email sent to \(email)", systemImage: "envelope.badge.checkmark")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Section("Body Stats") {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("cm", value: $heightCm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("cm").foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("kg").foregroundStyle(.secondary)
                    }

                    DatePicker("Date of Birth", selection: $dateOfBirth,
                               in: ...Date(), displayedComponents: .date)
                }

                Section("Activity Level") {
                    ForEach(activityLevels, id: \.id) { level in
                        ActivityEditRow(
                            icon: level.icon,
                            label: level.label,
                            isSelected: activityLevel == level.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { activityLevel = level.id }
                    }
                }

                Section("Diet Preferences") {
                    SelectionGrid(options: preferenceOptions, selected: $preferences)
                        .padding(.vertical, 4)
                }

                Section("Allergies") {
                    SelectionGrid(options: allergyOptions, selected: $allergies)
                        .padding(.vertical, 4)
                }

                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(emailVerificationSent ? "Done" : "Cancel") { dismiss() }
                }
                if !emailVerificationSent {
                    ToolbarItem(placement: .confirmationAction) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Button("Save") {
                                Task { await save() }
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        saveError = nil
        emailVerificationSent = false
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id

            // Update profile fields
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            struct UserUpdate: Encodable {
                let full_name: String
                let height_cm: Double
                let date_of_birth: String
                let activity_level: String
            }
            try await supabase
                .from("users")
                .update(UserUpdate(
                    full_name: fullName,
                    height_cm: heightCm,
                    date_of_birth: df.string(from: dateOfBirth),
                    activity_level: activityLevel
                ))
                .eq("id", value: userId)
                .execute()

            // Trigger email change verification if the address changed
            if email != originalEmail {
                try await supabase.auth.updateUser(user: UserAttributes(email: email))
                emailVerificationSent = true
            }

            // Insert new body metric for weight
            struct BodyMetricInsert: Encodable {
                let user_id: UUID
                let weight_kg: Double
            }
            try await supabase
                .from("body_metrics")
                .insert(BodyMetricInsert(user_id: userId, weight_kg: weightKg))
                .execute()

            // Replace food_preferences
            try await supabase
                .from("food_preferences")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            if !preferences.isEmpty {
                struct PrefInsert: Encodable {
                    let user_id: UUID
                    let preference: String
                }
                try await supabase
                    .from("food_preferences")
                    .insert(preferences.map { PrefInsert(user_id: userId, preference: $0) })
                    .execute()
            }

            // Replace allergies
            try await supabase
                .from("allergies")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            if !allergies.isEmpty {
                struct AllergyInsert: Encodable {
                    let user_id: UUID
                    let allergen: String
                }
                try await supabase
                    .from("allergies")
                    .insert(allergies.map { AllergyInsert(user_id: userId, allergen: $0) })
                    .execute()
            }

            await onSaved()
            if !emailVerificationSent {
                dismiss()
            }
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Sub-components

private struct ActivityEditRow: View {
    let icon: String
    let label: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: 24)
            Text(label)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
            }
        }
    }
}

private struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}

private struct FlowTagRow: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let rows = chunked(tags, size: 3)
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    ForEach(rows[i], id: \.self) { tag in
                        Text(tag.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func chunked(_ items: [String], size: Int) -> [[String]] {
        stride(from: 0, to: items.count, by: size).map {
            Array(items[$0..<min($0 + size, items.count)])
        }
    }
}

#Preview {
    ProfileView()
}
