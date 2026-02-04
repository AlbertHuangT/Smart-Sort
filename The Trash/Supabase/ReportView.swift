//
//  ReportView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI

struct ReportView: View {
    let predictedResult: TrashAnalysisResult
    let image: UIImage
    let userId: UUID?
    
    @Environment(\.dismiss) var dismiss
    
    // 对应垃圾桶分类
    let bins = ["Recycle (Blue Bin)", "Compost (Green Bin)", "Landfill (Black Bin)", "Hazardous"]
    
    @State private var selectedBin = "Landfill (Black Bin)"
    @State private var itemName = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI Prediction")) {
                    HStack {
                        Text("Identified as:")
                        Spacer()
                        Text(predictedResult.itemName).bold()
                    }
                    HStack {
                        Text("Category:")
                        Spacer()
                        Text(predictedResult.category)
                            .foregroundColor(predictedResult.color)
                    }
                }
                
                Section(header: Text("Your Correction (Human Feedback)")) {
                    Picker("Actually it is:", selection: $selectedBin) {
                        ForEach(bins, id: \.self) { bin in
                            Text(bin)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField("Correct Item Name (Optional)", text: $itemName)
                        .autocapitalization(.none)
                }
                
                Section {
                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView("Uploading Data...")
                            Spacer()
                        }
                    } else {
                        Button("Submit Feedback") {
                            submit()
                        }
                        .disabled(isSubmitting)
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Report Issue")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Thanks!", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your feedback helps make The Trash AI smarter.")
            }
            // 🔥 UX Fix: 自动预填选项
            .onAppear {
                // 如果 AI 的预测结果在我们已知的列表里，就自动选中它，方便用户微调
                if bins.contains(predictedResult.category) {
                    selectedBin = predictedResult.category
                }
            }
        }
    }
    
    func submit() {
        isSubmitting = true
        Task {
            do {
                try await FeedbackService.shared.submitFeedback(
                    image: image,
                    predictedLabel: predictedResult.itemName,
                    predictedCategory: predictedResult.category,
                    correctCategory: selectedBin,
                    comment: itemName,
                    userId: userId
                )
                // 成功
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                print("Feedback Error: \(error)")
                await MainActor.run {
                    isSubmitting = false
                }
            }
        }
    }
}
