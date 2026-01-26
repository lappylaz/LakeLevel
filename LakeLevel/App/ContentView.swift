//
//  ContentView.swift
//  LakeLevel
//
//  Created by Branson Blair on 1/24/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        LakeListView()
    }
}

#Preview {
    ContentView()
        .environmentObject(FavoritesService())
}
