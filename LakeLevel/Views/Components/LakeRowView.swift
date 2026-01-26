//
//  LakeRowView.swift
//  LakeLevel
//
//  Created by Branson Blair on 1/24/26.
//

import SwiftUI

struct LakeRowView: View {
    let lake: Lake
    @EnvironmentObject var favoritesService: FavoritesService

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "water.waves")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(lake.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text("Site: \(lake.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if favoritesService.isFavorite(lake) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        LakeRowView(lake: LakeCatalog.lakes[0])
        LakeRowView(lake: LakeCatalog.lakes[1])
    }
    .environmentObject(FavoritesService())
}
