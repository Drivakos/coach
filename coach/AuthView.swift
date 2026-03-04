//
//  AuthView.swift
//  coach
//

import SwiftUI
import Auth
import Supabase

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                }

                Section {
                    Button {
                        isSignUp.toggle()
                        errorMessage = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign in" : "No account? Sign up")
                            .font(.callout)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        do {
            if isSignUp {
                try await supabase.auth.signUp(email: email, password: password)
            } else {
                try await supabase.auth.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    AuthView()
}
