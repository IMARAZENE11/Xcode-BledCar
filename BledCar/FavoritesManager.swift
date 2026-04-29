//
//  FavoritesManager.swift
//  BledCar
//
//  Gestion native des véhicules favoris – stockage persistant UserDefaults.
//

import Foundation
import Combine

struct FavoriteVehicle: Codable, Identifiable, Equatable {
    let id: String          // URL de la page
    let name: String        // "Toyota RAV4"
    let category: String    // "SUV & 4x4"
    let url: String
    let savedAt: Date

    init(id: String, name: String, category: String = "", url: String) {
        self.id       = id
        self.name     = name
        self.category = category
        self.url      = url
        self.savedAt  = Date()
    }
}

@MainActor
final class FavoritesManager: ObservableObject {

    static let shared = FavoritesManager()

    // MARK: - Published

    @Published private(set) var favorites: [FavoriteVehicle] = []

    // MARK: - Private

    private let key = "bc_favorites_v1"

    private init() {
        load()
    }

    // MARK: - Public API

    func isFavorite(id: String) -> Bool {
        favorites.contains { $0.id == id }
    }

    func toggle(vehicle: FavoriteVehicle) {
        if isFavorite(id: vehicle.id) {
            favorites.removeAll { $0.id == vehicle.id }
        } else {
            favorites.insert(vehicle, at: 0)
        }
        save()
    }

    func add(_ vehicle: FavoriteVehicle) {
        guard !isFavorite(id: vehicle.id) else { return }
        favorites.insert(vehicle, at: 0)
        save()
    }

    func remove(id: String) {
        favorites.removeAll { $0.id == id }
        save()
    }

    func removeAll() {
        favorites.removeAll()
        save()
    }

    // MARK: - Persistance

    private func save() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([FavoriteVehicle].self, from: data)
        else { return }
        favorites = saved
    }
}
