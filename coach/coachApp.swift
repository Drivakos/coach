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

