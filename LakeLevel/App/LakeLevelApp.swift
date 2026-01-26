//
//  LakeLevelApp.swift
//  LakeLevel
//
//  Created by Branson Blair on 1/24/26.
//

import SwiftUI

@main
struct LakeLevelApp: App {
    @StateObject private var favoritesService = FavoritesService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(favoritesService)
        }
    }
}
