//
//  coachApp.swift
//  coach
//
//  Created by Vagelis Drivakos on 2/3/26.
//

import SwiftUI
import Auth
import Supabase

@main
struct coachApp: App {
    @State private var session = AuthSession()

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .signedIn:
                    ContentView()
                case .signedOut:
                    AuthView()
                }
            }
            .environment(session)
        }
    }
}

// MARK: - Auth session observable

enum AuthState { case loading, signedIn, signedOut }

@Observable
final class AuthSession {
    var state: AuthState = .loading

    init() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession:
                    state = session != nil ? .signedIn : .signedOut
                case .signedIn:
                    state = .signedIn
                case .signedOut:
                    state = .signedOut
                default:
                    break
                }
            }
        }
    }
}
