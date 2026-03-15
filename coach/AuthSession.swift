import Foundation
import Auth
import Supabase

enum AuthState { case loading, signedIn, signedOut }

@Observable
final class AuthSession {
    var state: AuthState = .loading
    var profileComplete: Bool = false
    /// Set when `checkProfileComplete()` fails due to a network/server error.
    /// Distinct from `profileComplete == false`, which means the profile is genuinely unfinished.
    var profileCheckFailed: Bool = false

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
                    profileCheckFailed = false
                default:
                    break
                }
            }
        }
    }

    func checkProfileComplete() async {
        do {
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

            struct TargetRow: Decodable { let id: UUID }
            let targets: [TargetRow] = try await supabase
                .from("nutrition_targets")
                .select("id")
                .execute()
                .value

            profileCheckFailed = false
            profileComplete = hasName && hasSex && !targets.isEmpty
        } catch {
            // Don't set profileComplete = false here — a network error doesn't mean the
            // profile is incomplete. Set profileCheckFailed so the UI can show a retry
            // prompt instead of routing to SetupWizardView.
            profileCheckFailed = true
        }
    }
}
