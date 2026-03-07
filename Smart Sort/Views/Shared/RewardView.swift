//
//  RewardView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/4/26.
//


import SwiftUI

struct RewardView: View {
    var body: some View {
        CompatibleContentUnavailableView {
            Label("Rewards", systemImage: "gift")
        } description: {
            Text("Rewards are coming soon. Stay tuned!")
        }
        .navigationTitle("Rewards")
    }
}
