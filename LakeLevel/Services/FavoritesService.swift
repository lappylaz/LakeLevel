//
//  FavoritesService.swift
//  LakeLevel
//
//  Created by Branson Blair on 1/24/26.
//

import Foundation

@MainActor
final class FavoritesService: ObservableObject {
    @Published private(set) var favoriteLakeIds: Set<String> = []

    private let userDefaultsKey = "favoriteLakes"

    init() {
        loadFavorites()
    }

    private func loadFavorites() {
        if let saved = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            favoriteLakeIds = Set(saved)
        }
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteLakeIds), forKey: userDefaultsKey)
    }

    func isFavorite(_ lake: Lake) -> Bool {
        favoriteLakeIds.contains(lake.id)
    }

    func toggleFavorite(_ lake: Lake) {
        if favoriteLakeIds.contains(lake.id) {
            favoriteLakeIds.remove(lake.id)
        } else {
            favoriteLakeIds.insert(lake.id)
        }
        saveFavorites()
    }

    func addFavorite(_ lake: Lake) {
        favoriteLakeIds.insert(lake.id)
        saveFavorites()
    }

    func removeFavorite(_ lake: Lake) {
        favoriteLakeIds.remove(lake.id)
        saveFavorites()
    }

    var favoriteLakes: [Lake] {
        LakeCatalog.lakes.filter { favoriteLakeIds.contains($0.id) }
    }
}
