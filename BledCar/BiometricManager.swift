//
//  BiometricManager.swift
//  BledCar
//
//  Authentification biométrique Face ID / Touch ID + stockage sécurisé Keychain.
//  Permet de se connecter rapidement sans retaper ses identifiants.
//  Fonctionnalité 100% native — impossible dans un navigateur web.
//

import Foundation
import LocalAuthentication
import Security

@MainActor
final class BiometricManager: ObservableObject {

    static let shared = BiometricManager()

    // MARK: - Published

    @Published var canUseBiometrics: Bool = false
    @Published var biometricType: LABiometryType = .none
    @Published var isAuthenticated: Bool = false

    // MARK: - Keychain keys

    private let keychainService = "com.BledCar.BledCar"
    private let tokenKey        = "bc_auth_token"
    private let emailKey        = "bc_user_email"
    private let biometricKey    = "bc_biometric_enabled"

    // MARK: - Init

    private init() {
        checkBiometrics()
    }

    // MARK: - Vérifier disponibilité

    func checkBiometrics() {
        let ctx = LAContext()
        var error: NSError?
        canUseBiometrics = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = ctx.biometryType
    }

    // MARK: - Authentifier

    /// Déclenche Face ID / Touch ID. Renvoie true si réussi.
    func authenticate(reason: String? = nil) async -> Bool {
        guard canUseBiometrics else { return false }
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Utiliser le mot de passe"
        let msg = reason ?? "Accédez rapidement à votre compte BledCar"
        do {
            let result = try await ctx.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: msg
            )
            isAuthenticated = result
            return result
        } catch {
            isAuthenticated = false
            return false
        }
    }

    // MARK: - Nom biométrique affiché

    var biometricName: String {
        switch biometricType {
        case .faceID:   return "Face ID"
        case .touchID:  return "Touch ID"
        default:        return "Biométrie"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID:   return "faceid"
        case .touchID:  return "touchid"
        default:        return "lock.shield.fill"
        }
    }

    // MARK: - Keychain : token JWT

    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: biometricKey) }
        set { UserDefaults.standard.set(newValue, forKey: biometricKey) }
    }

    func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     keychainService,
            kSecAttrAccount:     tokenKey,
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getToken() -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: tokenKey,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveEmail(_ email: String) {
        let data = Data(email.utf8)
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    keychainService,
            kSecAttrAccount:    emailKey,
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getEmail() -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: emailKey,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func clearCredentials() {
        let queries: [[CFString: Any]] = [
            [kSecClass: kSecClassGenericPassword, kSecAttrService: keychainService, kSecAttrAccount: tokenKey],
            [kSecClass: kSecClassGenericPassword, kSecAttrService: keychainService, kSecAttrAccount: emailKey]
        ]
        queries.forEach { SecItemDelete($0 as CFDictionary) }
        isBiometricEnabled = false
        isAuthenticated = false
    }
}

// MARK: - Vue de configuration Biométrie

import SwiftUI

struct BiometricSetupSheet: View {

    @ObservedObject private var bio = BiometricManager.shared
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            VStack(spacing: 28) {
                // Icône
                ZStack {
                    Circle()
                        .fill(Color.bcSoft)
                        .frame(width: 100, height: 100)
                    Image(systemName: bio.biometricIcon)
                        .font(.system(size: 46))
                        .foregroundColor(.bcAccent)
                }
                .padding(.top, 32)

                VStack(spacing: 8) {
                    Text("Connexion rapide avec \(bio.biometricName)")
                        .font(.title2.weight(.bold)).foregroundColor(.bcPrimary)
                        .multilineTextAlignment(.center)
                    Text("Accédez à votre compte BledCar en un instant — sans retaper votre email ni votre mot de passe.")
                        .font(.subheadline).foregroundColor(.bcPrimary.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                // Avantages
                VStack(alignment: .leading, spacing: 14) {
                    BioFeatureRow(icon: "bolt.fill",        text: "Accès instantané à chaque ouverture", color: .bcGold)
                    BioFeatureRow(icon: "lock.shield.fill", text: "Vos données sécurisées dans le Keychain iOS", color: .bcAccent)
                    BioFeatureRow(icon: "eye.slash.fill",   text: "Personne ne peut accéder à votre compte", color: .green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .background(Color.bcSoft.opacity(0.50))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 4)

                // Boutons
                VStack(spacing: 10) {
                    Button(action: onEnable) {
                        Label("Activer \(bio.biometricName)", systemImage: bio.biometricIcon)
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(Color.bcAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Button(action: onSkip) {
                        Text("Pas maintenant")
                            .font(.subheadline).foregroundColor(.bcPrimary.opacity(0.55))
                    }
                }
                .padding(.bottom, 36)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct BioFeatureRow: View {
    let icon: String; let text: String; let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(color).frame(width: 20)
            Text(text).font(.subheadline).foregroundColor(.bcPrimary)
            Spacer()
        }
    }
}
