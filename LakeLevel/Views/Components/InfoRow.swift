//
//  InfoRow.swift
//  LakeLevel
//
//  Created by Branson Blair on 1/24/26.
//

import SwiftUI

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        InfoRow(label: "Source", value: "USGS Water Services")
        InfoRow(label: "Site", value: "02166500")
        InfoRow(label: "Location", value: "Lake Greenwood, SC")
    }
    .padding()
}
