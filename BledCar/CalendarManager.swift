//
//  CalendarManager.swift
//  BledCar
//
//  Intégration Calendrier iOS natif (EventKit).
//  Ajoute les réservations BledCar directement dans le calendrier de l'utilisateur.
//  Fonctionnalité 100% native — impossible dans un navigateur web.
//

import Foundation
import EventKit

@MainActor
final class CalendarManager: ObservableObject {

    static let shared = CalendarManager()

    // MARK: - Published

    @Published var isAuthorized: Bool = false

    // MARK: - Private

    private let store = EKEventStore()

    private init() {
        checkStatus()
    }

    // MARK: - Permission

    private func checkStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            isAuthorized = (status == .fullAccess || status == .writeOnly)
        } else {
            isAuthorized = (status == .authorized)
        }
    }

    func requestPermission() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            isAuthorized = true
            return true
        case .notDetermined:
            if #available(iOS 17.0, *) {
                let granted = (try? await store.requestFullAccessToEvents()) ?? false
                isAuthorized = granted
                return granted
            } else {
                return await withCheckedContinuation { cont in
                    store.requestAccess(to: .event) { granted, _ in
                        Task { @MainActor in
                            self.isAuthorized = granted
                            cont.resume(returning: granted)
                        }
                    }
                }
            }
        default:
            isAuthorized = false
            return false
        }
    }

    // MARK: - Ajouter une réservation

    /// Ajoute une réservation BledCar dans le calendrier iOS.
    /// Renvoie l'identifiant de l'événement si succès, nil sinon.
    @discardableResult
    func addBooking(
        vehicleName: String,
        category: String = "",
        startDate: Date,
        endDate: Date,
        location: String = "",
        notes: String = ""
    ) async -> String? {

        let authorized = isAuthorized ? true : await requestPermission()
        guard authorized else { return nil }

        let event = EKEvent(eventStore: store)
        event.title       = "🚗 BledCar – \(vehicleName)"
        event.startDate   = startDate
        event.endDate     = endDate.addingTimeInterval(1)   // au moins 1s
        event.location    = location.isEmpty ? nil : location
        event.calendar    = store.defaultCalendarForNewEvents

        var fullNotes = "Réservation BledCar"
        if !category.isEmpty { fullNotes += "\nCatégorie : \(category)" }
        if !notes.isEmpty    { fullNotes += "\n\(notes)" }
        fullNotes += "\n\nGéré via l'app BledCar"
        event.notes = fullNotes

        // Alarme 1h avant
        event.addAlarm(EKAlarm(relativeOffset: -3600))
        // Alarme 24h avant
        event.addAlarm(EKAlarm(relativeOffset: -86400))

        do {
            try store.save(event, span: .thisEvent, commit: true)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    // MARK: - Supprimer une réservation

    func removeBooking(eventIdentifier: String) {
        guard isAuthorized,
              let event = store.event(withIdentifier: eventIdentifier) else { return }
        try? store.remove(event, span: .thisEvent, commit: true)
    }
}

// MARK: - Feuille de confirmation Calendrier

import SwiftUI

struct CalendarConfirmSheet: View {

    let vehicleName: String
    let category: String
    let startDate: Date
    let endDate: Date
    let location: String
    let notes: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Poignée
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            ScrollView {
                VStack(spacing: 24) {
                    // Icône
                    ZStack {
                        Circle()
                            .fill(Color.bcSoft)
                            .frame(width: 80, height: 80)
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 34))
                            .foregroundColor(.bcAccent)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 6) {
                        Text("Ajouter au Calendrier")
                            .font(.title2.weight(.bold)).foregroundColor(.bcPrimary)
                        Text("Votre réservation sera enregistrée dans le calendrier iOS avec des rappels automatiques.")
                            .font(.subheadline).foregroundColor(.bcPrimary.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    // Détails
                    VStack(alignment: .leading, spacing: 12) {
                        CalRow(icon: "car.fill",     label: vehicleName, color: .bcAccent)
                        if !category.isEmpty {
                            CalRow(icon: "tag.fill", label: category,    color: .bcPrimary)
                        }
                        CalRow(icon: "clock.fill",
                               label: "\(formatted(startDate)) → \(formatted(endDate))",
                               color: .bcPrimary)
                        if !location.isEmpty {
                            CalRow(icon: "mappin.circle.fill", label: location, color: .red)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .background(Color.bcSoft.opacity(0.50))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 4)

                    // Rappels
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.bcAccent)
                        Text("Rappels automatiques : 24h avant et 1h avant")
                            .font(.caption).foregroundColor(.bcPrimary.opacity(0.70))
                    }
                    .padding(.horizontal, 8)

                    // Boutons
                    VStack(spacing: 10) {
                        Button(action: onConfirm) {
                            Label("Ajouter à mon Calendrier", systemImage: "calendar.badge.plus")
                                .font(.headline).foregroundColor(.white)
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(Color.bcAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        Button(action: onCancel) {
                            Text("Non merci")
                                .font(.subheadline).foregroundColor(.bcPrimary.opacity(0.60))
                        }
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

private struct CalRow: View {
    let icon: String; let label: String; let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color).frame(width: 20)
            Text(label).font(.subheadline).foregroundColor(.bcPrimary)
            Spacer()
        }
    }
}
