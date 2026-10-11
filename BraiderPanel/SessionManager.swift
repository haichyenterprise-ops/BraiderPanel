import Foundation
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
final class SessionManager: NSObject, ObservableObject {

    static let shared = SessionManager()

    @Published var user: User?
    @Published var isInitialized = false
    @Published var isBusy = false
    @Published var authError: String?

    private var authListener: AuthStateDidChangeListenerHandle?

    override init() {
        super.init()

        self.user = Auth.auth().currentUser

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isInitialized = true
            }
        }
    }

    // MARK: - Computed

    var isSignedIn: Bool { user != nil }
    var uid: String { user?.uid ?? "" }
    var email: String? { user?.email }
    var displayName: String? { user?.displayName }

    // MARK: - Sign out
    func signOut() {
        do {
            try Auth.auth().signOut()

            UserDefaults.standard.removeObject(forKey: "currentUid")
            UserDefaults.standard.removeObject(forKey: "appleUserId")
            UserDefaults.standard.removeObject(forKey: "userAge")
            UserDefaults.standard.removeObject(forKey: "userName")
            UserDefaults.standard.removeObject(forKey: "locationPermissionDecision")

            self.user = nil
            Haptics.warning()
        } catch {
            print("[SessionManager] signOut failed:", error)
        }
    }

    /// Strong sign-out — wipes the Keychain-backed Firebase session.
    func hardSignOut() {
        signOut()

        let secItemClasses: [CFString] = [kSecClassGenericPassword]
        for itemClass in secItemClasses {
            let spec: [CFString: Any] = [kSecClass: itemClass]
            SecItemDelete(spec as CFDictionary)
        }
    }

    // MARK: - Email signup
    func signUpWithEmail(email: String, password: String, name: String) async throws {
        let clean = email.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        guard !clean.isEmpty, clean.contains("@") else {
            throw NSError(domain: "BraiderPanel", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Enter a valid email address."])
        }
        guard password.count >= 6 else {
            throw NSError(domain: "BraiderPanel", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Password must be at least 6 characters."])
        }
        guard !trimmedName.isEmpty else {
            throw NSError(domain: "BraiderPanel", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Please enter your full name."])
        }

        let result = try await Auth.auth().createUser(withEmail: clean, password: password)
        let change = result.user.createProfileChangeRequest()
        change.displayName = trimmedName
        try await change.commitChanges()
        self.user = result.user
    }

    // MARK: - Email login
    func signInWithEmail(email: String, password: String) async throws {
        let clean = email.trimmingCharacters(in: .whitespaces).lowercased()

        guard !clean.isEmpty, clean.contains("@") else {
            throw NSError(domain: "BraiderPanel", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Enter a valid email address."])
        }
        guard !password.isEmpty else {
            throw NSError(domain: "BraiderPanel", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Please enter your password."])
        }

        let result = try await Auth.auth().signIn(withEmail: clean, password: password)
        self.user = result.user
    }

    // MARK: - Reset
    func sendPasswordReset(email: String) async throws {
        let clean = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty, clean.contains("@") else {
            throw NSError(domain: "BraiderPanel", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Enter a valid email address."])
        }
        try await Auth.auth().sendPasswordReset(withEmail: clean)
    }

    // MARK: - Friendly errors
    static func friendlyError(_ error: Error) -> String {
        let ns = error as NSError
        let code = AuthErrorCode.Code(rawValue: ns.code)

        if let code {
            switch code {
            case .emailAlreadyInUse: return "That email is already registered. Try logging in."
            case .invalidEmail: return "That email doesn't look right."
            case .weakPassword: return "Password must be at least 6 characters."
            case .wrongPassword: return "Incorrect password."
            case .userNotFound: return "No account found for that email."
            case .invalidCredential: return "Wrong email or password."
            case .networkError: return "Network problem. Check your connection."
            case .tooManyRequests: return "Too many attempts. Try again in a moment."
            case .operationNotAllowed: return "Email sign-in isn't enabled in Firebase Console."
            default: return ns.localizedDescription
            }
        }
        return ns.localizedDescription
    }
}