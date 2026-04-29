//
//  WelcomeView.swift
//  BledCar
//
//  Écran d'accueil natif – présentation et entrée en mode découverte.
//

import SwiftUI

struct WelcomeView: View {
    let onDiscover: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {

                // ── Photo de fond plein écran (48% supérieur) ─────────────
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        Image("WelcomeBackground")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height * 0.48)
                            .clipped()

                        // Overlay dégradé sombre → transparent
                        LinearGradient(
                            colors: [.black.opacity(0.45), .black.opacity(0.10), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geo.size.height * 0.48)
                    }

                    Spacer()
                }

                // ── Feuille blanche du bas ─────────────────────────────────
                VStack(alignment: .leading, spacing: 20) {

                    // Badge logo flottant — centré en haut de la feuille
                    HStack(spacing: 12) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .shadow(color: .bcPrimary.opacity(0.25), radius: 8, x: 0, y: 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("BLEDCAR")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .tracking(3)
                                .foregroundColor(.bcPrimary)
                            Text("Location • Premium • Confiance")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.bcAccent)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .offset(y: -36)        // remonte sur la photo
                    .padding(.bottom, -36) // compense pour ne pas décaler le reste

                    // Titre accrocheur
                    Text("La voiture parfaite,\nquand vous en avez besoin.")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.bcPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Feature Card
                    VStack(alignment: .leading, spacing: 16) {
                        BCFeatureRow(icon: "car.2.fill",
                                     title: "5 000+ véhicules disponibles",
                                     subtitle: "Citadines, SUV, berlines premium, utilitaires & électriques")
                        BCFeatureRow(icon: "mappin.and.ellipse",
                                     title: "Livraison à domicile ou agence",
                                     subtitle: "Récupérez votre véhicule où vous voulez, quand vous voulez")
                        BCFeatureRow(icon: "checkmark.shield.fill",
                                     title: "Prix transparents, sans frais cachés",
                                     subtitle: "Le prix affiché est celui que vous payez. Toujours.")
                    }
                    .padding(18)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .bcPrimary.opacity(0.07), radius: 16, x: 0, y: 4)

                    // Bouton CTA
                    Button(action: onDiscover) {
                        HStack(spacing: 10) {
                            Image(systemName: "car.fill")
                                .font(.headline)
                            Text("Trouver un véhicule")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [.bcAccent, .bcPrimary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .bcAccent.opacity(0.30), radius: 14, x: 0, y: 6)
                    }

                    // Note bas de page
                    Text("La connexion n'est requise que pour effectuer une réservation.")
                        .font(.caption)
                        .foregroundColor(.bcPrimary.opacity(0.50))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, geo.safeAreaInsets.bottom + 16)
                .background(
                    Color.bcBackground
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .ignoresSafeArea(edges: .bottom)
                        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -6)
                )
                .frame(height: geo.size.height * 0.60)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Feature Row

private struct BCFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.bcSoft)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.bcAccent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.bcPrimary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.bcPrimary.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView(onDiscover: {})
}
