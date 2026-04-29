//
//  NotificationManager.swift
//  BledCar
//
//  Notifications locales natives – confirmations de réservation,
//  rappels de restitution, offres personnalisées.
//

import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    // MARK: - Published

    @Published var isAuthorized: Bool = false
    @Published var pendingCount: Int = 0

    // MARK: - Init

    private init() {}

    // MARK: - Autorisation

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    func checkStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        pendingCount = pending.count
    }

    // MARK: - Notifications locales

    /// Rappel de réservation (ex: "Votre Toyota RAV4 est prêt demain à 9h")
    func scheduleBookingReminder(vehicleName: String, date: Date, isDelivery: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "Rappel BledCar 🚗"
        content.body = isDelivery
            ? "Votre \(vehicleName) sera livré demain. Assurez-vous d'être disponible."
            : "Pensez à récupérer votre \(vehicleName) demain à l'agence."
        content.sound = .default
        content.badge = 1

        // Notification la veille à 10h
        var triggerDate = Calendar.current.dateComponents([.year, .month, .day], from: date)
        triggerDate.hour = 10
        triggerDate.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "booking-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Notification de bienvenue après inscription
    func sendWelcomeNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Bienvenue sur BledCar ! 🎉"
        content.body = "Profitez de milliers de véhicules disponibles near de chez vous. Réservez en 2 minutes."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "welcome", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Notification promotionnelle (appelée depuis un pont JS)
    func schedulePromoNotification(title: String, body: String, delaySeconds: Double = 5) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)
        let request = UNNotificationRequest(identifier: "promo-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Badge

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
