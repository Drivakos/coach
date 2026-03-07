//
//  coachApp.swift
//  coach
//
//  Created by Vagelis Drivakos on 2/3/26.
//

import SwiftUI
import Auth
import Supabase
import UserNotifications

@main
struct coachApp: App {
    @State private var session = AuthSession()
    @State private var appState = AppState()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .signedIn:
                    if session.profileComplete {
                        MainTabView()
                            .environment(appState)
                    } else {
                        SetupWizardView(onComplete: {
                            session.profileComplete = true
                        })
                    }
                case .signedOut:
                    AuthView()
                }
            }
            .environment(session)
            .task(id: session.state) {
                guard session.state == .signedIn else { return }
                appState.listenForNotificationTaps()
                await appState.loadProfile()
                await NotificationService.shared.requestPermissionAndSchedule()
                await WeeklySummaryService().rollUpIfNeeded()
            }
        }
    }
}

// MARK: - Auth session observable

enum AuthState { case loading, signedIn, signedOut }

@Observable
final class AuthSession {
    var state: AuthState = .loading
    var profileComplete: Bool = false

    init() {
        Task {
            for await (event, _) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession, .signedIn:
                    let hasSession = (try? await supabase.auth.session) != nil
                    if hasSession {
                        state = .signedIn
                        await checkProfileComplete()
                    } else {
                        state = .signedOut
                        profileComplete = false
                    }
                case .signedOut:
                    state = .signedOut
                    profileComplete = false
                default:
                    break
                }
            }
        }
    }

    func checkProfileComplete() async {
        do {
            // Fetch profile fields
            struct UserProfile: Decodable {
                let full_name: String?
                let sex: String?
            }
            let profile: UserProfile = try await supabase
                .from("users")
                .select("full_name, sex")
                .single()
                .execute()
                .value

            let hasName = profile.full_name?.isEmpty == false
            let hasSex  = profile.sex != nil

            // Check if any nutrition_targets exist
            struct TargetRow: Decodable { let id: UUID }
            let targets: [TargetRow] = try await supabase
                .from("nutrition_targets")
                .select("id")
                .execute()
                .value

            let hasTargets = !targets.isEmpty

            profileComplete = hasName && hasSex && hasTargets
        } catch {
            profileComplete = false
        }
    }
}
