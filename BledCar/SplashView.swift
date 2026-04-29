//
//  SplashView.swift
//  BledCar
//
//  Écran de lancement affiché 2.6 s – thème automobile / premium.
//

import SwiftUI

struct SplashView: View {

    // MARK: - Callbacks

    var onFinish: () -> Void

    // MARK: - Animation states

    @State private var badgeOpacity: Double = 0
    @State private var badgeOffset:  Double = -12
    @State private var textOpacity:  Double = 0
    @State private var textOffset:   Double = 16

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Photo de fond plein écran ─────────────────────────────────
            Image("WelcomeBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // ── Overlay léger pour lisibilité uniquement en haut/bas ──────
            LinearGradient(
                colors: [
                    .black.opacity(0.55),
                    .clear,
                    .clear,
                    .black.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── Badge logo en haut ────────────────────────────────────────
            VStack {
                HStack {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)

                    Text("BLEDCAR")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundColor(.white)
                }
                .opacity(badgeOpacity)
                .offset(y: badgeOffset)
                .padding(.top, 68)

                Spacer()

                // ── Texte en bas ──────────────────────────────────────────
                VStack(spacing: 6) {
                    Text("La location, à votre rythme.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.80))
                        .tracking(1)

                    Rectangle()
                        .frame(width: 40, height: 1.5)
                        .foregroundColor(Color.bcGold.opacity(0.80))
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
                .padding(.bottom, 52)
            }
        }
        .onAppear(perform: startAnimations)
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.7)) {
            badgeOpacity = 1.0
            badgeOffset  = 0
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.35)) {
            textOpacity = 1.0
            textOffset  = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            onFinish()
        }
    }
}

// MARK: - Preview

#Preview {
    SplashView(onFinish: {})
}
