//
//  coachApp.swift
//  coach
//
//  Created by Vagelis Drivakos on 2/3/26.
//

import SwiftUI
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
            .alert("Couldn't Load Profile", isPresented: Binding(
                get: { appState.profileLoadError != nil },
                set: { if !$0 { appState.profileLoadError = nil } }
            )) {
                Button("Retry") { Task { await appState.loadProfile() } }
                Button("Dismiss", role: .cancel) { appState.profileLoadError = nil }
            } message: {
                Text(appState.profileLoadError ?? "")
            }
            .task(id: session.state) {
                guard session.state == .signedIn else { return }
                appState.listenForNotificationTaps()
                async let profile: Void = appState.loadProfile()
                async let country: Void = appState.updateCountryCode()
                _ = await (profile, country)
                await NotificationService.shared.requestPermissionAndSchedule()
                // Plan generation now runs server-side via pg_cron every Monday.
                // The app just reads the pre-generated plan from the DB.
            }
        }
    }
}

