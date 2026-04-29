//
//  ContentView.swift
//  BledCar
//

import SwiftUI

// MARK: - SwiftUI Entry Point

struct ContentView: View {
    var body: some View {
        BledCARViewControllerRepresentable()
            .ignoresSafeArea()
    }
}

// MARK: - UIViewControllerRepresentable

struct BledCARViewControllerRepresentable: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> BledCARWebViewController {
        BledCARWebViewController()
    }

    func updateUIViewController(_ uiViewController: BledCARWebViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ContentView()
}
