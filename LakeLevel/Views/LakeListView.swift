//
//  LakeListView.swift
//  LakeLevel
//
//  Created by Branson Blair on 1/24/26.
//

import SwiftUI

struct LakeListView: View {
    @EnvironmentObject var favoritesService: FavoritesService
    @State private var searchText = ""
    @State private var selectedFilter: LakeFilter = .all

    enum LakeFilter: String, CaseIterable {
        case all = "All Lakes"
        case favorites = "Favorites"
    }

    private var filteredLakes: [Lake] {
        let lakes: [Lake]

        switch selectedFilter {
        case .all:
            lakes = LakeCatalog.search(searchText)
        case .favorites:
            if searchText.isEmpty {
                lakes = favoritesService.favoriteLakes
            } else {
                let lowercased = searchText.lowercased()
                lakes = favoritesService.favoriteLakes.filter {
                    $0.name.lowercased().contains(lowercased) ||
                    $0.state.lowercased().contains(lowercased)
                }
            }
        }

        return lakes.sorted { $0.name < $1.name }
    }

    private var groupedLakes: [String: [Lake]] {
        Dictionary(grouping: filteredLakes, by: { $0.state })
    }

    private var sortedStates: [String] {
        groupedLakes.keys.sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredLakes.isEmpty {
                    emptyStateView
                } else {
                    lakeList
                }
            }
            .navigationTitle("Lake Levels")
            .searchable(text: $searchText, prompt: "Search lakes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            ForEach(LakeFilter.allCases, id: \.self) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    HStack {
                        Text(filter.rawValue)
                        if filter == selectedFilter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: selectedFilter == .favorites ? "star.fill" : "line.3.horizontal.decrease.circle")
                .foregroundStyle(selectedFilter == .favorites ? .yellow : .blue)
        }
        .accessibilityLabel("Filter lakes")
        .accessibilityHint("Currently showing \(selectedFilter.rawValue.lowercased())")
    }

    private var lakeList: some View {
        List {
            ForEach(sortedStates, id: \.self) { state in
                Section(header: Text(stateName(for: state))) {
                    ForEach(groupedLakes[state] ?? []) { lake in
                        NavigationLink(value: lake) {
                            LakeRowView(lake: lake)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Lake.self) { lake in
            LakeDetailView(lake: lake)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(
                selectedFilter == .favorites ? "No Favorites" : "No Lakes Found",
                systemImage: selectedFilter == .favorites ? "star.slash" : "water.waves"
            )
        } description: {
            if selectedFilter == .favorites {
                Text("Lakes you mark as favorites will appear here.")
            } else {
                Text("Try a different search term.")
            }
        }
    }

    private func stateName(for abbreviation: String) -> String {
        let stateNames: [String: String] = [
            "AL": "Alabama", "AZ": "Arizona", "CA": "California",
            "FL": "Florida", "GA": "Georgia", "MI": "Michigan",
            "NC": "North Carolina", "NV": "Nevada", "NY": "New York",
            "OR": "Oregon", "SC": "South Carolina", "TN": "Tennessee",
            "TX": "Texas", "UT": "Utah", "VT": "Vermont",
            "WA": "Washington", "WI": "Wisconsin"
        ]
        return stateNames[abbreviation] ?? abbreviation
    }
}

#Preview {
    LakeListView()
        .environmentObject(FavoritesService())
}
