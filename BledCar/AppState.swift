//
//  AppState.swift
//  BledCar
//
//  Source de vérité unique pour la navigation et l'authentification.
//

import SwiftUI
import Combine

// MARK: - Palette de couleurs BledCar

extension Color {
    /// Bleu marine profond – couleur principale
    static let bcPrimary    = Color(red: 0.08, green: 0.13, blue: 0.26)
    /// Bleu électrique vif – accent
    static let bcAccent     = Color(red: 0.16, green: 0.44, blue: 0.90)
    /// Gris bleuté doux – surface secondaire
    static let bcSoft       = Color(red: 0.92, green: 0.94, blue: 0.97)
    /// Or premium – touches déco
    static let bcGold       = Color(red: 0.85, green: 0.68, blue: 0.22)
    /// Blanc glacé – fond général
    static let bcBackground = Color(red: 0.97, green: 0.97, blue: 0.99)
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {

    // MARK: Navigation racine

    enum RootScreen {
        case splash
        case main
    }

    @Published var rootScreen: RootScreen = .splash

    // MARK: Authentification

    @Published var isLoggedIn: Bool = false
    @Published var currentUserEmail: String = ""
    @Published var currentUserName: String  = ""

    // MARK: - Transitions

    func finishSplash() {
        withAnimation(.easeOut(duration: 0.55)) {
            rootScreen = .main
        }
    }

    func login(email: String, name: String = "Conducteur") {
        currentUserEmail = email
        currentUserName  = name
        isLoggedIn       = true
        withAnimation(.easeOut(duration: 0.4)) {
            rootScreen = .main
        }
    }

    func logout() {
        currentUserEmail = ""
        currentUserName  = ""
        isLoggedIn       = false
        clearSession()
        withAnimation(.easeOut(duration: 0.4)) {
            rootScreen = .main
        }
    }

    // MARK: - Sessions persistantes (UserDefaults)

    private let kLoggedIn = "bc_logged_in"
    private let kEmail    = "bc_email"
    private let kName     = "bc_name"

    func restoreSession() {
        let saved = UserDefaults.standard.bool(forKey: kLoggedIn)
        if saved {
            currentUserEmail = UserDefaults.standard.string(forKey: kEmail) ?? ""
            currentUserName  = UserDefaults.standard.string(forKey: kName) ?? "Conducteur"
            isLoggedIn       = true
        }
    }

    func saveSession() {
        UserDefaults.standard.set(isLoggedIn,        forKey: kLoggedIn)
        UserDefaults.standard.set(currentUserEmail,  forKey: kEmail)
        UserDefaults.standard.set(currentUserName,   forKey: kName)
    }

    func clearSession() {
        UserDefaults.standard.removeObject(forKey: kLoggedIn)
        UserDefaults.standard.removeObject(forKey: kEmail)
        UserDefaults.standard.removeObject(forKey: kName)
    }
}
