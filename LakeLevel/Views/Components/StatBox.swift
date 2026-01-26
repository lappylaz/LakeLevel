//
//  StatBox.swift
//  LakeLevel
//
//  Created by Branson Blair on 1/24/26.
//

import SwiftUI

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    HStack(spacing: 12) {
        StatBox(title: "High", value: "440.50", icon: "arrow.up", color: .green)
        StatBox(title: "Low", value: "438.20", icon: "arrow.down", color: .red)
        StatBox(title: "Average", value: "439.35", icon: "minus", color: .blue)
    }
    .padding()
}
