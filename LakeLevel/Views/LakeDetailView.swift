//
//  LakeDetailView.swift
//  LakeLevel
//
//  Created by Branson Blair on 1/24/26.
//

import SwiftUI
import Charts

struct LakeDetailView: View {
    let lake: Lake
    @StateObject private var lakeLevelService = LakeLevelService()
    @EnvironmentObject var favoritesService: FavoritesService

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                currentLevelCard
                    .padding(.horizontal)

                periodPicker
                    .padding(.horizontal)

                if !lakeLevelService.historicalReadings.isEmpty {
                    chartSection
                        .padding(.horizontal)

                    statsSection
                        .padding(.horizontal)
                }

                infoSection
                    .padding(.horizontal)

                Spacer(minLength: 20)
            }
            .padding(.top)
        }
        .background(backgroundGradient)
        .navigationTitle(lake.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesService.toggleFavorite(lake)
                } label: {
                    Image(systemName: favoritesService.isFavorite(lake) ? "star.fill" : "star")
                        .foregroundStyle(favoritesService.isFavorite(lake) ? .yellow : .gray)
                }
                .accessibilityLabel(favoritesService.isFavorite(lake) ? "Remove from favorites" : "Add to favorites")
                .accessibilityHint("Double tap to \(favoritesService.isFavorite(lake) ? "remove" : "add") \(lake.name) \(favoritesService.isFavorite(lake) ? "from" : "to") favorites")
            }
        }
        .refreshable {
            await lakeLevelService.fetchLakeLevel(for: lake)
        }
        .onAppear {
            if lakeLevelService.currentLevel == nil {
                Task {
                    await lakeLevelService.fetchLakeLevel(for: lake)
                }
            }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Time Period", selection: $lakeLevelService.selectedPeriod) {
            ForEach(LakeLevelPeriod.allCases, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: lakeLevelService.selectedPeriod) { _, newPeriod in
            Task {
                await lakeLevelService.fetchLakeLevel(period: newPeriod)
            }
        }
        .accessibilityLabel("Select time period for historical data")
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.cyan.opacity(0.15),
                Color.blue.opacity(0.08),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Current Level Card

    private var currentLevelCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "water.waves")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)

                Text("Current Lake Level")
                    .font(.headline)

                Spacer()

                if lakeLevelService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accessibilityLabel("Loading")
                }
            }

            if let level = lakeLevelService.currentLevel {
                VStack(spacing: 8) {
                    // Cache indicator
                    if lakeLevelService.isFromCache {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise.icloud")
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text("Cached data from \(lakeLevelService.cacheAge)")
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityLabel("Showing cached data from \(lakeLevelService.cacheAge)")
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(level.valueFormatted)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(lakeLevelService.isFromCache ? .orange : .blue)

                        Text(level.unit)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Text(lake.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Updated: \(level.dateFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(currentLevelAccessibilityLabel(level: level))
            } else if let error = lakeLevelService.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)

                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        Task {
                            await lakeLevelService.fetchLakeLevel(for: lake)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Double tap to reload lake level data")
                }
                .padding(.vertical)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Error loading data: \(error)")
            } else if lakeLevelService.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .accessibilityHidden(true)
                    Text("Loading lake level data...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Loading lake level data")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Chart Section

    private var chartYDomain: ClosedRange<Double> {
        guard let minVal = lakeLevelService.minLevel,
              let maxVal = lakeLevelService.maxLevel else {
            return 0...100
        }

        let range = maxVal - minVal
        let minRange: Double = 2.0

        if range < minRange {
            let midpoint = (minVal + maxVal) / 2
            return (midpoint - minRange / 2)...(midpoint + minRange / 2)
        } else {
            let padding = range * 0.1
            return (minVal - padding)...(maxVal + padding)
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lakeLevelService.selectedPeriod.chartTitle)
                .font(.headline)

            Chart {
                ForEach(lakeLevelService.historicalReadings) { reading in
                    LineMark(
                        x: .value("Date", reading.dateTime),
                        y: .value("Level", reading.value)
                    )
                    .foregroundStyle(Color.blue.gradient)

                    AreaMark(
                        x: .value("Date", reading.dateTime),
                        y: .value("Level", reading.value)
                    )
                    .foregroundStyle(Color.blue.opacity(0.1).gradient)
                }
            }
            .chartYScale(domain: chartYDomain)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
            .accessibilityLabel(chartAccessibilityLabel)
            .accessibilityHint("Chart showing water level trends")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func currentLevelAccessibilityLabel(level: LakeLevel) -> String {
        var label = "Current water level: \(level.valueFormatted) \(level.unit) at \(lake.displayName). Updated \(level.dateFormatted)"
        if lakeLevelService.isFromCache {
            label += ". Showing cached data from \(lakeLevelService.cacheAge)"
        }
        return label
    }

    private var chartAccessibilityLabel: String {
        guard let min = lakeLevelService.minLevel,
              let max = lakeLevelService.maxLevel,
              let avg = lakeLevelService.averageLevel else {
            return "\(lakeLevelService.selectedPeriod.chartTitle) with \(lakeLevelService.historicalReadings.count) readings"
        }
        return "\(lakeLevelService.selectedPeriod.chartTitle). \(lakeLevelService.historicalReadings.count) readings. Range from \(String(format: "%.2f", min)) to \(String(format: "%.2f", max)), average \(String(format: "%.2f", avg))"
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(lakeLevelService.selectedPeriod.statsTitle)
                    .font(.headline)
                Spacer()
                Text("\(lakeLevelService.historicalReadings.count) readings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Show notice if using real-time data for longer periods
            if lakeLevelService.dataSource == "Real-time" && lakeLevelService.selectedPeriod != .sevenDays {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text("Historical data not available. Showing recent real-time data only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Note: Historical data not available. Showing recent real-time data only.")
            }

            HStack(spacing: 12) {
                StatBox(
                    title: "High",
                    value: lakeLevelService.maxLevel.map { String(format: "%.2f", $0) } ?? "--",
                    icon: "arrow.up",
                    color: .green
                )

                StatBox(
                    title: "Low",
                    value: lakeLevelService.minLevel.map { String(format: "%.2f", $0) } ?? "--",
                    icon: "arrow.down",
                    color: .red
                )

                StatBox(
                    title: "Average",
                    value: lakeLevelService.averageLevel.map { String(format: "%.2f", $0) } ?? "--",
                    icon: "minus",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text("About This Data")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Source", value: "USGS Water Services")
                InfoRow(label: "Site", value: lake.id)
                InfoRow(label: "Location", value: lake.displayName)
                InfoRow(label: "Measurement", value: "Water Surface Elevation")
            }

            if let usgsURL = lake.usgsURL {
                Link(destination: usgsURL) {
                    HStack {
                        Text("View on USGS Website")
                            .font(.subheadline)
                        Image(systemName: "arrow.up.right.square")
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.blue)
                }
                .padding(.top, 4)
                .accessibilityLabel("View \(lake.name) on USGS Website")
                .accessibilityHint("Opens in Safari")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    NavigationStack {
        LakeDetailView(lake: LakeCatalog.lakes[0])
            .environmentObject(FavoritesService())
    }
}
