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
    let goal: String?
    let macro_split: String?
}

private struct BodyMetric: Decodable {
    let weight_kg: Double?
    let body_fat_pct: Double?
    let recorded_at: String
}

private struct FoodPreference: Decodable {
    let preference: String
}

private struct AllergyRow: Decodable {
    let allergen: String
}

// MARK: - View

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var profile: UserProfile? = nil
    @State private var latestMetric: BodyMetric? = nil
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
                    weightUnit: appState.weightUnit,
                    dateOfBirth: parsedDOB(profile?.date_of_birth),
                    sex: profile?.sex ?? "male",
                    activityLevel: ActivityLevel(rawValue: profile?.activity_level ?? "") ?? .moderatelyActive,
                    goal: Goal(rawValue: profile?.goal ?? "") ?? .maintain,
                    macroSplit: MacroSplit(rawValue: profile?.macro_split ?? "") ?? .moderateCarb,
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
                    ProfileRow(label: "Weight", value: appState.weightUnit.formatted(w))
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
            Section("Activity & Goal") {
                if let level = profile?.activity_level {
                    ProfileRow(label: "Activity Level", value: ActivityLevel(rawValue: level)?.label ?? level)
                }
                if let goal = profile?.goal {
                    ProfileRow(label: "Goal", value: Goal(rawValue: goal)?.label ?? goal)
                }
                if let split = profile?.macro_split {
                    ProfileRow(label: "Macro Split", value: MacroSplit(rawValue: split)?.label ?? split)
                }
            }

            // Nutrition targets
            if let target = appState.nutritionTarget {
                Section("Nutrition Targets") {
                    ProfileRow(label: "Calories", value: "\(Int(target.calories)) kcal")
                    ProfileRow(label: "Protein",  value: "\(Int(target.proteinG)) g")
                    ProfileRow(label: "Carbs",    value: "\(Int(target.carbsG)) g")
                    ProfileRow(label: "Fat",      value: "\(Int(target.fatG)) g")
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

            // Display settings
            Section("Display") {
                Picker("Weight Unit", selection: Bindable(appState).weightUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue.uppercased()).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appState.weightUnit) { _, newUnit in
                    Task { await appState.saveWeightUnit(newUnit) }
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
                .select("email, full_name, height_cm, date_of_birth, sex, activity_level, goal, macro_split")
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

            let (p, metrics, prefs, allergyRows) = try await (
                profileFetch, metricFetch, prefFetch, allergyFetch
            )

            profile = p
            latestMetric = metrics.first
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
    @Environment(AppState.self) private var appState

    @State private var fullName: String
    @State private var email: String
    private let originalEmail: String

    @State private var heightCm: Double
    @State private var weightDisplay: Double
    private let weightUnit: WeightUnit
    private let sex: String

    @State private var dateOfBirth: Date
    @State private var activityLevel: ActivityLevel
    @State private var goal: Goal
    @State private var macroSplit: MacroSplit

    @State private var preferences: Set<String>
    @State private var allergies: Set<String>

    @State private var isSaving = false
    @State private var saveError: String?
    @State private var emailVerificationSent = false

    private let activityLevels: [(level: ActivityLevel, icon: String, description: String)] = [
        (.sedentary,        "sofa",                                   "Little or no exercise, desk job"),
        (.lightlyActive,    "figure.walk",                            "Light exercise 1–3 days/week"),
        (.moderatelyActive, "figure.run",                             "Moderate exercise 3–5 days/week"),
        (.veryActive,       "figure.highintensity.intervaltraining",  "Hard exercise 6–7 days/week"),
        (.extraActive,      "bolt.fill",                              "Very hard exercise & physical job"),
    ]

    private let goalOptions: [(goal: Goal, icon: String, description: String)] = [
        (.loseWeight, "arrow.down.circle.fill",  "~300 kcal deficit below your maintenance"),
        (.maintain,   "equal.circle.fill",       "Calories matched to your maintenance TDEE"),
        (.gainMuscle, "arrow.up.circle.fill",    "~300 kcal surplus above your maintenance"),
    ]

    private let macroSplitOptions: [(split: MacroSplit, description: String)] = [
        (.lowerCarb,   "40% protein · 40% fat · 20% carbs"),
        (.moderateCarb,"30% protein · 35% fat · 35% carbs"),
        (.higherCarb,  "30% protein · 20% fat · 50% carbs"),
    ]

    private let preferenceOptions = ["vegan", "vegetarian", "keto", "paleo", "gluten-free", "dairy-free"]
    private let allergyOptions = ["nuts", "dairy", "eggs", "gluten", "soy", "shellfish", "fish", "wheat"]

    let onSaved: () async -> Void

    init(fullName: String, email: String, heightCm: Double, weightKg: Double, weightUnit: WeightUnit,
         dateOfBirth: Date, sex: String, activityLevel: ActivityLevel, goal: Goal, macroSplit: MacroSplit,
         initialPreferences: Set<String>, initialAllergies: Set<String>,
         onSaved: @escaping () async -> Void) {
        _fullName = State(initialValue: fullName)
        _email = State(initialValue: email)
        originalEmail = email
        _heightCm = State(initialValue: heightCm)
        _weightDisplay = State(initialValue: weightUnit.convert(weightKg))
        self.weightUnit = weightUnit
        self.sex = sex
        _dateOfBirth = State(initialValue: dateOfBirth)
        _activityLevel = State(initialValue: activityLevel)
        _goal = State(initialValue: goal)
        _macroSplit = State(initialValue: macroSplit)
        _preferences = State(initialValue: initialPreferences)
        _allergies = State(initialValue: initialAllergies)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                bodyStatsSection
                activitySection
                goalSection
                macroSplitSection

                Section {
                    Label {
                        Text("Calorie and macro targets are recalculated every time you save.")
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.tint)
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

    // MARK: - Form sections

    private var accountSection: some View {
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
    }

    private var bodyStatsSection: some View {
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
                TextField(weightUnit.rawValue, value: $weightDisplay, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                Text(weightUnit.rawValue).foregroundStyle(.secondary)
            }

            DatePicker("Date of Birth", selection: $dateOfBirth,
                       in: ...Date(), displayedComponents: .date)
        }
    }

    private var activitySection: some View {
        Section("Activity Level") {
            ForEach(activityLevels, id: \.level) { item in
                SelectableRow(
                    icon: item.icon,
                    label: item.level.label,
                    description: item.description,
                    isSelected: activityLevel == item.level
                )
                .contentShape(Rectangle())
                .onTapGesture { activityLevel = item.level }
            }
        }
    }

    private var goalSection: some View {
        Section("Goal") {
            ForEach(goalOptions, id: \.goal) { item in
                SelectableRow(
                    icon: item.icon,
                    label: item.goal.label,
                    description: item.description,
                    isSelected: goal == item.goal
                )
                .contentShape(Rectangle())
                .onTapGesture { goal = item.goal }
            }
        }
    }

    private var macroSplitSection: some View {
        Section("Macro Split") {
            ForEach(macroSplitOptions, id: \.split) { item in
                let t = previewTargets(for: item.split)
                MacroSplitRow(
                    label: item.split.label,
                    description: item.description,
                    preview: "\(Int(t.proteinG))p · \(Int(t.carbsG))c · \(Int(t.fatG))f",
                    isSelected: macroSplit == item.split
                )
                .contentShape(Rectangle())
                .onTapGesture { macroSplit = item.split }
            }
        }
    }

    private func previewTargets(for split: MacroSplit) -> TDEECalculator.Targets {
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 30
        return TDEECalculator.calculate(
            sex: sex,
            weightKg: weightUnit.toKg(weightDisplay),
            heightCm: heightCm,
            age: age,
            activityLevel: activityLevel,
            goal: goal,
            macroSplit: split
        )
    }

    // MARK: - Save

    private func save() async {
        // Capture ALL form state synchronously before any await.
        let snapFullName      = fullName
        let snapEmail         = email
        let snapHeightCm      = heightCm
        let snapWeightKg      = weightUnit.toKg(weightDisplay)
        let snapDOB           = dateOfBirth
        let snapActivityLevel = activityLevel
        let snapGoal          = goal
        let snapMacroSplit    = macroSplit
        let snapSex           = sex
        let snapPreferences   = preferences
        let snapAllergies     = allergies

        isSaving = true
        saveError = nil
        emailVerificationSent = false
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"

            struct UserUpdate: Encodable {
                let full_name: String
                let height_cm: Double
                let date_of_birth: String
                let activity_level: String
                let goal: String
                let macro_split: String
            }
            try await supabase
                .from("users")
                .update(UserUpdate(
                    full_name: snapFullName,
                    height_cm: snapHeightCm,
                    date_of_birth: df.string(from: snapDOB),
                    activity_level: snapActivityLevel.rawValue,
                    goal: snapGoal.rawValue,
                    macro_split: snapMacroSplit.rawValue
                ))
                .eq("id", value: userId)
                .execute()

            if snapEmail != originalEmail {
                try await supabase.auth.update(user: UserAttributes(email: snapEmail))
                emailVerificationSent = true
            }

            try await supabase
                .from("body_metrics")
                .insert(BodyMetricInsert(user_id: userId, weight_kg: snapWeightKg, body_fat_pct: nil))
                .execute()

            let age = Calendar.current.dateComponents([.year], from: snapDOB, to: Date()).year ?? 30
            let targets = TDEECalculator.calculate(
                sex: snapSex,
                weightKg: snapWeightKg,
                heightCm: snapHeightCm,
                age: age,
                activityLevel: snapActivityLevel,
                goal: snapGoal,
                macroSplit: snapMacroSplit
            )
            try await supabase
                .from("nutrition_targets")
                .insert(NutritionTargetInsert(
                    user_id: userId,
                    calories: targets.calories,
                    protein_g: targets.proteinG,
                    carbs_g: targets.carbsG,
                    fat_g: targets.fatG
                ))
                .execute()

            appState.nutritionTarget = StoredTarget(
                calories: targets.calories,
                proteinG: targets.proteinG,
                carbsG: targets.carbsG,
                fatG: targets.fatG
            )

            try await supabase.from("food_preferences").delete().eq("user_id", value: userId).execute()
            if !snapPreferences.isEmpty {
                try await supabase
                    .from("food_preferences")
                    .insert(snapPreferences.map { FoodPreferenceInsert(user_id: userId, preference: $0) })
                    .execute()
            }

            try await supabase.from("allergies").delete().eq("user_id", value: userId).execute()
            if !snapAllergies.isEmpty {
                try await supabase
                    .from("allergies")
                    .insert(snapAllergies.map { AllergyInsert(user_id: userId, allergen: $0) })
                    .execute()
            }

            await onSaved()
            if !emailVerificationSent { dismiss() }
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Sub-components

private struct SelectableRow: View {
    let icon: String
    let label: String
    let description: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct MacroSplitRow: View {
    let label: String
    let description: String
    let preview: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .fontWeight(isSelected ? .medium : .regular)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 2)
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
        .environment(AppState())
}
