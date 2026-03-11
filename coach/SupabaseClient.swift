//
//  SupabaseClient.swift
//  coach
//

import Foundation
import Supabase
import Auth

// In DEBUG builds, avoid the macOS keychain access prompt by
// storing the auth session in UserDefaults instead.
#if DEBUG
private struct UserDefaultsAuthStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws {
        UserDefaults.standard.set(value, forKey: key)
    }
    func retrieve(key: String) throws -> Data? {
        UserDefaults.standard.data(forKey: key)
    }
    func remove(key: String) throws {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
#endif

private func infoPlistString(_ key: String) -> String {
    // In preview mode, return dummy values to prevent crashes
    #if DEBUG
    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        switch key {
        case "SUPABASE_HOST":   return "localhost:54321"
        case "SUPABASE_ANON_KEY": return "preview-key"
        default: return ""
        }
    }
    #endif

    guard let value = Bundle.main.infoDictionary?[key] as? String,
          !value.isEmpty,
          !value.hasPrefix("$(") else {
        fatalError("'\(key)' missing or not expanded in Info.plist. Check Config.xcconfig is assigned in Xcode → Project → Info → Configurations.")
    }
    return value
}

let supabase: SupabaseClient = {
    let host = infoPlistString("SUPABASE_HOST")
    #if DEBUG
    let scheme = "http"
    #else
    let scheme = "https"
    #endif
    guard let url = URL(string: "\(scheme)://\(host)") else {
        fatalError("SUPABASE_HOST '\(host)' could not form a valid URL.")
    }
    return SupabaseClient(
        supabaseURL: url,
        supabaseKey: infoPlistString("SUPABASE_ANON_KEY"),
        options: SupabaseClientOptions(
            auth: {
                #if DEBUG
                .init(storage: UserDefaultsAuthStorage(), emitLocalSessionAsInitialSession: true)
                #else
                .init(emitLocalSessionAsInitialSession: true)
                #endif
            }()
        )
    )
}()
